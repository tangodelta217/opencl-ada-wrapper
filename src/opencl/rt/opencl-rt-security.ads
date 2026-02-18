with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;

package OpenCL.RT.Security is
   type Verify_Fn is access function
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code;

   procedure Install_Verifier (V : Verify_Fn);

   --  Explicit plugin configuration path for RT integrations. If loading or
   --  symbol resolution fails, Status is OCLW_SIGNATURE_NOT_IMPLEMENTED.
   procedure Configure_Plugin
     (Path : String;
      Symbol : String := "oclw_kpack_verify_v1";
      Status : out OpenCL.Errors.Status_Code);

   function Verify
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Strict : Boolean := False) return OpenCL.Errors.Status_Code;
end OpenCL.RT.Security;
