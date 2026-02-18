with Ada.Command_Line;
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
with System;

procedure Smoke_Program_Binary_Roundtrip is
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;

   use type Errors.Status_Code;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;

   Kernel_Source : constant String :=
     "__kernel void add1(__global const uchar* src, __global uchar* dst) "
     & "{ const size_t gid = get_global_id(0); "
     & "dst[gid] = (uchar)(src[gid] + (uchar)1); }";

   subtype Byte is Interfaces.Unsigned_8;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Host_Byte_Array is array (Byte_Index) of aliased Byte;

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Input_Data : Host_Byte_Array := (others => 0);
   Output_Data : Host_Byte_Array := (others => 0);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;
   Binary_Status : Errors.Status_Code := Errors.Success;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   In_Buffer : Buffers.Buffer;
   Out_Buffer : Buffers.Buffer;
   Source_Prg : Programs.Program;
   Binary_Prg : Programs.Program;
   K : Kernels.Kernel;

   Binary_Bytes : Interfaces.C.size_t := 0;
   Binary_Used : Natural := 0;
   Binary_Data : Program_Byte_Array_Access := null;

   Failed : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Trim_Natural_Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Natural_Image;

   function Trim_U32_Image (Value : Interfaces.Unsigned_32) return String is
      Raw : constant String := Interfaces.Unsigned_32'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_U32_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function FNV1a_32
     (Data : Programs.Byte_Array;
      Used : Natural) return Interfaces.Unsigned_32
   is
      Hash : Interfaces.Unsigned_32 := 16#811C9DC5#;
      Prime : constant Interfaces.Unsigned_32 := 16#01000193#;
   begin
      if Used = 0 then
         return Hash;
      end if;

      for Offset in 0 .. Used - 1 loop
         declare
            Index : constant Positive := Data'First + Integer (Offset);
            Value : constant Interfaces.Unsigned_32 :=
              Interfaces.Unsigned_32 (Data (Index));
         begin
            Hash := (Hash xor Value) * Prime;
         end;
      end loop;

      return Hash;
   end FNV1a_32;

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

      Programs.Release (Prg => Binary_Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_binary_program: " & Errors.Image (Release_Status));
      end if;

      Programs.Release (Prg => Source_Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_source_program: " & Errors.Image (Release_Status));
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
   Core.Enumerate_Platforms
     (Out_Platforms => Platforms,
      Used => Platform_Used,
      Status => Status);
   if Platform_Used = 0 then
      Ada.Text_IO.Put_Line ("RESULT=SKIP reason=" & Errors.Image (Status));
      return;
   end if;

   Core.Enumerate_Devices
     (P => Platforms (Platforms'First),
      Out_Devices => Devices,
      Used => Device_Used,
      Status => Status);
   if Device_Used = 0 then
      Ada.Text_IO.Put_Line ("RESULT=SKIP reason=" & Errors.Image (Status));
      return;
   end if;

   Contexts.Create
     (Device => Devices (Devices'First),
      Ctx => Ctx,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_context", Status);
   end if;

   if not Failed then
      Queues.Create
        (Ctx => Ctx,
         Dev => Devices (Devices'First),
         Q => Q,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_queue", Status);
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
      Programs.Create_From_Source
        (Ctx => Ctx,
         Source => Kernel_Source,
         Prg => Source_Prg,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_program_from_source", Status);
      end if;
   end if;

   if not Failed then
      Programs.Build
        (Prg => Source_Prg,
         Dev => Devices (Devices'First),
         Options => "-cl-std=CL1.2",
         Status => Status);

      if not Errors.Is_Success (Status) then
         Ada.Text_IO.Put_Line
           ("ERROR build_source_program: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Ada.Text_IO.Put_Line ("BUILD_LOG_BEGIN");
         Ada.Text_IO.Put_Line
           (Programs.Build_Log
              (Prg => Source_Prg,
               Dev => Devices (Devices'First),
               Status => Binary_Status,
               Max_Bytes => 65_536));
         Ada.Text_IO.Put_Line ("BUILD_LOG_END");
         Failed := True;
      end if;
   end if;

   if not Failed then
      Programs.Binary_Size
        (Prg => Source_Prg,
         Bytes => Binary_Bytes,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("binary_size", Status);
      elsif Binary_Bytes = 0 then
         Mark_Fail ("binary_size_zero", Errors.Invalid_Binary);
      elsif Binary_Bytes > Interfaces.C.size_t (Positive'Last) then
         Mark_Fail ("binary_size_too_large", Errors.Invalid_Value);
      end if;
   end if;

   if not Failed then
      declare
         Checksum : Interfaces.Unsigned_32 := 0;
      begin
         Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Binary_Bytes)));

         Programs.Get_Binary
           (Prg => Source_Prg,
            Data => Binary_Data.all,
            Used => Binary_Used,
            Status => Status);

         if not Errors.Is_Success (Status) then
            Mark_Fail ("get_binary", Status);
         elsif Binary_Used = 0 then
            Mark_Fail ("get_binary_used_zero", Errors.Invalid_Binary);
         elsif Binary_Used > Natural (Binary_Bytes) then
            Mark_Fail ("get_binary_used_out_of_range", Errors.Invalid_Value);
         else
            Checksum := FNV1a_32 (Data => Binary_Data.all, Used => Binary_Used);
            Ada.Text_IO.Put_Line ("INFO binary_size=" & Trim_Natural_Image (Binary_Used));
            Ada.Text_IO.Put_Line ("INFO binary_fnv1a32=" & Trim_U32_Image (Checksum));
         end if;
      end;
   end if;

   if not Failed then
      Programs.Release (Prg => Source_Prg, Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("release_source_program_before_reload", Status);
      end if;
   end if;

   if not Failed then
      Programs.Create_From_Binary
        (Ctx => Ctx,
         Dev => Devices (Devices'First),
         Data => Binary_Data.all,
         Prg => Binary_Prg,
         Binary_Status => Binary_Status,
         Status => Status);

      if not Errors.Is_Success (Status) or else not Errors.Is_Success (Binary_Status) then
         Ada.Text_IO.Put_Line
           ("ERROR create_program_from_binary: status="
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Ada.Text_IO.Put_Line
           ("ERROR create_program_from_binary_device_status="
            & Errors.Image (Binary_Status)
            & " status_int="
            & Status_Int_Image (Binary_Status));
         Failed := True;
      end if;
   end if;

   if not Failed then
      Programs.Build
        (Prg => Binary_Prg,
         Dev => Devices (Devices'First),
         Options => "",
         Status => Status);
      if not Errors.Is_Success (Status) then
         Ada.Text_IO.Put_Line
           ("ERROR build_binary_program: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Ada.Text_IO.Put_Line ("BUILD_LOG_BEGIN");
         Ada.Text_IO.Put_Line
           (Programs.Build_Log
              (Prg => Binary_Prg,
               Dev => Devices (Devices'First),
               Status => Binary_Status,
               Max_Bytes => 65_536));
         Ada.Text_IO.Put_Line ("BUILD_LOG_END");
         Failed := True;
      end if;
   end if;

   if not Failed then
      Kernels.Create
        (Prg => Binary_Prg,
         Name => "add1",
         K => K,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_kernel", Status);
      end if;
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
      Queues.Finish (Q => Q, Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("finish_queue", Status);
      end if;
   end if;

   if not Failed then
      for I in Output_Data'Range loop
         Output_Data (I) := 0;
      end loop;

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
               Expected : constant Byte :=
                 Byte ((Integer (Input_Data (I)) + 1) mod 256);
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
              ("ERROR binary_roundtrip_mismatch count="
               & Trim_Natural_Image (Mismatch_Count));
            Ada.Text_IO.Put_Line
              ("ERROR first_mismatch index="
               & Trim_Natural_Image (First_Mismatch_Index)
               & " expected="
               & Trim_Natural_Image (Natural (First_Expected))
               & " actual="
               & Trim_Natural_Image (Natural (First_Actual)));
            Failed := True;
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
end Smoke_Program_Binary_Roundtrip;
