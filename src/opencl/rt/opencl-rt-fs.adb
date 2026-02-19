with Ada.Streams;
with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;
with System;

package body OpenCL.RT.FS is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.size_t;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Streams.Stream_Element_Offset;
   use type OpenCL.Errors.Status_Code;

   O_RDONLY : constant Interfaces.C.int := 0;

   subtype Mode_T is Interfaces.C.unsigned;
   S_IFMT : constant Mode_T := 16#F000#;
   S_IFREG : constant Mode_T := 16#8000#;

   type Time_Spec is record
      Tv_Sec : Interfaces.C.long;
      Tv_Nsec : Interfaces.C.long;
   end record;
   pragma Convention (C, Time_Spec);

   type Stat_Buffer is record
      St_Dev : Interfaces.C.unsigned_long;
      St_Ino : Interfaces.C.unsigned_long;
      St_Nlink : Interfaces.C.unsigned_long;
      St_Mode : Mode_T;
      St_Uid : Interfaces.C.unsigned;
      St_Gid : Interfaces.C.unsigned;
      Pad_0 : Interfaces.C.int;
      St_Rdev : Interfaces.C.unsigned_long;
      St_Size : Interfaces.C.long;
      St_Blksize : Interfaces.C.long;
      St_Blocks : Interfaces.C.long;
      St_Atim : Time_Spec;
      St_Mtim : Time_Spec;
      St_Ctim : Time_Spec;
      Glibc_Reserved_0 : Interfaces.C.long;
      Glibc_Reserved_1 : Interfaces.C.long;
      Glibc_Reserved_2 : Interfaces.C.long;
   end record;
   pragma Convention (C, Stat_Buffer);

   function C_Open
     (Path : Interfaces.C.Strings.chars_ptr;
      Flags : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Open, "open");

   function C_Read
     (FD : Interfaces.C.int;
      Buf : System.Address;
      Count : Interfaces.C.size_t) return Interfaces.C.long;
   pragma Import (C, C_Read, "read");

   function C_Close (FD : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   function C_Fstat
     (FD : Interfaces.C.int;
      Info : access Stat_Buffer) return Interfaces.C.int;
   pragma Import (C, C_Fstat, "fstat");

   function C_Stat
     (Path : Interfaces.C.Strings.chars_ptr;
      Info : access Stat_Buffer) return Interfaces.C.int;
   pragma Import (C, C_Stat, "stat");

   Current_Seam : Seam_Callback := null;

   function Is_Regular_File (Mode : Mode_T) return Boolean is
   begin
      return (Mode and S_IFMT) = S_IFREG;
   end Is_Regular_File;

   function Snapshot_Path (Snap : File_Snapshot) return String is
   begin
      if Snap.Path_Last = 0 then
         return "";
      else
         return Snap.Path_Buffer (1 .. Snap.Path_Last);
      end if;
   end Snapshot_Path;

   procedure Close (Snap : in out File_Snapshot) is
      Close_Result : Interfaces.C.int := 0;
   begin
      if Snap.Opened and then Snap.FD >= 0 then
         Close_Result := C_Close (Snap.FD);
         if Close_Result /= 0 then
            null;
         end if;
      end if;

      Snap.FD := -1;
      Snap.Path_Last := 0;
      Snap.Pre_Inode := 0;
      Snap.Pre_Size := 0;
      Snap.Pre_Mode := 0;
      Snap.Opened := False;
   end Close;

   procedure Open_Snapshot
     (Path : String;
      Snap : out File_Snapshot;
      Status : out Status_Code)
   is
      C_Path : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Pre_Info : aliased Stat_Buffer;
      FD : Interfaces.C.int := -1;
   begin
      --  Reset output snapshot first.
      Snap.FD := -1;
      Snap.Path_Last := 0;
      Snap.Pre_Inode := 0;
      Snap.Pre_Size := 0;
      Snap.Pre_Mode := 0;
      Snap.Opened := False;
      Status := OpenCL.Errors.Success;

      if Path'Length = 0 or else Path'Length > Max_Snapshot_Path_Length then
         Status := OpenCL.Errors.OCLW_FS_Policy_Violation;
         return;
      end if;

      C_Path := Interfaces.C.Strings.New_String (Path);
      FD := C_Open (Path => C_Path, Flags => O_RDONLY);
      if FD < 0 then
         Interfaces.C.Strings.Free (C_Path);
         C_Path := Interfaces.C.Strings.Null_Ptr;
         Status := OpenCL.Errors.OCLW_IO_Error;
         return;
      end if;

      if C_Fstat (FD => FD, Info => Pre_Info'Access) /= 0 then
         declare
            Close_Result : constant Interfaces.C.int := C_Close (FD);
         begin
            if Close_Result /= 0 then
               null;
            end if;
         end;
         Interfaces.C.Strings.Free (C_Path);
         C_Path := Interfaces.C.Strings.Null_Ptr;
         Status := OpenCL.Errors.OCLW_IO_Error;
         return;
      end if;

      if not Is_Regular_File (Pre_Info.St_Mode) then
         declare
            Close_Result : constant Interfaces.C.int := C_Close (FD);
         begin
            if Close_Result /= 0 then
               null;
            end if;
         end;
         Interfaces.C.Strings.Free (C_Path);
         C_Path := Interfaces.C.Strings.Null_Ptr;
         Status := OpenCL.Errors.OCLW_FS_Policy_Violation;
         return;
      end if;

      Snap.FD := FD;
      Snap.Path_Last := Path'Length;
      Snap.Path_Buffer (1 .. Path'Length) := Path;
      Snap.Pre_Inode := Pre_Info.St_Ino;
      Snap.Pre_Size := Pre_Info.St_Size;
      Snap.Pre_Mode := Pre_Info.St_Mode;
      Snap.Opened := True;

      Interfaces.C.Strings.Free (C_Path);
      C_Path := Interfaces.C.Strings.Null_Ptr;

      if Current_Seam /= null then
         Current_Seam.all (Path);
      end if;
   exception
      when others =>
         if C_Path /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (C_Path);
         end if;

         if Snap.Opened then
            Close (Snap);
         elsif FD >= 0 then
            declare
               Close_Result : constant Interfaces.C.int := C_Close (FD);
            begin
               if Close_Result /= 0 then
                  null;
               end if;
            end;
         end if;

         Status := OpenCL.Errors.OCLW_IO_Error;
   end Open_Snapshot;

   procedure Read_All
     (Snap : in out File_Snapshot;
      Data : out OpenCL.Core.Programs.Byte_Array;
      Used : out Natural;
      Status : out Status_Code)
   is
      Chunk_Bytes : constant Positive := 4_096;
      Total_Read : Natural := 0;
      Expected_Size : Natural := 0;
      Post_Info : aliased Stat_Buffer;
      Path_Info : aliased Stat_Buffer;
      C_Path : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Path_Text : constant String := Snapshot_Path (Snap);
   begin
      Status := OpenCL.Errors.Success;
      Used := 0;

      for I in Data'Range loop
         Data (I) := 0;
      end loop;

      if not Snap.Opened or else Snap.FD < 0 then
         Status := OpenCL.Errors.OCLW_IO_Error;
         return;
      end if;

      if not Is_Regular_File (Mode_T (Snap.Pre_Mode)) then
         Status := OpenCL.Errors.OCLW_FS_Policy_Violation;
         return;
      end if;

      if Snap.Pre_Size < 0 then
         Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
         return;
      end if;

      if Snap.Pre_Size > Interfaces.C.long (Natural'Last) then
         Status := OpenCL.Errors.OCLW_Limit_Exceeded;
         return;
      end if;

      Expected_Size := Natural (Snap.Pre_Size);
      if Expected_Size > Data'Length then
         Status := OpenCL.Errors.OCLW_Limit_Exceeded;
         return;
      end if;

      while Total_Read < Expected_Size loop
         declare
            Remaining : constant Natural := Expected_Size - Total_Read;
            This_Chunk : constant Natural :=
              (if Remaining > Chunk_Bytes then Chunk_Bytes else Remaining);
            Raw : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (This_Chunk));
            Bytes_Read : Interfaces.C.long := 0;
            Read_Count : Natural := 0;
         begin
            Bytes_Read :=
              C_Read
                (FD => Snap.FD,
                 Buf => Raw (Raw'First)'Address,
                 Count => Interfaces.C.size_t (This_Chunk));

            if Bytes_Read < 0 then
               Status := OpenCL.Errors.OCLW_IO_Error;
               return;
            elsif Bytes_Read = 0 then
               Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
               return;
            end if;

            if Bytes_Read > Interfaces.C.long (This_Chunk) then
               Status := OpenCL.Errors.OCLW_IO_Error;
               return;
            end if;

            Read_Count := Natural (Bytes_Read);
            for Offset in 0 .. Read_Count - 1 loop
               Data (Data'First + Total_Read + Offset) :=
                 OpenCL.Core.Programs.Byte
                   (Raw (Raw'First + Ada.Streams.Stream_Element_Offset (Offset)));
            end loop;

            Total_Read := Total_Read + Read_Count;
         end;
      end loop;

      if Total_Read /= Expected_Size then
         Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
         return;
      end if;

      if C_Fstat (FD => Snap.FD, Info => Post_Info'Access) /= 0 then
         Status := OpenCL.Errors.OCLW_IO_Error;
         return;
      end if;

      if not Is_Regular_File (Post_Info.St_Mode)
        or else Post_Info.St_Ino /= Snap.Pre_Inode
        or else Post_Info.St_Size /= Snap.Pre_Size
      then
         Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
         return;
      end if;

      if Path_Text'Length = 0 then
         Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
         return;
      end if;

      C_Path := Interfaces.C.Strings.New_String (Path_Text);
      if C_Stat (Path => C_Path, Info => Path_Info'Access) /= 0 then
         Interfaces.C.Strings.Free (C_Path);
         C_Path := Interfaces.C.Strings.Null_Ptr;
         Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
         return;
      end if;

      Interfaces.C.Strings.Free (C_Path);
      C_Path := Interfaces.C.Strings.Null_Ptr;

      if not Is_Regular_File (Path_Info.St_Mode)
        or else Path_Info.St_Ino /= Snap.Pre_Inode
        or else Path_Info.St_Size /= Snap.Pre_Size
      then
         Status := OpenCL.Errors.OCLW_FS_TOCTOU_Detected;
         return;
      end if;

      Used := Expected_Size;
   exception
      when others =>
         if C_Path /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (C_Path);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
   end Read_All;

   procedure Install_Hook (Callback : Seam_Callback) is
   begin
      Current_Seam := Callback;
   end Install_Hook;

   procedure Clear_Hook is
   begin
      Current_Seam := null;
   end Clear_Hook;

end OpenCL.RT.FS;
