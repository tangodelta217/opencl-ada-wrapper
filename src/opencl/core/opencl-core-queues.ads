with OpenCL.Core.Contexts;
with OpenCL.Errors;
with OpenCL.Raw.API;

package OpenCL.Core.Queues is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Queue is private;

   procedure Create
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Q : out Queue;
      Status : out Status_Code);

   procedure Release
     (Q : in out Queue;
      Status : out Status_Code);

   procedure Finish
     (Q : Queue;
      Status : out Status_Code);

   --  Helper required by sibling child package Buffers.
   function Raw_Handle (Q : Queue) return OpenCL.Raw.API.cl_command_queue;

private
   package API renames OpenCL.Raw.API;

   type Queue is record
      Handle : API.cl_command_queue := null;
   end record;
end OpenCL.Core.Queues;
