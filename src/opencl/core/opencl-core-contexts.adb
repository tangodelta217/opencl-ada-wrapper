with System;

package body OpenCL.Core.Contexts is

   use type API.cl_context;
   use type API.cl_device_id;
   use type API.cl_int;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Create
     (Device : OpenCL.Core.Device;
      Ctx : out Context;
      Status : out OpenCL.Errors.Status_Code)
   is
      Raw_Device : aliased API.cl_device_id := null;
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
   begin
      Ctx.Handle := null;
      Status := OpenCL.Errors.Success;

      if Device.Handle = null then
         Status := OpenCL.Errors.Invalid_Device;
         return;
      end if;

      Raw_Device := Device.Handle;
      Ctx.Handle := API.clCreateContext
        (properties => System.Null_Address,
         num_devices => 1,
         devices => Raw_Device'Access,
         pfn_notify => System.Null_Address,
         user_data => System.Null_Address,
         errcode_ret => Error_Code'Access);

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if Ctx.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;
   end Create;

   procedure Release
     (Ctx : in out Context;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if Ctx.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseContext (Ctx.Handle);
      if Raw_Status = API.CL_SUCCESS then
         Ctx.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   function Raw_Handle (Ctx : Context) return OpenCL.Raw.API.cl_context is
   begin
      return Ctx.Handle;
   end Raw_Handle;

end OpenCL.Core.Contexts;
