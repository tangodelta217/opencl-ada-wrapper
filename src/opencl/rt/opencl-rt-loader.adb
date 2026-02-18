with Ada.Strings;
with Ada.Strings.Fixed;
with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;

package body OpenCL.RT.Loader is

   use type OpenCL.Errors.Status_Code;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Matches
     (Expected : OpenCL.RT.Packs.Bounded_String;
      Actual : String) return Boolean
   is
   begin
      return Trimmed (OpenCL.RT.Packs.To_String (Expected)) = Trimmed (Actual);
   end Matches;

   procedure Select_Device
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Platform : out OpenCL.Core.Platform;
      Device : out OpenCL.Core.Device;
      Status : out Status_Code)
   is
      package Core renames OpenCL.Core;
      package Errors renames OpenCL.Errors;

      Max_Platforms : constant Positive := 16;
      Max_Devices_Per_Platform : constant Positive := 64;

      Platforms : Core.Platform_List (1 .. Max_Platforms);
      Devices : Core.Device_List (1 .. Max_Devices_Per_Platform);

      Platform_Used : Natural := 0;
      Device_Used : Natural := 0;
      Null_Platform : Core.Platform;
      Null_Device : Core.Device;
   begin
      Platform := Null_Platform;
      Device := Null_Device;
      Status := Errors.Success;

      Core.Enumerate_Platforms
        (Out_Platforms => Platforms,
         Used => Platform_Used,
         Status => Status);

      if Platform_Used = 0 then
         if Status = Errors.Success then
            Status := Errors.OCLW_Fingerprint_Mismatch;
         end if;
         return;
      end if;

      for Platform_Pos in 1 .. Platform_Used loop
         declare
            P : constant Core.Platform :=
              Platforms (Platforms'First + Platform_Pos - 1);
            Platform_Name_Status : Errors.Status_Code := Errors.Success;
            Platform_Vendor_Status : Errors.Status_Code := Errors.Success;
            Platform_Version_Status : Errors.Status_Code := Errors.Success;
            Platform_Name : constant String :=
              Core.Get_Platform_Info
                (P => P,
                 What => Core.Name,
                 Status => Platform_Name_Status,
                 Max_Bytes => Core.Default_Max_Info_Bytes);
            Platform_Vendor : constant String :=
              Core.Get_Platform_Info
                (P => P,
                 What => Core.Vendor,
                 Status => Platform_Vendor_Status,
                 Max_Bytes => Core.Default_Max_Info_Bytes);
            Platform_Version : constant String :=
              Core.Get_Platform_Info
                (P => P,
                 What => Core.Version,
                 Status => Platform_Version_Status,
                 Max_Bytes => Core.Default_Max_Info_Bytes);
         begin
            if not Errors.Is_Success (Platform_Name_Status)
              or else not Errors.Is_Success (Platform_Vendor_Status)
              or else not Errors.Is_Success (Platform_Version_Status)
            then
               null;
            elsif Matches (Meta.Platform_Name, Platform_Name)
              and then Matches (Meta.Platform_Vendor, Platform_Vendor)
              and then Matches (Meta.Platform_Version, Platform_Version)
            then
               declare
                  Device_Enum_Status : Errors.Status_Code := Errors.Success;
               begin
               Core.Enumerate_Devices
                 (P => P,
                  Out_Devices => Devices,
                  Used => Device_Used,
                  Status => Device_Enum_Status);

               if Device_Used = 0 then
                  if Device_Enum_Status /= Errors.Success
                    and then Device_Enum_Status /= Errors.Device_Not_Found
                  then
                     null;
                  end if;
                  null;
               else
                  for Device_Pos in 1 .. Device_Used loop
                     declare
                        D : constant Core.Device :=
                          Devices (Devices'First + Device_Pos - 1);
                        Device_Name_Status : Errors.Status_Code := Errors.Success;
                        Device_Vendor_Status : Errors.Status_Code := Errors.Success;
                        Device_Version_Status : Errors.Status_Code := Errors.Success;
                        Driver_Version_Status : Errors.Status_Code := Errors.Success;
                        Device_Name : constant String :=
                          Core.Get_Device_Info
                            (D => D,
                             What => Core.Name,
                             Status => Device_Name_Status,
                             Max_Bytes => Core.Default_Max_Info_Bytes);
                        Device_Vendor : constant String :=
                          Core.Get_Device_Info
                            (D => D,
                             What => Core.Vendor,
                             Status => Device_Vendor_Status,
                             Max_Bytes => Core.Default_Max_Info_Bytes);
                        Device_Version : constant String :=
                          Core.Get_Device_Info
                            (D => D,
                             What => Core.Version,
                             Status => Device_Version_Status,
                             Max_Bytes => Core.Default_Max_Info_Bytes);
                        Driver_Version : constant String :=
                          Core.Get_Device_Info
                            (D => D,
                             What => Core.Driver_Version,
                             Status => Driver_Version_Status,
                             Max_Bytes => Core.Default_Max_Info_Bytes);
                     begin
                        if not Errors.Is_Success (Device_Name_Status)
                          or else not Errors.Is_Success (Device_Vendor_Status)
                          or else not Errors.Is_Success (Device_Version_Status)
                          or else not Errors.Is_Success (Driver_Version_Status)
                        then
                           null;
                        elsif Matches (Meta.Device_Name, Device_Name)
                          and then Matches (Meta.Device_Vendor, Device_Vendor)
                          and then Matches (Meta.Device_Version, Device_Version)
                          and then Matches (Meta.Driver_Version, Driver_Version)
                        then
                           Platform := P;
                           Device := D;
                           Status := Errors.Success;
                           return;
                        end if;
                     end;
                  end loop;
               end if;
               end;
            end if;
         end;
      end loop;

      Status := Errors.OCLW_Fingerprint_Mismatch;
   end Select_Device;

   procedure Create_Program_From_Pack
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Meta : OpenCL.RT.Packs.Pack_Metadata;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Prg : out OpenCL.Core.Programs.Program;
      Status : out Status_Code)
   is
      package Errors renames OpenCL.Errors;
      package Programs renames OpenCL.Core.Programs;
      package Security renames OpenCL.RT.Security;

      Binary_Status : Errors.Status_Code := Errors.Success;
      Build_Status : Errors.Status_Code := Errors.Success;
      Release_Status : Errors.Status_Code := Errors.Success;
      Null_Program : Programs.Program;
   begin
      Prg := Null_Program;
      Status := Errors.Success;

      if Used = 0 or else Used > Bin'Length then
         Status := Errors.Invalid_Value;
         return;
      end if;

      if Meta.Signature_Required then
         if Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Alg))'Length = 0
           or else Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Value))'Length = 0
         then
            Status := Errors.OCLW_Signature_Missing;
            return;
         end if;

         declare
            Signing_Text : constant String :=
              OpenCL.RT.Packs.Canonical_Signing_Text (Meta);
            Verify_Status : Errors.Status_Code := Errors.Success;
         begin
            if Signing_Text'Length = 0 then
               Status := Errors.OCLW_Pack_Format_Error;
               return;
            end if;

            Verify_Status :=
              Security.Verify
                (Meta => Meta,
                 Signing_Text => Signing_Text,
                 Bin => Bin,
                 Used => Used);
            if Verify_Status /= Errors.Success then
               Status := Verify_Status;
               return;
            end if;
         end;
      end if;

      declare
         Last_Index : constant Positive := Bin'First + Integer (Used) - 1;
      begin
         Programs.Create_From_Binary
           (Ctx => Ctx,
            Dev => Dev,
            Data => Bin (Bin'First .. Last_Index),
            Prg => Prg,
            Binary_Status => Binary_Status,
            Status => Status);
      end;

      if Status /= Errors.Success then
         return;
      end if;

      if Binary_Status /= Errors.Success then
         Status := Binary_Status;
         return;
      end if;

      Programs.Build
        (Prg => Prg,
         Dev => Dev,
         Options => Trimmed (OpenCL.RT.Packs.To_String (Meta.Build_Options)),
         Status => Build_Status);

      if Build_Status /= Errors.Success then
         Programs.Release (Prg => Prg, Status => Release_Status);
         if Release_Status /= Errors.Success then
            null;
         end if;
         Status := Build_Status;
         return;
      end if;
   end Create_Program_From_Pack;

end OpenCL.RT.Loader;
