with OpenCL.RT.Memtrack;

package OpenCL.RT.Policy is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   --  RT strict policy for build options:
   --  allowlist minima: "" y "-cl-std=CL1.2".
   --  cualquier otro valor se rechaza (fail-closed en loader strict).
   function Is_Build_Options_Allowed (Options : String) return Boolean;
end OpenCL.RT.Policy;
