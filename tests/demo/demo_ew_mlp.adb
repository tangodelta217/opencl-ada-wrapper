with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with EW_MLP_Kernel_Source;
with EW_MLP_Model;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Kernels;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.RT.Loader;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;
with Smoke_RT_Test_Verifier;
with System;

procedure Demo_EW_MLP is
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Model renames EW_MLP_Model;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package Security renames OpenCL.RT.Security;

   use type Ada.Directories.File_Kind;
   use type Ada.Calendar.Time;
   use type Errors.Status_Code;
   use type GNAT.OS_Lib.String_Access;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.C.unsigned_char;

   Local_Logs_Dir_Rel : constant String := "docs/VV/Execution_Logs/local";
   Plugin_Build_Script_Rel : constant String :=
     "tools/crypto_provider_ref/build.sh";
   Plugin_SO_Rel : constant String :=
     "tools/crypto_provider_ref/liboclw_crypto_provider_ref.so";
   Plugin_Symbol : constant String := "oclw_kpack_verify_v1";

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Batch_Samples : constant Positive := 1024;

   subtype Sample_Index is Natural range 0 .. Batch_Samples - 1;
   subtype Output_Index is Model.Output_Index;

   type Input_Flat_Array is
     array (Natural range 0 .. Batch_Samples * Model.Input_Size - 1) of
       aliased Interfaces.C.unsigned_char;
   type Logits_Flat_Array is
     array (Natural range 0 .. Batch_Samples * Model.Output_Size - 1) of
       aliased Interfaces.C.int;
   type Class_Flat_Array is
     array (Natural range 0 .. Batch_Samples - 1) of
       aliased Interfaces.C.unsigned_char;
   type Confusion_Matrix is array (Output_Index, Output_Index) of Natural;

   Input_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Batch_Samples * Model.Input_Size);
   Logits_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t
       (Batch_Samples
        * Model.Output_Size
        * (Interfaces.C.int'Size / System.Storage_Unit));
   Class_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Batch_Samples);

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Trim_Natural_Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Natural_Image;

   function Trim_Long_Float_Image (Value : Long_Float) return String is
      Raw : constant String := Long_Float'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Long_Float_Image;

   function Trim_LLI_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_LLI_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function UTC_Compact return String is
      Raw : constant String :=
        Ada.Calendar.Formatting.Image
          (Date => Ada.Calendar.Clock,
           Include_Time_Fraction => False,
           Time_Zone => 0);
   begin
      if Raw'Length >= 19 then
         return
           Raw (Raw'First .. Raw'First + 3)
           & Raw (Raw'First + 5 .. Raw'First + 6)
           & Raw (Raw'First + 8 .. Raw'First + 9)
           & "T"
           & Raw (Raw'First + 11 .. Raw'First + 12)
           & Raw (Raw'First + 14 .. Raw'First + 15)
           & Raw (Raw'First + 17 .. Raw'First + 18)
           & "Z";
      else
         return "00000000T000000Z";
      end if;
   end UTC_Compact;

   function Candidate_From_Self (Relative_Path : String) return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Parent_1 : constant String := Ada.Directories.Containing_Directory (Self_Dir);
      Parent_2 : constant String := Ada.Directories.Containing_Directory (Parent_1);
   begin
      if Parent_2'Length = 0 then
         return Relative_Path;
      else
         return Parent_2 & "/" & Relative_Path;
      end if;
   exception
      when others =>
         return Relative_Path;
   end Candidate_From_Self;

   function Locate_Path (Relative_Path : String) return String is
      Candidate_1 : constant String := Relative_Path;
      Candidate_2 : constant String := Candidate_From_Self (Relative_Path);
   begin
      if Ada.Directories.Exists (Candidate_1) then
         return Candidate_1;
      elsif Ada.Directories.Exists (Candidate_2) then
         return Candidate_2;
      else
         return Relative_Path;
      end if;
   end Locate_Path;

   function Locate_Gen_Pack_EW_MLP return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Candidate_1 : constant String := Self_Dir & "/gen_pack_ew_mlp";
      Candidate_2 : constant String := "tests/bin/gen_pack_ew_mlp";
      Candidate_3 : constant String := Candidate_From_Self ("tests/bin/gen_pack_ew_mlp");
   begin
      if Ada.Directories.Exists (Candidate_1) then
         return Candidate_1;
      elsif Ada.Directories.Exists (Candidate_2) then
         return Candidate_2;
      elsif Ada.Directories.Exists (Candidate_3) then
         return Candidate_3;
      else
         return "";
      end if;
   end Locate_Gen_Pack_EW_MLP;

   function Ensure_Reference_Plugin
     (Build_Log_Path : String;
      Plugin_Path : out Packs.Bounded_String;
      Skip_Reason : out Packs.Bounded_String) return Boolean
   is
      Build_Script : constant String := Locate_Path (Plugin_Build_Script_Rel);
      Plugin_SO : constant String := Locate_Path (Plugin_SO_Rel);
      GCC_Path : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("gcc");
      Args : GNAT.OS_Lib.Argument_List (1 .. 1);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      Plugin_Path := Packs.To_Bounded ("");
      Skip_Reason := Packs.To_Bounded ("");

      if GCC_Path = null then
         Skip_Reason := Packs.To_Bounded ("gcc_not_found");
         return False;
      end if;
      GNAT.OS_Lib.Free (GCC_Path);

      if not Ada.Directories.Exists (Build_Script) then
         Skip_Reason := Packs.To_Bounded ("plugin_build_script_not_found");
         return False;
      end if;

      Args (1) := new String'(Build_Script);
      GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/bash",
         Args => Args,
         Output_File => Build_Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));

      if not Success or else Return_Code /= 0 then
         Skip_Reason := Packs.To_Bounded ("plugin_build_failed");
         return False;
      end if;

      if not Ada.Directories.Exists (Plugin_SO) then
         Skip_Reason := Packs.To_Bounded ("plugin_so_not_found");
         return False;
      end if;

      Plugin_Path := Packs.To_Bounded (Ada.Directories.Full_Name (Plugin_SO));
      return True;
   end Ensure_Reference_Plugin;

   function Generate_Offline_Pack
     (Pack_Dir : String;
      Manifest_Path : String;
      Binary_Path : String;
      Gen_Log_Path : String) return Boolean
   is
      Gen_Exec : constant String := Locate_Gen_Pack_EW_MLP;
      Args : GNAT.OS_Lib.Argument_List (1 .. 1);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      if Gen_Exec'Length = 0 then
         return False;
      end if;

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      Ada.Environment_Variables.Set ("OCLW_PACK_DIR", Pack_Dir);
      Args (1) := new String'("");
      GNAT.OS_Lib.Spawn
        (Program_Name => Gen_Exec,
         Args => Args,
         Output_File => Gen_Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));

      return
        Success
        and then Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Generate_Offline_Pack;

   procedure Prepare_Signed_Metadata
     (Meta : in out Packs.Pack_Metadata;
      Bin : Programs.Byte_Array;
      Used : Natural;
      Status : out Errors.Status_Code)
   is
   begin
      Status := Errors.Success;

      Meta.Signature_Required := True;
      Meta.Signature_Alg := Packs.To_Bounded ("CMS-PKCS7-SHA256");
      Meta.Signer_Id := Packs.To_Bounded ("OCLW-EW-MLP-DEMO");
      Meta.Signature_Value := Packs.To_Bounded ("");

      declare
         Signing_Text : constant String := Packs.Canonical_Signing_Text (Meta);
         Signature : constant String :=
           Smoke_RT_Test_Verifier.Compute_Test_Signature
             (Signing_Text => Signing_Text,
              Bin => Bin,
              Used => Used);
      begin
         if Signing_Text'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            return;
         end if;

         if Signature'Length = 0 then
            Status := Errors.OCLW_Signature_Invalid;
            return;
         end if;

         Meta.Signature_Value := Packs.To_Bounded (Signature);
      end;
   end Prepare_Signed_Metadata;

   procedure Select_First_Device
     (Platform : out Core.Platform;
      Device : out Core.Device;
      Status : out Errors.Status_Code)
   is
      Platforms : Core.Platform_List (1 .. Max_Platforms);
      Devices : Core.Device_List (1 .. Max_Devices);
      Platform_Used : Natural := 0;
      Device_Used : Natural := 0;
      Null_Platform : Core.Platform;
      Null_Device : Core.Device;
   begin
      Platform := Null_Platform;
      Device := Null_Device;
      Status := Errors.Success;

      Core.Enumerate_Platforms
        (Out_Platforms => Platforms,
         Used => Platform_Used,
         Status => Status);
      if Platform_Used = 0 then
         return;
      end if;

      Core.Enumerate_Devices
        (P => Platforms (Platforms'First),
         Out_Devices => Devices,
         Used => Device_Used,
         Status => Status);
      if Device_Used = 0 then
         return;
      end if;

      Platform := Platforms (Platforms'First);
      Device := Devices (Devices'First);
      Status := Errors.Success;
   end Select_First_Device;

   function Safe_Platform_Info
     (P : Core.Platform;
      What : Core.Platform_Info_Kind) return String
   is
      Info_Status : Errors.Status_Code := Errors.Success;
      Value : constant String :=
        Core.Get_Platform_Info
          (P => P,
           What => What,
           Status => Info_Status,
           Max_Bytes => Core.Default_Max_Info_Bytes);
   begin
      if Errors.Is_Success (Info_Status) and then Value'Length > 0 then
         return Value;
      end if;
      return "<unknown>";
   end Safe_Platform_Info;

   function Safe_Device_Info
     (D : Core.Device;
      What : Core.Device_Info_Kind) return String
   is
      Info_Status : Errors.Status_Code := Errors.Success;
      Value : constant String :=
        Core.Get_Device_Info
          (D => D,
           What => What,
           Status => Info_Status,
           Max_Bytes => Core.Default_Max_Info_Bytes);
   begin
      if Errors.Is_Success (Info_Status) and then Value'Length > 0 then
         return Value;
      end if;
      return "<unknown>";
   end Safe_Device_Info;

   X_Batch : Model.Batch_Byte_Array (Sample_Index);
   Labels_Expected : Model.Batch_Class_Array (Sample_Index);
   Classes_CPU : Model.Batch_Class_Array (Sample_Index);
   Logits_CPU : Model.Batch_Logit_Array (Sample_Index);

   X_Flat : Input_Flat_Array := (others => 0);
   Logits_Device : Logits_Flat_Array := (others => 0);
   Classes_Device : Class_Flat_Array := (others => 0);

   Binary_Data : Program_Byte_Array_Access := null;
   Binary_Used : Natural := 0;

   Platform : Core.Platform;
   Device : Core.Device;
   Default_Platform : Core.Platform;
   Default_Device : Core.Device;
   Ctx : Contexts.Context;
   Q : Queues.Queue;
   X_Buffer : Buffers.Buffer;
   Logits_Buffer : Buffers.Buffer;
   Class_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;

   procedure Mark_Fail (Step : String; Code : Errors.Status_Code) is
   begin
      Ada.Text_IO.Put_Line
        ("ERROR "
         & Step
         & ": "
         & Errors.Image (Code)
         & " status_int="
         & Status_Int_Image (Code));
      Failed := True;
   end Mark_Fail;

   procedure Cleanup is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Kernels.Release (K => K, Status => Release_Status);
      Programs.Release (Prg => Prg, Status => Release_Status);
      Buffers.Release (B => Class_Buffer, Status => Release_Status);
      Buffers.Release (B => Logits_Buffer, Status => Release_Status);
      Buffers.Release (B => X_Buffer, Status => Release_Status);
      Queues.Release (Q => Q, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;
   end Cleanup;

begin
   declare
      Timestamp : constant String := UTC_Compact;
      Pack_Dir : constant String :=
        Local_Logs_Dir_Rel & "/" & Timestamp & "_demo_ew_mlp_pack";
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      Gen_Log_Path : constant String := Pack_Dir & "/gen_pack_ew_mlp.log";
      Plugin_Log_Path : constant String := Pack_Dir & "/crypto_plugin_build.log";

      Meta_Unsigned : Packs.Pack_Metadata;
      Meta_Signed : Packs.Pack_Metadata;

      Plugin_Path : Packs.Bounded_String := Packs.To_Bounded ("");
      Plugin_Skip_Reason : Packs.Bounded_String := Packs.To_Bounded ("");

      Has_RT_Pack : Boolean := False;
      Program_Ready : Boolean := False;
      Strict_Attempted : Boolean := False;
      Execution_Mode : Packs.Bounded_String := Packs.To_Bounded ("DEV_JIT");
      Kernel_Name_Text : Packs.Bounded_String := Packs.To_Bounded (EW_MLP_Kernel_Source.Kernel_Name);
   begin
      Ada.Text_IO.Put_Line ("INFO demo=ew_mlp");
      Ada.Text_IO.Put_Line ("INFO mlp_shape=in64_hidden96_out4");
      Ada.Text_IO.Put_Line ("INFO quant=int_only_u8_i8_i32");
      Ada.Text_IO.Put_Line ("INFO batch=" & Trim_Natural_Image (Batch_Samples));

      if not Model.Self_Check then
         Ada.Text_IO.Put_Line ("ERROR cpu_self_check=FAIL");
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Model.Make_Batch
        (X => X_Batch,
         Labels => Labels_Expected,
         Start_Sample_Index => 0);
      Model.Infer_CPU_Batch
        (X => X_Batch,
         Logits => Logits_CPU,
         Classes => Classes_CPU);

      Select_First_Device
        (Platform => Default_Platform,
         Device => Default_Device,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason=" & Errors.Image (Status));
         return;
      end if;

      Platform := Default_Platform;
      Device := Default_Device;
      Ada.Text_IO.Put_Line
        ("INFO fingerprint_name="
         & Safe_Device_Info (Device, Core.Name));
      Ada.Text_IO.Put_Line
        ("INFO fingerprint_vendor="
         & Safe_Device_Info (Device, Core.Vendor));
      Ada.Text_IO.Put_Line
        ("INFO fingerprint_driver="
         & Safe_Device_Info (Device, Core.Driver_Version));
      Ada.Text_IO.Put_Line
        ("INFO fingerprint_version="
         & Safe_Device_Info (Device, Core.Version));

      for S in Sample_Index loop
         for F in Model.Feature_Index loop
            X_Flat (Natural (S) * Model.Input_Size + Natural (F)) :=
              Interfaces.C.unsigned_char (X_Batch (S) (F));
         end loop;
      end loop;

      Has_RT_Pack :=
        Generate_Offline_Pack
          (Pack_Dir => Pack_Dir,
           Manifest_Path => Manifest_Path,
           Binary_Path => Binary_Path,
           Gen_Log_Path => Gen_Log_Path);
      Ada.Text_IO.Put_Line
        ("INFO rt_pack_generation="
         & (if Has_RT_Pack then "PASS" else "FAIL"));

      if Has_RT_Pack then
         Packs.Read_Manifest
           (Path => Manifest_Path,
            Meta => Meta_Unsigned,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Has_RT_Pack := False;
         end if;
      end if;

      if Has_RT_Pack then
         if Meta_Unsigned.Binary_Size = 0
           or else Meta_Unsigned.Binary_Size > Interfaces.C.size_t (Positive'Last)
         then
            Has_RT_Pack := False;
         else
            Binary_Data :=
              new Programs.Byte_Array (1 .. Positive (Integer (Meta_Unsigned.Binary_Size)));
            Packs.Read_Binary
              (Path => Binary_Path,
               Buffer => Binary_Data.all,
               Used => Binary_Used,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Has_RT_Pack := False;
            end if;

            if Has_RT_Pack then
               Packs.Verify_Binary
                 (Meta => Meta_Unsigned,
                  Buffer => Binary_Data.all,
                  Used => Binary_Used,
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Has_RT_Pack := False;
               end if;
            end if;
         end if;
      end if;

      if Has_RT_Pack then
         Loader.Select_Device
           (Meta => Meta_Unsigned,
            Platform => Platform,
            Device => Device,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Has_RT_Pack := False;
            Platform := Default_Platform;
            Device := Default_Device;
         end if;
      end if;

      Contexts.Create
        (Device => Device,
         Ctx => Ctx,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_context", Status);
      end if;

      if not Failed then
         Queues.Create
           (Ctx => Ctx,
            Dev => Device,
            Q => Q,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_queue", Status);
         end if;
      end if;

      if not Failed and then Has_RT_Pack then
         Strict_Attempted :=
           Ensure_Reference_Plugin
             (Build_Log_Path => Plugin_Log_Path,
              Plugin_Path => Plugin_Path,
              Skip_Reason => Plugin_Skip_Reason);

         if Strict_Attempted then
            Meta_Signed := Meta_Unsigned;
            Prepare_Signed_Metadata
              (Meta => Meta_Signed,
               Bin => Binary_Data.all,
               Used => Binary_Used,
               Status => Status);

            if Errors.Is_Success (Status) then
               Packs.Write_Manifest
                 (Path => Manifest_Path,
                  Meta => Meta_Signed,
                  Status => Status);
            end if;

            if Errors.Is_Success (Status) then
               Ada.Environment_Variables.Set
                 (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
                  Value =>
                    Ada.Directories.Containing_Directory
                      (Packs.To_String (Plugin_Path)));
               Security.Install_Verifier (V => null);
               Security.Configure_Plugin
                 (Path => Packs.To_String (Plugin_Path),
                  Symbol => Plugin_Symbol,
                  Status => Status);
            end if;

            if Errors.Is_Success (Status) then
               Loader.Create_Program_From_Pack_Strict_RT
                 (Ctx => Ctx,
                  Dev => Device,
                  Meta => Meta_Signed,
                  Bin => Binary_Data.all,
                  Used => Binary_Used,
                  Prg => Prg,
                  Status => Status);
            end if;

            if Errors.Is_Success (Status) then
               Program_Ready := True;
               Execution_Mode := Packs.To_Bounded ("RT_NOJIT");
               Kernel_Name_Text := Meta_Signed.Kernel_Name;
            end if;
         end if;

         if not Program_Ready then
            Loader.Create_Program_From_Pack
              (Ctx => Ctx,
               Dev => Device,
               Meta => Meta_Unsigned,
               Bin => Binary_Data.all,
               Used => Binary_Used,
               Prg => Prg,
               Status => Status);
            if Errors.Is_Success (Status) then
               Program_Ready := True;
               Execution_Mode := Packs.To_Bounded ("RT_NOJIT");
               Kernel_Name_Text := Meta_Unsigned.Kernel_Name;
            end if;
         end if;
      end if;

      if not Failed and then not Program_Ready then
         Programs.Create_From_Source
           (Ctx => Ctx,
            Source => EW_MLP_Kernel_Source.Source,
            Prg => Prg,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_program_from_source", Status);
         end if;

         if not Failed then
            Programs.Build
              (Prg => Prg,
               Dev => Device,
               Options => EW_MLP_Kernel_Source.Build_Options,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("build_program_source", Status);
            end if;
         end if;

         if not Failed then
            Program_Ready := True;
            Execution_Mode := Packs.To_Bounded ("DEV_SOURCE_FALLBACK");
            Kernel_Name_Text := Packs.To_Bounded (EW_MLP_Kernel_Source.Kernel_Name);
         end if;
      end if;

      if not Failed and then Program_Ready then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Input_Bytes,
            B => X_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_x_buffer", Status);
         end if;
      end if;

      if not Failed and then Program_Ready then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Logits_Bytes,
            B => Logits_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_logits_buffer", Status);
         end if;
      end if;

      if not Failed and then Program_Ready then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Class_Bytes,
            B => Class_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_class_buffer", Status);
         end if;
      end if;

      if not Failed and then Program_Ready then
         declare
            Kernel_Name : constant String :=
              Ada.Strings.Fixed.Trim
                (Packs.To_String (Kernel_Name_Text),
                 Ada.Strings.Both);
         begin
            Kernels.Create
              (Prg => Prg,
               Name => Kernel_Name,
               K => K,
               Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("create_kernel", Status);
               end if;
            end;
         end if;

         if not Failed then
            Ada.Text_IO.Put_Line ("INFO mode=" & Packs.To_String (Execution_Mode));
         end if;

      if not Failed then
         Kernels.Set_Arg_Buffer (K => K, Index => 0, B => X_Buffer, Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_x", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer (K => K, Index => 1, B => Logits_Buffer, Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_logits", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer (K => K, Index => 2, B => Class_Buffer, Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_cls", Status);
         end if;
      end if;

      if not Failed then
         declare
            Start_Time : constant Ada.Calendar.Time := Ada.Calendar.Clock;
            Stop_Time : Ada.Calendar.Time := Start_Time;
         begin
            Buffers.Write
              (Q => Q,
               B => X_Buffer,
               Host => X_Flat (X_Flat'First)'Address,
               Bytes => Input_Bytes,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("write_x", Status);
            end if;

            if not Failed then
               Kernels.Enqueue_1D
                 (Q => Q,
                  K => K,
                  Global_Size => Interfaces.C.size_t (Batch_Samples),
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("enqueue_1d", Status);
               end if;
            end if;

            if not Failed then
               Queues.Finish (Q => Q, Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("finish_queue", Status);
               end if;
            end if;

            if not Failed then
               Buffers.Read
                 (Q => Q,
                  B => Class_Buffer,
                  Host => Classes_Device (Classes_Device'First)'Address,
                  Bytes => Class_Bytes,
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("read_classes", Status);
               end if;
            end if;

            if not Failed then
               Stop_Time := Ada.Calendar.Clock;

               declare
                  Host_Seconds : constant Long_Float :=
                    Long_Float (Stop_Time - Start_Time);
                  Host_Ns : constant Long_Long_Integer :=
                    Long_Long_Integer
                      (Host_Seconds * 1_000_000_000.0 + 0.5);
                  Throughput : constant Long_Long_Integer :=
                    (if Host_Seconds > 0.0
                     then Long_Long_Integer
                       (Long_Float (Batch_Samples) / Host_Seconds + 0.5)
                     else 0);

                  Class_Mismatch_Count : Natural := 0;
                  CPU_Expected_Mismatch_Count : Natural := 0;
                  Out_Of_Range_Class_Count : Natural := 0;
                  Correct_Count : Natural := 0;
                  CM : Confusion_Matrix := (others => (others => 0));
               begin
                  for S in Sample_Index loop
                     declare
                        Expected : constant Natural := Natural (Labels_Expected (S));
                        CPU_Class : constant Natural := Natural (Classes_CPU (S));
                        Device_Class : constant Natural := Natural (Classes_Device (S));
                     begin
                        if CPU_Class /= Expected then
                           CPU_Expected_Mismatch_Count := CPU_Expected_Mismatch_Count + 1;
                        end if;

                        if Device_Class <= Output_Index'Last then
                           CM (Output_Index (Expected), Output_Index (Device_Class)) :=
                             CM (Output_Index (Expected), Output_Index (Device_Class)) + 1;
                        else
                           Out_Of_Range_Class_Count := Out_Of_Range_Class_Count + 1;
                        end if;

                        if Device_Class = Expected then
                           Correct_Count := Correct_Count + 1;
                        end if;

                        if Device_Class /= CPU_Class or else Device_Class /= Expected then
                           Class_Mismatch_Count := Class_Mismatch_Count + 1;
                        end if;
                     end;
                  end loop;

                  Ada.Text_IO.Put_Line
                    ("INFO fingerprint_platform="
                     & Safe_Platform_Info (Platform, Core.Name));
                  Ada.Text_IO.Put_Line
                    ("INFO fingerprint_vendor="
                     & Safe_Device_Info (Device, Core.Vendor));
                  Ada.Text_IO.Put_Line
                    ("INFO fingerprint_driver="
                     & Safe_Device_Info (Device, Core.Driver_Version));
                  Ada.Text_IO.Put_Line
                    ("INFO strict_signature="
                     & (if Strict_Attempted then "ATTEMPTED" else "UNAVAILABLE"));
                  Ada.Text_IO.Put_Line
                    ("INFO latency_host_ns=" & Trim_LLI_Image (Host_Ns));
                  Ada.Text_IO.Put_Line
                    ("INFO throughput_vectors_per_sec="
                     & Trim_LLI_Image (Throughput));
                  Ada.Text_IO.Put_Line
                    ("INFO accuracy="
                     & Trim_Natural_Image (Correct_Count)
                     & "/"
                     & Trim_Natural_Image (Batch_Samples));

                  for R in Output_Index loop
                     Ada.Text_IO.Put_Line
                       ("INFO confusion_row_"
                        & Trim_Natural_Image (Natural (R))
                        & "="
                        & Trim_Natural_Image (CM (R, 0))
                        & ","
                        & Trim_Natural_Image (CM (R, 1))
                        & ","
                        & Trim_Natural_Image (CM (R, 2))
                        & ","
                        & Trim_Natural_Image (CM (R, 3)));
                  end loop;

                  for Class_Id in Output_Index loop
                     declare
                        S : constant Sample_Index := Sample_Index (Natural (Class_Id));
                        Sum_Band_0 : Natural := 0;
                        Sum_Band_1 : Natural := 0;
                        Sum_Band_2 : Natural := 0;
                        Sum_Band_3 : Natural := 0;
                     begin
                        for F in Model.Feature_Index loop
                           declare
                              V : constant Natural := Natural (X_Batch (S) (F));
                              Band : constant Natural := Natural (F) / 16;
                           begin
                              case Band is
                                 when 0 =>
                                    Sum_Band_0 := Sum_Band_0 + V;
                                 when 1 =>
                                    Sum_Band_1 := Sum_Band_1 + V;
                                 when 2 =>
                                    Sum_Band_2 := Sum_Band_2 + V;
                                 when others =>
                                    Sum_Band_3 := Sum_Band_3 + V;
                              end case;
                           end;
                        end loop;

                        Ada.Text_IO.Put_Line
                          ("INFO visual_class_"
                           & Trim_Natural_Image (Natural (Class_Id))
                           & " sum_band0="
                           & Trim_Natural_Image (Sum_Band_0)
                           & " sum_band1="
                           & Trim_Natural_Image (Sum_Band_1)
                           & " sum_band2="
                           & Trim_Natural_Image (Sum_Band_2)
                           & " sum_band3="
                           & Trim_Natural_Image (Sum_Band_3)
                           & " predicted="
                           & Trim_Natural_Image (Natural (Classes_Device (S)))
                           & " expected="
                           & Trim_Natural_Image (Natural (Labels_Expected (S))));
                     end;
                  end loop;

                  if Class_Mismatch_Count > 0
                    or else CPU_Expected_Mismatch_Count > 0
                    or else Out_Of_Range_Class_Count > 0
                  then
                     Failed := True;
                  end if;
               end;
            end if;
         end;
      end if;

      Cleanup;

      if Failed then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      else
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      end if;
   exception
      when others =>
         Cleanup;
         Ada.Text_IO.Put_Line
           ("ERROR unhandled_exception: "
            & Errors.Image (Errors.OCLW_IO_Error)
            & " status_int="
            & Status_Int_Image (Errors.OCLW_IO_Error));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end;
end Demo_EW_MLP;
