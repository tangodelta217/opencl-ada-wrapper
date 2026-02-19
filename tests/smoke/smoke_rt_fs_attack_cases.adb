with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
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

procedure Smoke_RT_FS_Attack_Cases is
   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package SIO renames Ada.Streams.Stream_IO;

   use type Errors.Status_Code;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;

   --  OCLW-TST-3001/TST-3002/TST-3003: FS attacks (symlink/traversal/TOCTOU).
   Default_Pack_Dir : constant String :=
     "docs/VV/Execution_Logs/local/pack_fs_attack_cases";

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Failed : Boolean := False;

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
               return Value & "/fs_attack_cases";
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
         & Status_Int_Image (Expected)
         & " got_int="
         & Status_Int_Image (Got));
      Failed := True;
   end Mark_Fail;

   function Is_FS_Rejection (Code : Errors.Status_Code) return Boolean is
   begin
      return
        Code = Errors.OCLW_FS_Policy_Violation
        or else Code = Errors.OCLW_Pack_Format_Error;
   end Is_FS_Rejection;

   procedure Expect_FS_Rejection
     (Step : String;
      Code : Errors.Status_Code) is
   begin
      if Is_FS_Rejection (Code) then
         Ada.Text_IO.Put_Line
           ("INFO "
            & Step
            & "=PASS expected=OCLW_FS_POLICY_VIOLATION|OCLW_PACK_FORMAT_ERROR"
            & " got="
            & Errors.Image (Code));
      else
         Mark_Fail (Step, Errors.OCLW_FS_Policy_Violation, Code);
      end if;
   end Expect_FS_Rejection;

   function Spawn_Ln_S
     (Target : String;
      Link_Path : String) return Boolean
   is
      Args : GNAT.OS_Lib.Argument_List (1 .. 3);
      Result : Integer := 0;
   begin
      Args (1) := new String'("-sfn");
      Args (2) := new String'(Target);
      Args (3) := new String'(Link_Path);
      Result := GNAT.OS_Lib.Spawn (Program_Name => "/bin/ln", Args => Args);
      for I in Args'Range loop
         GNAT.OS_Lib.Free (Args (I));
      end loop;
      return Result = 0;
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

   procedure Write_Binary_File
     (Path : String;
      Data : Programs.Byte_Array;
      Used : Natural;
      Status : out Errors.Status_Code)
   is
      File : SIO.File_Type;
   begin
      Status := Errors.Success;
      SIO.Create (File => File, Mode => SIO.Out_File, Name => Path);

      if Used > Data'Length then
         Status := Errors.Invalid_Value;
         SIO.Close (File);
         return;
      end if;

      if Used > 0 then
         declare
            Raw : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Used));
         begin
            for Offset in 0 .. Used - 1 loop
               Raw
                 (Raw'First + Ada.Streams.Stream_Element_Offset (Offset)) :=
                 Ada.Streams.Stream_Element
                   (Data (Data'First + Integer (Offset)));
            end loop;
            SIO.Write (File => File, Item => Raw);
         end;
      end if;

      SIO.Close (File);
   exception
      when SIO.Name_Error
         | SIO.Use_Error
         | SIO.Status_Error
         | SIO.Device_Error
         | Constraint_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Status := Errors.OCLW_IO_Error;
      when others =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Status := Errors.OCLW_IO_Error;
   end Write_Binary_File;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      Manifest_Backup : constant String := Pack_Dir & "/manifest_backup.kpack";
      Binary_Backup : constant String := Pack_Dir & "/program_backup.bin";
      Outside_Dir : constant String := Pack_Dir & "_outside";
      Outside_Manifest : constant String := Outside_Dir & "/manifest_outside.kpack";
      Outside_Binary : constant String := Outside_Dir & "/program_outside.bin";

      Traversal_Path : constant String :=
        Pack_Dir
        & "/../"
        & Ada.Directories.Simple_Name (Pack_Dir)
        & "/manifest.kpack";

      Status : Errors.Status_Code := Errors.Success;
      Meta : Packs.Pack_Metadata;
      Buffer : Program_Byte_Array_Access := null;
      Used : Natural := 0;
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO manifest_path=" & Manifest_Path);
      Ada.Text_IO.Put_Line ("INFO binary_path=" & Binary_Path);

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      if not Ensure_Base_Pack (Pack_Dir, Manifest_Path, Binary_Path) then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=pack_generation_unavailable");
         return;
      end if;

      if not Ada.Directories.Exists (Outside_Dir) then
         Ada.Directories.Create_Path (Outside_Dir);
      end if;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if Status /= Errors.Success then
         Mark_Fail ("read_manifest_base", Errors.Success, Status);
      end if;

      if not Failed then
         if Meta.Binary_Size = 0 then
            Mark_Fail ("base_binary_size_zero", Errors.Success, Errors.OCLW_Pack_Format_Error);
         elsif Meta.Binary_Size > Interfaces.C.size_t (Positive'Last) then
            Mark_Fail ("base_binary_size_range", Errors.Success, Errors.OCLW_Limit_Exceeded);
         else
            Buffer := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));
         end if;
      end if;

      --  Case 1: manifest symlink points outside pack dir -> fail-closed.
      if not Failed then
         Delete_If_Exists (Manifest_Backup);
         Delete_If_Exists (Outside_Manifest);

         Ada.Directories.Copy_File (Source_Name => Manifest_Path, Target_Name => Outside_Manifest);
         Ada.Directories.Rename (Old_Name => Manifest_Path, New_Name => Manifest_Backup);

         if not Spawn_Ln_S (Target => Outside_Manifest, Link_Path => Manifest_Path) then
            Mark_Fail ("case1_create_manifest_symlink", Errors.Success, Errors.OCLW_IO_Error);
         else
            Packs.Read_Manifest
              (Path => Manifest_Path,
               Meta => Meta,
               Status => Status);
            Expect_FS_Rejection ("case1_manifest_symlink", Status);
         end if;

         Delete_If_Exists (Manifest_Path);
         Ada.Directories.Rename (Old_Name => Manifest_Backup, New_Name => Manifest_Path);
      end if;

      --  Case 2: binary symlink points outside pack dir -> fail-closed.
      if not Failed then
         Delete_If_Exists (Binary_Backup);
         Delete_If_Exists (Outside_Binary);

         Ada.Directories.Copy_File (Source_Name => Binary_Path, Target_Name => Outside_Binary);
         Ada.Directories.Rename (Old_Name => Binary_Path, New_Name => Binary_Backup);

         if not Spawn_Ln_S (Target => Outside_Binary, Link_Path => Binary_Path) then
            Mark_Fail ("case2_create_binary_symlink", Errors.Success, Errors.OCLW_IO_Error);
         else
            for I in Buffer'Range loop
               Buffer (I) := 0;
            end loop;
            Packs.Read_Binary
              (Path => Binary_Path,
               Buffer => Buffer.all,
               Used => Used,
               Status => Status);
            Expect_FS_Rejection ("case2_binary_symlink", Status);
         end if;

         Delete_If_Exists (Binary_Path);
         Ada.Directories.Rename (Old_Name => Binary_Backup, New_Name => Binary_Path);
      end if;

      --  Case 3: path traversal in path argument must be rejected.
      if not Failed then
         Packs.Read_Manifest
           (Path => Traversal_Path,
            Meta => Meta,
            Status => Status);
         Expect_FS_Rejection ("case3_path_traversal", Status);
      end if;

      --  Case 4: TOCTOU simulation (verify, replace, verify again).
      if not Failed then
         Packs.Read_Manifest
           (Path => Manifest_Path,
            Meta => Meta,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("case4_read_manifest", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         for I in Buffer'Range loop
            Buffer (I) := 0;
         end loop;
         Packs.Read_Binary
           (Path => Binary_Path,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("case4_read_binary_before", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         Packs.Verify_Binary
           (Meta => Meta,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("case4_verify_before_replace", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         if Used = 0 then
            Mark_Fail ("case4_used_zero_before_tamper", Errors.Success, Errors.OCLW_IO_Error);
         else
            Buffer (Buffer'First) := Buffer (Buffer'First) xor 16#01#;
            Write_Binary_File
              (Path => Binary_Path,
               Data => Buffer.all,
               Used => Used,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("case4_replace_binary", Errors.Success, Status);
            end if;
         end if;
      end if;

      if not Failed then
         for I in Buffer'Range loop
            Buffer (I) := 0;
         end loop;
         Packs.Read_Binary
           (Path => Binary_Path,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("case4_read_binary_after_replace", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         Packs.Verify_Binary
           (Meta => Meta,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.OCLW_Hash_Mismatch then
            Mark_Fail ("case4_toctou_hash_mismatch", Errors.OCLW_Hash_Mismatch, Status);
         else
            Ada.Text_IO.Put_Line
              ("INFO case4_toctou_hash_mismatch=PASS expected="
               & Errors.Image (Errors.OCLW_Hash_Mismatch));
         end if;
      end if;

      if Buffer /= null then
         Free_Program_Byte_Array (Buffer);
      end if;
   exception
      when others =>
         if Buffer /= null then
            Free_Program_Byte_Array (Buffer);
         end if;
         Failed := True;
         Ada.Text_IO.Put_Line ("ERROR unhandled_exception_in_smoke_rt_fs_attack_cases");
   end;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Smoke_RT_FS_Attack_Cases;
