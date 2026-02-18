with Ada.Characters.Handling;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;
with Interfaces.C;
with OpenCL.RT.Hash;

package body OpenCL.RT.Packs is

   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_32;
   use type OpenCL.Errors.Status_Code;

   package TIO renames Ada.Text_IO;
   package SIO renames Ada.Streams.Stream_IO;
   use type SIO.Count;

   Max_Manifest_Line_Length : constant Positive := 2_048;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function To_Bounded (Value : String) return Bounded_String is
   begin
      if Value'Length > Max_Field_Length then
         return
           Fields.To_Bounded_String
             (Value (Value'First .. Value'First + Max_Field_Length - 1));
      else
         return Fields.To_Bounded_String (Value);
      end if;
   end To_Bounded;

   procedure Warn_Truncated (Key : String) is
   begin
      TIO.Put_Line
        ("WARN OpenCL.RT.Packs: value truncated key="
         & Key
         & " max="
         & Natural'Image (Max_Field_Length));
   end Warn_Truncated;

   function Parse_Natural (Text : String; Value : out Natural) return Boolean is
      Clean : constant String := Trimmed (Text);
      Acc : Natural := 0;
   begin
      Value := 0;

      if Clean'Length = 0 then
         return False;
      end if;

      for C of Clean loop
         if C < '0' or else C > '9' then
            return False;
         end if;

         declare
            Digit : constant Natural := Character'Pos (C) - Character'Pos ('0');
         begin
            if Acc > (Natural'Last - Digit) / 10 then
               return False;
            end if;

            Acc := (Acc * 10) + Digit;
         end;
      end loop;

      Value := Acc;
      return True;
   end Parse_Natural;

   function Parse_Unsigned_32
     (Text : String;
      Value : out Interfaces.Unsigned_32) return Boolean
   is
      Clean : constant String := Trimmed (Text);
      Acc : Interfaces.Unsigned_32 := 0;
   begin
      Value := 0;

      if Clean'Length = 0 then
         return False;
      end if;

      for C of Clean loop
         if C < '0' or else C > '9' then
            return False;
         end if;

         declare
            Digit : constant Interfaces.Unsigned_32 :=
              Interfaces.Unsigned_32 (Character'Pos (C) - Character'Pos ('0'));
         begin
            if Acc > (Interfaces.Unsigned_32'Last - Digit) / 10 then
               return False;
            end if;

            Acc := (Acc * 10) + Digit;
         end;
      end loop;

      Value := Acc;
      return True;
   end Parse_Unsigned_32;

   function Natural_Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Natural_Image;

   function Size_T_Image (Value : Interfaces.C.size_t) return String is
      Raw : constant String := Interfaces.C.size_t'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Size_T_Image;

   function U32_Image (Value : Interfaces.Unsigned_32) return String is
      Raw : constant String := Interfaces.Unsigned_32'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end U32_Image;

   procedure Read_Manifest
     (Path : String;
      Meta : out Pack_Metadata;
      Status : out Status_Code)
   is
      File : TIO.File_Type;
      Line_Buffer : String (1 .. Max_Manifest_Line_Length);
      Last : Natural := 0;
      Line_No : Natural := 0;

      Seen_Kpack_Version : Boolean := False;
      Seen_Pack_Id : Boolean := False;
      Seen_Created_Utc : Boolean := False;
      Seen_Platform_Name : Boolean := False;
      Seen_Platform_Vendor : Boolean := False;
      Seen_Platform_Version : Boolean := False;
      Seen_Device_Name : Boolean := False;
      Seen_Device_Vendor : Boolean := False;
      Seen_Device_Version : Boolean := False;
      Seen_Driver_Version : Boolean := False;
      Seen_Binary_Size : Boolean := False;
      Seen_Binary_FNV1a32 : Boolean := False;
      Seen_Kernel_Name : Boolean := False;

      procedure Set_Field
        (Target : out Bounded_String;
         Key : String;
         Value : String)
      is
      begin
         if Value'Length > Max_Field_Length then
            Warn_Truncated (Key);
         end if;

         Target := To_Bounded (Value);
      end Set_Field;
   begin
      Meta := (others => <>);
      Status := OpenCL.Errors.Success;

      TIO.Open (File => File, Mode => TIO.In_File, Name => Path);

      while not TIO.End_Of_File (File) loop
         TIO.Get_Line (File, Line_Buffer, Last);
         Line_No := Line_No + 1;

         if Last = Line_Buffer'Last and then not TIO.End_Of_Line (File) then
            TIO.Skip_Line (File);
            TIO.Put_Line
              ("WARN OpenCL.RT.Packs: manifest line truncated line="
               & Natural_Image (Line_No)
               & " max="
               & Natural'Image (Max_Manifest_Line_Length));
         end if;

         declare
            Raw_Line : constant String :=
              (if Last = 0 then "" else Line_Buffer (1 .. Last));
            Line_Text : constant String := Trimmed (Raw_Line);
            Sep : Natural := 0;
         begin
            if Line_Text'Length = 0 then
               null;
            elsif Line_Text (Line_Text'First) = '#' then
               null;
            else
               Sep := Ada.Strings.Fixed.Index (Line_Text, "=");

               if Sep = 0 or else Sep = Line_Text'First then
                  Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                  TIO.Close (File);
                  return;
               end if;

               declare
                  Key_Raw : constant String :=
                    Trimmed (Line_Text (Line_Text'First .. Sep - 1));
                  Value_Raw : constant String :=
                    (if Sep < Line_Text'Last
                     then Trimmed (Line_Text (Sep + 1 .. Line_Text'Last))
                     else "");
                  Key : constant String :=
                    Ada.Characters.Handling.To_Lower (Key_Raw);
                  Parsed_Natural : Natural := 0;
                  Parsed_U32 : Interfaces.Unsigned_32 := 0;
               begin
                  if Key'Length = 0 then
                     Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                     TIO.Close (File);
                     return;
                  end if;

                  if Key = "kpack_version" then
                     if not Parse_Natural (Value_Raw, Parsed_Natural) then
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;
                     Meta.Kpack_Version := Parsed_Natural;
                     Seen_Kpack_Version := True;
                  elsif Key = "pack_id" then
                     Set_Field (Meta.Pack_Id, Key, Value_Raw);
                     Seen_Pack_Id := True;
                  elsif Key = "created_utc" then
                     Set_Field (Meta.Created_Utc, Key, Value_Raw);
                     Seen_Created_Utc := True;
                  elsif Key = "platform_name" then
                     Set_Field (Meta.Platform_Name, Key, Value_Raw);
                     Seen_Platform_Name := True;
                  elsif Key = "platform_vendor" then
                     Set_Field (Meta.Platform_Vendor, Key, Value_Raw);
                     Seen_Platform_Vendor := True;
                  elsif Key = "platform_version" then
                     Set_Field (Meta.Platform_Version, Key, Value_Raw);
                     Seen_Platform_Version := True;
                  elsif Key = "device_name" then
                     Set_Field (Meta.Device_Name, Key, Value_Raw);
                     Seen_Device_Name := True;
                  elsif Key = "device_vendor" then
                     Set_Field (Meta.Device_Vendor, Key, Value_Raw);
                     Seen_Device_Vendor := True;
                  elsif Key = "device_version" then
                     Set_Field (Meta.Device_Version, Key, Value_Raw);
                     Seen_Device_Version := True;
                  elsif Key = "driver_version" then
                     Set_Field (Meta.Driver_Version, Key, Value_Raw);
                     Seen_Driver_Version := True;
                  elsif Key = "opencl_c_version" then
                     Set_Field (Meta.OpenCL_C_Version, Key, Value_Raw);
                  elsif Key = "build_options" then
                     Set_Field (Meta.Build_Options, Key, Value_Raw);
                  elsif Key = "binary_size" then
                     if not Parse_Natural (Value_Raw, Parsed_Natural) then
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;
                     Meta.Binary_Size := Interfaces.C.size_t (Parsed_Natural);
                     Seen_Binary_Size := True;
                  elsif Key = "binary_fnv1a32" then
                     if not Parse_Unsigned_32 (Value_Raw, Parsed_U32) then
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;
                     Meta.Binary_FNV1a32 := Parsed_U32;
                     Seen_Binary_FNV1a32 := True;
                  elsif Key = "kernel_name" then
                     Set_Field (Meta.Kernel_Name, Key, Value_Raw);
                     Seen_Kernel_Name := True;
                  else
                     Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                     TIO.Close (File);
                     return;
                  end if;
               end;
            end if;
         end;
      end loop;

      TIO.Close (File);

      if not
        (Seen_Kpack_Version
         and Seen_Pack_Id
         and Seen_Created_Utc
         and Seen_Platform_Name
         and Seen_Platform_Vendor
         and Seen_Platform_Version
         and Seen_Device_Name
         and Seen_Device_Vendor
         and Seen_Device_Version
         and Seen_Driver_Version
         and Seen_Binary_Size
         and Seen_Binary_FNV1a32
         and Seen_Kernel_Name)
      then
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
      end if;
   exception
      when TIO.Name_Error
         | TIO.Use_Error
         | TIO.Status_Error
         | TIO.Device_Error
         | TIO.End_Error =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
      when others =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
   end Read_Manifest;

   procedure Write_Manifest
     (Path : String;
      Meta : Pack_Metadata;
      Status : out Status_Code)
   is
      File : TIO.File_Type;
   begin
      Status := OpenCL.Errors.Success;

      TIO.Create (File => File, Mode => TIO.Out_File, Name => Path);

      TIO.Put_Line (File, "# OpenCL RT Kernel Pack Manifest");
      TIO.Put_Line (File, "kpack_version=" & Natural_Image (Meta.Kpack_Version));
      TIO.Put_Line (File, "pack_id=" & To_String (Meta.Pack_Id));
      TIO.Put_Line (File, "created_utc=" & To_String (Meta.Created_Utc));

      TIO.Put_Line (File, "platform_name=" & To_String (Meta.Platform_Name));
      TIO.Put_Line (File, "platform_vendor=" & To_String (Meta.Platform_Vendor));
      TIO.Put_Line
        (File,
         "platform_version=" & To_String (Meta.Platform_Version));

      TIO.Put_Line (File, "device_name=" & To_String (Meta.Device_Name));
      TIO.Put_Line (File, "device_vendor=" & To_String (Meta.Device_Vendor));
      TIO.Put_Line (File, "device_version=" & To_String (Meta.Device_Version));
      TIO.Put_Line
        (File,
         "driver_version=" & To_String (Meta.Driver_Version));

      TIO.Put_Line
        (File,
         "opencl_c_version=" & To_String (Meta.OpenCL_C_Version));
      TIO.Put_Line (File, "build_options=" & To_String (Meta.Build_Options));

      TIO.Put_Line (File, "binary_size=" & Size_T_Image (Meta.Binary_Size));
      TIO.Put_Line
        (File,
         "binary_fnv1a32=" & U32_Image (Meta.Binary_FNV1a32));
      TIO.Put_Line (File, "kernel_name=" & To_String (Meta.Kernel_Name));

      TIO.Close (File);
   exception
      when TIO.Name_Error
         | TIO.Use_Error
         | TIO.Status_Error
         | TIO.Device_Error =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
      when others =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
   end Write_Manifest;

   procedure Read_Binary
     (Path : String;
      Buffer : out OpenCL.Core.Programs.Byte_Array;
      Used : out Natural;
      Status : out Status_Code)
   is
      File : SIO.File_Type;
      File_Size : SIO.Count := 0;
   begin
      Status := OpenCL.Errors.Success;
      Used := 0;

      for I in Buffer'Range loop
         Buffer (I) := 0;
      end loop;

      SIO.Open (File => File, Mode => SIO.In_File, Name => Path);

      File_Size := SIO.Size (File);
      if File_Size > SIO.Count (Natural'Last) then
         Status := OpenCL.Errors.OCLW_IO_Error;
         SIO.Close (File);
         return;
      end if;

      if File_Size > SIO.Count (Buffer'Length) then
         Status := OpenCL.Errors.OCLW_IO_Error;
         SIO.Close (File);
         return;
      end if;

      if File_Size = 0 then
         SIO.Close (File);
         return;
      end if;

      declare
         Element_Count : constant Natural := Natural (File_Size);
         Raw : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Element_Count));
         Last : Ada.Streams.Stream_Element_Offset := 0;
      begin
         SIO.Read (File => File, Item => Raw, Last => Last);

         if Last /= Raw'Last then
            Status := OpenCL.Errors.OCLW_IO_Error;
            SIO.Close (File);
            return;
         end if;

         for Offset in Raw'Range loop
            Buffer (Buffer'First + Integer (Offset - Raw'First)) :=
              OpenCL.Core.Programs.Byte (Raw (Offset));
         end loop;

         Used := Element_Count;
      end;

      SIO.Close (File);
   exception
      when SIO.Name_Error
         | SIO.Use_Error
         | SIO.Status_Error
         | SIO.Device_Error
         | Constraint_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
      when others =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
   end Read_Binary;

   procedure Verify_Binary
     (Meta : Pack_Metadata;
      Buffer : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Status : out Status_Code)
   is
      Calculated : Interfaces.Unsigned_32 := 0;
   begin
      Status := OpenCL.Errors.Success;

      if Used = 0 or else Used > Buffer'Length then
         Status := OpenCL.Errors.OCLW_Hash_Mismatch;
         return;
      end if;

      if Meta.Binary_Size /= Interfaces.C.size_t (Used) then
         Status := OpenCL.Errors.OCLW_Hash_Mismatch;
         return;
      end if;

      Calculated := OpenCL.RT.Hash.FNV1a_32 (Data => Buffer, Used => Used);
      if Calculated /= Meta.Binary_FNV1a32 then
         Status := OpenCL.Errors.OCLW_Hash_Mismatch;
         return;
      end if;
   end Verify_Binary;

end OpenCL.RT.Packs;
