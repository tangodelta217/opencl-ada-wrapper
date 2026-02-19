with OpenCL.Core.Programs;

package OpenCL.RT.Constant_Time is
   --  Constant-time equality for byte and text payloads. Length mismatch
   --  contributes to the accumulator and does not short-circuit.
   function Ct_Equal
     (A : OpenCL.Core.Programs.Byte_Array;
      B : OpenCL.Core.Programs.Byte_Array) return Boolean;

   function Ct_Equal (A, B : String) return Boolean;
end OpenCL.RT.Constant_Time;
