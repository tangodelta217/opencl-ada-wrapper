with Interfaces.C;
with OpenCL.Core.Contexts;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.Raw.API;
with System;

package OpenCL.Core.Buffers is
   subtype Status_Code is OpenCL.Errors.Status_Code;
   subtype size_t is Interfaces.C.size_t;

   type Buffer is private;

   procedure Create
     (Ctx : OpenCL.Core.Contexts.Context;
      Bytes : Interfaces.C.size_t;
      B : out Buffer;
      Status : out Status_Code);

   procedure Release
     (B : in out Buffer;
      Status : out Status_Code);

   procedure Write
     (Q : OpenCL.Core.Queues.Queue;
      B : Buffer;
      Host : System.Address;
      Bytes : size_t;
      Status : out Status_Code);

   procedure Read
     (Q : OpenCL.Core.Queues.Queue;
      B : Buffer;
      Host : System.Address;
      Bytes : size_t;
      Status : out Status_Code);

private
   package API renames OpenCL.Raw.API;

   type Buffer is record
      Handle : API.cl_mem := null;
   end record;
end OpenCL.Core.Buffers;
