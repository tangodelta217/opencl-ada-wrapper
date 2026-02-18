with Interfaces;
with OpenCL.Core.Programs;

package OpenCL.RT.Hash is
   function FNV1a_32
     (Data : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return Interfaces.Unsigned_32;

   function Hex_Image (Value : Interfaces.Unsigned_32) return String;
end OpenCL.RT.Hash;
