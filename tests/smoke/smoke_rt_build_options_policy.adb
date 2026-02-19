with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
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
with Smoke_RT_Build_Options_Verifier;
with Smoke_RT_Test_Verifier;

procedure Smoke_RT_Build_Options_Policy is
   --  OCLW-TST-0022: RT strict build options allow/deny policy.
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package Security renames OpenCL.RT.Security;

   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;

   Default_Pack_Dir : constant String :=
     "docs/VV/Execution_Logs/local/pack_rt_build_options_policy";
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;

   subtype Byte is Interfaces.Unsigned_8;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Host_Byte_Array is array (Byte_Index) of aliased Byte;

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Resolve_Pack_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("OCLW_PACK_DIR") then
         declare
            Value : constant String := Ada.Environment_Variables.Value ("OCLW_PACK_DIR");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return Default_Pack_Dir;
   end Resolve_Pack_Dir;

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

   function Locate_Gen_Pack_Add1 return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Candidate_1 : constant String := Self_Dir & "/gen_pack_add1";
      Candidate_2 : constant String := "tests/bin/gen_pack_add1";
      Candidate_3 : constant String := Candidate_From_Self ("tests/bin/gen_pack_add1");
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
   end Locate_Gen_Pack_Add1;

   function Ensure_Base_Pack
     (Pack_Dir : String;
      Manifest_Path : String;
      Binary_Path : String) return Boolean
   is
      Gen_Exec : constant String := Locate_Gen_Pack_Add1;
      Args : GNAT.OS_Lib.Argument_List (1 .. 1);
      Success : Boolean := False;
      Return_Code : Integer := 0;
      Gen_Log_Path : constant String := Pack_Dir & "/gen_pack_add1.log";
   begin
      if Gen_Exec'Length = 0 then
         Ada.Text_IO.Put_Line ("WARN missing_gen_pack_add1_executable");
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

      Ada.Text_IO.Put_Line
        ("INFO gen_pack_add1_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Gen_Log_Path);

      return
        Success
        and then Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Ensure_Base_Pack;

   procedure Execute_Add1_Strict
     (Meta : Packs.Pack_Metadata;
      Bin : Programs.Byte_Array;
      Used : Natural;
      Status : out Errors.Status_Code)
   is
      Input_Data : Host_Byte_Array := (others => 0);
      Output_Data : Host_Byte_Array := (others => 0);

      Platform : Core.Platform;
      Device : Core.Device;
      Ctx : Contexts.Context;
      Q : Queues.Queue;
      In_Buffer : Buffers.Buffer;
      Out_Buffer : Buffers.Buffer;
      Prg : Programs.Program;
      K : Kernels.Kernel;

      Release_Status : Errors.Status_Code := Errors.Success;

      procedure Cleanup is
      begin
         Kernels.Release (K => K, Status => Release_Status);
         Buffers.Release (B => Out_Buffer, Status => Release_Status);
         Buffers.Release (B => In_Buffer, Status => Release_Status);
         Programs.Release (Prg => Prg, Status => Release_Status);
         Queues.Release (Q => Q, Status => Release_Status);
         Contexts.Release (Ctx => Ctx, Status => Release_Status);
      end Cleanup;
   begin
      Status := Errors.Success;

      Loader.Select_Device
        (Meta => Meta,
         Platform => Platform,
         Device => Device,
         Status => Status);
      if Status /= Errors.Success then
         return;
      end if;

      Contexts.Create
        (Device => Device,
         Ctx => Ctx,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Queues.Create
        (Ctx => Ctx,
         Dev => Device,
         Q => Q,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Loader.Create_Program_From_Pack_Strict_RT
        (Ctx => Ctx,
         Dev => Device,
         Meta => Meta,
         Bin => Bin,
         Used => Used,
         Prg => Prg,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Buffers.Create
        (Ctx => Ctx,
         Bytes => Transfer_Bytes,
         B => In_Buffer,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Buffers.Create
        (Ctx => Ctx,
         Bytes => Transfer_Bytes,
         B => Out_Buffer,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      for I in Input_Data'Range loop
         Input_Data (I) := Byte (I mod 256);
      end loop;

      Buffers.Write
        (Q => Q,
         B => In_Buffer,
         Host => Input_Data (Input_Data'First)'Address,
         Bytes => Transfer_Bytes,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      declare
         Kernel_Name : constant String := Trimmed (Packs.To_String (Meta.Kernel_Name));
      begin
         if Kernel_Name'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            Cleanup;
            return;
         end if;

         Kernels.Create
           (Prg => Prg,
            Name => Kernel_Name,
            K => K,
            Status => Status);
      end;
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Kernels.Set_Arg_Buffer
        (K => K,
         Index => 0,
         B => In_Buffer,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Kernels.Set_Arg_Buffer
        (K => K,
         Index => 1,
         B => Out_Buffer,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Kernels.Enqueue_1D
        (Q => Q,
         K => K,
         Global_Size => Transfer_Bytes,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Buffers.Read
        (Q => Q,
         B => Out_Buffer,
         Host => Output_Data (Output_Data'First)'Address,
         Bytes => Transfer_Bytes,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      for I in Output_Data'Range loop
         declare
            Expected : constant Byte := Byte ((I + 1) mod 256);
         begin
            if Output_Data (I) /= Expected then
               Status := Errors.Invalid_Value;
               Cleanup;
               return;
            end if;
         end;
      end loop;

      Cleanup;
   exception
      when others =>
         Cleanup;
         Status := Errors.OCLW_IO_Error;
   end Execute_Add1_Strict;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";

      Status : Errors.Status_Code := Errors.Success;
      Case_Allow_Pass : Boolean := False;
      Case_Deny_Pass : Boolean := False;

      Meta_Base : Packs.Pack_Metadata;
      Meta_Allow : Packs.Pack_Metadata;
      Meta_Deny : Packs.Pack_Metadata;

      Binary_Data : Program_Byte_Array_Access := null;
      Binary_Used : Natural := 0;
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO manifest_path=" & Manifest_Path);
      Ada.Text_IO.Put_Line ("INFO binary_path=" & Binary_Path);

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      if not Ensure_Base_Pack (Pack_Dir, Manifest_Path, Binary_Path) then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=pack_generation_failed");
         return;
      end if;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta_Base,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR read_manifest_base: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      if Meta_Base.Binary_Size = 0
        or else Meta_Base.Binary_Size > Interfaces.C.size_t (Positive'Last)
      then
         Ada.Text_IO.Put_Line
           ("ERROR invalid_binary_size_in_manifest status_int="
            & Status_Int_Image (Errors.OCLW_Pack_Format_Error));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Binary_Data :=
        new Programs.Byte_Array (1 .. Positive (Integer (Meta_Base.Binary_Size)));
      Packs.Read_Binary
        (Path => Binary_Path,
         Buffer => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR read_binary_base: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      if Binary_Used = 0 then
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("ERROR binary_used_zero");
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Security.Install_Verifier
        (V => Smoke_RT_Build_Options_Verifier.Verify'Access);

      --  Allow case: strict policy must accept empty/"-cl-std=CL1.2".
      Meta_Allow := Meta_Base;
      Meta_Allow.Signature_Required := True;
      Meta_Allow.Signature_Alg := Packs.To_Bounded ("CMS-PKCS7-SHA256");
      Meta_Allow.Signer_Id := Packs.To_Bounded ("OCLW-BUILD-OPT-POLICY");
      Meta_Allow.Build_Options := Packs.To_Bounded ("-cl-std=CL1.2");
      Meta_Allow.Signature_Value := Packs.To_Bounded ("");

      declare
         Signing_Text : constant String := Packs.Canonical_Signing_Text (Meta_Allow);
         Signature : constant String :=
           Smoke_RT_Test_Verifier.Compute_Test_Signature
             (Signing_Text => Signing_Text,
              Bin => Binary_Data.all,
              Used => Binary_Used);
      begin
         if Signing_Text'Length = 0 or else Signature'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            Ada.Text_IO.Put_Line
              ("INFO case_allow=FAIL signing_text/signature_invalid status_int="
               & Status_Int_Image (Status));
         else
            Meta_Allow.Signature_Value := Packs.To_Bounded (Signature);
            Packs.Write_Manifest
              (Path => Manifest_Path,
               Meta => Meta_Allow,
               Status => Status);
            if Status /= Errors.Success then
               Ada.Text_IO.Put_Line
                 ("INFO case_allow=FAIL write_manifest_status="
                  & Errors.Image (Status)
                  & " status_int="
                  & Status_Int_Image (Status));
            else
               Execute_Add1_Strict
                 (Meta => Meta_Allow,
                  Bin => Binary_Data.all,
                  Used => Binary_Used,
                  Status => Status);
               if Status = Errors.Success then
                  Case_Allow_Pass := True;
                  Ada.Text_IO.Put_Line ("INFO case_allow=PASS");
               else
                  Ada.Text_IO.Put_Line
                    ("INFO case_allow=FAIL status="
                     & Errors.Image (Status)
                     & " status_int="
                     & Status_Int_Image (Status));
               end if;
            end if;
         end if;
      end;

      --  Deny case: strict policy must reject disallowed options.
      Meta_Deny := Meta_Allow;
      Meta_Deny.Build_Options := Packs.To_Bounded ("-cl-opt-disable");
      Meta_Deny.Signature_Value := Packs.To_Bounded ("");

      declare
         Signing_Text : constant String := Packs.Canonical_Signing_Text (Meta_Deny);
         Signature : constant String :=
           Smoke_RT_Test_Verifier.Compute_Test_Signature
             (Signing_Text => Signing_Text,
              Bin => Binary_Data.all,
              Used => Binary_Used);
      begin
         if Signing_Text'Length = 0 or else Signature'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            Ada.Text_IO.Put_Line
              ("INFO case_deny=FAIL signing_text/signature_invalid status_int="
               & Status_Int_Image (Status));
         else
            Meta_Deny.Signature_Value := Packs.To_Bounded (Signature);
            Packs.Write_Manifest
              (Path => Manifest_Path,
               Meta => Meta_Deny,
               Status => Status);
            if Status /= Errors.Success then
               Ada.Text_IO.Put_Line
                 ("INFO case_deny=FAIL write_manifest_status="
                  & Errors.Image (Status)
                  & " status_int="
                  & Status_Int_Image (Status));
            else
               Execute_Add1_Strict
                 (Meta => Meta_Deny,
                  Bin => Binary_Data.all,
                  Used => Binary_Used,
                  Status => Status);
               if Status = Errors.OCLW_Build_Options_Disallowed then
                  Case_Deny_Pass := True;
                  Ada.Text_IO.Put_Line
                    ("INFO case_deny=PASS expected=OCLW_BUILD_OPTIONS_DISALLOWED");
               else
                  Ada.Text_IO.Put_Line
                    ("INFO case_deny=FAIL expected="
                     & Errors.Image (Errors.OCLW_Build_Options_Disallowed)
                     & " got="
                     & Errors.Image (Status)
                     & " got_int="
                     & Status_Int_Image (Status));
               end if;
            end if;
         end if;
      end;

      Security.Install_Verifier (V => null);
      Free_Program_Byte_Array (Binary_Data);

      if Case_Allow_Pass and then Case_Deny_Pass then
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      else
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   exception
      when others =>
         Security.Install_Verifier (V => null);
         if Binary_Data /= null then
            Free_Program_Byte_Array (Binary_Data);
         end if;
         Ada.Text_IO.Put_Line
           ("ERROR unhandled_exception: "
            & Errors.Image (Errors.OCLW_IO_Error)
            & " status_int="
            & Status_Int_Image (Errors.OCLW_IO_Error));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end;
end Smoke_RT_Build_Options_Policy;
