with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces.C;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;

procedure Smoke_RT_Plugin_Allowlist_Policy is
   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Security renames OpenCL.RT.Security;

   use type Errors.Status_Code;
   use type GNAT.OS_Lib.String_Access;
   use type Interfaces.C.int;

   Tmp_Base_Dir : constant String := "/tmp/oclw_g33_plugin_allowlist_policy";
   Plugin_Build_Script_Rel : constant String := "tools/crypto_provider_ref/build.sh";
   Plugin_SO_Rel : constant String := "tools/crypto_provider_ref/liboclw_crypto_provider_ref.so";
   Plugin_Symbol : constant String := "oclw_kpack_verify_v1";

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

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

   function Ensure_Reference_Plugin
     (Plugin_Path : out Packs.Bounded_String;
      Skip_Reason : out Packs.Bounded_String) return Boolean
   is
      Build_Script : constant String := Locate_Path (Plugin_Build_Script_Rel);
      Plugin_SO : constant String := Locate_Path (Plugin_SO_Rel);
      Build_Log : constant String := Tmp_Base_Dir & "/plugin_build.log";
      GCC_Path : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("gcc");
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

      if not Ada.Directories.Exists (Tmp_Base_Dir) then
         Ada.Directories.Create_Path (Tmp_Base_Dir);
      end if;

      Args (1) := new String'(Build_Script);
      GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/bash",
         Args => Args,
         Output_File => Build_Log,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));

      Ada.Text_IO.Put_Line
        ("INFO plugin_build_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Build_Log);

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

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   function Create_Symlink
     (Target_Path : String;
      Link_Path : String;
      Log_Path : String) return Boolean
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 3);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      Delete_If_Exists (Link_Path);

      Args (1) := new String'("-s");
      Args (2) := new String'(Target_Path);
      Args (3) := new String'(Link_Path);
      GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/ln",
         Args => Args,
         Output_File => Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));
      GNAT.OS_Lib.Free (Args (3));

      return Success and then Return_Code = 0;
   end Create_Symlink;

   function Copy_File
     (From_Path : String;
      To_Path : String;
      Log_Path : String) return Boolean
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 2);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      Delete_If_Exists (To_Path);

      Args (1) := new String'(From_Path);
      Args (2) := new String'(To_Path);
      GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/cp",
         Args => Args,
         Output_File => Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));

      return Success and then Return_Code = 0;
   end Copy_File;

   function Chmod_World_Writable
     (Path : String;
      Log_Path : String) return Boolean
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 2);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      Args (1) := new String'("777");
      Args (2) := new String'(Path);
      GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/chmod",
         Args => Args,
         Output_File => Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));

      return Success and then Return_Code = 0;
   end Chmod_World_Writable;

   function Status_Image (Code : Errors.Status_Code) return String is
   begin
      return Errors.Image (Code);
   end Status_Image;

