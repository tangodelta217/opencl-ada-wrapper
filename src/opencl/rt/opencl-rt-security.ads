with OpenCL.Core.Programs;
with OpenCL.RT.Packs;

package OpenCL.RT.Security is
   type Signature_Status is (Not_Implemented, Pass, Fail);

   procedure Verify_Signature
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Manifest_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Status : out Signature_Status);
end OpenCL.RT.Security;
