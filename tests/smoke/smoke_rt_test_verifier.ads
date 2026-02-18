with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;

package Smoke_RT_Test_Verifier is
   function Compute_Test_Signature
     (Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return String;

   function Verify
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code;
end Smoke_RT_Test_Verifier;
