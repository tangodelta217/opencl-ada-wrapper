with Interfaces;
with OpenCL.Raw.API;
with System;

package body OpenCL.Core.Profiling is

   package API renames OpenCL.Raw.API;

   use type API.cl_command_queue;
   use type API.cl_command_queue_properties;
   use type API.cl_event;
   use type API.cl_int;
   use type API.cl_ulong;
   use type API.size_t;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   function Is_Profiling_Available
     (Q : OpenCL.Core.Queues.Queue) return Boolean
   is
      Properties : constant API.cl_command_queue_properties :=
        OpenCL.Core.Queues.Raw_Properties (Q);
   begin
      if OpenCL.Core.Queues.Raw_Handle (Q) = null then
         return False;
      end if;

      return (Properties and API.CL_QUEUE_PROFILING_ENABLE) /= 0;
   end Is_Profiling_Available;

   function Duration_Ns
     (Ev : OpenCL.Core.Events.Event;
      Status : out Status_Code) return Interfaces.Unsigned_64
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Start_Timestamp : aliased API.cl_ulong := 0;
      End_Timestamp : aliased API.cl_ulong := 0;
      Timestamp_Bytes : constant API.size_t :=
        API.size_t (API.cl_ulong'Size / System.Storage_Unit);
      Raw_Event : constant API.cl_event := OpenCL.Core.Events.Raw_Handle (Ev);
   begin
      Status := OpenCL.Errors.Success;

      if Raw_Event = null then
         Status := OpenCL.Errors.Invalid_Event;
         return 0;
      end if;

      Raw_Status := API.clGetEventProfilingInfo
        (event => Raw_Event,
         param_name => API.CL_PROFILING_COMMAND_START,
         param_value_size => Timestamp_Bytes,
         param_value => Start_Timestamp'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return 0;
      end if;

      Raw_Status := API.clGetEventProfilingInfo
        (event => Raw_Event,
         param_name => API.CL_PROFILING_COMMAND_END,
         param_value_size => Timestamp_Bytes,
         param_value => End_Timestamp'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return 0;
      end if;

      if End_Timestamp < Start_Timestamp then
         Status := OpenCL.Errors.Invalid_Value;
         return 0;
      end if;

      return Interfaces.Unsigned_64 (End_Timestamp - Start_Timestamp);
   end Duration_Ns;

end OpenCL.Core.Profiling;
