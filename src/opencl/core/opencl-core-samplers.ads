with OpenCL.Core.Contexts;
with OpenCL.Errors;
with OpenCL.Raw.API;

package OpenCL.Core.Samplers is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Sampler is private;

   procedure Create_Basic
     (Ctx : OpenCL.Core.Contexts.Context;
      S : out Sampler;
      Status : out Status_Code;
      Normalized_Coords : Boolean := False;
      Addressing_Mode : OpenCL.Raw.API.cl_addressing_mode :=
        OpenCL.Raw.API.CL_ADDRESS_CLAMP;
      Filter_Mode : OpenCL.Raw.API.cl_filter_mode :=
        OpenCL.Raw.API.CL_FILTER_NEAREST);

   procedure Release
     (S : in out Sampler;
      Status : out Status_Code);

   --  Helper required by sibling child packages (Kernels).
   function Raw_Handle (S : Sampler) return OpenCL.Raw.API.cl_sampler;

private
   package API renames OpenCL.Raw.API;

   type Sampler is record
      Handle : API.cl_sampler := null;
   end record;
end OpenCL.Core.Samplers;
