with Interfaces.C;
with System;

package OpenCL.Raw.API is
   --  ABI decision:
   --  OpenCL handles are opaque C pointers. In Ada 2012 we map them to
   --  access-to-opaque-record types to avoid Ada 2022 representation rules
   --  on System.Address-derived types.
   --  OpenCL info queries use void* buffers in C, represented with System.Address.

   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;

   subtype cl_int is Interfaces.C.int;
   subtype cl_uint is Interfaces.C.unsigned;
   subtype cl_ulong is Interfaces.C.unsigned_long_long;
   subtype size_t is Interfaces.C.size_t;

   subtype cl_platform_info is cl_uint;
   subtype cl_device_info is cl_uint;
   subtype cl_bitfield is cl_ulong;

   --  Keep CL_DEVICE_TYPE constant name (device-info query) and avoid Ada
   --  case-insensitive identifier collision with the C type name.
   subtype cl_device_type_mask is cl_bitfield;

   type cl_platform_id_struct is null record;
   pragma Convention (C, cl_platform_id_struct);

   type cl_device_id_struct is null record;
   pragma Convention (C, cl_device_id_struct);

   type cl_platform_id is access all cl_platform_id_struct;
   pragma Convention (C, cl_platform_id);

   type cl_device_id is access all cl_device_id_struct;
   pragma Convention (C, cl_device_id);

   type cl_platform_id_array is array (size_t range <>) of aliased cl_platform_id;
   type cl_device_id_array is array (size_t range <>) of aliased cl_device_id;

   --  ABI checks (GNAT): stop compilation if target C mapping does not match
   --  expected OpenCL ABI widths/alignment.
   pragma Compile_Time_Error
     (cl_int'Size /= 32,
      "ABI check failed: cl_int must be 32-bit");
   pragma Compile_Time_Error
     (cl_uint'Size /= 32,
      "ABI check failed: cl_uint must be 32-bit");
   pragma Compile_Time_Error
     (cl_ulong'Size /= 64,
      "ABI check failed: cl_ulong must be 64-bit");
   pragma Compile_Time_Error
     (cl_platform_id'Size /= System.Address'Size,
      "ABI check failed: cl_platform_id size mismatch");
   pragma Compile_Time_Error
     (cl_device_id'Size /= System.Address'Size,
      "ABI check failed: cl_device_id size mismatch");

   CL_SUCCESS : constant cl_int := 0;
   CL_DEVICE_NOT_FOUND : constant cl_int := cl_int (-1);
   CL_PLATFORM_NOT_FOUND_KHR : constant cl_int := cl_int (-1001);

   CL_PLATFORM_VERSION : constant cl_platform_info := 16#0901#;
   CL_PLATFORM_NAME : constant cl_platform_info := 16#0902#;
   CL_PLATFORM_VENDOR : constant cl_platform_info := 16#0903#;

   CL_DEVICE_TYPE : constant cl_device_info := 16#1000#;
   CL_DEVICE_NAME : constant cl_device_info := 16#102B#;
   CL_DEVICE_VENDOR : constant cl_device_info := 16#102C#;
   CL_DRIVER_VERSION : constant cl_device_info := 16#102D#;
   CL_DEVICE_VERSION : constant cl_device_info := 16#102F#;

   CL_DEVICE_TYPE_DEFAULT : constant cl_device_type_mask := 16#0000_0001#;
   CL_DEVICE_TYPE_CPU : constant cl_device_type_mask := 16#0000_0002#;
   CL_DEVICE_TYPE_GPU : constant cl_device_type_mask := 16#0000_0004#;
   CL_DEVICE_TYPE_ACCELERATOR : constant cl_device_type_mask := 16#0000_0008#;
   CL_DEVICE_TYPE_CUSTOM : constant cl_device_type_mask := 16#0000_0010#;
   CL_DEVICE_TYPE_ALL : constant cl_device_type_mask := 16#FFFF_FFFF#;

   function clGetPlatformIDs
     (num_entries : cl_uint;
      platforms : access cl_platform_id;
      num_platforms : access cl_uint) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clGetPlatformIDs";

   function clGetPlatformInfo
     (platform : cl_platform_id;
      param_name : cl_platform_info;
      param_value_size : size_t;
      param_value : System.Address;
      param_value_size_ret : access size_t) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clGetPlatformInfo";

   function clGetDeviceIDs
     (platform : cl_platform_id;
      device_type : cl_device_type_mask;
      num_entries : cl_uint;
      devices : access cl_device_id;
      num_devices : access cl_uint) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clGetDeviceIDs";

   function clGetDeviceInfo
     (device : cl_device_id;
      param_name : cl_device_info;
      param_value_size : size_t;
      param_value : System.Address;
      param_value_size_ret : access size_t) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clGetDeviceInfo";

end OpenCL.Raw.API;
