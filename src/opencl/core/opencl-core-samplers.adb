with OpenCL.Core.Contexts;

package body OpenCL.Core.Samplers is

   use type API.cl_bool;
   use type API.cl_context;
   use type API.cl_int;
   use type API.cl_sampler;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Create_Basic
     (Ctx : OpenCL.Core.Contexts.Context;
      S : out Sampler;
      Status : out Status_Code;
      Normalized_Coords : Boolean := False;
      Addressing_Mode : OpenCL.Raw.API.cl_addressing_mode :=
        OpenCL.Raw.API.CL_ADDRESS_CLAMP;
      Filter_Mode : OpenCL.Raw.API.cl_filter_mode :=
        OpenCL.Raw.API.CL_FILTER_NEAREST)
   is
      Raw_Ctx : constant API.cl_context := OpenCL.Core.Contexts.Raw_Handle (Ctx);
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
      Normalized : API.cl_bool := API.CL_FALSE;
   begin
      S.Handle := null;
      Status := OpenCL.Errors.Success;

      if Raw_Ctx = null then
         Status := OpenCL.Errors.Invalid_Context;
         return;
      end if;

      if Normalized_Coords then
         Normalized := API.CL_TRUE;
      end if;

      S.Handle := API.clCreateSampler
        (context => Raw_Ctx,
         normalized_coords => Normalized,
         addressing_mode => API.cl_addressing_mode (Addressing_Mode),
         filter_mode => API.cl_filter_mode (Filter_Mode),
         errcode_ret => Error_Code'Access);

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if S.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
      end if;
   end Create_Basic;

   procedure Release
     (S : in out Sampler;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if S.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseSampler (S.Handle);
      if Raw_Status = API.CL_SUCCESS then
         S.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   function Raw_Handle (S : Sampler) return OpenCL.Raw.API.cl_sampler is
   begin
      return S.Handle;
   end Raw_Handle;

end OpenCL.Core.Samplers;
