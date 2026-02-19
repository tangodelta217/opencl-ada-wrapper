with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Images;
with OpenCL.Core.Kernels;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Core.Samplers;
with OpenCL.Errors;

procedure Smoke_Image_Roundtrip is
   package Core renames OpenCL.Core;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Images renames OpenCL.Core.Images;
   package Kernels renames OpenCL.Core.Kernels;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package Samplers renames OpenCL.Core.Samplers;

   use type Errors.Status_Code;
   use type Interfaces.C.unsigned_char;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Width_Px : constant Positive := 32;
   Height_Px : constant Positive := 32;
   Pixel_Bytes : constant Positive := 4;
   Image_Bytes : constant Positive := Width_Px * Height_Px * Pixel_Bytes;
   Global_Work_Items : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Width_Px * Height_Px);
   Row_Pitch : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Width_Px * Pixel_Bytes);

   Kernel_Source : constant String :=
     "__kernel void copy_rgba(read_only image2d_t src, "
     & "write_only image2d_t dst, sampler_t smp) "
     & "{ int gid = (int)get_global_id(0); "
     & "int width = get_image_width(src); "
     & "int2 p = (int2)(gid % width, gid / width); "
     & "uint4 v = read_imageui(src, smp, p); "
     & "write_imageui(dst, p, v); }";

   subtype Byte is Interfaces.C.unsigned_char;
   subtype Byte_Index is Natural range 0 .. Image_Bytes - 1;
   type Byte_Array is array (Byte_Index) of aliased Byte;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Input_Data : Byte_Array := (others => 0);
   Output_Data : Byte_Array := (others => 0);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;
   Supports_Images : Boolean := False;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   Src_Image : Images.Image;
   Dst_Image : Images.Image;
   Smpl : Samplers.Sampler;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Failed : Boolean := False;

   procedure Mark_Fail (Step : String; Code : Errors.Status_Code) is
   begin
      Ada.Text_IO.Put_Line ("ERROR " & Step & ": " & Errors.Image (Code));
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

      Samplers.Release (S => Smpl, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_sampler: " & Errors.Image (Release_Status));
      end if;

      Images.Release (Img => Dst_Image, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_dst_image: " & Errors.Image (Release_Status));
      end if;

      Images.Release (Img => Src_Image, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_src_image: " & Errors.Image (Release_Status));
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

   Supports_Images := Core.Device_Image_Support
     (D => Devices (Devices'First),
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("query_device_image_support", Status);
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if not Supports_Images then
      Ada.Text_IO.Put_Line ("RESULT=SKIP reason=CL_DEVICE_IMAGE_SUPPORT=0");
      return;
   end if;

   for Y in 0 .. Height_Px - 1 loop
      for X in 0 .. Width_Px - 1 loop
         declare
            Base : constant Natural := (Y * Width_Px + X) * Pixel_Bytes;
         begin
            Input_Data (Base + 0) := Byte (X mod 256);
            Input_Data (Base + 1) := Byte (Y mod 256);
            Input_Data (Base + 2) := Byte ((X + Y) mod 256);
            Input_Data (Base + 3) := Byte (16#FF#);
         end;
      end loop;
   end loop;

   Contexts.Create
     (Device => Devices (Devices'First),
      Ctx => Ctx,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_context", Status);
      Cleanup;
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Queues.Create
     (Ctx => Ctx,
      Dev => Devices (Devices'First),
      Q => Q,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_queue", Status);
      Cleanup;
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Images.Create_Image2D_RGBA8
     (Ctx => Ctx,
      Width => Interfaces.C.size_t (Width_Px),
      Height => Interfaces.C.size_t (Height_Px),
      Img => Src_Image,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_src_image", Status);
   end if;

   if not Failed then
      Images.Create_Image2D_RGBA8
        (Ctx => Ctx,
         Width => Interfaces.C.size_t (Width_Px),
         Height => Interfaces.C.size_t (Height_Px),
         Img => Dst_Image,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_dst_image", Status);
      end if;
   end if;

   if not Failed then
      Samplers.Create_Basic
        (Ctx => Ctx,
         S => Smpl,
         Status => Status,
         Normalized_Coords => False);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_sampler", Status);
      end if;
   end if;

   if not Failed then
      Images.Write
        (Q => Q,
         Img => Src_Image,
         Host => Input_Data (Input_Data'First)'Address,
         Width => Interfaces.C.size_t (Width_Px),
         Height => Interfaces.C.size_t (Height_Px),
         Row_Pitch => Row_Pitch,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("write_src_image", Status);
      end if;
   end if;

   if not Failed then
      Programs.Create_From_Source
        (Ctx => Ctx,
         Source => Kernel_Source,
         Prg => Prg,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_program_from_source", Status);
      end if;
   end if;

   if not Failed then
      Programs.Build
        (Prg => Prg,
         Dev => Devices (Devices'First),
         Options => "-cl-std=CL1.2",
         Status => Status);
      if not Errors.Is_Success (Status) then
         Ada.Text_IO.Put_Line
           ("INFO build_log="
            & Programs.Build_Log
              (Prg => Prg,
               Dev => Devices (Devices'First),
               Status => Status));
         Mark_Fail ("build_program", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Create
        (Prg => Prg,
         Name => "copy_rgba",
         K => K,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_kernel", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Image
        (K => K,
         Index => 0,
         Img => Src_Image,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_src_image", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Image
        (K => K,
         Index => 1,
         Img => Dst_Image,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_dst_image", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Sampler
        (K => K,
         Index => 2,
         S => Smpl,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_sampler", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Enqueue_1D
        (Q => Q,
         K => K,
         Global_Size => Global_Work_Items,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("enqueue_copy_rgba", Status);
      end if;
   end if;

   if not Failed then
      Images.Read
        (Q => Q,
         Img => Dst_Image,
         Host => Output_Data (Output_Data'First)'Address,
         Width => Interfaces.C.size_t (Width_Px),
         Height => Interfaces.C.size_t (Height_Px),
         Row_Pitch => Row_Pitch,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_dst_image", Status);
      end if;
   end if;

   if not Failed then
      declare
         Mismatch_Count : Natural := 0;
         First_Mismatch_Index : Natural := 0;
      begin
         for I in Output_Data'Range loop
            if Output_Data (I) /= Input_Data (I) then
               if Mismatch_Count = 0 then
                  First_Mismatch_Index := I;
               end if;
               Mismatch_Count := Mismatch_Count + 1;
            end if;
         end loop;

         if Mismatch_Count > 0 then
            Ada.Text_IO.Put_Line
              ("ERROR image_roundtrip_mismatch count="
               & Natural'Image (Mismatch_Count)
               & " first_index="
               & Natural'Image (First_Mismatch_Index));
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
end Smoke_Image_Roundtrip;
