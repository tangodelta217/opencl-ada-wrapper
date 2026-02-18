with Interfaces.C;
with OpenCL.Core.Buffers;
with OpenCL.Core.Events;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.Raw.API;

package OpenCL.Core.Kernels is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Kernel is private;

   procedure Create
     (Prg : OpenCL.Core.Programs.Program;
      Name : String;
      K : out Kernel;
      Status : out Status_Code);

   procedure Set_Arg_Buffer
     (K : Kernel;
      Index : Natural;
      B : OpenCL.Core.Buffers.Buffer;
      Status : out Status_Code);

   procedure Enqueue_1D
     (Q : OpenCL.Core.Queues.Queue;
      K : Kernel;
      Global_Size : Interfaces.C.size_t;
      Status : out Status_Code);

   procedure Enqueue_1D
     (Q : OpenCL.Core.Queues.Queue;
      K : Kernel;
      Global_Size : Interfaces.C.size_t;
      Ev : out OpenCL.Core.Events.Event;
      Status : out Status_Code);

   procedure Release
     (K : in out Kernel;
      Status : out Status_Code);

private
   package API renames OpenCL.Raw.API;

   type Kernel is record
      Handle : API.cl_kernel := null;
   end record;
end OpenCL.Core.Kernels;
