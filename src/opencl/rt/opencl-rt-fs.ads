with Interfaces.C;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;

package OpenCL.RT.FS is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   subtype Status_Code is OpenCL.Errors.Status_Code;

   --  Hook callback used by test-only child units.
   type Seam_Callback is access procedure (Path : String);

   type File_Snapshot is limited private;

   procedure Open_Snapshot
     (Path : String;
      Snap : out File_Snapshot;
      Status : out Status_Code);

   procedure Read_All
     (Snap : in out File_Snapshot;
      Data : out OpenCL.Core.Programs.Byte_Array;
      Used : out Natural;
      Status : out Status_Code);

   procedure Close (Snap : in out File_Snapshot);

private
   Max_Snapshot_Path_Length : constant Positive := 4_096;

   --  Private hooks: only child units (tests) can call these.
   procedure Install_Hook (Callback : Seam_Callback);
   procedure Clear_Hook;

   type File_Snapshot is limited record
      FD : Interfaces.C.int := Interfaces.C.int (-1);
      Path_Buffer : String (1 .. Max_Snapshot_Path_Length) := (others => ' ');
      Path_Last : Natural := 0;
      Pre_Inode : Interfaces.C.unsigned_long := 0;
      Pre_Size : Interfaces.C.long := 0;
      Pre_Mode : Interfaces.C.unsigned := 0;
      Opened : Boolean := False;
   end record;
end OpenCL.RT.FS;
