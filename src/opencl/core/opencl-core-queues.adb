with OpenCL.Core.Contexts;

package body OpenCL.Core.Queues is

   use type API.cl_command_queue;
   use type API.cl_context;
   use type API.cl_device_id;
   use type API.cl_int;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Create
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Q : out Queue;
      Status : out Status_Code;
      Properties : OpenCL.Raw.API.cl_command_queue_properties := 0)
   is
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
      Raw_Ctx : constant API.cl_context := OpenCL.Core.Contexts.Raw_Handle (Ctx);
   begin
      Q.Handle := null;
      Q.Properties := 0;
      Status := OpenCL.Errors.Success;

      if Raw_Ctx = null then
         Status := OpenCL.Errors.Invalid_Context;
         return;
      end if;

      if Dev.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         return;
      end if;

      Q.Handle := API.clCreateCommandQueue
        (context => Raw_Ctx,
         device => Dev.Handle,
         properties => API.cl_command_queue_properties (Properties),
         errcode_ret => Error_Code'Access);

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if Q.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;

      Q.Properties := API.cl_command_queue_properties (Properties);
   end Create;

   procedure Release
     (Q : in out Queue;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if Q.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseCommandQueue (Q.Handle);
      if Raw_Status = API.CL_SUCCESS then
         Q.Handle := null;
         Q.Properties := 0;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   procedure Finish
     (Q : Queue;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if Q.Handle = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      Raw_Status := API.clFinish (Q.Handle);
      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Finish;

   function Raw_Handle (Q : Queue) return OpenCL.Raw.API.cl_command_queue is
   begin
      return Q.Handle;
   end Raw_Handle;

   function Raw_Properties
     (Q : Queue) return OpenCL.Raw.API.cl_command_queue_properties
   is
   begin
      return Q.Properties;
   end Raw_Properties;

end OpenCL.Core.Queues;
