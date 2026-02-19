with OpenCL.RT.FS;

package body OpenCL.RT.FS.Test_Seam is

   procedure Install (Callback : Seam_Callback) is
   begin
      OpenCL.RT.FS.Install_Hook (Callback => Callback);
   end Install;

   procedure Clear is
   begin
      OpenCL.RT.FS.Clear_Hook;
   end Clear;

end OpenCL.RT.FS.Test_Seam;
