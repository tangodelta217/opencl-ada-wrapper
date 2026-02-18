with OpenCL.Errors;

package body OpenCL.RT.Security is

   Installed_Verifier : Verify_Fn := null;

   procedure Install_Verifier (V : Verify_Fn) is
   begin
      Installed_Verifier := V;
   end Install_Verifier;

   function Verify
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code
   is
   begin
      if Installed_Verifier = null then
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      else
         return Installed_Verifier
           (Meta => Meta,
            Signing_Text => Signing_Text,
            Bin => Bin,
            Used => Used);
      end if;
   end Verify;

end OpenCL.RT.Security;
