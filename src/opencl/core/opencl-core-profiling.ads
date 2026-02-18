with Interfaces;
with OpenCL.Core.Events;
with OpenCL.Core.Queues;
with OpenCL.Errors;

package OpenCL.Core.Profiling is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   function Is_Profiling_Available
     (Q : OpenCL.Core.Queues.Queue) return Boolean;

   function Duration_Ns
     (Ev : OpenCL.Core.Events.Event;
      Status : out Status_Code) return Interfaces.Unsigned_64;
end OpenCL.Core.Profiling;
