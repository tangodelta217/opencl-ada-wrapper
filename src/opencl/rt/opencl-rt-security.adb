package body OpenCL.RT.Security is

   procedure Verify_Signature
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Manifest_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Status : out Signature_Status)
   is
      pragma Unreferenced (Meta);
      pragma Unreferenced (Manifest_Text);
      pragma Unreferenced (Bin);
      pragma Unreferenced (Used);
   begin
      --  Hook only: cryptographic provider integration is deferred to G6/G7.
      Status := Not_Implemented;
   end Verify_Signature;

end OpenCL.RT.Security;
