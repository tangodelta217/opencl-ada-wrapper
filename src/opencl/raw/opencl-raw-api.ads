with Interfaces.C;
with Interfaces.C.Strings;
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
   subtype cl_program_info is cl_uint;
   subtype cl_program_build_info is cl_uint;
   subtype cl_bitfield is cl_ulong;
   subtype cl_bool is cl_uint;
   subtype cl_mem_flags is cl_bitfield;
   subtype cl_command_queue_properties is cl_bitfield;
   subtype cl_build_status is cl_int;

   --  Keep CL_DEVICE_TYPE constant name (device-info query) and avoid Ada
   --  case-insensitive identifier collision with the C type name.
   subtype cl_device_type_mask is cl_bitfield;

   type cl_platform_id_struct is null record;
   pragma Convention (C, cl_platform_id_struct);

   type cl_device_id_struct is null record;
   pragma Convention (C, cl_device_id_struct);

   type cl_context_struct is null record;
   pragma Convention (C, cl_context_struct);

   type cl_command_queue_struct is null record;
   pragma Convention (C, cl_command_queue_struct);

   type cl_mem_struct is null record;
   pragma Convention (C, cl_mem_struct);

   type cl_event_struct is null record;
   pragma Convention (C, cl_event_struct);

   type cl_program_struct is null record;
   pragma Convention (C, cl_program_struct);

   type cl_kernel_struct is null record;
   pragma Convention (C, cl_kernel_struct);

   type cl_platform_id is access all cl_platform_id_struct;
   pragma Convention (C, cl_platform_id);

   type cl_device_id is access all cl_device_id_struct;
   pragma Convention (C, cl_device_id);

   type cl_context is access all cl_context_struct;
   pragma Convention (C, cl_context);

   type cl_command_queue is access all cl_command_queue_struct;
   pragma Convention (C, cl_command_queue);

   type cl_mem is access all cl_mem_struct;
   pragma Convention (C, cl_mem);

   type cl_event is access all cl_event_struct;
   pragma Convention (C, cl_event);

   type cl_program is access all cl_program_struct;
   pragma Convention (C, cl_program);

   type cl_kernel is access all cl_kernel_struct;
   pragma Convention (C, cl_kernel);

   type cl_platform_id_array is array (size_t range <>) of aliased cl_platform_id;
   type cl_device_id_array is array (size_t range <>) of aliased cl_device_id;
   type cl_event_array is array (size_t range <>) of aliased cl_event;

   --  ABI checks (GNAT): stop compilation if target C mapping does not match
   --  expected OpenCL ABI widths/alignment.
   pragma Compile_Time_Error
     (cl_int'Size /= 32,
      "ABI check failed: cl_int must be 32-bit");
   pragma Compile_Time_Error
     (cl_uint'Size /= 32,
      "ABI check failed: cl_uint must be 32-bit");
   pragma Compile_Time_Error
     (cl_bool'Size /= 32,
      "ABI check failed: cl_bool must be 32-bit");
   pragma Compile_Time_Error
     (cl_ulong'Size /= 64,
      "ABI check failed: cl_ulong must be 64-bit");
   pragma Compile_Time_Error
     (cl_platform_id'Size /= System.Address'Size,
      "ABI check failed: cl_platform_id size mismatch");
   pragma Compile_Time_Error
     (cl_device_id'Size /= System.Address'Size,
      "ABI check failed: cl_device_id size mismatch");
   pragma Compile_Time_Error
     (cl_context'Size /= System.Address'Size,
      "ABI check failed: cl_context size mismatch");
   pragma Compile_Time_Error
     (cl_command_queue'Size /= System.Address'Size,
      "ABI check failed: cl_command_queue size mismatch");
   pragma Compile_Time_Error
     (cl_mem'Size /= System.Address'Size,
      "ABI check failed: cl_mem size mismatch");
   pragma Compile_Time_Error
     (cl_event'Size /= System.Address'Size,
      "ABI check failed: cl_event size mismatch");
   pragma Compile_Time_Error
     (cl_program'Size /= System.Address'Size,
      "ABI check failed: cl_program size mismatch");
   pragma Compile_Time_Error
     (cl_kernel'Size /= System.Address'Size,
      "ABI check failed: cl_kernel size mismatch");

   CL_SUCCESS : constant cl_int := 0;
   CL_DEVICE_NOT_FOUND : constant cl_int := cl_int (-1);
   CL_COMPILER_NOT_AVAILABLE : constant cl_int := cl_int (-3);
   CL_OUT_OF_RESOURCES : constant cl_int := cl_int (-5);
   CL_OUT_OF_HOST_MEMORY : constant cl_int := cl_int (-6);
   CL_BUILD_PROGRAM_FAILURE : constant cl_int := cl_int (-11);
   CL_INVALID_BINARY : constant cl_int := cl_int (-42);
   CL_INVALID_PROGRAM : constant cl_int := cl_int (-44);
   CL_PLATFORM_NOT_FOUND_KHR : constant cl_int := cl_int (-1001);

   CL_FALSE : constant cl_bool := cl_bool (0);
   CL_TRUE : constant cl_bool := cl_bool (1);

   CL_PLATFORM_VERSION : constant cl_platform_info := 16#0901#;
   CL_PLATFORM_NAME : constant cl_platform_info := 16#0902#;
   CL_PLATFORM_VENDOR : constant cl_platform_info := 16#0903#;

   CL_DEVICE_TYPE : constant cl_device_info := 16#1000#;
   CL_DEVICE_NAME : constant cl_device_info := 16#102B#;
   CL_DEVICE_VENDOR : constant cl_device_info := 16#102C#;
   CL_DRIVER_VERSION : constant cl_device_info := 16#102D#;
   CL_DEVICE_VERSION : constant cl_device_info := 16#102F#;
   CL_DEVICE_COMPILER_AVAILABLE : constant cl_device_info := 16#1028#;
   CL_DEVICE_OPENCL_C_VERSION : constant cl_device_info := 16#103D#;

   CL_DEVICE_TYPE_DEFAULT : constant cl_device_type_mask := 16#0000_0001#;
   CL_DEVICE_TYPE_CPU : constant cl_device_type_mask := 16#0000_0002#;
   CL_DEVICE_TYPE_GPU : constant cl_device_type_mask := 16#0000_0004#;
   CL_DEVICE_TYPE_ACCELERATOR : constant cl_device_type_mask := 16#0000_0008#;
   CL_DEVICE_TYPE_CUSTOM : constant cl_device_type_mask := 16#0000_0010#;
   CL_DEVICE_TYPE_ALL : constant cl_device_type_mask := 16#FFFF_FFFF#;

   CL_MEM_READ_WRITE : constant cl_mem_flags := 16#0000_0001#;

   CL_PROGRAM_BUILD_STATUS : constant cl_program_build_info := 16#1181#;
   CL_PROGRAM_BUILD_OPTIONS : constant cl_program_build_info := 16#1182#;
   CL_PROGRAM_BUILD_LOG : constant cl_program_build_info := 16#1183#;
   CL_PROGRAM_NUM_DEVICES : constant cl_program_info := 16#1162#;
   CL_PROGRAM_SOURCE : constant cl_program_info := 16#1164#;
   CL_PROGRAM_BINARY_SIZES : constant cl_program_info := 16#1165#;
   CL_PROGRAM_BINARIES : constant cl_program_info := 16#1166#;

   CL_BUILD_SUCCESS : constant cl_build_status := cl_build_status (0);
   CL_BUILD_NONE : constant cl_build_status := cl_build_status (-1);
   CL_BUILD_ERROR : constant cl_build_status := cl_build_status (-2);
   CL_BUILD_IN_PROGRESS : constant cl_build_status := cl_build_status (-3);

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

   function clCreateContext
     (properties : System.Address;
      num_devices : cl_uint;
      devices : access cl_device_id;
      pfn_notify : System.Address;
      user_data : System.Address;
      errcode_ret : access cl_int) return cl_context
   with
     Import,
     Convention => C,
     External_Name => "clCreateContext";

   function clReleaseContext
     (context : cl_context) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clReleaseContext";

   function clCreateCommandQueue
     (context : cl_context;
      device : cl_device_id;
      properties : cl_command_queue_properties;
      errcode_ret : access cl_int) return cl_command_queue
   with
     Import,
     Convention => C,
     External_Name => "clCreateCommandQueue";

   function clReleaseCommandQueue
     (command_queue : cl_command_queue) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clReleaseCommandQueue";

   function clCreateBuffer
     (context : cl_context;
      flags : cl_mem_flags;
      size : size_t;
      host_ptr : System.Address;
      errcode_ret : access cl_int) return cl_mem
   with
     Import,
     Convention => C,
     External_Name => "clCreateBuffer";

   function clReleaseMemObject
     (memobj : cl_mem) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clReleaseMemObject";

   function clEnqueueWriteBuffer
     (command_queue : cl_command_queue;
      buffer : cl_mem;
      blocking_write : cl_bool;
      offset : size_t;
      size : size_t;
      ptr : System.Address;
      num_events_in_wait_list : cl_uint;
      event_wait_list : access cl_event;
      event : access cl_event) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clEnqueueWriteBuffer";

   function clEnqueueReadBuffer
     (command_queue : cl_command_queue;
      buffer : cl_mem;
      blocking_read : cl_bool;
      offset : size_t;
      size : size_t;
      ptr : System.Address;
      num_events_in_wait_list : cl_uint;
      event_wait_list : access cl_event;
      event : access cl_event) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clEnqueueReadBuffer";

   function clFinish
     (command_queue : cl_command_queue) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clFinish";

   --  ABI note:
   --  For pointer-to-pointer / pointer-array C parameters (`const char**`,
   --  `const size_t*` and NDRange arrays), this thin binding uses
   --  `System.Address`. Thick binding passes the address of the first element
   --  of a properly laid-out C-compatible array.

   function clCreateProgramWithSource
     (context : cl_context;
      count : cl_uint;
      strings : System.Address;
      lengths : System.Address;
      errcode_ret : access cl_int) return cl_program
   with
     Import,
     Convention => C,
     External_Name => "clCreateProgramWithSource";

   function clCreateProgramWithBinary
     (context : cl_context;
      num_devices : cl_uint;
      device_list : access cl_device_id;
      lengths : System.Address;
      binaries : System.Address;
      binary_status : access cl_int;
      errcode_ret : access cl_int) return cl_program
   with
     Import,
     Convention => C,
     External_Name => "clCreateProgramWithBinary";

   function clBuildProgram
     (program : cl_program;
      num_devices : cl_uint;
      device_list : access cl_device_id;
      options : Interfaces.C.Strings.chars_ptr;
      pfn_notify : System.Address;
      user_data : System.Address) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clBuildProgram";

   function clGetProgramInfo
     (program : cl_program;
      param_name : cl_program_info;
      param_value_size : size_t;
      param_value : System.Address;
      param_value_size_ret : access size_t) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clGetProgramInfo";

   function clGetProgramBuildInfo
     (program : cl_program;
      device : cl_device_id;
      param_name : cl_program_build_info;
      param_value_size : size_t;
      param_value : System.Address;
      param_value_size_ret : access size_t) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clGetProgramBuildInfo";

   function clReleaseProgram
     (program : cl_program) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clReleaseProgram";

   function clCreateKernel
     (program : cl_program;
      kernel_name : Interfaces.C.Strings.chars_ptr;
      errcode_ret : access cl_int) return cl_kernel
   with
     Import,
     Convention => C,
     External_Name => "clCreateKernel";

   function clSetKernelArg
     (kernel : cl_kernel;
      arg_index : cl_uint;
      arg_size : size_t;
      arg_value : System.Address) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clSetKernelArg";

   function clEnqueueNDRangeKernel
     (command_queue : cl_command_queue;
      kernel : cl_kernel;
      work_dim : cl_uint;
      global_work_offset : System.Address;
      global_work_size : System.Address;
      local_work_size : System.Address;
      num_events_in_wait_list : cl_uint;
      event_wait_list : access cl_event;
      event : access cl_event) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clEnqueueNDRangeKernel";

   function clReleaseKernel
     (kernel : cl_kernel) return cl_int
   with
     Import,
     Convention => C,
     External_Name => "clReleaseKernel";

end OpenCL.Raw.API;
