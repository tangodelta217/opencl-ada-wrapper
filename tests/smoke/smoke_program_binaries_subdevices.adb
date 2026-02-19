with Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.Raw.API;
with System;

procedure Smoke_Program_Binaries_Subdevices is
   package API renames OpenCL.Raw.API;
   package Core renames OpenCL.Core;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Programs renames OpenCL.Core.Programs;

   use type API.cl_device_id;
   use type API.cl_int;
   use type API.cl_uint;
   use type API.cl_device_partition_property;
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

   type Raw_Device_Array is array (Natural range <>) of aliased API.cl_device_id;
   type Raw_Device_Array_Access is access Raw_Device_Array;
   procedure Free_Raw_Device_Array is new Ada.Unchecked_Deallocation
     (Object => Raw_Device_Array,
      Name => Raw_Device_Array_Access);

   type Partition_Property_Array is
     array (Natural range <>) of aliased API.cl_device_partition_property;

   function To_Raw_Device is new Ada.Unchecked_Conversion
     (Source => Core.Device,
      Target => API.cl_device_id);

   function To_Core_Device is new Ada.Unchecked_Conversion
     (Source => API.cl_device_id,
      Target => Core.Device);

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;

   Ctx : Contexts.Context;
   Prg : Programs.Program;
   Bin_0 : Program_Byte_Array_Access := null;
   Bin_1 : Program_Byte_Array_Access := null;

   Raw_Subdevices : Raw_Device_Array_Access := null;
   Raw_Subdevice_Count : Natural := 0;

   Subdevices_Created : Natural := 0;
   Num_Devices_Value : Interfaces.C.size_t := 0;
   Binary_Size_0 : Interfaces.C.size_t := 0;
   Binary_Size_1 : Interfaces.C.size_t := 0;

   Failed : Boolean := False;
   Skipped : Boolean := False;
   Skip_Reason : Ada.Strings.Unbounded.Unbounded_String :=
     Ada.Strings.Unbounded.To_Unbounded_String ("unknown");

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

   function Trim_Size_Image (Value : Interfaces.C.size_t) return String is
      Raw : constant String := Interfaces.C.size_t'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Size_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function To_Status (Code : API.cl_int) return Errors.Status_Code is
   begin
      return Errors.Status_Code (Code);
   end To_Status;

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

   procedure Mark_Skip (Reason : String) is
   begin
      Skip_Reason := Ada.Strings.Unbounded.To_Unbounded_String (Reason);
      Skipped := True;
   end Mark_Skip;

   procedure Print_Stable_Info is
   begin
      Ada.Text_IO.Put_Line
        ("INFO subdevices_created=" & Trim_Natural_Image (Subdevices_Created));
      Ada.Text_IO.Put_Line
        ("INFO num_devices=" & Trim_Size_Image (Num_Devices_Value));
      Ada.Text_IO.Put_Line
        ("INFO binary_size_0=" & Trim_Size_Image (Binary_Size_0));
      Ada.Text_IO.Put_Line
        ("INFO binary_size_1=" & Trim_Size_Image (Binary_Size_1));
   end Print_Stable_Info;

   procedure Cleanup is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Programs.Release (Prg => Prg, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Bin_0 /= null then
         Free_Program_Byte_Array (Bin_0);
      end if;
      if Bin_1 /= null then
         Free_Program_Byte_Array (Bin_1);
      end if;

      if Raw_Subdevices /= null then
         for I in Raw_Subdevices'Range loop
            if Raw_Subdevices (I) /= null then
               declare
                  Ignore_Device_Status : constant API.cl_int :=
                    API.clReleaseDevice (Raw_Subdevices (I));
               begin
                  pragma Unreferenced (Ignore_Device_Status);
               end;
            end if;
         end loop;
         Free_Raw_Device_Array (Raw_Subdevices);
      end if;
   end Cleanup;

begin
   declare
      Status : Errors.Status_Code := Errors.Success;
   begin
      Core.Enumerate_Platforms
        (Out_Platforms => Platforms,
         Used => Platform_Used,
         Status => Status);
      if Platform_Used = 0 then
         Mark_Skip ("no_platform");
      elsif Status /= Errors.Success then
         Mark_Skip (Errors.Image (Status));
      end if;
   end;

   if not Skipped then
      declare
         Status : Errors.Status_Code := Errors.Success;
      begin
         Core.Enumerate_Devices
           (P => Platforms (Platforms'First),
            Out_Devices => Devices,
            Used => Device_Used,
            Status => Status);
         if Device_Used = 0 then
            Mark_Skip ("no_device");
         elsif Status /= Errors.Success then
            Mark_Skip (Errors.Image (Status));
         end if;
      end;
   end if;

   if not Skipped then
      declare
         Raw_Device : constant API.cl_device_id := To_Raw_Device (Devices (Devices'First));
         Max_Sub_Devices : aliased API.cl_uint := 0;
         Max_Compute_Units : aliased API.cl_uint := 0;
         Prop_Size_Ret : aliased API.size_t := 0;
         type Prop_Info_Array is array (Natural range <>) of aliased API.cl_device_partition_property;
         Prop_Info : aliased Prop_Info_Array (0 .. 15) := (others => 0);
         Raw_Status : API.cl_int := API.CL_SUCCESS;
         UInt_Bytes : constant API.size_t :=
           API.size_t (API.cl_uint'Size / System.Storage_Unit);
         Prop_Bytes : constant API.size_t :=
           API.size_t (Prop_Info'Length)
           * API.size_t (API.cl_device_partition_property'Size / System.Storage_Unit);
         Supports_Equally : Boolean := False;
         Partition_Units : API.cl_device_partition_property := 1;
         Partition_Props : aliased Partition_Property_Array (0 .. 2) :=
           (0 => API.CL_DEVICE_PARTITION_EQUALLY,
            1 => 1,
            2 => 0);
         Query_Count : aliased API.cl_uint := 0;
      begin
         if Raw_Device = null then
            Mark_Skip ("invalid_root_device");
         end if;

         if not Skipped then
            Raw_Status := API.clGetDeviceInfo
              (device => Raw_Device,
               param_name => API.CL_DEVICE_PARTITION_MAX_SUB_DEVICES,
               param_value_size => UInt_Bytes,
               param_value => Max_Sub_Devices'Address,
               param_value_size_ret => null);
            if Raw_Status /= API.CL_SUCCESS then
               Mark_Skip
                 ("partition_query_failed_"
                  & Trim_Int_Image (Interfaces.C.int (Raw_Status)));
            end if;
         end if;

         if not Skipped then
            Raw_Status := API.clGetDeviceInfo
              (device => Raw_Device,
               param_name => API.CL_DEVICE_MAX_COMPUTE_UNITS,
               param_value_size => UInt_Bytes,
               param_value => Max_Compute_Units'Address,
               param_value_size_ret => null);
            if Raw_Status /= API.CL_SUCCESS then
               Mark_Skip
                 ("compute_units_query_failed_"
                  & Trim_Int_Image (Interfaces.C.int (Raw_Status)));
            elsif Max_Sub_Devices < 2 or else Max_Compute_Units < 2 then
               Mark_Skip ("partition_not_supported_or_insufficient_units");
            end if;
         end if;

         if not Skipped then
            Raw_Status := API.clGetDeviceInfo
              (device => Raw_Device,
               param_name => API.CL_DEVICE_PARTITION_PROPERTIES,
               param_value_size => Prop_Bytes,
               param_value => Prop_Info (Prop_Info'First)'Address,
               param_value_size_ret => Prop_Size_Ret'Access);

            if Raw_Status /= API.CL_SUCCESS then
               Mark_Skip
                 ("partition_properties_query_failed_"
                  & Trim_Int_Image (Interfaces.C.int (Raw_Status)));
            else
               for I in Prop_Info'Range loop
                  exit when Prop_Info (I) = 0;
                  if Prop_Info (I) = API.CL_DEVICE_PARTITION_EQUALLY then
                     Supports_Equally := True;
                     exit;
                  end if;
               end loop;

               if not Supports_Equally then
                  Mark_Skip ("partition_equally_not_supported");
               end if;
            end if;
         end if;

         if not Skipped then
            Partition_Units := API.cl_device_partition_property (Max_Compute_Units / 2);
            if Partition_Units < 1 then
               Partition_Units := 1;
            end if;
            Partition_Props (1) := Partition_Units;

            Raw_Status := API.clCreateSubDevices
              (in_device => Raw_Device,
               properties => Partition_Props (Partition_Props'First)'Access,
               num_devices => 0,
               out_devices => null,
               num_devices_ret => Query_Count'Access);

            if Raw_Status /= API.CL_SUCCESS then
               Mark_Skip
                 ("create_subdevices_query_failed_"
                  & Trim_Int_Image (Interfaces.C.int (Raw_Status)));
            elsif Query_Count < 2 then
               Mark_Skip ("subdevices_below_2");
            end if;
         end if;

         if not Skipped then
            Raw_Subdevice_Count := Natural (Query_Count);
            Raw_Subdevices := new Raw_Device_Array (0 .. Raw_Subdevice_Count - 1);
            for I in Raw_Subdevices'Range loop
               Raw_Subdevices (I) := null;
            end loop;

            Raw_Status := API.clCreateSubDevices
              (in_device => Raw_Device,
               properties => Partition_Props (Partition_Props'First)'Access,
               num_devices => Query_Count,
               out_devices => Raw_Subdevices (Raw_Subdevices'First)'Access,
               num_devices_ret => null);

            if Raw_Status /= API.CL_SUCCESS then
               Mark_Skip
                 ("create_subdevices_failed_"
                  & Trim_Int_Image (Interfaces.C.int (Raw_Status)));
            else
               Subdevices_Created := 2;
            end if;
         end if;
      end;
   end if;

   if not Skipped then
      declare
         Sub_Devices : Core.Device_List (1 .. 2);
         Status : Errors.Status_Code := Errors.Success;
      begin
         Sub_Devices (1) := To_Core_Device (Raw_Subdevices (0));
         Sub_Devices (2) := To_Core_Device (Raw_Subdevices (1));

         Contexts.Create
           (Devices => Sub_Devices,
            Used => 2,
            Ctx => Ctx,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("create_context_subdevices", Status);
         end if;

         if not Failed then
            Programs.Create_From_Source
              (Ctx => Ctx,
               Source => Kernel_Source,
               Prg => Prg,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("create_program_from_source", Status);
            end if;
         end if;

         if not Failed then
            Programs.Build
              (Prg => Prg,
               Dev => Sub_Devices (1),
               Options => "-cl-std=CL1.2",
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("build_program_device_0", Status);
            end if;
         end if;

         if not Failed then
            Programs.Build
              (Prg => Prg,
               Dev => Sub_Devices (2),
               Options => "-cl-std=CL1.2",
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("build_program_device_1", Status);
            end if;
         end if;

         if not Failed then
            Programs.Num_Devices
              (Prg => Prg,
               N => Num_Devices_Value,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("num_devices", Status);
            elsif Num_Devices_Value /= 2 then
               Mark_Skip ("num_devices_not_2");
            end if;
         end if;

         if not Failed and then not Skipped then
            Programs.Binary_Size_At
              (Prg => Prg,
               Index => 0,
               Bytes => Binary_Size_0,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("binary_size_at_0", Status);
            end if;
         end if;

         if not Failed and then not Skipped then
            Programs.Binary_Size_At
              (Prg => Prg,
               Index => 1,
               Bytes => Binary_Size_1,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("binary_size_at_1", Status);
            end if;
         end if;

         if not Failed and then not Skipped then
            if Binary_Size_0 = 0 or else Binary_Size_1 = 0 then
               Mark_Fail ("binary_size_zero", Errors.Invalid_Binary);
            elsif Binary_Size_0 > Interfaces.C.size_t (Positive'Last)
              or else Binary_Size_1 > Interfaces.C.size_t (Positive'Last)
            then
               Mark_Fail ("binary_size_too_large", Errors.OCLW_Limit_Exceeded);
            end if;
         end if;

         if not Failed and then not Skipped then
            declare
               Ptrs : Programs.Buffer_Ptr_Array (1 .. 2);
               Sizes : Programs.Size_T_Array (1 .. 2);
            begin
               Bin_0 := new Programs.Byte_Array (1 .. Positive (Integer (Binary_Size_0)));
               Bin_1 := new Programs.Byte_Array (1 .. Positive (Integer (Binary_Size_1)));

               Ptrs (1) := Bin_0.all (Bin_0.all'First)'Address;
               Ptrs (2) := Bin_1.all (Bin_1.all'First)'Address;
               Sizes (1) := Interfaces.C.size_t (Bin_0.all'Length);
               Sizes (2) := Interfaces.C.size_t (Bin_1.all'Length);

               Programs.Get_Binaries
                 (Prg => Prg,
                  Ptrs => Ptrs,
                  Sizes => Sizes,
                  Status => Status);
               if Status /= Errors.Success then
                  Mark_Fail ("get_binaries", Status);
               end if;
            end;
         end if;
      end;
   end if;

   Print_Stable_Info;

   if Skipped then
      Ada.Text_IO.Put_Line
        ("RESULT=SKIP reason=" & Ada.Strings.Unbounded.To_String (Skip_Reason));
   elsif Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
   end if;

   Cleanup;
exception
   when others =>
      Cleanup;
      Print_Stable_Info;
      Ada.Text_IO.Put_Line
        ("ERROR unhandled_exception: "
         & Errors.Image (Errors.OCLW_IO_Error)
         & " status_int="
         & Status_Int_Image (Errors.OCLW_IO_Error));
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Smoke_Program_Binaries_Subdevices;
