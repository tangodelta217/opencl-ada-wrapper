with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces.C;
with OpenCL.Errors;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;

procedure Smoke_RT_Untrusted_Plugin is
   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package Security renames OpenCL.RT.Security;

   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type GNAT.OS_Lib.String_Access;

   Default_Pack_Dir : constant String :=
     "docs/VV/Execution_Logs/local/pack_rt_untrusted_plugin";
   Plugin_Build_Script_Rel : constant String :=
     "tools/crypto_provider_ref/build.sh";
   Plugin_SO_Rel : constant String :=
     "tools/crypto_provider_ref/liboclw_crypto_provider_ref.so";
   Plugin_Symbol : constant String := "oclw_kpack_verify_v1";

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
            Value : constant String :=
              Ada.Environment_Variables.Value ("OCLW_PACK_DIR");
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

   function Ensure_Reference_Plugin
     (Build_Log_Path : String;
      Plugin_Path : out Packs.Bounded_String;
      Skip_Reason : out Packs.Bounded_String) return Boolean
   is
      Build_Script : constant String := Locate_Path (Plugin_Build_Script_Rel);
      Plugin_SO : constant String := Locate_Path (Plugin_SO_Rel);
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

   function Set_World_Writable
     (Plugin_Path : String;
      Chmod_Log_Path : String) return Boolean
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 2);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      Args (1) := new String'("777");
      Args (2) := new String'(Plugin_Path);
      GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/chmod",
         Args => Args,
         Output_File => Chmod_Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));

      Ada.Text_IO.Put_Line
        ("INFO chmod_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Chmod_Log_Path);

      return Success and then Return_Code = 0;
   end Set_World_Writable;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Build_Log_Path : constant String := Pack_Dir & "/crypto_plugin_build.log";
      Chmod_Log_Path : constant String := Pack_Dir & "/chmod_plugin.log";
      Plugin_Path : Packs.Bounded_String := Packs.To_Bounded ("");
      Skip_Reason : Packs.Bounded_String := Packs.To_Bounded ("");
      Status : Errors.Status_Code := Errors.Success;
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO strict_policy_mode=ENABLED");
      Ada.Text_IO.Put_Line ("INFO verifier_mode=REFERENCE_PLUGIN (NOT CRYPTO)");

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      if not Ensure_Reference_Plugin
               (Build_Log_Path => Build_Log_Path,
                Plugin_Path => Plugin_Path,
                Skip_Reason => Skip_Reason)
      then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason=" & Packs.To_String (Skip_Reason));
         return;
      end if;

      Ada.Text_IO.Put_Line ("INFO plugin_path=" & Packs.To_String (Plugin_Path));

      if not Set_World_Writable
               (Plugin_Path => Packs.To_String (Plugin_Path),
                Chmod_Log_Path => Chmod_Log_Path)
      then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=chmod_failed");
         return;
      end if;

      Security.Install_Verifier (V => null);
      Security.Configure_Plugin
        (Path => Packs.To_String (Plugin_Path),
         Symbol => Plugin_Symbol,
         Status => Status);

      Ada.Text_IO.Put_Line
        ("INFO configure_plugin_status="
         & Errors.Image (Status)
         & " status_int="
         & Status_Int_Image (Status));

      if Status = Errors.OCLW_Plugin_Unsafe_Perms
        or else Status = Errors.OCLW_Plugin_Untrusted
      then
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      else
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end;
exception
   when others =>
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Smoke_RT_Untrusted_Plugin;
