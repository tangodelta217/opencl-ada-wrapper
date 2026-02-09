with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.Core.Contexts;
with System;

package body OpenCL.Core.Programs is

   use type API.cl_context;
   use type API.cl_device_id;
   use type API.cl_int;
   use type API.cl_program;
   use type API.size_t;
   use type Interfaces.C.Strings.chars_ptr;

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
