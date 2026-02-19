with OpenCL.RT.FS;

package OpenCL.RT.FS.Test_Seam is
   subtype Seam_Callback is OpenCL.RT.FS.Seam_Callback;

   procedure Install (Callback : Seam_Callback);
   procedure Clear;
end OpenCL.RT.FS.Test_Seam;
