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
with OpenCL.RT.FS.Test_Seam;
with OpenCL.RT.Packs;

procedure Smoke_RT_TOCTOU_Binary_Swap is
   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package SIO renames Ada.Streams.Stream_IO;

   use type Errors.Status_Code;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;

   Default_Pack_Dir : constant String := "/tmp/oclw_g32_binary_toctou";

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
               return Value & "/g32_binary_toctou";
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

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Tamper_First_Byte (Path : String; Status : out Errors.Status_Code) is
      File : SIO.File_Type;
      Data : Ada.Streams.Stream_Element_Array (1 .. 1);
      Last : Ada.Streams.Stream_Element_Offset := 0;
   begin
      Status := Errors.Success;

      SIO.Open (File => File, Mode => SIO.In_File, Name => Path);
      SIO.Read (File => File, Item => Data, Last => Last);
      if Last /= Data'Last then
         Status := Errors.OCLW_IO_Error;
         SIO.Close (File);
         return;
      end if;

      SIO.Close (File);

      Data (Data'First) :=
        Ada.Streams.Stream_Element
          (Interfaces.Unsigned_8 (Data (Data'First)) xor 16#01#);

      SIO.Create (File => File, Mode => SIO.Out_File, Name => Path);
      SIO.Write (File => File, Item => Data);
      SIO.Close (File);
   exception
      when others =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Status := Errors.OCLW_IO_Error;
   end Tamper_First_Byte;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      Binary_Backup : constant String := Pack_Dir & "/program_backup_toctou.bin";
      Binary_Swap : constant String := Pack_Dir & "/program_swap_toctou.bin";

      Status : Errors.Status_Code := Errors.Success;
      Meta : Packs.Pack_Metadata;
      Buffer : Program_Byte_Array_Access := null;
      Used : Natural := 0;
      Swap_Done : Boolean := False;

      procedure On_After_PreStat (Path : String) is
      begin
         if Swap_Done then
            return;
         end if;

         if Path /= Binary_Path then
            return;
         end if;

         Delete_If_Exists (Binary_Backup);
         Ada.Directories.Rename
           (Old_Name => Binary_Path,
            New_Name => Binary_Backup);
         Ada.Directories.Rename
           (Old_Name => Binary_Swap,
            New_Name => Binary_Path);
         Swap_Done := True;
      exception
         when others =>
            null;
      end On_After_PreStat;

      procedure Restore_Files is
      begin
         if Ada.Directories.Exists (Binary_Backup) then
            Delete_If_Exists (Binary_Path);
            Ada.Directories.Rename
              (Old_Name => Binary_Backup,
               New_Name => Binary_Path);
         end if;
      exception
         when others =>
            null;
      end Restore_Files;
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
         Failed := True;
      elsif Meta.Binary_Size = 0 or else Meta.Binary_Size > Interfaces.C.size_t (Positive'Last) then
         Failed := True;
      else
         Buffer := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));
      end if;

      if not Failed then
         Delete_If_Exists (Binary_Backup);
         Delete_If_Exists (Binary_Swap);

         Ada.Directories.Copy_File
           (Source_Name => Binary_Path,
            Target_Name => Binary_Swap);

         Tamper_First_Byte (Path => Binary_Swap, Status => Status);
         if Status /= Errors.Success then
            Failed := True;
         end if;
      end if;

      if not Failed then
         OpenCL.RT.FS.Test_Seam.Install
           (Callback => On_After_PreStat'Unrestricted_Access);

         Packs.Read_Binary
           (Path => Binary_Path,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);

         OpenCL.RT.FS.Test_Seam.Clear;

         if Status = Errors.OCLW_FS_TOCTOU_Detected and then Swap_Done then
            Ada.Text_IO.Put_Line
              ("INFO case_binary_toctou=PASS expected="
               & Errors.Image (Errors.OCLW_FS_TOCTOU_Detected)
               & " got="
               & Errors.Image (Status)
               & " got_int="
               & Status_Int_Image (Status));
         else
            Failed := True;
            Ada.Text_IO.Put_Line
              ("INFO case_binary_toctou=FAIL expected="
               & Errors.Image (Errors.OCLW_FS_TOCTOU_Detected)
               & " got="
               & Errors.Image (Status)
               & " got_int="
               & Status_Int_Image (Status));
         end if;
      end if;

      Restore_Files;
      Delete_If_Exists (Binary_Swap);

      if Buffer /= null then
         Free_Program_Byte_Array (Buffer);
      end if;
   exception
      when others =>
         OpenCL.RT.FS.Test_Seam.Clear;
         if Buffer /= null then
            Free_Program_Byte_Array (Buffer);
         end if;
         Failed := True;
   end;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Smoke_RT_TOCTOU_Binary_Swap;
