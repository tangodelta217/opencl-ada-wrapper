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
with OpenCL.Core;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Loader;
with OpenCL.RT.Packs;

procedure Smoke_RT_Negative_Cases is
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Loader renames OpenCL.RT.Loader;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package SIO renames Ada.Streams.Stream_IO;

   use type Errors.Status_Code;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;

   Default_Pack_Dir : constant String :=
     "docs/VV/Execution_Logs/local/pack_add1_negative";

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
      if Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path)
      then
         return True;
      end if;

      if Gen_Exec'Length = 0 then
         Ada.Text_IO.Put_Line ("WARN missing_gen_pack_add1_executable");
         return False;
      end if;

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      Ada.Environment_Variables.Set ("OCLW_PACK_DIR", Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO invoking_gen_pack_add1=" & Gen_Exec);

      Args (1) := new String'("");
      Return_Code := GNAT.OS_Lib.Spawn (Program_Name => Gen_Exec, Args => Args);
      GNAT.OS_Lib.Free (Args (1));

      Ada.Text_IO.Put_Line
        ("INFO gen_pack_add1_return_code=" & Trim_Int_Image (Interfaces.C.int (Return_Code)));

      return
        Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Ensure_Base_Pack;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      Manifest_BadFP_Path : constant String := Pack_Dir & "/manifest_badfp.kpack";
      Manifest_Corrupt_Path : constant String := Pack_Dir & "/manifest_corrupt.kpack";
      Manifest_Longline_Path : constant String := Pack_Dir & "/manifest_longline.kpack";
      Binary_Tampered_Path : constant String := Pack_Dir & "/program_tampered.bin";

      Status : Errors.Status_Code := Errors.Success;
      Meta_Original : Packs.Pack_Metadata;
      Meta_BadFP : Packs.Pack_Metadata;
      Meta_Corrupt : Packs.Pack_Metadata;
      Buffer : Program_Byte_Array_Access := null;
      Used : Natural := 0;
      Platform : Core.Platform;
      Device : Core.Device;
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

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta_Original,
         Status => Status);
      if Status /= Errors.Success then
         Mark_Fail ("read_manifest_base", Errors.Success, Status);
      end if;

      if not Failed then
         if Meta_Original.Binary_Size = 0 then
            Mark_Fail
              ("base_manifest_binary_size",
               Errors.Success,
               Errors.OCLW_Pack_Format_Error);
         elsif Meta_Original.Binary_Size > Interfaces.C.size_t (Positive'Last) then
            Mark_Fail
              ("base_manifest_binary_size_range",
               Errors.Success,
               Errors.OCLW_Pack_Format_Error);
         else
            Buffer :=
              new Programs.Byte_Array (1 .. Positive (Integer (Meta_Original.Binary_Size)));
         end if;
      end if;

      if not Failed then
         Packs.Read_Binary
           (Path => Binary_Path,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("read_binary_base", Errors.Success, Status);
         elsif Used = 0 then
            Mark_Fail
              ("base_binary_used_zero",
               Errors.Success,
               Errors.OCLW_IO_Error);
         end if;
      end if;

      --  Case 1: tampered binary must be rejected by hash mismatch.
      if not Failed then
         Buffer (Buffer'First) := Buffer (Buffer'First) xor 16#01#;
         Write_Binary_File
           (Path => Binary_Tampered_Path,
            Data => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("write_binary_tampered", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         for I in Buffer'Range loop
            Buffer (I) := 0;
         end loop;

         Packs.Read_Binary
           (Path => Binary_Tampered_Path,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("read_binary_tampered", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         Packs.Verify_Binary
           (Meta => Meta_Original,
            Buffer => Buffer.all,
            Used => Used,
            Status => Status);
         if Status /= Errors.OCLW_Hash_Mismatch then
            Mark_Fail ("case1_binary_tamper", Errors.OCLW_Hash_Mismatch, Status);
         else
            Ada.Text_IO.Put_Line
              ("INFO case1_binary_tamper=PASS expected="
               & Errors.Image (Errors.OCLW_Hash_Mismatch));
         end if;
      end if;

      --  Case 2: fingerprint mismatch must be rejected by device selection.
      if not Failed then
         Meta_BadFP := Meta_Original;
         Meta_BadFP.Device_Name :=
           Packs.To_Bounded (Packs.To_String (Meta_Original.Device_Name) & "_tamper");
         Packs.Write_Manifest
           (Path => Manifest_BadFP_Path,
            Meta => Meta_BadFP,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("write_manifest_badfp", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         Packs.Read_Manifest
           (Path => Manifest_BadFP_Path,
            Meta => Meta_BadFP,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("read_manifest_badfp", Errors.Success, Status);
         end if;
      end if;

      if not Failed then
         Loader.Select_Device
           (Meta => Meta_BadFP,
            Platform => Platform,
            Device => Device,
            Status => Status);
         if Status /= Errors.OCLW_Fingerprint_Mismatch then
            Mark_Fail
              ("case2_fingerprint_tamper",
               Errors.OCLW_Fingerprint_Mismatch,
               Status);
         else
            Ada.Text_IO.Put_Line
              ("INFO case2_fingerprint_tamper=PASS expected="
               & Errors.Image (Errors.OCLW_Fingerprint_Mismatch));
         end if;
      end if;

      --  Case 3: corrupt manifest format must be rejected by parser.
      if not Failed then
         declare
            File : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Create
              (File => File,
               Mode => Ada.Text_IO.Out_File,
               Name => Manifest_Corrupt_Path);
            Ada.Text_IO.Put_Line (File, "kpack_version=1");
            Ada.Text_IO.Put_Line (File, "this_line_has_no_equal_sign");
            Ada.Text_IO.Close (File);
         exception
            when others =>
               if Ada.Text_IO.Is_Open (File) then
                  Ada.Text_IO.Close (File);
               end if;
               Mark_Fail
                 ("write_manifest_corrupt",
                  Errors.Success,
                  Errors.OCLW_IO_Error);
         end;
      end if;

      if not Failed then
         Packs.Read_Manifest
           (Path => Manifest_Corrupt_Path,
            Meta => Meta_Corrupt,
            Status => Status);
         if Status /= Errors.OCLW_Pack_Format_Error then
            Mark_Fail
              ("case3_format_tamper",
               Errors.OCLW_Pack_Format_Error,
               Status);
         else
            Ada.Text_IO.Put_Line
              ("INFO case3_format_tamper=PASS expected="
               & Errors.Image (Errors.OCLW_Pack_Format_Error));
         end if;
      end if;

      --  Case 4: overlong manifest line must fail closed.
      if not Failed then
         declare
            File : Ada.Text_IO.File_Type;
            Long_Value : String (1 .. Packs.Max_Manifest_Line_Length + 32);
         begin
            Long_Value := (others => 'A');
            Ada.Text_IO.Create
              (File => File,
               Mode => Ada.Text_IO.Out_File,
               Name => Manifest_Longline_Path);
            Ada.Text_IO.Put_Line (File, "kpack_version=1");
            Ada.Text_IO.Put_Line (File, "pack_id=" & Long_Value);
            Ada.Text_IO.Close (File);
         exception
            when others =>
               if Ada.Text_IO.Is_Open (File) then
                  Ada.Text_IO.Close (File);
               end if;
               Mark_Fail
                 ("write_manifest_longline",
                  Errors.Success,
                  Errors.OCLW_IO_Error);
         end;
      end if;

      if not Failed then
         Packs.Read_Manifest
           (Path => Manifest_Longline_Path,
            Meta => Meta_Corrupt,
            Status => Status);
         if Status /= Errors.OCLW_Pack_Format_Error then
            Mark_Fail
              ("case4_line_limit",
               Errors.OCLW_Pack_Format_Error,
               Status);
         else
            Ada.Text_IO.Put_Line
              ("INFO case4_line_limit=PASS expected="
               & Errors.Image (Errors.OCLW_Pack_Format_Error));
         end if;
      end if;

      if Buffer /= null then
         Free_Program_Byte_Array (Buffer);
      end if;

      if Failed then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      else
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      end if;
   exception
      when others =>
         Ada.Text_IO.Put_Line
           ("ERROR unhandled_exception: "
            & Errors.Image (Errors.OCLW_IO_Error)
            & " status_int="
            & Status_Int_Image (Errors.OCLW_IO_Error));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end;
end Smoke_RT_Negative_Cases;
