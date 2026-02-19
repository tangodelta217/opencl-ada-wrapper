with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Bounded;
with Ada.Strings.Fixed;
with OpenCL.Errors;

package body OpenCL.Core.Device_Selection is

   use type OpenCL.Errors.Status_Code;

   package Errors renames OpenCL.Errors;

   Max_Info_Length : constant Positive := 512;
   package Info_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Info_Length);
   subtype Bounded_String is Info_Strings.Bounded_String;

   type Candidate_Key is record
      Platform : OpenCL.Core.Platform;
      Device : OpenCL.Core.Device;
      Platform_Index : Natural := 0;
      Device_Index : Natural := 0;
      Platform_Name : Bounded_String := Info_Strings.To_Bounded_String ("");
      Platform_Vendor : Bounded_String := Info_Strings.To_Bounded_String ("");
      Platform_Version : Bounded_String := Info_Strings.To_Bounded_String ("");
      Device_Name : Bounded_String := Info_Strings.To_Bounded_String ("");
      Device_Vendor : Bounded_String := Info_Strings.To_Bounded_String ("");
      Device_Version : Bounded_String := Info_Strings.To_Bounded_String ("");
      Driver_Version : Bounded_String := Info_Strings.To_Bounded_String ("");
   end record;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Canonical_Order_Key (Value : String) return String is
   begin
      return Ada.Characters.Handling.To_Upper (Trimmed (Value));
   end Canonical_Order_Key;

   function To_Bounded (Value : String) return Bounded_String is
   begin
      if Value'Length > Max_Info_Length then
         return
           Info_Strings.To_Bounded_String
             (Value (Value'First .. Value'First + Max_Info_Length - 1));
      else
         return Info_Strings.To_Bounded_String (Value);
      end if;
   end To_Bounded;

   function Matches (Expected : String; Actual : String) return Boolean is
      E : constant String := Trimmed (Expected);
      A : constant String := Trimmed (Actual);
   begin
      if E'Length = 0 then
         return True;
      end if;

      return E = A;
   end Matches;

   function Less (Left : Candidate_Key; Right : Candidate_Key) return Boolean is
      Left_Device_Vendor : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Left.Device_Vendor));
      Right_Device_Vendor : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Right.Device_Vendor));
      Left_Device_Name : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Left.Device_Name));
      Right_Device_Name : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Right.Device_Name));
      Left_Driver : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Left.Driver_Version));
      Right_Driver : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Right.Driver_Version));
      Left_Platform_Vendor : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Left.Platform_Vendor));
      Right_Platform_Vendor : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Right.Platform_Vendor));
      Left_Platform_Name : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Left.Platform_Name));
      Right_Platform_Name : constant String :=
        Canonical_Order_Key (Info_Strings.To_String (Right.Platform_Name));
   begin
      if Left_Device_Vendor /= Right_Device_Vendor then
         return Left_Device_Vendor < Right_Device_Vendor;
      end if;

      if Left_Device_Name /= Right_Device_Name then
         return Left_Device_Name < Right_Device_Name;
      end if;

      if Left_Driver /= Right_Driver then
         return Left_Driver < Right_Driver;
      end if;

      if Left_Platform_Vendor /= Right_Platform_Vendor then
         return Left_Platform_Vendor < Right_Platform_Vendor;
      end if;

      if Left_Platform_Name /= Right_Platform_Name then
         return Left_Platform_Name < Right_Platform_Name;
      end if;

      if Left.Platform_Index /= Right.Platform_Index then
         return Left.Platform_Index < Right.Platform_Index;
      end if;

      return Left.Device_Index < Right.Device_Index;
   end Less;

   function Select_Device
     (Expected_Platform_Name : String := "";
      Expected_Platform_Vendor : String := "";
      Expected_Platform_Version : String := "";
      Expected_Device_Name : String := "";
      Expected_Device_Vendor : String := "";
      Expected_Device_Version : String := "";
      Expected_Driver_Version : String := "") return Selection_Result
   is
      Max_Platforms : constant Positive := 16;
      Max_Devices_Per_Platform : constant Positive := 64;

      Platforms : OpenCL.Core.Platform_List (1 .. Max_Platforms);
      Devices : OpenCL.Core.Device_List (1 .. Max_Devices_Per_Platform);

      Platform_Used : Natural := 0;
      Device_Used : Natural := 0;
      Enum_Status : Errors.Status_Code := Errors.Success;
      Query_Status : Errors.Status_Code := Errors.Success;
      Best : Candidate_Key;
      Has_Best : Boolean := False;
      Any_Filter : constant Boolean :=
        Trimmed (Expected_Platform_Name)'Length > 0
        or else Trimmed (Expected_Platform_Vendor)'Length > 0
        or else Trimmed (Expected_Platform_Version)'Length > 0
        or else Trimmed (Expected_Device_Name)'Length > 0
        or else Trimmed (Expected_Device_Vendor)'Length > 0
        or else Trimmed (Expected_Device_Version)'Length > 0
        or else Trimmed (Expected_Driver_Version)'Length > 0;
      Null_Platform : OpenCL.Core.Platform;
      Null_Device : OpenCL.Core.Device;
      Result : Selection_Result :=
        (Platform => Null_Platform,
         Device => Null_Device,
         Status => Errors.Success);
   begin
      OpenCL.Core.Enumerate_Platforms
        (Out_Platforms => Platforms,
         Used => Platform_Used,
         Status => Enum_Status);

      if Platform_Used = 0 then
         if Enum_Status /= Errors.Success then
            Result.Status := Enum_Status;
         elsif Any_Filter then
            Result.Status := Errors.OCLW_Fingerprint_Mismatch;
         else
            Result.Status := Errors.Device_Not_Found;
         end if;
         return Result;
      end if;

      for Platform_Pos in 1 .. Platform_Used loop
         declare
            P : constant OpenCL.Core.Platform :=
              Platforms (Platforms'First + Platform_Pos - 1);
         begin
            OpenCL.Core.Enumerate_Devices
              (P => P,
               Out_Devices => Devices,
               Used => Device_Used,
               Status => Enum_Status);

            if Device_Used = 0 then
               null;
            else
               for Device_Pos in 1 .. Device_Used loop
                  declare
                     D : constant OpenCL.Core.Device :=
                       Devices (Devices'First + Device_Pos - 1);
                     Platform_Name_Status : Errors.Status_Code := Errors.Success;
                     Platform_Vendor_Status : Errors.Status_Code := Errors.Success;
                     Platform_Version_Status : Errors.Status_Code := Errors.Success;
                     Device_Name_Status : Errors.Status_Code := Errors.Success;
                     Device_Vendor_Status : Errors.Status_Code := Errors.Success;
                     Device_Version_Status : Errors.Status_Code := Errors.Success;
                     Driver_Version_Status : Errors.Status_Code := Errors.Success;
                     Platform_Name : constant String :=
                       OpenCL.Core.Get_Platform_Info
                         (P => P,
                          What => OpenCL.Core.Name,
                          Status => Platform_Name_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Platform_Vendor : constant String :=
                       OpenCL.Core.Get_Platform_Info
                         (P => P,
                          What => OpenCL.Core.Vendor,
                          Status => Platform_Vendor_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Platform_Version : constant String :=
                       OpenCL.Core.Get_Platform_Info
                         (P => P,
                          What => OpenCL.Core.Version,
                          Status => Platform_Version_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Device_Name : constant String :=
                       OpenCL.Core.Get_Device_Info
                         (D => D,
                          What => OpenCL.Core.Name,
                          Status => Device_Name_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Device_Vendor : constant String :=
                       OpenCL.Core.Get_Device_Info
                         (D => D,
                          What => OpenCL.Core.Vendor,
                          Status => Device_Vendor_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Device_Version : constant String :=
                       OpenCL.Core.Get_Device_Info
                         (D => D,
                          What => OpenCL.Core.Version,
                          Status => Device_Version_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Driver_Version : constant String :=
                       OpenCL.Core.Get_Device_Info
                         (D => D,
                          What => OpenCL.Core.Driver_Version,
                          Status => Driver_Version_Status,
                          Max_Bytes => OpenCL.Core.Default_Max_Info_Bytes);
                     Candidate : Candidate_Key;
                  begin
                     Query_Status := Errors.Success;
                     if not Errors.Is_Success (Platform_Name_Status)
                       or else not Errors.Is_Success (Platform_Vendor_Status)
                       or else not Errors.Is_Success (Platform_Version_Status)
                       or else not Errors.Is_Success (Device_Name_Status)
                       or else not Errors.Is_Success (Device_Vendor_Status)
                       or else not Errors.Is_Success (Device_Version_Status)
                       or else not Errors.Is_Success (Driver_Version_Status)
                     then
                        Query_Status := Errors.OCLW_IO_Error;
                     end if;

                     if Query_Status /= Errors.Success then
                        null;
                     elsif not Matches (Expected_Platform_Name, Platform_Name)
                       or else not Matches (Expected_Platform_Vendor, Platform_Vendor)
                       or else not Matches (Expected_Platform_Version, Platform_Version)
                       or else not Matches (Expected_Device_Name, Device_Name)
                       or else not Matches (Expected_Device_Vendor, Device_Vendor)
                       or else not Matches (Expected_Device_Version, Device_Version)
                       or else not Matches (Expected_Driver_Version, Driver_Version)
                     then
                        null;
                     else
                        Candidate.Platform := P;
                        Candidate.Device := D;
                        Candidate.Platform_Index := Platform_Pos - 1;
                        Candidate.Device_Index := Device_Pos - 1;
                        Candidate.Platform_Name := To_Bounded (Trimmed (Platform_Name));
                        Candidate.Platform_Vendor := To_Bounded (Trimmed (Platform_Vendor));
                        Candidate.Platform_Version := To_Bounded (Trimmed (Platform_Version));
                        Candidate.Device_Name := To_Bounded (Trimmed (Device_Name));
                        Candidate.Device_Vendor := To_Bounded (Trimmed (Device_Vendor));
                        Candidate.Device_Version := To_Bounded (Trimmed (Device_Version));
                        Candidate.Driver_Version := To_Bounded (Trimmed (Driver_Version));

                        if not Has_Best or else Less (Candidate, Best) then
                           Best := Candidate;
                           Has_Best := True;
                        end if;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;

      if Has_Best then
         Result.Platform := Best.Platform;
         Result.Device := Best.Device;
         Result.Status := Errors.Success;
      elsif Any_Filter then
         Result.Status := Errors.OCLW_Fingerprint_Mismatch;
      else
         Result.Status := Errors.Device_Not_Found;
      end if;

      return Result;
   end Select_Device;

end OpenCL.Core.Device_Selection;
