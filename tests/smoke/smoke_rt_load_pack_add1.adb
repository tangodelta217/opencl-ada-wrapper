with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
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
with System;

procedure Smoke_RT_Load_Pack_Add1 is
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;

   use type Errors.Status_Code;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Interfaces.C.int;

   Default_Pack_Dir : constant String := "docs/VV/Execution_Logs/local/pack_add1";
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;

   subtype Byte is Interfaces.Unsigned_8;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Host_Byte_Array is array (Byte_Index) of aliased Byte;

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Input_Data : Host_Byte_Array := (others => 0);
   Output_Data : Host_Byte_Array := (others => 0);

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

   Status : Errors.Status_Code := Errors.Success;
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
               return Value;
            end if;
         end;
      end if;

      return Default_Pack_Dir;
   end Resolve_Pack_Dir;

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
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_kernel: " & Errors.Image (Release_Status));
      end if;

      Programs.Release (Prg => Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_program: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => Out_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_out_buffer: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => In_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_in_buffer: " & Errors.Image (Release_Status));
      end if;

      Queues.Release (Q => Q, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_queue: " & Errors.Image (Release_Status));
      end if;

      Contexts.Release (Ctx => Ctx, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_context: " & Errors.Image (Release_Status));
      end if;

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;
   end Cleanup;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO manifest_path=" & Manifest_Path);
      Ada.Text_IO.Put_Line ("INFO binary_path=" & Binary_Path);

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_manifest", Status);
      end if;

      if not Failed then
         if Meta.Binary_Size = 0 then
            Mark_Fail ("manifest_binary_size_zero", Errors.OCLW_Pack_Format_Error);
         elsif Meta.Binary_Size > Interfaces.C.size_t (Positive'Last) then
            Mark_Fail ("manifest_binary_size_too_large", Errors.OCLW_Pack_Format_Error);
         else
            Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));
         end if;
      end if;

      if not Failed then
         Packs.Read_Binary
           (Path => Binary_Path,
            Buffer => Binary_Data.all,
            Used => Binary_Used,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("read_binary", Status);
         end if;
      end if;

      if not Failed then
         Packs.Verify_Binary
           (Meta => Meta,
            Buffer => Binary_Data.all,
            Used => Binary_Used,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("verify_binary", Status);
         end if;
      end if;

      if not Failed then
         declare
            Neg_Meta : Packs.Pack_Metadata := Meta;
            Neg_Platform : Core.Platform;
            Neg_Device : Core.Device;
            Neg_Status : Errors.Status_Code := Errors.Success;
         begin
            Neg_Meta.Device_Name := Packs.To_Bounded ("OCLW_NEGATIVE_DEVICE_NAME");
            Loader.Select_Device
              (Meta => Neg_Meta,
               Platform => Neg_Platform,
               Device => Neg_Device,
               Status => Neg_Status);

            if Neg_Status /= Errors.OCLW_Fingerprint_Mismatch then
               Mark_Fail ("negative_fingerprint_check", Errors.OCLW_Fingerprint_Mismatch);
            else
               Ada.Text_IO.Put_Line ("INFO negative_fingerprint_check=PASS");
            end if;
         end;
      end if;

      if not Failed then
         Loader.Select_Device
           (Meta => Meta,
            Platform => Platform,
            Device => Device,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("select_device", Status);
         end if;
      end if;

      if not Failed then
         Contexts.Create
           (Device => Device,
            Ctx => Ctx,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_context", Status);
         end if;
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

      if not Failed then
         Loader.Create_Program_From_Pack
           (Ctx => Ctx,
            Dev => Device,
            Meta => Meta,
            Bin => Binary_Data.all,
            Used => Binary_Used,
            Prg => Prg,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_program_from_pack", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => In_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_in_buffer", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => Out_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_out_buffer", Status);
         end if;
      end if;

      if not Failed then
         for I in Input_Data'Range loop
            Input_Data (I) := Byte (I mod 256);
         end loop;

         Buffers.Write
           (Q => Q,
            B => In_Buffer,
            Host => Input_Data (Input_Data'First)'Address,
            Bytes => Transfer_Bytes,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("write_in_buffer", Status);
         end if;
      end if;

      if not Failed then
         declare
            Kernel_Name : constant String :=
              Ada.Strings.Fixed.Trim
                (Packs.To_String (Meta.Kernel_Name),
                 Ada.Strings.Both);
         begin
            if Kernel_Name'Length = 0 then
               Mark_Fail ("kernel_name_empty", Errors.OCLW_Pack_Format_Error);
            else
               Kernels.Create
                 (Prg => Prg,
                  Name => Kernel_Name,
                  K => K,
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("create_kernel", Status);
               end if;
            end if;
         end;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer
           (K => K,
            Index => 0,
            B => In_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_0_in_buffer", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer
           (K => K,
            Index => 1,
            B => Out_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_1_out_buffer", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Enqueue_1D
           (Q => Q,
            K => K,
            Global_Size => Transfer_Bytes,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("enqueue_1d", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Read
           (Q => Q,
            B => Out_Buffer,
            Host => Output_Data (Output_Data'First)'Address,
            Bytes => Transfer_Bytes,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("read_out_buffer", Status);
         end if;
      end if;

      if not Failed then
         declare
            Mismatch_Count : Natural := 0;
            First_Mismatch_Index : Natural := 0;
            First_Expected : Byte := 0;
            First_Actual : Byte := 0;
         begin
            for I in Output_Data'Range loop
               declare
                  Expected : constant Byte := Byte ((I + 1) mod 256);
               begin
                  if Output_Data (I) /= Expected then
                     if Mismatch_Count = 0 then
                        First_Mismatch_Index := I;
                        First_Expected := Expected;
                        First_Actual := Output_Data (I);
                     end if;
                     Mismatch_Count := Mismatch_Count + 1;
                  end if;
               end;
            end loop;

            if Mismatch_Count > 0 then
               Ada.Text_IO.Put_Line
                 ("ERROR output_mismatch count=" & Natural'Image (Mismatch_Count));
               Ada.Text_IO.Put_Line
                 ("ERROR first_mismatch index="
                  & Natural'Image (First_Mismatch_Index)
                  & " expected="
                  & Byte'Image (First_Expected)
                  & " actual="
                  & Byte'Image (First_Actual));
               Mark_Fail ("verify_output", Errors.Invalid_Value);
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
end Smoke_RT_Load_Pack_Add1;
