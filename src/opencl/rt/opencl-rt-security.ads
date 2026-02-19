with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;
with OpenCL.RT.Packs;

package OpenCL.RT.Security is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   type Verify_Fn is access function
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code;

   procedure Install_Verifier (V : Verify_Fn);

   --  Explicit plugin configuration path for RT integrations. Path hardening:
   --  absolute path, no symlink, regular file and not world-writable.
   --  Allowlist checks use OCLW_RT_PLUGIN_ALLOWLIST (if defined) and are
   --  mandatory in strict verification paths.
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
