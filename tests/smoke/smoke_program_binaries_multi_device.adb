with Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with System;

procedure Smoke_Program_Binaries_Multi_Device is
   package Core renames OpenCL.Core;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Programs renames OpenCL.Core.Programs;

   use type Errors.Status_Code;
   use type Interfaces.C.size_t;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;

   Kernel_Source : constant String :=
     "__kernel void add1(__global const uchar* src, __global uchar* dst) "
     & "{ const size_t gid = get_global_id(0); "
     & "dst[gid] = (uchar)(src[gid] + (uchar)1); }";

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;

   Single_Ctx : Contexts.Context;
   Single_Prg : Programs.Program;
   Multi_Ctx : Contexts.Context;
   Multi_Prg : Programs.Program;

   Single_Bin : Program_Byte_Array_Access := null;
   Multi_Bin_0 : Program_Byte_Array_Access := null;
   Multi_Bin_1 : Program_Byte_Array_Access := null;

   Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Trim_Size_Image (Value : Interfaces.C.size_t) return String is
      Raw : constant String := Interfaces.C.size_t'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Size_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

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

   procedure Cleanup_Single is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Programs.Release (Prg => Single_Prg, Status => Release_Status);
      Contexts.Release (Ctx => Single_Ctx, Status => Release_Status);
      if Single_Bin /= null then
         Free_Program_Byte_Array (Single_Bin);
      end if;
   end Cleanup_Single;

   procedure Cleanup_Multi is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Programs.Release (Prg => Multi_Prg, Status => Release_Status);
      Contexts.Release (Ctx => Multi_Ctx, Status => Release_Status);
      if Multi_Bin_0 /= null then
         Free_Program_Byte_Array (Multi_Bin_0);
      end if;
      if Multi_Bin_1 /= null then
         Free_Program_Byte_Array (Multi_Bin_1);
      end if;
   end Cleanup_Multi;

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

   Ada.Text_IO.Put_Line ("INFO device_count=" & Natural'Image (Device_Used));

   --  Single-device path is mandatory.
   Contexts.Create
     (Device => Devices (Devices'First),
      Ctx => Single_Ctx,
      Status => Status);
   if Status /= Errors.Success then
      Mark_Fail ("single_create_context", Status);
   end if;

   if not Failed then
      Programs.Create_From_Source
        (Ctx => Single_Ctx,
         Source => Kernel_Source,
         Prg => Single_Prg,
         Status => Status);
      if Status /= Errors.Success then
         Mark_Fail ("single_create_program_from_source", Status);
      end if;
   end if;

   if not Failed then
      Programs.Build
        (Prg => Single_Prg,
         Dev => Devices (Devices'First),
         Options => "-cl-std=CL1.2",
         Status => Status);
      if Status /= Errors.Success then
         Mark_Fail ("single_build_program", Status);
      end if;
   end if;

   if not Failed then
      declare
         Num_Devices : Interfaces.C.size_t := 0;
         Binary_Size_0 : Interfaces.C.size_t := 0;
         Binary_Used_0 : Natural := 0;
         Ptrs : Programs.Buffer_Ptr_Array (1 .. 1);
         Sizes : Programs.Size_T_Array (1 .. 1);
      begin
         Programs.Num_Devices
           (Prg => Single_Prg,
            N => Num_Devices,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("single_num_devices", Status);
         elsif Num_Devices /= 1 then
            Mark_Fail ("single_num_devices_not_1", Errors.Invalid_Value);
         end if;

         if not Failed then
            Ada.Text_IO.Put_Line
              ("INFO single_num_devices=" & Trim_Size_Image (Num_Devices));
            Programs.Binary_Size_At
              (Prg => Single_Prg,
               Index => 0,
               Bytes => Binary_Size_0,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("single_binary_size_at_0", Status);
            elsif Binary_Size_0 = 0 then
               Mark_Fail ("single_binary_size_zero", Errors.Invalid_Binary);
            elsif Binary_Size_0 > Interfaces.C.size_t (Positive'Last) then
               Mark_Fail ("single_binary_size_too_large", Errors.OCLW_Limit_Exceeded);
            end if;
         end if;

         if not Failed then
            Ada.Text_IO.Put_Line
              ("INFO single_binary_size_0=" & Trim_Size_Image (Binary_Size_0));

            Single_Bin :=
              new Programs.Byte_Array (1 .. Positive (Integer (Binary_Size_0)));

            Programs.Get_Binary_At
              (Prg => Single_Prg,
               Index => 0,
               Data => Single_Bin.all,
               Used => Binary_Used_0,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("single_get_binary_at_0", Status);
            elsif Binary_Used_0 = 0 then
               Mark_Fail ("single_binary_used_zero", Errors.Invalid_Binary);
            end if;
         end if;

         if not Failed then
            Ptrs (Ptrs'First) := Single_Bin.all (Single_Bin.all'First)'Address;
            Sizes (Sizes'First) := Interfaces.C.size_t (Single_Bin.all'Length);
            Programs.Get_Binaries
              (Prg => Single_Prg,
               Ptrs => Ptrs,
               Sizes => Sizes,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("single_get_binaries", Status);
            end if;
         end if;
      end;
   end if;

   --  Multi-device path is opportunistic and controlled.
   if not Failed then
      if Device_Used < 2 then
         Ada.Text_IO.Put_Line ("INFO multi_device_test=SKIP_NO_MULTI_DEVICE");
      else
         declare
            Selected_Devices : Core.Device_List (1 .. 2);
         begin
            Selected_Devices (1) := Devices (Devices'First);
            Selected_Devices (2) := Devices (Devices'First + 1);

            Contexts.Create
              (Devices => Selected_Devices,
               Used => 2,
               Ctx => Multi_Ctx,
               Status => Status);
            if Status /= Errors.Success then
               Ada.Text_IO.Put_Line
                 ("INFO multi_device_test=SKIP_CONTEXT_CREATE_FAILED status="
                  & Errors.Image (Status)
                  & " status_int="
                  & Status_Int_Image (Status));
            else
               Ada.Text_IO.Put_Line ("INFO multi_device_test=RUN");

               Programs.Create_From_Source
                 (Ctx => Multi_Ctx,
                  Source => Kernel_Source,
                  Prg => Multi_Prg,
                  Status => Status);
               if Status /= Errors.Success then
                  Mark_Fail ("multi_create_program_from_source", Status);
               end if;

               if not Failed then
                  Programs.Build
                    (Prg => Multi_Prg,
                     Dev => Selected_Devices (1),
                     Options => "-cl-std=CL1.2",
                     Status => Status);
                  if Status /= Errors.Success then
                     Mark_Fail ("multi_build_program", Status);
                  end if;
               end if;

               if not Failed then
                  declare
                     Num_Devices : Interfaces.C.size_t := 0;
                     Binary_Size_0 : Interfaces.C.size_t := 0;
                     Binary_Size_1 : Interfaces.C.size_t := 0;
                     Ptrs : Programs.Buffer_Ptr_Array (1 .. 2);
                     Sizes : Programs.Size_T_Array (1 .. 2);
                  begin
                     Programs.Num_Devices
                       (Prg => Multi_Prg,
                        N => Num_Devices,
                        Status => Status);
                     if Status /= Errors.Success then
                        Mark_Fail ("multi_num_devices", Status);
                     elsif Num_Devices /= 2 then
                        Mark_Fail ("multi_num_devices_not_2", Errors.Invalid_Value);
                     end if;

                     if not Failed then
                        Ada.Text_IO.Put_Line
                          ("INFO multi_num_devices=" & Trim_Size_Image (Num_Devices));

                        Programs.Binary_Size_At
                          (Prg => Multi_Prg,
                           Index => 0,
                           Bytes => Binary_Size_0,
                           Status => Status);
                        if Status /= Errors.Success then
                           Mark_Fail ("multi_binary_size_at_0", Status);
                        end if;

                        if not Failed then
                           Programs.Binary_Size_At
                             (Prg => Multi_Prg,
                              Index => 1,
                              Bytes => Binary_Size_1,
                              Status => Status);
                           if Status /= Errors.Success then
                              Mark_Fail ("multi_binary_size_at_1", Status);
                           end if;
                        end if;

                        if not Failed then
                           if Binary_Size_0 = 0 or else Binary_Size_1 = 0 then
                              Mark_Fail ("multi_binary_size_zero", Errors.Invalid_Binary);
                           elsif Binary_Size_0 > Interfaces.C.size_t (Positive'Last)
                             or else Binary_Size_1 > Interfaces.C.size_t (Positive'Last)
                           then
                              Mark_Fail
                                ("multi_binary_size_too_large",
                                 Errors.OCLW_Limit_Exceeded);
                           end if;
                        end if;

                        if not Failed then
                           Ada.Text_IO.Put_Line
                             ("INFO multi_binary_size_0=" & Trim_Size_Image (Binary_Size_0));
                           Ada.Text_IO.Put_Line
                             ("INFO multi_binary_size_1=" & Trim_Size_Image (Binary_Size_1));

                           Multi_Bin_0 :=
                             new Programs.Byte_Array
                               (1 .. Positive (Integer (Binary_Size_0)));
                           Multi_Bin_1 :=
                             new Programs.Byte_Array
                               (1 .. Positive (Integer (Binary_Size_1)));

                           Ptrs (1) :=
                             Multi_Bin_0.all (Multi_Bin_0.all'First)'Address;
                           Ptrs (2) :=
                             Multi_Bin_1.all (Multi_Bin_1.all'First)'Address;
                           Sizes (1) := Interfaces.C.size_t (Multi_Bin_0.all'Length);
                           Sizes (2) := Interfaces.C.size_t (Multi_Bin_1.all'Length);

                           Programs.Get_Binaries
                             (Prg => Multi_Prg,
                              Ptrs => Ptrs,
                              Sizes => Sizes,
                              Status => Status);
                           if Status /= Errors.Success then
                              Mark_Fail ("multi_get_binaries", Status);
                           end if;
                        end if;
                     end if;
                  end;
               end if;
            end if;
         end;
      end if;
   end if;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
   end if;

   Cleanup_Multi;
   Cleanup_Single;
exception
   when others =>
      Cleanup_Multi;
      Cleanup_Single;
      Ada.Text_IO.Put_Line
        ("ERROR unhandled_exception: "
         & Errors.Image (Errors.OCLW_IO_Error)
         & " status_int="
         & Status_Int_Image (Errors.OCLW_IO_Error));
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Smoke_Program_Binaries_Multi_Device;
