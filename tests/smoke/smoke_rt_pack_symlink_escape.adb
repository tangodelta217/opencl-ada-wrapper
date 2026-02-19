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
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;

procedure Smoke_RT_Pack_Symlink_Escape is
   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;

   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;

   Default_Pack_Dir : constant String := "/tmp/oclw_g31_pack_symlink_escape";
   Outside_Manifest : constant String := "/tmp/outside_manifest_g31.kpack";
   Outside_Binary : constant String := "/tmp/outside_program_g31.bin";

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Failed : Boolean := False;
   Skip_Test : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Resolve_Pack_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("OCLW_PACK_DIR") then
         declare
            Value : constant String := Ada.Environment_Variables.Value ("OCLW_PACK_DIR");
         begin
            if Value'Length > 0 then
               return Value & "/g31_symlink_escape";
            end if;
         end;
      end if;

      return Default_Pack_Dir;
   end Resolve_Pack_Dir;

   function Locate_Gen_Pack_Add1 return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Candidate_1 : constant String := Self_Dir & "/gen_pack_add1";
      Candidate_2 : constant String := "tests/bin/gen_pack_add1";
   begin
      if Ada.Directories.Exists (Candidate_1) then
         return Candidate_1;
      elsif Ada.Directories.Exists (Candidate_2) then
         return Candidate_2;
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
      Return_Code : Integer := 0;
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
      Return_Code := GNAT.OS_Lib.Spawn (Program_Name => Gen_Exec, Args => Args);
      GNAT.OS_Lib.Free (Args (1));

      Ada.Text_IO.Put_Line
        ("INFO gen_pack_add1_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code)));

      return
        Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Ensure_Base_Pack;

   function Spawn_Ln_S
     (Target : String;
      Link_Path : String) return Boolean
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 3);
      Return_Code : Integer := 0;
   begin
      Args (1) := new String'("-sfn");
      Args (2) := new String'(Target);
      Args (3) := new String'(Link_Path);
      Return_Code := GNAT.OS_Lib.Spawn (Program_Name => "/bin/ln", Args => Args);
      for I in Args'Range loop
         GNAT.OS_Lib.Free (Args (I));
      end loop;
      return Return_Code = 0;
   end Spawn_Ln_S;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Mark_Fail
     (Step : String;
      Expected : Errors.Status_Code;
      Got : Errors.Status_Code)
   is
   begin
      Ada.Text_IO.Put_Line
        ("ERROR "
         & Step
         & ": expected="
         & Errors.Image (Expected)
         & " got="
         & Errors.Image (Got)
         & " expected_int="
         & Trim_Int_Image (Interfaces.C.int (Expected))
         & " got_int="
         & Trim_Int_Image (Interfaces.C.int (Got)));
      Failed := True;
   end Mark_Fail;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";

      Manifest_Backup : constant String := Pack_Dir & "/manifest_backup_g31.kpack";
      Binary_Backup : constant String := Pack_Dir & "/program_backup_g31.bin";

      Meta : Packs.Pack_Metadata;
      Binary_Data : Program_Byte_Array_Access := null;
      Binary_Used : Natural := 0;
      Status : Errors.Status_Code := Errors.Success;
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);

      if not Ensure_Base_Pack (Pack_Dir, Manifest_Path, Binary_Path) then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=pack_generation_unavailable");
         return;
      end if;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if Status /= Errors.Success then
         Mark_Fail ("read_manifest_base", Errors.Success, Status);
      end if;

      if not Failed then
         if Meta.Binary_Size = 0 or else Meta.Binary_Size > Interfaces.C.size_t (Positive'Last) then
            Mark_Fail ("base_binary_size", Errors.Success, Errors.OCLW_Pack_Format_Error);
         else
            Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));
         end if;
      end if;

      --  Case A: manifest.kpack symlink escape must be rejected.
      if not Failed then
         Delete_If_Exists (Manifest_Backup);
         Delete_If_Exists (Outside_Manifest);
         Ada.Directories.Rename (Old_Name => Manifest_Path, New_Name => Manifest_Backup);
         Ada.Directories.Copy_File (Source_Name => Manifest_Backup, Target_Name => Outside_Manifest);

         if not Spawn_Ln_S (Target => Outside_Manifest, Link_Path => Manifest_Path) then
            Skip_Test := True;
         else
            Packs.Read_Manifest
              (Path => Manifest_Path,
               Meta => Meta,
               Status => Status);
            if Status = Errors.OCLW_FS_Policy_Violation then
               Ada.Text_IO.Put_Line
                 ("INFO case_manifest_symlink=PASS expected="
                  & Errors.Image (Errors.OCLW_FS_Policy_Violation)
                  & " got="
                  & Errors.Image (Status));
            else
               Mark_Fail
                 ("case_manifest_symlink",
                  Errors.OCLW_FS_Policy_Violation,
                  Status);
            end if;
         end if;

         Delete_If_Exists (Manifest_Path);
         if Ada.Directories.Exists (Manifest_Backup) then
            Ada.Directories.Rename (Old_Name => Manifest_Backup, New_Name => Manifest_Path);
         end if;
      end if;

      --  Case B: program.bin symlink escape must be rejected.
      if not Failed and then not Skip_Test then
         Delete_If_Exists (Binary_Backup);
         Delete_If_Exists (Outside_Binary);
         Ada.Directories.Rename (Old_Name => Binary_Path, New_Name => Binary_Backup);
         Ada.Directories.Copy_File (Source_Name => Binary_Backup, Target_Name => Outside_Binary);

         if not Spawn_Ln_S (Target => Outside_Binary, Link_Path => Binary_Path) then
            Skip_Test := True;
         else
            for I in Binary_Data'Range loop
               Binary_Data (I) := 0;
            end loop;
            Packs.Read_Binary
              (Path => Binary_Path,
               Buffer => Binary_Data.all,
               Used => Binary_Used,
               Status => Status);
            if Status = Errors.OCLW_FS_Policy_Violation then
               Ada.Text_IO.Put_Line
                 ("INFO case_binary_symlink=PASS expected="
                  & Errors.Image (Errors.OCLW_FS_Policy_Violation)
                  & " got="
                  & Errors.Image (Status));
            else
               Mark_Fail
                 ("case_binary_symlink",
                  Errors.OCLW_FS_Policy_Violation,
                  Status);
            end if;
         end if;

         Delete_If_Exists (Binary_Path);
         if Ada.Directories.Exists (Binary_Backup) then
            Ada.Directories.Rename (Old_Name => Binary_Backup, New_Name => Binary_Path);
         end if;
      end if;

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;
   exception
      when others =>
         if Binary_Data /= null then
            Free_Program_Byte_Array (Binary_Data);
         end if;
         Failed := True;
         Ada.Text_IO.Put_Line ("ERROR unhandled_exception_in_smoke_rt_pack_symlink_escape");
   end;

   if Skip_Test then
      Ada.Text_IO.Put_Line ("RESULT=SKIP reason=symlink_creation_not_allowed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   elsif Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Smoke_RT_Pack_Symlink_Escape;
