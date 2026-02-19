with Interfaces.C;
with OpenCL.Errors;
with System;

package body OpenCL.Core is

   use type API.cl_int;
   use type API.cl_uint;
   use type API.size_t;
   use type API.cl_platform_id;
   use type API.cl_device_id;

   type Raw_Platform_List is array (Positive range <>) of aliased API.cl_platform_id;
   type Raw_Device_List is array (Positive range <>) of aliased API.cl_device_id;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   function Min_Count (Reported : API.cl_uint; Capacity : Natural) return Natural is
   begin
      if Capacity = 0 then
         return 0;
      elsif Reported > API.cl_uint (Capacity) then
         return Capacity;
      else
         return Natural (Reported);
      end if;
   end Min_Count;

   function To_Raw (What : Platform_Info_Kind) return API.cl_platform_info is
   begin
      case What is
         when Name =>
            return API.CL_PLATFORM_NAME;
         when Vendor =>
            return API.CL_PLATFORM_VENDOR;
         when Version =>
            return API.CL_PLATFORM_VERSION;
      end case;
   end To_Raw;

   function To_Raw (What : Device_Info_Kind) return API.cl_device_info is
   begin
      case What is
         when Name =>
            return API.CL_DEVICE_NAME;
         when Vendor =>
            return API.CL_DEVICE_VENDOR;
         when Version =>
            return API.CL_DEVICE_VERSION;
         when Driver_Version =>
            return API.CL_DRIVER_VERSION;
      end case;
   end To_Raw;

   procedure Enumerate_Platforms
     (Out_Platforms : out Platform_List;
      Used : out Natural;
      Status : out OpenCL.Errors.Status_Code)
   is
      Count_Raw : aliased API.cl_uint := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      To_Copy : Natural := 0;
   begin
      for I in Out_Platforms'Range loop
         Out_Platforms (I).Handle := null;
      end loop;

      Used := 0;
      Status := OpenCL.Errors.Success;

      Raw_Status := API.clGetPlatformIDs
        (num_entries => 0,
         platforms => null,
         num_platforms => Count_Raw'Access);

      if Raw_Status = API.CL_PLATFORM_NOT_FOUND_KHR then
         Status := OpenCL.Errors.Platform_Not_Found_KHR;
         return;
      elsif Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      To_Copy := Min_Count (Count_Raw, Out_Platforms'Length);
      if To_Copy = 0 then
         return;
      end if;

      declare
         Handles : Raw_Platform_List (1 .. To_Copy) := (others => null);
      begin
         Raw_Status := API.clGetPlatformIDs
           (num_entries => API.cl_uint (To_Copy),
            platforms => Handles (Handles'First)'Access,
            num_platforms => null);

         if Raw_Status = API.CL_PLATFORM_NOT_FOUND_KHR then
            Status := OpenCL.Errors.Platform_Not_Found_KHR;
            return;
         elsif Raw_Status /= API.CL_SUCCESS then
            Status := To_Status (Raw_Status);
            return;
         end if;

         for Offset in 0 .. To_Copy - 1 loop
            Out_Platforms (Out_Platforms'First + Offset).Handle :=
              Handles (Handles'First + Offset);
         end loop;
         Used := To_Copy;
      end;
   end Enumerate_Platforms;

   procedure Enumerate_Devices
     (P : Platform;
      Out_Devices : out Device_List;
      Used : out Natural;
      Status : out Status_Code)
   is
      Count_Raw : aliased API.cl_uint := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      To_Copy : Natural := 0;
   begin
      for I in Out_Devices'Range loop
         Out_Devices (I).Handle := null;
      end loop;

      Used := 0;
      Status := OpenCL.Errors.Success;

      if P.Handle = null then
         Status := OpenCL.Errors.Invalid_Platform;
         return;
      end if;

      Raw_Status := API.clGetDeviceIDs
        (platform => P.Handle,
         device_type => API.CL_DEVICE_TYPE_ALL,
         num_entries => 0,
         devices => null,
         num_devices => Count_Raw'Access);

      if Raw_Status = API.CL_DEVICE_NOT_FOUND then
         Status := OpenCL.Errors.Device_Not_Found;
         return;
      elsif Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      To_Copy := Min_Count (Count_Raw, Out_Devices'Length);
      if To_Copy = 0 then
         return;
      end if;

      declare
         Handles : Raw_Device_List (1 .. To_Copy) := (others => null);
      begin
         Raw_Status := API.clGetDeviceIDs
           (platform => P.Handle,
            device_type => API.CL_DEVICE_TYPE_ALL,
            num_entries => API.cl_uint (To_Copy),
            devices => Handles (Handles'First)'Access,
            num_devices => null);

         if Raw_Status = API.CL_DEVICE_NOT_FOUND then
            Status := OpenCL.Errors.Device_Not_Found;
            return;
         elsif Raw_Status /= API.CL_SUCCESS then
            Status := To_Status (Raw_Status);
            return;
         end if;

         for Offset in 0 .. To_Copy - 1 loop
            Out_Devices (Out_Devices'First + Offset).Handle :=
              Handles (Handles'First + Offset);
         end loop;
         Used := To_Copy;
      end;
   end Enumerate_Devices;

   function Get_Platform_Info
     (P : Platform;
      What : Platform_Info_Kind;
      Status : out OpenCL.Errors.Status_Code;
      Max_Bytes : Positive := Default_Max_Info_Bytes) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if P.Handle = null then
         Status := OpenCL.Errors.Invalid_Platform;
         return "";
      end if;

      Raw_Status := API.clGetPlatformInfo
        (platform => P.Handle,
         param_name => To_Raw (What),
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return "";
      end if;

      if Needed = 0 then
         return "";
      end if;

      if Needed > API.size_t (Max_Bytes) then
         Copy_Size := API.size_t (Max_Bytes);
      else
         Copy_Size := Needed;
      end if;

      declare
         subtype Info_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      begin
         Raw_Status := API.clGetPlatformInfo
           (platform => P.Handle,
            param_name => To_Raw (What),
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Raw_Status /= API.CL_SUCCESS then
            Status := To_Status (Raw_Status);
            return "";
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
      end;
   end Get_Platform_Info;

   function Get_Device_Info
     (D : Device;
      What : Device_Info_Kind;
      Status : out OpenCL.Errors.Status_Code;
      Max_Bytes : Positive := Default_Max_Info_Bytes) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if D.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         return "";
      end if;

      Raw_Status := API.clGetDeviceInfo
        (device => D.Handle,
         param_name => To_Raw (What),
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return "";
      end if;

      if Needed = 0 then
         return "";
      end if;

      if Needed > API.size_t (Max_Bytes) then
         Copy_Size := API.size_t (Max_Bytes);
      else
         Copy_Size := Needed;
      end if;

      declare
         subtype Info_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      begin
         Raw_Status := API.clGetDeviceInfo
           (device => D.Handle,
            param_name => To_Raw (What),
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Raw_Status /= API.CL_SUCCESS then
            Status := To_Status (Raw_Status);
            return "";
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
      end;
   end Get_Device_Info;

   function Device_Image_Support
     (D : Device;
      Status : out OpenCL.Errors.Status_Code) return Boolean
   is
      Value : aliased API.cl_bool := API.CL_FALSE;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Bool_Bytes : constant API.size_t :=
        API.size_t (API.cl_bool'Size / System.Storage_Unit);
   begin
      Status := OpenCL.Errors.Success;

      if D.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         return False;
      end if;

      Raw_Status := API.clGetDeviceInfo
        (device => D.Handle,
         param_name => API.CL_DEVICE_IMAGE_SUPPORT,
         param_value_size => Bool_Bytes,
         param_value => Value'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return False;
      end if;

      return Value /= API.CL_FALSE;
   end Device_Image_Support;

end OpenCL.Core;
