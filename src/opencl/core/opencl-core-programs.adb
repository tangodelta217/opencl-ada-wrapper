with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.Core.Contexts;
with System;

package body OpenCL.Core.Programs is

   use type API.cl_context;
   use type API.cl_device_id;
   use type API.cl_int;
   use type API.cl_uint;
   use type API.cl_program;
   use type API.size_t;
   use type Interfaces.C.Strings.chars_ptr;
   use type OpenCL.Errors.Status_Code;

   Truncated_Suffix : constant String := "[TRUNCATED]";
   Build_Log_Unavailable_Prefix : constant String := "BUILD_LOG_UNAVAILABLE: ";
   Source_Unavailable_Prefix : constant String := "PROGRAM_SOURCE_UNAVAILABLE: ";

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   function Clamp_Size
     (Needed : API.size_t;
      Max_Bytes : Positive;
      Truncated : out Boolean) return API.size_t
   is
   begin
      if Needed > API.size_t (Max_Bytes) then
         Truncated := True;
         return API.size_t (Max_Bytes);
      else
         Truncated := False;
         return Needed;
      end if;
   end Clamp_Size;

   function Has_Single_Device
     (Prg : Program;
      Status : out Status_Code) return Boolean
   is
      Num_Devices : aliased API.cl_uint := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      UInt_Bytes : constant API.size_t :=
        API.size_t (API.cl_uint'Size / System.Storage_Unit);
   begin
      Status := OpenCL.Errors.Success;

      Raw_Status := API.clGetProgramInfo
        (program => Prg.Handle,
         param_name => API.CL_PROGRAM_NUM_DEVICES,
         param_value_size => UInt_Bytes,
         param_value => Num_Devices'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return False;
      end if;

      if Num_Devices /= 1 then
         Status := OpenCL.Errors.Invalid_Value;
         return False;
      end if;

      return True;
   end Has_Single_Device;

   procedure Create_From_Source
     (Ctx : OpenCL.Core.Contexts.Context;
      Source : String;
      Prg : out Program;
      Status : out Status_Code)
   is
      Raw_Ctx : constant API.cl_context := OpenCL.Core.Contexts.Raw_Handle (Ctx);
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
      Source_String : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Source_Pointers : aliased Interfaces.C.Strings.chars_ptr_array (0 .. 0) :=
        (others => Interfaces.C.Strings.Null_Ptr);
   begin
      Prg.Handle := null;
      Status := OpenCL.Errors.Success;

      if Raw_Ctx = null then
         Status := OpenCL.Errors.Invalid_Context;
         return;
      end if;

      Source_String := Interfaces.C.Strings.New_String (Source);
      Source_Pointers (Source_Pointers'First) := Source_String;

      Prg.Handle := API.clCreateProgramWithSource
        (context => Raw_Ctx,
         count => 1,
         strings => Source_Pointers (Source_Pointers'First)'Address,
         lengths => System.Null_Address,
         errcode_ret => Error_Code'Access);

      if Source_String /= Interfaces.C.Strings.Null_Ptr then
         Interfaces.C.Strings.Free (Source_String);
      end if;

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;
   end Create_From_Source;

   procedure Build
     (Prg : Program;
      Dev : OpenCL.Core.Device;
      Options : String;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Options_Ptr : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
   begin
      Status := OpenCL.Errors.Success;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Invalid_Program;
         return;
      end if;

      if Dev.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         return;
      end if;

      --  Build all devices in the program context (OpenCL allows
      --  `num_devices = 0` with `device_list = NULL`).
      if Options'Length = 0 then
         Raw_Status := API.clBuildProgram
           (program => Prg.Handle,
            num_devices => 0,
            device_list => null,
            options => Interfaces.C.Strings.Null_Ptr,
            pfn_notify => System.Null_Address,
            user_data => System.Null_Address);
      else
         Options_Ptr := Interfaces.C.Strings.New_String (Options);
         Raw_Status := API.clBuildProgram
           (program => Prg.Handle,
            num_devices => 0,
            device_list => null,
            options => Options_Ptr,
            pfn_notify => System.Null_Address,
            user_data => System.Null_Address);
         if Options_Ptr /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Options_Ptr);
         end if;
      end if;

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Build;

   function Build_Log
     (Prg : Program;
      Dev : OpenCL.Core.Device;
      Status : out Status_Code;
      Max_Bytes : Positive := 65_536) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Truncated : Boolean := False;
   begin
      Status := OpenCL.Errors.Success;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Invalid_Program;
         return Build_Log_Unavailable_Prefix & OpenCL.Errors.Image (Status);
      end if;

      if Dev.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         return Build_Log_Unavailable_Prefix & OpenCL.Errors.Image (Status);
      end if;

      Raw_Status := API.clGetProgramBuildInfo
        (program => Prg.Handle,
         device => Dev.Handle,
         param_name => API.CL_PROGRAM_BUILD_LOG,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return Build_Log_Unavailable_Prefix & OpenCL.Errors.Image (Status);
      end if;

      if Needed = 0 then
         return "";
      end if;

      Copy_Size := Clamp_Size
        (Needed => Needed,
         Max_Bytes => Max_Bytes,
         Truncated => Truncated);

      declare
         subtype Log_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Log_Buffer := (others => Interfaces.C.nul);
      begin
         Raw_Status := API.clGetProgramBuildInfo
           (program => Prg.Handle,
            device => Dev.Handle,
            param_name => API.CL_PROGRAM_BUILD_LOG,
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Raw_Status /= API.CL_SUCCESS then
            Status := To_Status (Raw_Status);
            return Build_Log_Unavailable_Prefix & OpenCL.Errors.Image (Status);
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         declare
            Text : constant String := Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
         begin
            if Truncated then
               return Text & Truncated_Suffix;
            else
               return Text;
            end if;
         end;
      end;
   end Build_Log;

   function Source
     (Prg : Program;
      Status : out Status_Code;
      Max_Bytes : Positive := 16_384) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Truncated : Boolean := False;
   begin
      Status := OpenCL.Errors.Success;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Invalid_Program;
         return Source_Unavailable_Prefix & OpenCL.Errors.Image (Status);
      end if;

      Raw_Status := API.clGetProgramInfo
        (program => Prg.Handle,
         param_name => API.CL_PROGRAM_SOURCE,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return Source_Unavailable_Prefix & OpenCL.Errors.Image (Status);
      end if;

      if Needed = 0 then
         return "";
      end if;

      Copy_Size := Clamp_Size
        (Needed => Needed,
         Max_Bytes => Max_Bytes,
         Truncated => Truncated);

      declare
         subtype Source_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Source_Buffer := (others => Interfaces.C.nul);
      begin
         Raw_Status := API.clGetProgramInfo
           (program => Prg.Handle,
            param_name => API.CL_PROGRAM_SOURCE,
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Raw_Status /= API.CL_SUCCESS then
            Status := To_Status (Raw_Status);
            return Source_Unavailable_Prefix & OpenCL.Errors.Image (Status);
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         declare
            Text : constant String := Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
         begin
            if Truncated then
               return Text & Truncated_Suffix;
            else
               return Text;
            end if;
         end;
      end;
   end Source;

   procedure Binary_Size
     (Prg : Program;
      Bytes : out Interfaces.C.size_t;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Binary_Bytes : aliased API.size_t := 0;
      Size_T_Bytes : constant API.size_t :=
        API.size_t (API.size_t'Size / System.Storage_Unit);
   begin
      Bytes := 0;
      Status := OpenCL.Errors.Success;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Invalid_Program;
         return;
      end if;

      if not Has_Single_Device (Prg, Status) then
         return;
      end if;

      Raw_Status := API.clGetProgramInfo
        (program => Prg.Handle,
         param_name => API.CL_PROGRAM_BINARY_SIZES,
         param_value_size => Size_T_Bytes,
         param_value => Binary_Bytes'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      Bytes := Binary_Bytes;
   end Binary_Size;

   procedure Get_Binary
     (Prg : Program;
      Data : out Byte_Array;
      Used : out Natural;
      Status : out Status_Code)
   is
      Expected_Size : API.size_t := 0;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Address_Bytes : constant API.size_t :=
        API.size_t (System.Address'Size / System.Storage_Unit);

      type Address_Array is array (Natural range <>) of aliased System.Address;
      Binary_Pointers : aliased Address_Array (0 .. 0) :=
        (others => System.Null_Address);
   begin
      Used := 0;
      Status := OpenCL.Errors.Success;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Invalid_Program;
         return;
      end if;

      Binary_Size
        (Prg => Prg,
         Bytes => Expected_Size,
         Status => Status);
      if Status /= OpenCL.Errors.Success then
         return;
      end if;

      if Expected_Size = 0 then
         return;
      end if;

      if Expected_Size > API.size_t (Data'Length) then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Binary_Pointers (Binary_Pointers'First) := Data (Data'First)'Address;

      Raw_Status := API.clGetProgramInfo
        (program => Prg.Handle,
         param_name => API.CL_PROGRAM_BINARIES,
         param_value_size => Address_Bytes,
         param_value => Binary_Pointers (Binary_Pointers'First)'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      Used := Natural (Expected_Size);
   end Get_Binary;

   procedure Create_From_Binary
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Data : Byte_Array;
      Prg : out Program;
      Binary_Status : out OpenCL.Errors.Status_Code;
      Status : out OpenCL.Errors.Status_Code)
   is
      Raw_Ctx : constant API.cl_context := OpenCL.Core.Contexts.Raw_Handle (Ctx);
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;

      type Device_Array is array (Natural range <>) of aliased API.cl_device_id;
      type Size_Array is array (Natural range <>) of aliased API.size_t;
      type Address_Array is array (Natural range <>) of aliased System.Address;
      type Int_Array is array (Natural range <>) of aliased API.cl_int;

      Device_List : aliased Device_Array (0 .. 0) := (others => null);
      Binary_Lengths : aliased Size_Array (0 .. 0) := (others => 0);
      Binary_Pointers : aliased Address_Array (0 .. 0) :=
        (others => System.Null_Address);
      Binary_Status_List : aliased Int_Array (0 .. 0) :=
        (others => API.CL_SUCCESS);
   begin
      Prg.Handle := null;
      Binary_Status := OpenCL.Errors.Success;
      Status := OpenCL.Errors.Success;

      if Raw_Ctx = null then
         Status := OpenCL.Errors.Invalid_Context;
         Binary_Status := Status;
         return;
      end if;

      if Dev.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         Binary_Status := Status;
         return;
      end if;

      if Data'Length = 0 then
         Status := OpenCL.Errors.Invalid_Value;
         Binary_Status := Status;
         return;
      end if;

      Device_List (Device_List'First) := Dev.Handle;
      Binary_Lengths (Binary_Lengths'First) := API.size_t (Data'Length);
      Binary_Pointers (Binary_Pointers'First) := Data (Data'First)'Address;

      Prg.Handle := API.clCreateProgramWithBinary
        (context => Raw_Ctx,
         num_devices => 1,
         device_list => Device_List (Device_List'First)'Access,
         lengths => Binary_Lengths (Binary_Lengths'First)'Address,
         binaries => Binary_Pointers (Binary_Pointers'First)'Address,
         binary_status => Binary_Status_List (Binary_Status_List'First)'Access,
         errcode_ret => Error_Code'Access);

      Binary_Status := To_Status (Binary_Status_List (Binary_Status_List'First));

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if Binary_Status /= OpenCL.Errors.Success then
         Status := Binary_Status;
         return;
      end if;

      if Prg.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;
   end Create_From_Binary;

   procedure Release
     (Prg : in out Program;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if Prg.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseProgram (Prg.Handle);
      if Raw_Status = API.CL_SUCCESS then
         Prg.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   function Raw_Handle (Prg : Program) return OpenCL.Raw.API.cl_program is
   begin
      return Prg.Handle;
   end Raw_Handle;

end OpenCL.Core.Programs;
