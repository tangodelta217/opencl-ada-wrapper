with OpenCL.Errors;
with OpenCL.Raw.API;

package OpenCL.Core.Contexts is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Context is private;

   procedure Create
     (Device : OpenCL.Core.Device;
      Ctx : out Context;
      Status : out OpenCL.Errors.Status_Code);

   procedure Release
     (Ctx : in out Context;
      Status : out Status_Code);

   --  Helper required by sibling child packages (Queues/Buffers).
   function Raw_Handle (Ctx : Context) return OpenCL.Raw.API.cl_context;

private
   package API renames OpenCL.Raw.API;

   type Context is record
      Handle : API.cl_context := null;
   end record;
end OpenCL.Core.Contexts;
