with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Bounded;
with Ada.Strings.Fixed;
with OpenCL.Core;
with OpenCL.Core.Device_Selection;
with OpenCL.Errors;
with OpenCL.RT.Constant_Time;
with OpenCL.RT.Memtrack;
with OpenCL.RT.Packs;

package body OpenCL.RT.Catalog is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   use type Ada.Directories.File_Kind;
   use type OpenCL.Errors.Status_Code;

   package Errors renames OpenCL.Errors;
   package Device_Selection renames OpenCL.Core.Device_Selection;
   package Packs renames OpenCL.RT.Packs;

   Max_Subpacks : constant Positive := 64;
   Max_Path_Length : constant Positive := 1_024;

   package Path_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Path_Length);
   subtype Path_Bounded_String is Path_Strings.Bounded_String;

   type Path_Array is array (Positive range <>) of Path_Bounded_String;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function To_Bounded_Path (Value : String) return Path_Bounded_String is
   begin
      if Value'Length > Max_Path_Length then
         return
           Path_Strings.To_Bounded_String
             (Value (Value'First .. Value'First + Max_Path_Length - 1));
      else
         return Path_Strings.To_Bounded_String (Value);
      end if;
   end To_Bounded_Path;

   function Match (Expected : Packs.Bounded_String; Actual : String) return Boolean is
   begin
      return OpenCL.RT.Constant_Time.Ct_Equal
        (Trimmed (Packs.To_String (Expected)),
         Trimmed (Actual));
   end Match;

   procedure Sort_Paths
     (Items : in out Path_Array;
      Count : Natural)
   is
   begin
      if Count < 2 then
         return;
      end if;

      for I in 2 .. Count loop
         declare
            Current : constant Path_Bounded_String := Items (I);
            J : Natural := I;
         begin
            while J > 1 loop
               exit when not (Path_Strings.To_String (Current)
                              < Path_Strings.To_String (Items (J - 1)));
               Items (J) := Items (J - 1);
               J := J - 1;
            end loop;
            Items (J) := Current;
         end;
      end loop;
   end Sort_Paths;

   procedure Load_From_Catalog
     (Catalog_Dir : String;
      Out_Pack_Dir : out OpenCL.RT.Packs.Bounded_String;
      Status : out Status_Code)
   is
      Search : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Filter : constant Ada.Directories.Filter_Type :=
        (Ada.Directories.Ordinary_File => False,
         Ada.Directories.Directory => True,
         Ada.Directories.Special_File => False);
      Paths : Path_Array (1 .. Max_Subpacks);
      Path_Count : Natural := 0;

      Selected : Device_Selection.Selection_Result;

      Platform_Name_Status : Errors.Status_Code := Errors.Success;
      Platform_Vendor_Status : Errors.Status_Code := Errors.Success;
      Platform_Version_Status : Errors.Status_Code := Errors.Success;
      Device_Name_Status : Errors.Status_Code := Errors.Success;
      Device_Vendor_Status : Errors.Status_Code := Errors.Success;
      Device_Version_Status : Errors.Status_Code := Errors.Success;
      Driver_Version_Status : Errors.Status_Code := Errors.Success;
   begin
      Out_Pack_Dir := Packs.To_Bounded ("");
      Status := Errors.Success;

      if not Ada.Directories.Exists (Catalog_Dir) then
         Status := Errors.OCLW_IO_Error;
         return;
      end if;

      if Ada.Directories.Kind (Catalog_Dir) /= Ada.Directories.Directory then
         Status := Errors.OCLW_IO_Error;
         return;
      end if;

      Ada.Directories.Start_Search
        (Search => Search,
         Directory => Catalog_Dir,
         Pattern => "*",
         Filter => Filter);

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);

         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            else
               if Full'Length > Max_Path_Length then
                  Status := Errors.OCLW_Limit_Exceeded;
                  Ada.Directories.End_Search (Search);
                  return;
               end if;

               if Path_Count = Max_Subpacks then
                  Status := Errors.OCLW_Limit_Exceeded;
                  Ada.Directories.End_Search (Search);
                  return;
               end if;

               Path_Count := Path_Count + 1;
               Paths (Path_Count) := To_Bounded_Path (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);

      if Path_Count = 0 then
         Status := Errors.OCLW_Fingerprint_Mismatch;
         return;
      end if;

      Sort_Paths (Items => Paths, Count => Path_Count);

      Selected :=
        Device_Selection.Select_Device
          (Expected_Platform_Name => "",
           Expected_Platform_Vendor => "",
           Expected_Platform_Version => "",
           Expected_Device_Name => "",
           Expected_Device_Vendor => "",
           Expected_Device_Version => "",
           Expected_Driver_Version => "");
      if Selected.Status /= Errors.Success then
         Status := Selected.Status;
         return;
      end if;

      declare
         Runtime_Platform_Name : constant String :=
           OpenCL.Core.Get_Platform_Info
             (P => Selected.Platform,
              What => OpenCL.Core.Name,
              Status => Platform_Name_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
         Runtime_Platform_Vendor : constant String :=
           OpenCL.Core.Get_Platform_Info
             (P => Selected.Platform,
              What => OpenCL.Core.Vendor,
              Status => Platform_Vendor_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
         Runtime_Platform_Version : constant String :=
           OpenCL.Core.Get_Platform_Info
             (P => Selected.Platform,
              What => OpenCL.Core.Version,
              Status => Platform_Version_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
         Runtime_Device_Name : constant String :=
           OpenCL.Core.Get_Device_Info
             (D => Selected.Device,
              What => OpenCL.Core.Name,
              Status => Device_Name_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
         Runtime_Device_Vendor : constant String :=
           OpenCL.Core.Get_Device_Info
             (D => Selected.Device,
              What => OpenCL.Core.Vendor,
              Status => Device_Vendor_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
         Runtime_Device_Version : constant String :=
           OpenCL.Core.Get_Device_Info
             (D => Selected.Device,
              What => OpenCL.Core.Version,
              Status => Device_Version_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
         Runtime_Driver_Version : constant String :=
           OpenCL.Core.Get_Device_Info
             (D => Selected.Device,
              What => OpenCL.Core.Driver_Version,
              Status => Driver_Version_Status,
              Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
      begin
         if not Errors.Is_Success (Platform_Name_Status)
           or else not Errors.Is_Success (Platform_Vendor_Status)
           or else not Errors.Is_Success (Platform_Version_Status)
           or else not Errors.Is_Success (Device_Name_Status)
           or else not Errors.Is_Success (Device_Vendor_Status)
           or else not Errors.Is_Success (Device_Version_Status)
           or else not Errors.Is_Success (Driver_Version_Status)
         then
            Status := Errors.OCLW_IO_Error;
            return;
         end if;

         for I in 1 .. Path_Count loop
            declare
               Dir_Path : constant String := Path_Strings.To_String (Paths (I));
               Manifest_Path : constant String := Dir_Path & "/manifest.kpack";
               Meta : Packs.Pack_Metadata;
               Meta_Status : Errors.Status_Code := Errors.Success;
            begin
               Packs.Read_Manifest
                 (Path => Manifest_Path,
                  Meta => Meta,
                  Status => Meta_Status);
               if Meta_Status /= Errors.Success then
                  Status := Meta_Status;
                  return;
               end if;

               if Match (Meta.Platform_Name, Runtime_Platform_Name)
                 and then Match (Meta.Platform_Vendor, Runtime_Platform_Vendor)
                 and then Match (Meta.Platform_Version, Runtime_Platform_Version)
                 and then Match (Meta.Device_Name, Runtime_Device_Name)
                 and then Match (Meta.Device_Vendor, Runtime_Device_Vendor)
                 and then Match (Meta.Device_Version, Runtime_Device_Version)
                 and then Match (Meta.Driver_Version, Runtime_Driver_Version)
               then
                  Out_Pack_Dir := Packs.To_Bounded (Dir_Path);
                  Status := Errors.Success;
                  return;
               end if;
            end;
         end loop;
      end;

      Status := Errors.OCLW_Fingerprint_Mismatch;
   exception
      when others =>
         Status := Errors.OCLW_IO_Error;
   end Load_From_Catalog;

end OpenCL.RT.Catalog;
