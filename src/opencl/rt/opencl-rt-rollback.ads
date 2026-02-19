with Interfaces;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;

package OpenCL.RT.Rollback is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   function Get_Last
     (Key : String;
      Value : out Interfaces.Unsigned_64) return OpenCL.Errors.Status_Code;

   function Set_Last
     (Key : String;
      Value : Interfaces.Unsigned_64) return OpenCL.Errors.Status_Code;
end OpenCL.RT.Rollback;
