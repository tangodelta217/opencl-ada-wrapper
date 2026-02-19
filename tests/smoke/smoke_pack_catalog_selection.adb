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
with OpenCL.RT.Catalog;
with OpenCL.RT.Loader;
with OpenCL.RT.Packs;

procedure Smoke_Pack_Catalog_Selection is
   --  OCLW-TST-0024: deterministic pack catalog selection + no-match fail-closed.
   package Buffers renames OpenCL.Core.Buffers;
   package Catalog renames OpenCL.RT.Catalog;
   package Contexts renames OpenCL.Core.Contexts;
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;

   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;

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

   procedure Ensure_Clean_Dir (Path : String; Status : out Errors.Status_Code) is
   begin
      Status := Errors.Success;
      begin
         if Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_Tree (Directory => Path);
         end if;
      exception
         when others =>
            Status := Errors.OCLW_IO_Error;
            return;
      end;

      begin
         Ada.Directories.Create_Path (New_Directory => Path);
      exception
         when others =>
            Status := Errors.OCLW_IO_Error;
      end;
   end Ensure_Clean_Dir;

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
      Cleanup_Status : Errors.Status_Code := Errors.Success;
   begin
      if Gen_Exec'Length = 0 then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=missing_gen_pack_add1");
         return False;
      end if;

      Ensure_Clean_Dir (Path => Pack_Dir, Status => Cleanup_Status);
      if Cleanup_Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=cannot_prepare_pack_dir");
         return False;
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

   procedure Copy_Pack
     (Source_Dir : String;
      Target_Dir : String;
      Status : out Errors.Status_Code)
   is
      Source_Manifest : constant String := Source_Dir & "/manifest.kpack";
      Source_Binary : constant String := Source_Dir & "/program.bin";
      Target_Manifest : constant String := Target_Dir & "/manifest.kpack";
      Target_Binary : constant String := Target_Dir & "/program.bin";
   begin
      Ensure_Clean_Dir (Path => Target_Dir, Status => Status);
      if Status /= Errors.Success then
         return;
      end if;

      begin
         Ada.Directories.Copy_File
           (Source_Name => Source_Manifest,
            Target_Name => Target_Manifest);
         Ada.Directories.Copy_File
           (Source_Name => Source_Binary,
            Target_Name => Target_Binary);
      exception
         when others =>
            Status := Errors.OCLW_IO_Error;
            return;
      end;

      Status := Errors.Success;
   end Copy_Pack;

   procedure Tamper_Device_Fingerprint
     (Manifest_Path : String;
      Status : out Errors.Status_Code)
   is
      Meta : Packs.Pack_Metadata;
   begin
      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if Status /= Errors.Success then
         return;
      end if;

      Meta.Device_Name := Packs.To_Bounded ("OCLW-G24-ALTERED-DEVICE");
      Packs.Write_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
   end Tamper_Device_Fingerprint;

   procedure Execute_Add1_From_Pack
     (Pack_Dir : String;
      Status : out Errors.Status_Code)
   is
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";

      Meta : Packs.Pack_Metadata;
      Binary_Data : Program_Byte_Array_Access := null;
      Binary_Used : Natural := 0;

      Platform : Core.Platform;
      Device : Core.Device;
      Ctx : Contexts.Context;
      Q : Queues.Queue;
      In_Buffer : Buffers.Buffer;
      Out_Buffer : Buffers.Buffer;
      Prg : Programs.Program;
      K : Kernels.Kernel;

      Input_Data : Host_Byte_Array := (others => 0);
      Output_Data : Host_Byte_Array := (others => 0);
      Release_Status : Errors.Status_Code := Errors.Success;

      procedure Cleanup is
      begin
         Kernels.Release (K => K, Status => Release_Status);
         Programs.Release (Prg => Prg, Status => Release_Status);
         Buffers.Release (B => Out_Buffer, Status => Release_Status);
         Buffers.Release (B => In_Buffer, Status => Release_Status);
         Queues.Release (Q => Q, Status => Release_Status);
         Contexts.Release (Ctx => Ctx, Status => Release_Status);
         if Binary_Data /= null then
            Free_Program_Byte_Array (Binary_Data);
         end if;
      end Cleanup;
   begin
      Status := Errors.Success;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      if Meta.Binary_Size = 0
        or else Meta.Binary_Size > Interfaces.C.size_t (Positive'Last)
      then
         Status := Errors.OCLW_Pack_Format_Error;
         Cleanup;
         return;
      end if;

      Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));

      Packs.Read_Binary
        (Path => Binary_Path,
         Buffer => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Packs.Verify_Binary
        (Meta => Meta,
         Buffer => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Loader.Select_Device
        (Meta => Meta,
         Platform => Platform,
         Device => Device,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Contexts.Create (Device => Device, Ctx => Ctx, Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Queues.Create (Ctx => Ctx, Dev => Device, Q => Q, Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Loader.Create_Program_From_Pack
        (Ctx => Ctx,
         Dev => Device,
         Meta => Meta,
         Bin => Binary_Data.all,
         Used => Binary_Used,
         Prg => Prg,
         Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Buffers.Create (Ctx => Ctx, Bytes => Transfer_Bytes, B => In_Buffer, Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Buffers.Create (Ctx => Ctx, Bytes => Transfer_Bytes, B => Out_Buffer, Status => Status);
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
         Kernel_Name : constant String :=
           Ada.Strings.Fixed.Trim (Packs.To_String (Meta.Kernel_Name), Ada.Strings.Both);
      begin
         if Kernel_Name'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            Cleanup;
            return;
         end if;

         Kernels.Create (Prg => Prg, Name => Kernel_Name, K => K, Status => Status);
      end;
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Kernels.Set_Arg_Buffer (K => K, Index => 0, B => In_Buffer, Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Kernels.Set_Arg_Buffer (K => K, Index => 1, B => Out_Buffer, Status => Status);
      if Status /= Errors.Success then
         Cleanup;
         return;
      end if;

      Kernels.Enqueue_1D (Q => Q, K => K, Global_Size => Transfer_Bytes, Status => Status);
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
      Status := Errors.Success;
   exception
      when others =>
         Cleanup;
         Status := Errors.OCLW_IO_Error;
   end Execute_Add1_From_Pack;

begin
   declare
      Base_Dir : constant String := "/tmp/oclw_g24_pack_catalog_selection";
      Source_Pack_Dir : constant String := Base_Dir & "/source_pack";
      Catalog_Positive_Dir : constant String := Base_Dir & "/catalog_positive";
      Catalog_Negative_Dir : constant String := Base_Dir & "/catalog_negative";
      Variant_A_Dir : constant String := Catalog_Positive_Dir & "/001_variantA";
      Variant_B_Dir : constant String := Catalog_Positive_Dir & "/002_variantB";
      Variant_B_Neg_Dir : constant String := Catalog_Negative_Dir & "/001_variantB";

      Source_Manifest : constant String := Source_Pack_Dir & "/manifest.kpack";
      Source_Binary : constant String := Source_Pack_Dir & "/program.bin";
      Variant_B_Manifest : constant String := Variant_B_Dir & "/manifest.kpack";
      Variant_B_Neg_Manifest : constant String := Variant_B_Neg_Dir & "/manifest.kpack";

      Selected_Pack_Dir : Packs.Bounded_String := Packs.To_Bounded ("");
      Status : Errors.Status_Code := Errors.Success;
      Positive_Pass : Boolean := False;
      Negative_Pass : Boolean := False;
   begin
      Ada.Text_IO.Put_Line ("INFO base_dir=" & Base_Dir);
      Ada.Text_IO.Put_Line ("INFO catalog_positive_dir=" & Catalog_Positive_Dir);
      Ada.Text_IO.Put_Line ("INFO catalog_negative_dir=" & Catalog_Negative_Dir);

      Ensure_Clean_Dir (Path => Base_Dir, Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=tmp_dir_unavailable");
         return;
      end if;

      if not Ensure_Base_Pack
               (Pack_Dir => Source_Pack_Dir,
                Manifest_Path => Source_Manifest,
                Binary_Path => Source_Binary)
      then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=base_pack_unavailable");
         return;
      end if;

      Copy_Pack (Source_Dir => Source_Pack_Dir, Target_Dir => Variant_A_Dir, Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Copy_Pack (Source_Dir => Source_Pack_Dir, Target_Dir => Variant_B_Dir, Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Copy_Pack
        (Source_Dir => Source_Pack_Dir,
         Target_Dir => Variant_B_Neg_Dir,
         Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Tamper_Device_Fingerprint (Manifest_Path => Variant_B_Manifest, Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Tamper_Device_Fingerprint (Manifest_Path => Variant_B_Neg_Manifest, Status => Status);
      if Status /= Errors.Success then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Catalog.Load_From_Catalog
        (Catalog_Dir => Catalog_Positive_Dir,
         Out_Pack_Dir => Selected_Pack_Dir,
         Status => Status);
      if Status = Errors.Success then
         declare
            Selected : constant String := Packs.To_String (Selected_Pack_Dir);
         begin
            Ada.Text_IO.Put_Line ("INFO selected_pack_dir=" & Selected);
            if Selected /= Variant_A_Dir then
               Ada.Text_IO.Put_Line ("INFO case_positive=FAIL reason=unexpected_variant");
            else
               Execute_Add1_From_Pack (Pack_Dir => Selected, Status => Status);
               if Status = Errors.Success then
                  Positive_Pass := True;
                  Ada.Text_IO.Put_Line ("INFO case_positive=PASS");
               else
                  Ada.Text_IO.Put_Line
                    ("INFO case_positive=FAIL status="
                     & Errors.Image (Status)
                     & " status_int="
                     & Status_Int_Image (Status));
               end if;
            end if;
         end;
      else
         Ada.Text_IO.Put_Line
           ("INFO case_positive=FAIL status="
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
      end if;

      Catalog.Load_From_Catalog
        (Catalog_Dir => Catalog_Negative_Dir,
         Out_Pack_Dir => Selected_Pack_Dir,
         Status => Status);
      if Status = Errors.OCLW_Fingerprint_Mismatch then
         Negative_Pass := True;
         Ada.Text_IO.Put_Line
           ("INFO case_negative=PASS expected=OCLW_FINGERPRINT_MISMATCH");
      else
         Ada.Text_IO.Put_Line
           ("INFO case_negative=FAIL expected="
            & Errors.Image (Errors.OCLW_Fingerprint_Mismatch)
            & " got="
            & Errors.Image (Status)
            & " got_int="
            & Status_Int_Image (Status));
      end if;

      if Positive_Pass and then Negative_Pass then
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
end Smoke_Pack_Catalog_Selection;
