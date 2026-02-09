with Interfaces.C;
with System;

package OpenCL.Raw.API is
   --  ABI decision:
   --  OpenCL handles are opaque C pointers, represented as System.Address-sized
   --  opaque scalar types in Ada so we do not assume any record layout.
   --  OpenCL info queries use void* buffers in C, represented with System.Address.

   subtype cl_int is Interfaces.C.int;
   subtype cl_uint is Interfaces.C.unsigned;
   subtype cl_ulong is Interfaces.C.unsigned_long;
   subtype size_t is Interfaces.C.size_t;

   subtype cl_platform_info is cl_uint;
   subtype cl_device_info is cl_uint;
   subtype cl_bitfield is cl_ulong;
   subtype cl_device_type is cl_bitfield;

   type cl_platform_id is new System.Address;
   type cl_device_id is new System.Address;

   type cl_platform_id_array is array (size_t range <>) of aliased cl_platform_id;
   type cl_device_id_array is array (size_t range <>) of aliased cl_device_id;

   CL_SUCCESS : constant cl_int := 0;

   CL_PLATFORM_VERSION : constant cl_platform_info := 16#0901#;
   CL_PLATFORM_NAME : constant cl_platform_info := 16#0902#;
   CL_PLATFORM_VENDOR : constant cl_platform_info := 16#0903#;

   CL_DEVICE_TYPE : constant cl_device_info := 16#1000#;
   CL_DEVICE_NAME : constant cl_device_info := 16#102B#;
   CL_DEVICE_VENDOR : constant cl_device_info := 16#102C#;
   CL_DEVICE_VERSION : constant cl_device_info := 16#102F#;

   CL_DEVICE_TYPE_ALL : constant cl_device_type := 16#FFFF_FFFF#;

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
      device_type : cl_device_type;
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
