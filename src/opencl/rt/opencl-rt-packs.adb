with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
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
   Max_Encoded_Field_Length : constant Positive := Max_Field_Length * 2;

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

   function Parse_Boolean_01
     (Text : String;
      Value : out Boolean) return Boolean
   is
      Clean : constant String := Trimmed (Text);
   begin
      Value := False;

      if Clean = "0" then
         Value := False;
         return True;
      elsif Clean = "1" then
         Value := True;
         return True;
      else
         return False;
      end if;
   end Parse_Boolean_01;

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

   function Boolean_01_Image (Value : Boolean) return String is
   begin
      if Value then
         return "1";
      else
         return "0";
      end if;
   end Boolean_01_Image;

   function Has_Outer_Whitespace (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;

      return
        (Value (Value'First) <= ' ')
        or else (Value (Value'Last) <= ' ');
   end Has_Outer_Whitespace;

   function Has_Forbidden_Field_Char (C : Character) return Boolean is
      Pos : constant Natural := Character'Pos (C);
   begin
      return
        Pos < 16#20#
        or else Pos = 16#7F#;
   end Has_Forbidden_Field_Char;

   function Find_Separator (Line : String) return Natural is
      Escaped : Boolean := False;
   begin
      for I in Line'Range loop
         if Escaped then
            Escaped := False;
         elsif Line (I) = '\' then
            Escaped := True;
         elsif Line (I) = '=' then
            return I;
         end if;
      end loop;

      return 0;
   end Find_Separator;

   function Encode_Field
     (Value : String;
      Encoded : out String;
      Last : out Natural) return Boolean
   is
      Cursor : Natural := 0;

      procedure Append (C : Character; Ok : in out Boolean) is
      begin
         if Cursor = Encoded'Length then
            Ok := False;
            return;
         end if;

         Cursor := Cursor + 1;
         Encoded (Cursor) := C;
      end Append;

      Ok : Boolean := True;
   begin
      Last := 0;

      if Value'Length > Max_Field_Length then
         return False;
      end if;

      if Has_Outer_Whitespace (Value) then
         return False;
      end if;

      for C of Value loop
         if C = Ada.Characters.Latin_1.LF or else C = Ada.Characters.Latin_1.CR then
            return False;
         end if;

         if Has_Forbidden_Field_Char (C) then
            return False;
         end if;

         if C = '\' or else C = '=' then
            Append ('\', Ok);
            if not Ok then
               return False;
            end if;
         end if;

         Append (C, Ok);
         if not Ok then
            return False;
         end if;
      end loop;

      Last := Cursor;
      return True;
   end Encode_Field;

   function Decode_Field
     (Encoded : String;
      Decoded : out Bounded_String) return Boolean
   is
      Buffer : String (1 .. Max_Field_Length);
      Cursor : Natural := 0;
      Escaped : Boolean := False;

      procedure Append (C : Character; Ok : in out Boolean) is
      begin
         if Cursor = Buffer'Length then
            Ok := False;
            return;
         end if;

         Cursor := Cursor + 1;
         Buffer (Cursor) := C;
      end Append;

      Ok : Boolean := True;
   begin
      Decoded := Fields.To_Bounded_String ("");

      if Has_Outer_Whitespace (Encoded) then
         return False;
      end if;

      for C of Encoded loop
         if Escaped then
            if C = '\' or else C = '=' then
               Append (C, Ok);
               if not Ok then
                  return False;
               end if;
            else
               return False;
            end if;

            Escaped := False;
         elsif C = '\' then
            Escaped := True;
         elsif C = '=' then
            return False;
         else
            if Has_Forbidden_Field_Char (C) then
               return False;
            end if;

            Append (C, Ok);
            if not Ok then
               return False;
            end if;
         end if;
      end loop;

      if Escaped then
         return False;
      end if;

      if Cursor > 0 then
         Decoded := Fields.To_Bounded_String (Buffer (1 .. Cursor));
      end if;

      return True;
   end Decode_Field;

   procedure Read_Manifest
     (Path : String;
      Meta : out Pack_Metadata;
      Status : out Status_Code)
   is
      File : TIO.File_Type;
      Line_Buffer : String (1 .. Max_Manifest_Line_Length);
      Last : Natural := 0;

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
      Seen_OpenCL_C_Version : Boolean := False;
      Seen_Build_Options : Boolean := False;
      Seen_Binary_Size : Boolean := False;
      Seen_Binary_FNV1a32 : Boolean := False;
      Seen_Kernel_Name : Boolean := False;
      Seen_Signature_Required : Boolean := False;
      Seen_Signature_Alg : Boolean := False;
      Seen_Signature_Value : Boolean := False;
      Seen_Signer_Id : Boolean := False;
   begin
      Meta := (others => <>);
      Status := OpenCL.Errors.Success;

      TIO.Open (File => File, Mode => TIO.In_File, Name => Path);

      while not TIO.End_Of_File (File) loop
         TIO.Get_Line (File, Line_Buffer, Last);

         if Last = Line_Buffer'Last and then not TIO.End_Of_Line (File) then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            TIO.Close (File);
            return;
         end if;

         declare
            Raw_Line : constant String :=
              (if Last = 0 then "" else Line_Buffer (1 .. Last));
            Line_Text : constant String := Trimmed (Raw_Line);
         begin
            if Line_Text'Length = 0 then
               null;
            elsif Line_Text (Line_Text'First) = '#' then
               null;
            else
               declare
                  Sep : constant Natural := Find_Separator (Raw_Line);
               begin
                  if Raw_Line /= Line_Text then
                     Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                     TIO.Close (File);
                     return;
                  end if;

                  if Sep = 0 or else Sep = Raw_Line'First then
                     Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                     TIO.Close (File);
                     return;
                  end if;

                  declare
                     Key_Raw : constant String :=
                       Raw_Line (Raw_Line'First .. Sep - 1);
                     Value_Encoded : constant String :=
                       (if Sep < Raw_Line'Last
                        then Raw_Line (Sep + 1 .. Raw_Line'Last)
                        else "");
                     Key : constant String :=
                       Ada.Characters.Handling.To_Lower (Key_Raw);
                     Decoded_Value : Bounded_String := Fields.To_Bounded_String ("");
                     Parsed_Natural : Natural := 0;
                     Parsed_U32 : Interfaces.Unsigned_32 := 0;
                     Parsed_Boolean : Boolean := False;
                  begin
                     if Key'Length = 0 then
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;

                     --  Strict policy: no whitespace around '=' and no silent
                     --  normalization for canonical lines.
                     if Has_Outer_Whitespace (Key_Raw)
                       or else Has_Outer_Whitespace (Value_Encoded)
                     then
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;

                     if not Decode_Field (Value_Encoded, Decoded_Value) then
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;

                     if Key = "kpack_version" then
                        if Seen_Kpack_Version then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        if not Parse_Natural
                          (To_String (Decoded_Value), Parsed_Natural)
                        then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        Meta.Kpack_Version := Parsed_Natural;
                        Seen_Kpack_Version := True;
                     elsif Key = "pack_id" then
                        if Seen_Pack_Id then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Pack_Id := Decoded_Value;
                        Seen_Pack_Id := True;
                     elsif Key = "created_utc" then
                        if Seen_Created_Utc then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Created_Utc := Decoded_Value;
                        Seen_Created_Utc := True;
                     elsif Key = "platform_name" then
                        if Seen_Platform_Name then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Platform_Name := Decoded_Value;
                        Seen_Platform_Name := True;
                     elsif Key = "platform_vendor" then
                        if Seen_Platform_Vendor then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Platform_Vendor := Decoded_Value;
                        Seen_Platform_Vendor := True;
                     elsif Key = "platform_version" then
                        if Seen_Platform_Version then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Platform_Version := Decoded_Value;
                        Seen_Platform_Version := True;
                     elsif Key = "device_name" then
                        if Seen_Device_Name then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Device_Name := Decoded_Value;
                        Seen_Device_Name := True;
                     elsif Key = "device_vendor" then
                        if Seen_Device_Vendor then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Device_Vendor := Decoded_Value;
                        Seen_Device_Vendor := True;
                     elsif Key = "device_version" then
                        if Seen_Device_Version then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Device_Version := Decoded_Value;
                        Seen_Device_Version := True;
                     elsif Key = "driver_version" then
                        if Seen_Driver_Version then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Driver_Version := Decoded_Value;
                        Seen_Driver_Version := True;
                     elsif Key = "opencl_c_version" then
                        if Seen_OpenCL_C_Version then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.OpenCL_C_Version := Decoded_Value;
                        Seen_OpenCL_C_Version := True;
                     elsif Key = "build_options" then
                        if Seen_Build_Options then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Build_Options := Decoded_Value;
                        Seen_Build_Options := True;
                     elsif Key = "binary_size" then
                        if Seen_Binary_Size then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        if not Parse_Natural
                          (To_String (Decoded_Value), Parsed_Natural)
                        then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        Meta.Binary_Size := Interfaces.C.size_t (Parsed_Natural);
                        Seen_Binary_Size := True;
                     elsif Key = "binary_fnv1a32" then
                        if Seen_Binary_FNV1a32 then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        if not Parse_Unsigned_32
                          (To_String (Decoded_Value), Parsed_U32)
                        then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        Meta.Binary_FNV1a32 := Parsed_U32;
                        Seen_Binary_FNV1a32 := True;
                     elsif Key = "kernel_name" then
                        if Seen_Kernel_Name then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Kernel_Name := Decoded_Value;
                        Seen_Kernel_Name := True;
                     elsif Key = "signature_required" then
                        if Seen_Signature_Required then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        if not Parse_Boolean_01
                          (To_String (Decoded_Value), Parsed_Boolean)
                        then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;

                        Meta.Signature_Required := Parsed_Boolean;
                        Seen_Signature_Required := True;
                     elsif Key = "signature_alg" then
                        if Seen_Signature_Alg then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Signature_Alg := Decoded_Value;
                        Seen_Signature_Alg := True;
                     elsif Key = "signature_value" then
                        if Seen_Signature_Value then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Signature_Value := Decoded_Value;
                        Seen_Signature_Value := True;
                     elsif Key = "signer_id" then
                        if Seen_Signer_Id then
                           Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                           TIO.Close (File);
                           return;
                        end if;
                        Meta.Signer_Id := Decoded_Value;
                        Seen_Signer_Id := True;
                     else
                        Status := OpenCL.Errors.OCLW_Pack_Format_Error;
                        TIO.Close (File);
                        return;
                     end if;
                  end;
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
         return;
      end if;

      if Meta.Signature_Required then
         if not Seen_Signature_Alg
           or else not Seen_Signature_Value
           or else To_String (Meta.Signature_Alg)'Length = 0
           or else To_String (Meta.Signature_Value)'Length = 0
         then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            return;
         end if;
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
      when Constraint_Error =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
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
      File : SIO.File_Type;

      procedure Write_Field (Key : String; Value : String) is
         Encoded_Buffer : String (1 .. Max_Encoded_Field_Length);
         Encoded_Last : Natural := 0;
      begin
         if not Encode_Field
           (Value => Value,
            Encoded => Encoded_Buffer,
            Last => Encoded_Last)
         then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            return;
         end if;

         if Key'Length + 1 + Encoded_Last + 1 > Max_Manifest_Line_Length then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            return;
         end if;

         declare
            Encoded_Value : constant String :=
              (if Encoded_Last = 0 then "" else Encoded_Buffer (1 .. Encoded_Last));
            Line : constant String :=
              Key & "=" & Encoded_Value & Ada.Characters.Latin_1.LF;
            Bytes : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Line'Length));
         begin
            for I in Line'Range loop
               Bytes
                 (Bytes'First
                  + Ada.Streams.Stream_Element_Offset (I - Line'First)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Line (I)));
            end loop;

            SIO.Write (File => File, Item => Bytes);
         end;
      end Write_Field;
   begin
      Status := OpenCL.Errors.Success;

      if Meta.Signature_Required
        and then
          (To_String (Meta.Signature_Alg)'Length = 0
           or else To_String (Meta.Signature_Value)'Length = 0)
      then
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
         return;
      end if;

      SIO.Create (File => File, Mode => SIO.Out_File, Name => Path);

      Write_Field ("kpack_version", Natural_Image (Meta.Kpack_Version));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("pack_id", To_String (Meta.Pack_Id));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("created_utc", To_String (Meta.Created_Utc));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("platform_name", To_String (Meta.Platform_Name));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("platform_vendor", To_String (Meta.Platform_Vendor));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("platform_version", To_String (Meta.Platform_Version));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("device_name", To_String (Meta.Device_Name));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("device_vendor", To_String (Meta.Device_Vendor));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("device_version", To_String (Meta.Device_Version));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("driver_version", To_String (Meta.Driver_Version));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("opencl_c_version", To_String (Meta.OpenCL_C_Version));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("build_options", To_String (Meta.Build_Options));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("binary_size", Size_T_Image (Meta.Binary_Size));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("binary_fnv1a32", U32_Image (Meta.Binary_FNV1a32));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("kernel_name", To_String (Meta.Kernel_Name));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("signature_required", Boolean_01_Image (Meta.Signature_Required));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("signature_alg", To_String (Meta.Signature_Alg));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("signature_value", To_String (Meta.Signature_Value));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

      Write_Field ("signer_id", To_String (Meta.Signer_Id));
      if Status /= OpenCL.Errors.Success then
         SIO.Close (File);
         return;
      end if;

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
   end Write_Manifest;

   function Canonical_Signing_Text (Meta : Pack_Metadata) return String is
      Buffer : String (1 .. Max_Canonical_Signing_Text_Length);
      Cursor : Natural := 0;

      function Append_Char (C : Character) return Boolean is
      begin
         if Cursor = Buffer'Length then
            return False;
         end if;

         Cursor := Cursor + 1;
         Buffer (Cursor) := C;
         return True;
      end Append_Char;

      function Append_Text (Text : String) return Boolean is
      begin
         for C of Text loop
            if not Append_Char (C) then
               return False;
            end if;
         end loop;

         return True;
      end Append_Text;

      function Append_Field_Line (Key : String; Value : String) return Boolean is
         Encoded_Buffer : String (1 .. Max_Encoded_Field_Length);
         Encoded_Last : Natural := 0;
      begin
         if not Encode_Field (Value => Value, Encoded => Encoded_Buffer, Last => Encoded_Last) then
            return False;
         end if;

         if not Append_Text (Key) then
            return False;
         end if;
         if not Append_Char ('=') then
            return False;
         end if;

         if Encoded_Last > 0 then
            if not Append_Text (Encoded_Buffer (1 .. Encoded_Last)) then
               return False;
            end if;
         end if;

         return Append_Char (Ada.Characters.Latin_1.LF);
      end Append_Field_Line;
   begin
      if not Append_Field_Line ("kpack_version", Natural_Image (Meta.Kpack_Version)) then
         return "";
      end if;
      if not Append_Field_Line ("pack_id", To_String (Meta.Pack_Id)) then
         return "";
      end if;
      if not Append_Field_Line ("created_utc", To_String (Meta.Created_Utc)) then
         return "";
      end if;
      if not Append_Field_Line ("platform_name", To_String (Meta.Platform_Name)) then
         return "";
      end if;
      if not Append_Field_Line ("platform_vendor", To_String (Meta.Platform_Vendor)) then
         return "";
      end if;
      if not Append_Field_Line ("platform_version", To_String (Meta.Platform_Version)) then
         return "";
      end if;
      if not Append_Field_Line ("device_name", To_String (Meta.Device_Name)) then
         return "";
      end if;
      if not Append_Field_Line ("device_vendor", To_String (Meta.Device_Vendor)) then
         return "";
      end if;
      if not Append_Field_Line ("device_version", To_String (Meta.Device_Version)) then
         return "";
      end if;
      if not Append_Field_Line ("driver_version", To_String (Meta.Driver_Version)) then
         return "";
      end if;
      if not Append_Field_Line ("opencl_c_version", To_String (Meta.OpenCL_C_Version)) then
         return "";
      end if;
      if not Append_Field_Line ("build_options", To_String (Meta.Build_Options)) then
         return "";
      end if;
      if not Append_Field_Line ("binary_size", Size_T_Image (Meta.Binary_Size)) then
         return "";
      end if;
      if not Append_Field_Line ("binary_fnv1a32", U32_Image (Meta.Binary_FNV1a32)) then
         return "";
      end if;
      if not Append_Field_Line ("kernel_name", To_String (Meta.Kernel_Name)) then
         return "";
      end if;
      if not Append_Field_Line ("signer_id", To_String (Meta.Signer_Id)) then
         return "";
      end if;

      if Cursor = 0 then
         return "";
      else
         return Buffer (1 .. Cursor);
      end if;
   exception
      when others =>
         return "";
   end Canonical_Signing_Text;

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
