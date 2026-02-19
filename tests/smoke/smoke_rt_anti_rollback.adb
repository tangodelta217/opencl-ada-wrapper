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
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Loader;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;
with Smoke_RT_Test_Verifier;

procedure Smoke_RT_Anti_Rollback is
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Loader renames OpenCL.RT.Loader;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Security renames OpenCL.RT.Security;

   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type GNAT.OS_Lib.String_Access;

   Default_Pack_Dir : constant String :=
     "docs/VV/Execution_Logs/local/pack_rt_anti_rollback";
   Plugin_Build_Script_Rel : constant String :=
     "tools/crypto_provider_ref/build.sh";
   Plugin_SO_Rel : constant String :=
     "tools/crypto_provider_ref/liboclw_crypto_provider_ref.so";
   Plugin_Symbol : constant String := "oclw_kpack_verify_v1";
   State_File : constant String := "/tmp/oclw_rollback_state_g18.txt";

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
         Ada.Text_IO.Put_Line ("INFO skip_reason=missing_gen_pack_add1_executable");
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

      Ada.Text_IO.Put_Line
        ("INFO plugin_build_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Build_Log_Path);

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

   procedure Load_Strict
     (Meta : Packs.Pack_Metadata;
      Bin : Programs.Byte_Array;
      Used : Natural;
      Status : out Errors.Status_Code)
   is
      Platform : OpenCL.Core.Platform;
      Device : OpenCL.Core.Device;
      Ctx : Contexts.Context;
      Prg : Programs.Program;
      Release_Status : Errors.Status_Code := Errors.Success;
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

      Programs.Release (Prg => Prg, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);
   end Load_Strict;

   procedure Prepare_Manifest
     (Manifest_Path : String;
      Base_Meta : in out Packs.Pack_Metadata;
      Bin : Programs.Byte_Array;
      Used : Natural;
      Counter : Interfaces.Unsigned_64;
      Status : out Errors.Status_Code)
   is
   begin
      Status := Errors.Success;

      Base_Meta.Pack_Version_Present := True;
      Base_Meta.Pack_Version := 1;
      Base_Meta.Monotonic_Counter_Present := True;
      Base_Meta.Monotonic_Counter := Counter;
      Base_Meta.Signature_Required := True;
      Base_Meta.Signature_Alg := Packs.To_Bounded ("CMS-PKCS7-SHA256");
      Base_Meta.Signer_Id := Packs.To_Bounded ("DEV-ROLLBACK");

      declare
         Signing_Text : constant String := Packs.Canonical_Signing_Text (Base_Meta);
         Signature_Text : constant String :=
           Smoke_RT_Test_Verifier.Compute_Test_Signature
             (Signing_Text => Signing_Text,
              Bin => Bin,
              Used => Used);
      begin
         if Signing_Text'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            return;
         end if;

         if Signature_Text'Length = 0 then
            Status := Errors.OCLW_Signature_Invalid;
            return;
         end if;

         Base_Meta.Signature_Value := Packs.To_Bounded (Signature_Text);
      end;

      Packs.Write_Manifest
        (Path => Manifest_Path,
         Meta => Base_Meta,
         Status => Status);
   end Prepare_Manifest;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      Build_Log_Path : constant String := Pack_Dir & "/crypto_plugin_build.log";

      Meta : Packs.Pack_Metadata;
      Plugin_Path : Packs.Bounded_String := Packs.To_Bounded ("");
      Skip_Reason : Packs.Bounded_String := Packs.To_Bounded ("");
      Binary_Data : Program_Byte_Array_Access := null;
      Binary_Used : Natural := 0;
      Status : Errors.Status_Code := Errors.Success;
      Case1_Pass : Boolean := False;
      Case2_Pass : Boolean := False;
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO manifest_path=" & Manifest_Path);
      Ada.Text_IO.Put_Line ("INFO binary_path=" & Binary_Path);
      Ada.Text_IO.Put_Line ("INFO rollback_state_file=" & State_File);

      if not Ensure_Base_Pack
          (Pack_Dir => Pack_Dir,
           Manifest_Path => Manifest_Path,
           Binary_Path => Binary_Path)
      then
         Ada.Text_IO.Put_Line ("RESULT=SKIP");
         return;
      end if;

      if not Ensure_Reference_Plugin
          (Build_Log_Path => Build_Log_Path,
           Plugin_Path => Plugin_Path,
           Skip_Reason => Skip_Reason)
      then
         Ada.Text_IO.Put_Line
           ("INFO skip_reason=" & Packs.To_String (Skip_Reason));
         Ada.Text_IO.Put_Line ("RESULT=SKIP");
         return;
      end if;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR read_manifest: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      if Meta.Binary_Size = 0 or else Meta.Binary_Size > Interfaces.C.size_t (Positive'Last) then
         Ada.Text_IO.Put_Line ("ERROR invalid_binary_size_in_manifest");
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));
      Packs.Read_Binary
        (Path => Binary_Path,
         Buffer => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR read_binary: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Packs.Verify_Binary
        (Meta => Meta,
         Buffer => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR verify_binary: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      if Ada.Directories.Exists (State_File) then
         Ada.Directories.Delete_File (State_File);
      end if;
      Ada.Environment_Variables.Set
        (Name => "OCLW_ROLLBACK_STATE_FILE",
         Value => State_File);
      Ada.Environment_Variables.Set
        (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
         Value => Ada.Directories.Containing_Directory (Packs.To_String (Plugin_Path)));

      Security.Configure_Plugin
        (Path => Packs.To_String (Plugin_Path),
         Symbol => Plugin_Symbol,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR configure_plugin: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Prepare_Manifest
        (Manifest_Path => Manifest_Path,
         Base_Meta => Meta,
         Bin => Binary_Data.all,
         Used => Binary_Used,
         Counter => 100,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR prepare_manifest_case1: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Load_Strict
        (Meta => Meta,
         Bin => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status = Errors.Success then
         Case1_Pass := True;
         Ada.Text_IO.Put_Line ("INFO case1_counter=100 result=PASS");
      else
         Ada.Text_IO.Put_Line
           ("INFO case1_counter=100 result=FAIL status="
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
      end if;

      Prepare_Manifest
        (Manifest_Path => Manifest_Path,
         Base_Meta => Meta,
         Bin => Binary_Data.all,
         Used => Binary_Used,
         Counter => 99,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR prepare_manifest_case2: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Free_Program_Byte_Array (Binary_Data);
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Load_Strict
        (Meta => Meta,
         Bin => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status = Errors.OCLW_Rollback_Detected then
         Case2_Pass := True;
         Ada.Text_IO.Put_Line ("INFO case2_counter=99 expected=OCLW_ROLLBACK_DETECTED result=PASS");
      else
         Ada.Text_IO.Put_Line
           ("INFO case2_counter=99 expected=OCLW_ROLLBACK_DETECTED result=FAIL status="
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
      end if;

      Free_Program_Byte_Array (Binary_Data);

      if Case1_Pass and then Case2_Pass then
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      else
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   exception
      when others =>
         Ada.Text_IO.Put_Line ("ERROR unexpected_exception");
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end;
end Smoke_RT_Anti_Rollback;