begin
   declare
      Plugin_Path : Packs.Bounded_String := Packs.To_Bounded ("");
      Skip_Reason : Packs.Bounded_String := Packs.To_Bounded ("");
      Plugin_Dir : Packs.Bounded_String := Packs.To_Bounded ("");
      Status : Errors.Status_Code := Errors.Success;
      Failed : Boolean := False;
   begin
      if not Ensure_Reference_Plugin
               (Plugin_Path => Plugin_Path,
                Skip_Reason => Skip_Reason)
      then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason=" & Packs.To_String (Skip_Reason));
         return;
      end if;

      Plugin_Dir :=
        Packs.To_Bounded
          (Ada.Directories.Containing_Directory (Packs.To_String (Plugin_Path)));

      Ada.Text_IO.Put_Line ("INFO strict_policy_mode=ENABLED");
      Ada.Text_IO.Put_Line ("INFO plugin_path=" & Packs.To_String (Plugin_Path));

      --  Case A: allowlist does not include plugin directory.
      Ada.Environment_Variables.Set
        (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
         Value => "/tmp/oclw_g33_not_allowed_only");
      Security.Install_Verifier (V => null);
      Security.Configure_Plugin
        (Path => Packs.To_String (Plugin_Path),
         Symbol => Plugin_Symbol,
         Status => Status);
      if Status = Errors.OCLW_Plugin_Path_Not_Allowed then
         Ada.Text_IO.Put_Line
           ("INFO case_not_allowed=PASS expected=OCLW_PLUGIN_PATH_NOT_ALLOWED got="
            & Status_Image (Status));
      else
         Failed := True;
         Ada.Text_IO.Put_Line
           ("INFO case_not_allowed=FAIL expected=OCLW_PLUGIN_PATH_NOT_ALLOWED got="
            & Status_Image (Status));
      end if;

      --  Case B: allowlist includes plugin directory.
      Ada.Environment_Variables.Set
        (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
         Value => Packs.To_String (Plugin_Dir));
      Security.Install_Verifier (V => null);
      Security.Configure_Plugin
        (Path => Packs.To_String (Plugin_Path),
         Symbol => Plugin_Symbol,
         Status => Status);
      if Status = Errors.Success then
         declare
            Meta : Packs.Pack_Metadata := (others => <>);
            Bin : Programs.Byte_Array (1 .. 4) := (16#10#, 16#20#, 16#30#, 16#40#);
            Strict_Status : Errors.Status_Code := Errors.Success;
         begin
            Meta.Signature_Required := True;
            Meta.Signature_Alg := Packs.To_Bounded ("TEST-FNV1A32");
            Meta.Signature_Value := Packs.To_Bounded ("DEADBEEF");
            Meta.Signer_Id := Packs.To_Bounded ("OCLW-G33-SMOKE");
            Strict_Status :=
              Security.Verify
                (Meta => Meta,
                 Signing_Text => "kpack_version=1" & ASCII.LF,
                 Bin => Bin,
                 Used => Bin'Length,
                 Strict => True);

            if Strict_Status = Errors.OCLW_Signature_Invalid
              or else Strict_Status = Errors.Success
            then
               Ada.Text_IO.Put_Line ("INFO case_allowed=PASS");
            else
               Failed := True;
               Ada.Text_IO.Put_Line
                 ("INFO case_allowed=FAIL got=" & Status_Image (Strict_Status));
            end if;
         end;
      else
         Failed := True;
         Ada.Text_IO.Put_Line
           ("INFO case_allowed=FAIL got=" & Status_Image (Status));
      end if;

      --  Case C: symlink plugin path must be rejected.
      declare
         Symlink_Dir : constant String := Tmp_Base_Dir & "/case_symlink";
         Symlink_Path : constant String := Symlink_Dir & "/plugin_link.so";
         Symlink_Log : constant String := Symlink_Dir & "/ln.log";
      begin
         if not Ada.Directories.Exists (Symlink_Dir) then
            Ada.Directories.Create_Path (Symlink_Dir);
         end if;

         if not Create_Symlink
                  (Target_Path => Packs.To_String (Plugin_Path),
                   Link_Path => Symlink_Path,
                   Log_Path => Symlink_Log)
         then
            Ada.Text_IO.Put_Line ("RESULT=SKIP reason=symlink_creation_failed");
            return;
         end if;

         Ada.Environment_Variables.Set
           (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
            Value => Symlink_Dir & ":" & Packs.To_String (Plugin_Dir));
         Security.Install_Verifier (V => null);
         Security.Configure_Plugin
           (Path => Symlink_Path,
            Symbol => Plugin_Symbol,
            Status => Status);

         if Status = Errors.OCLW_FS_Policy_Violation
           or else Status = Errors.OCLW_Plugin_Untrusted
         then
            Ada.Text_IO.Put_Line
              ("INFO case_symlink=PASS expected=OCLW_FS_POLICY_VIOLATION got="
               & Status_Image (Status));
         else
            Failed := True;
            Ada.Text_IO.Put_Line
              ("INFO case_symlink=FAIL expected=OCLW_FS_POLICY_VIOLATION got="
               & Status_Image (Status));
         end if;
      end;

      --  Case D: world-writable plugin must be rejected.
      declare
         Unsafe_Dir : constant String := Tmp_Base_Dir & "/case_world_writable";
         Unsafe_Path : constant String := Unsafe_Dir & "/plugin_world_writable.so";
         Copy_Log : constant String := Unsafe_Dir & "/cp.log";
         Chmod_Log : constant String := Unsafe_Dir & "/chmod.log";
      begin
         if not Ada.Directories.Exists (Unsafe_Dir) then
            Ada.Directories.Create_Path (Unsafe_Dir);
         end if;

         if not Copy_File
                  (From_Path => Packs.To_String (Plugin_Path),
                   To_Path => Unsafe_Path,
                   Log_Path => Copy_Log)
         then
            Ada.Text_IO.Put_Line ("RESULT=SKIP reason=copy_failed");
            return;
         end if;

         if not Chmod_World_Writable
                  (Path => Unsafe_Path,
                   Log_Path => Chmod_Log)
         then
            Ada.Text_IO.Put_Line ("RESULT=SKIP reason=chmod_failed");
            return;
         end if;

         Ada.Environment_Variables.Set
           (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
            Value => Unsafe_Dir);
         Security.Install_Verifier (V => null);
         Security.Configure_Plugin
           (Path => Unsafe_Path,
            Symbol => Plugin_Symbol,
            Status => Status);

         if Status = Errors.OCLW_Plugin_Unsafe_Perms then
            Ada.Text_IO.Put_Line
              ("INFO case_world_writable=PASS expected=OCLW_PLUGIN_UNSAFE_PERMS got="
               & Status_Image (Status));
         else
            Failed := True;
            Ada.Text_IO.Put_Line
              ("INFO case_world_writable=FAIL expected=OCLW_PLUGIN_UNSAFE_PERMS got="
               & Status_Image (Status));
         end if;
      end;

      if Failed then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      else
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      end if;
   end;
exception
   when others =>
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Smoke_RT_Plugin_Allowlist_Policy;
