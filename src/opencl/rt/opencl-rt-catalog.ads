with OpenCL.Errors;
with OpenCL.RT.Memtrack;
with OpenCL.RT.Packs;

package OpenCL.RT.Catalog is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   subtype Status_Code is OpenCL.Errors.Status_Code;

   --  Loads catalog directory, evaluates subpacks in deterministic order and
   --  selects the first exact fingerprint match for the current deterministic
   --  device selection.
   --  On no match, returns OCLW_FINGERPRINT_MISMATCH (fail-closed).
   procedure Load_From_Catalog
     (Catalog_Dir : String;
      Out_Pack_Dir : out OpenCL.RT.Packs.Bounded_String;
      Status : out Status_Code);
end OpenCL.RT.Catalog;
