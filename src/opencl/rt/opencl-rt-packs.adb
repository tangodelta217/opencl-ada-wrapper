with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.RT.Constant_Time;
with OpenCL.RT.FS;
with OpenCL.RT.Hash;
with OpenCL.RT.Memtrack;
with System;

package body OpenCL.RT.Packs is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Directories.File_Size;
   use type Ada.Directories.File_Kind;
   use type Interfaces.C.size_t;
   use type Interfaces.C.Strings.chars_ptr;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type OpenCL.Errors.Status_Code;

   package SIO renames Ada.Streams.Stream_IO;
   use type SIO.Count;

   Max_Encoded_Field_Length : constant Positive := Max_Field_Length * 2;

   function C_Realpath
     (Path : Interfaces.C.Strings.chars_ptr;
      Resolved_Path : System.Address) return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, C_Realpath, "realpath");

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

   function Parse_Natural (Text : String; Value : out Natural) return Boolean
     with Post =>
       (if Parse_Natural'Result
        then Value <= Natural'Last
        else True)
   is
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
     with Post =>
       (if Parse_Unsigned_32'Result
        then Value <= Interfaces.Unsigned_32'Last
        else True)
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

   function Parse_Unsigned_64
     (Text : String;
      Value : out Interfaces.Unsigned_64) return Boolean
     with Post =>
       (if Parse_Unsigned_64'Result
        then Value <= Interfaces.Unsigned_64'Last
        else True)
   is
      Clean : constant String := Trimmed (Text);
      Acc : Interfaces.Unsigned_64 := 0;
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
            Digit : constant Interfaces.Unsigned_64 :=
              Interfaces.Unsigned_64 (Character'Pos (C) - Character'Pos ('0'));
         begin
            if Acc > (Interfaces.Unsigned_64'Last - Digit) / 10 then
               return False;
            end if;

            Acc := (Acc * 10) + Digit;
         end;
      end loop;

      Value := Acc;
      return True;
   end Parse_Unsigned_64;

   function Parse_Boolean_01
     (Text : String;
      Value : out Boolean) return Boolean
     with Post =>
       (if Parse_Boolean_01'Result
        then (Trimmed (Text) = "0" and then Value = False)
             or else (Trimmed (Text) = "1" and then Value = True)
        else True)
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

   function Effective_Max_RT_Binary_Size return Interfaces.C.size_t is
      Acc : Interfaces.C.size_t := 0;
   begin
      if not Ada.Environment_Variables.Exists ("OCLW_RT_MAX_BINARY_SIZE") then
         return Max_RT_Binary_Size_Default;
      end if;

      declare
         Raw : constant String :=
           Trimmed (Ada.Environment_Variables.Value ("OCLW_RT_MAX_BINARY_SIZE"));
      begin
         if Raw'Length = 0 then
            return Max_RT_Binary_Size_Default;
         end if;

         for C of Raw loop
            if C < '0' or else C > '9' then
               return Max_RT_Binary_Size_Default;
            end if;

            declare
               Digit : constant Interfaces.C.size_t :=
                 Interfaces.C.size_t (Character'Pos (C) - Character'Pos ('0'));
            begin
               if Acc > (Interfaces.C.size_t'Last - Digit) / 10 then
                  return Max_RT_Binary_Size_Default;
               end if;

               Acc := (Acc * 10) + Digit;
            end;
         end loop;
      end;

      if Acc = 0 then
         return Max_RT_Binary_Size_Default;
      end if;

      return Acc;
   exception
      when others =>
         return Max_RT_Binary_Size_Default;
   end Effective_Max_RT_Binary_Size;

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

   function U64_Image (Value : Interfaces.Unsigned_64) return String is
      Raw : constant String := Interfaces.Unsigned_64'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end U64_Image;

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

   function Contains_Parent_Component (Path : String) return Boolean is
   begin
      if Path'Length = 0 then
         return False;
      end if;

      declare
         Component_Start : Positive := Path'First;
      begin
         for I in Path'Range loop
            if Path (I) = '/' or else Path (I) = '\' then
               if I > Component_Start
                 and then Path (Component_Start .. I - 1) = ".."
               then
                  return True;
               end if;
               if I < Path'Last then
                  Component_Start := I + 1;
               else
                  Component_Start := Path'Last;
               end if;
            end if;
         end loop;

         if Component_Start <= Path'Last
           and then Path (Component_Start .. Path'Last) = ".."
         then
            return True;
         end if;
      end;

      return False;
   end Contains_Parent_Component;

   function Normalize_No_Trailing_Slash (Path : String) return String is
   begin
      if Path'Length = 0 then
         return "";
      end if;

      declare
         Last : Natural := Path'Last;
      begin
         while Last > Path'First and then Path (Last) = '/' loop
            Last := Last - 1;
         end loop;

         return Path (Path'First .. Last);
      end;
   end Normalize_No_Trailing_Slash;

   function Path_Is_Within_Dir
     (File_Path : String;
      Dir_Path : String) return Boolean
   is
      File_Norm : constant String := Normalize_No_Trailing_Slash (File_Path);
      Dir_Norm : constant String := Normalize_No_Trailing_Slash (Dir_Path);
      Prefix_Last : Natural := 0;
   begin
      if File_Norm'Length = 0 or else Dir_Norm'Length = 0 then
         return False;
      end if;

      if File_Norm'Length <= Dir_Norm'Length then
         return False;
      end if;

      Prefix_Last := File_Norm'First + Dir_Norm'Length - 1;
      if File_Norm (File_Norm'First .. Prefix_Last) /= Dir_Norm then
         return False;
      end if;

      return File_Norm (Prefix_Last + 1) = '/';
   end Path_Is_Within_Dir;

   function Canonical_Path
     (Path : String;
      Status : out Status_Code) return String
   is
      Path_Ptr : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Resolved_Ptr : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
   begin
      Status := OpenCL.Errors.Success;

      Path_Ptr := Interfaces.C.Strings.New_String (Path);
      Resolved_Ptr := C_Realpath (Path => Path_Ptr, Resolved_Path => System.Null_Address);
      Interfaces.C.Strings.Free (Path_Ptr);
      Path_Ptr := Interfaces.C.Strings.Null_Ptr;

      if Resolved_Ptr = Interfaces.C.Strings.Null_Ptr then
         Status := OpenCL.Errors.OCLW_FS_Policy_Violation;
         return "";
      end if;

      declare
         Value : constant String := Interfaces.C.Strings.Value (Resolved_Ptr);
      begin
         Interfaces.C.Strings.Free (Resolved_Ptr);
         Resolved_Ptr := Interfaces.C.Strings.Null_Ptr;
         return Value;
      end;
   exception
      when others =>
         if Path_Ptr /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Path_Ptr);
         end if;
         if Resolved_Ptr /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Resolved_Ptr);
         end if;
         Status := OpenCL.Errors.OCLW_IO_Error;
         return "";
   end Canonical_Path;

   function Effective_Pack_Dir (Path : String) return String is
   begin
      return Ada.Directories.Containing_Directory (Path);
   end Effective_Pack_Dir;

   function Validate_Input_File_Path (Path : String) return Status_Code is
      Clean_Path : constant String := Trimmed (Path);
      Raw_Pack_Dir : constant String := Effective_Pack_Dir (Path);
      Resolve_Status : Status_Code := OpenCL.Errors.Success;
   begin
      if Clean_Path'Length = 0 then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if Clean_Path /= Path then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if Contains_Parent_Component (Path) then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if not Ada.Directories.Exists (Path) then
         return OpenCL.Errors.OCLW_IO_Error;
      end if;

      if GNAT.OS_Lib.Is_Symbolic_Link (Path) then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if Raw_Pack_Dir'Length = 0 then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if Contains_Parent_Component (Raw_Pack_Dir) then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if not Ada.Directories.Exists (Raw_Pack_Dir) then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      if Ada.Directories.Kind (Raw_Pack_Dir) /= Ada.Directories.Directory then
         return OpenCL.Errors.OCLW_FS_Policy_Violation;
      end if;

      declare
         Canonical_Dir : constant String :=
           Canonical_Path (Path => Raw_Pack_Dir, Status => Resolve_Status);
      begin
         if Resolve_Status /= OpenCL.Errors.Success then
            return Resolve_Status;
         end if;

         declare
            Canonical_File : constant String :=
              Canonical_Path (Path => Path, Status => Resolve_Status);
         begin
            if Resolve_Status /= OpenCL.Errors.Success then
               return Resolve_Status;
            end if;

            if not Path_Is_Within_Dir
                (File_Path => Canonical_File,
                 Dir_Path => Canonical_Dir)
            then
               return OpenCL.Errors.OCLW_FS_Policy_Violation;
            end if;
         end;
      end;

      return OpenCL.Errors.Success;
   exception
      when others =>
         return OpenCL.Errors.OCLW_IO_Error;
   end Validate_Input_File_Path;

   function Find_Separator (Line : String) return Natural
     with Post =>
       (if Find_Separator'Result /= 0
        then Find_Separator'Result in Line'Range
             and then Line (Find_Separator'Result) = '='
        else True)
   is
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

   type Manifest_Key is
     (Manifest_Key_None,
      Manifest_Key_Kpack_Version,
      Manifest_Key_Pack_Version,
      Manifest_Key_Pack_Id,
      Manifest_Key_Created_Utc,
      Manifest_Key_Platform_Name,
      Manifest_Key_Platform_Vendor,
      Manifest_Key_Platform_Version,
      Manifest_Key_Device_Name,
      Manifest_Key_Device_Vendor,
      Manifest_Key_Device_Version,
      Manifest_Key_Driver_Version,
      Manifest_Key_OpenCL_C_Version,
      Manifest_Key_Build_Options,
      Manifest_Key_Binary_Size,
      Manifest_Key_Binary_FNV1a32,
      Manifest_Key_Monotonic_Counter,
      Manifest_Key_Kernel_Name,
      Manifest_Key_Signature_Required,
      Manifest_Key_Signature_Alg,
      Manifest_Key_Signature_Value,
      Manifest_Key_Signer_Id,
      Manifest_Key_Unknown);

   type Manifest_Seen_Flags is record
      Kpack_Version : Boolean := False;
      Pack_Version : Boolean := False;
      Pack_Id : Boolean := False;
      Created_Utc : Boolean := False;
      Platform_Name : Boolean := False;
      Platform_Vendor : Boolean := False;
      Platform_Version : Boolean := False;
      Device_Name : Boolean := False;
      Device_Vendor : Boolean := False;
      Device_Version : Boolean := False;
      Driver_Version : Boolean := False;
      OpenCL_C_Version : Boolean := False;
      Build_Options : Boolean := False;
      Binary_Size : Boolean := False;
      Binary_FNV1a32 : Boolean := False;
      Monotonic_Counter : Boolean := False;
      Kernel_Name : Boolean := False;
      Signature_Required : Boolean := False;
      Signature_Alg : Boolean := False;
      Signature_Value : Boolean := False;
      Signer_Id : Boolean := False;
   end record;

   function Key_From_Text (Key_Raw : String) return Manifest_Key
     with Pre => Key_Raw'Length > 0
   is
      Key : constant String := Ada.Characters.Handling.To_Lower (Key_Raw);
   begin
      if Key = "kpack_version" then
         return Manifest_Key_Kpack_Version;
      elsif Key = "pack_version" then
         return Manifest_Key_Pack_Version;
      elsif Key = "pack_id" then
         return Manifest_Key_Pack_Id;
      elsif Key = "created_utc" then
         return Manifest_Key_Created_Utc;
      elsif Key = "platform_name" then
         return Manifest_Key_Platform_Name;
      elsif Key = "platform_vendor" then
         return Manifest_Key_Platform_Vendor;
      elsif Key = "platform_version" then
         return Manifest_Key_Platform_Version;
      elsif Key = "device_name" then
         return Manifest_Key_Device_Name;
      elsif Key = "device_vendor" then
         return Manifest_Key_Device_Vendor;
      elsif Key = "device_version" then
         return Manifest_Key_Device_Version;
      elsif Key = "driver_version" then
         return Manifest_Key_Driver_Version;
      elsif Key = "opencl_c_version" then
         return Manifest_Key_OpenCL_C_Version;
      elsif Key = "build_options" then
         return Manifest_Key_Build_Options;
      elsif Key = "binary_size" then
         return Manifest_Key_Binary_Size;
      elsif Key = "binary_fnv1a32" then
         return Manifest_Key_Binary_FNV1a32;
      elsif Key = "monotonic_counter" then
         return Manifest_Key_Monotonic_Counter;
      elsif Key = "kernel_name" then
         return Manifest_Key_Kernel_Name;
      elsif Key = "signature_required" then
         return Manifest_Key_Signature_Required;
      elsif Key = "signature_alg" then
         return Manifest_Key_Signature_Alg;
      elsif Key = "signature_value" then
         return Manifest_Key_Signature_Value;
      elsif Key = "signer_id" then
         return Manifest_Key_Signer_Id;
      else
         return Manifest_Key_Unknown;
      end if;
   end Key_From_Text;

   procedure Parse_Manifest_Line
     (Raw_Line : String;
      Parsed : out Boolean;
      Key : out Manifest_Key;
      Decoded_Value : out Bounded_String;
      Status : out Status_Code)
     with Post =>
       (if Status /= OpenCL.Errors.Success
        then Key = Manifest_Key_None)
   is
      Line_Text : constant String := Trimmed (Raw_Line);
      Sep : Natural := 0;
   begin
      Parsed := False;
      Key := Manifest_Key_None;
      Decoded_Value := Fields.To_Bounded_String ("");
      Status := OpenCL.Errors.Success;

      if Line_Text'Length = 0 then
         return;
      end if;

      if Line_Text (Line_Text'First) = '#' then
         return;
      end if;

      Parsed := True;

      --  Canonical strictness for key-value lines.
      if Raw_Line /= Line_Text then
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
         Parsed := False;
         return;
      end if;

      Sep := Find_Separator (Raw_Line);
      if Sep = 0 or else Sep = Raw_Line'First then
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
         Parsed := False;
         return;
      end if;

      declare
         Key_Raw : constant String := Raw_Line (Raw_Line'First .. Sep - 1);
         Value_Encoded : constant String :=
           (if Sep < Raw_Line'Last
            then Raw_Line (Sep + 1 .. Raw_Line'Last)
            else "");
      begin
         if Has_Outer_Whitespace (Key_Raw)
           or else Has_Outer_Whitespace (Value_Encoded)
         then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            Parsed := False;
            return;
         end if;

         if not Decode_Field (Value_Encoded, Decoded_Value) then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            Parsed := False;
            return;
         end if;

         Key := Key_From_Text (Key_Raw);
         if Key = Manifest_Key_Unknown then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            Parsed := False;
            Key := Manifest_Key_None;
            return;
         end if;
      end;
   end Parse_Manifest_Line;

   procedure Mark_Seen
     (Seen_Field : in out Boolean;
      Status : out Status_Code) is
   begin
      if Seen_Field then
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
      else
         Seen_Field := True;
         Status := OpenCL.Errors.Success;
      end if;
   end Mark_Seen;

   procedure Apply_Manifest_Entry
     (Key : Manifest_Key;
      Value : Bounded_String;
      Meta : in out Pack_Metadata;
      Seen : in out Manifest_Seen_Flags;
      Max_RT_Binary_Size : Interfaces.C.size_t;
      Status : out Status_Code)
   is
      Parsed_Natural : Natural := 0;
      Parsed_U32 : Interfaces.Unsigned_32 := 0;
      Parsed_U64 : Interfaces.Unsigned_64 := 0;
      Parsed_Boolean : Boolean := False;
      Value_Text : constant String := To_String (Value);
   begin
      Status := OpenCL.Errors.Success;

      case Key is
         when Manifest_Key_None | Manifest_Key_Unknown =>
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            return;

         when Manifest_Key_Kpack_Version =>
            Mark_Seen (Seen.Kpack_Version, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            if not Parse_Natural (Value_Text, Parsed_Natural) then
               Status := OpenCL.Errors.OCLW_Pack_Format_Error;
               return;
            end if;
            Meta.Kpack_Version := Parsed_Natural;

         when Manifest_Key_Pack_Version =>
            Mark_Seen (Seen.Pack_Version, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            if not Parse_Unsigned_32 (Value_Text, Parsed_U32) then
               Status := OpenCL.Errors.OCLW_Pack_Format_Error;
               return;
            end if;
            Meta.Pack_Version := Parsed_U32;
            Meta.Pack_Version_Present := True;

         when Manifest_Key_Pack_Id =>
            Mark_Seen (Seen.Pack_Id, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Pack_Id := Value;

         when Manifest_Key_Created_Utc =>
            Mark_Seen (Seen.Created_Utc, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Created_Utc := Value;

         when Manifest_Key_Platform_Name =>
            Mark_Seen (Seen.Platform_Name, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Platform_Name := Value;

         when Manifest_Key_Platform_Vendor =>
            Mark_Seen (Seen.Platform_Vendor, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Platform_Vendor := Value;

         when Manifest_Key_Platform_Version =>
            Mark_Seen (Seen.Platform_Version, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Platform_Version := Value;

         when Manifest_Key_Device_Name =>
            Mark_Seen (Seen.Device_Name, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Device_Name := Value;

         when Manifest_Key_Device_Vendor =>
            Mark_Seen (Seen.Device_Vendor, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Device_Vendor := Value;

         when Manifest_Key_Device_Version =>
            Mark_Seen (Seen.Device_Version, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Device_Version := Value;

         when Manifest_Key_Driver_Version =>
            Mark_Seen (Seen.Driver_Version, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Driver_Version := Value;

         when Manifest_Key_OpenCL_C_Version =>
            Mark_Seen (Seen.OpenCL_C_Version, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.OpenCL_C_Version := Value;

         when Manifest_Key_Build_Options =>
            Mark_Seen (Seen.Build_Options, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Build_Options := Value;

         when Manifest_Key_Binary_Size =>
            Mark_Seen (Seen.Binary_Size, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            if not Parse_Natural (Value_Text, Parsed_Natural) then
               Status := OpenCL.Errors.OCLW_Pack_Format_Error;
               return;
            end if;
            Meta.Binary_Size := Interfaces.C.size_t (Parsed_Natural);
            if Meta.Binary_Size > Max_RT_Binary_Size then
               Status := OpenCL.Errors.OCLW_Limit_Exceeded;
               return;
            end if;

         when Manifest_Key_Binary_FNV1a32 =>
            Mark_Seen (Seen.Binary_FNV1a32, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            if not Parse_Unsigned_32 (Value_Text, Parsed_U32) then
               Status := OpenCL.Errors.OCLW_Pack_Format_Error;
               return;
            end if;
            Meta.Binary_FNV1a32 := Parsed_U32;

         when Manifest_Key_Monotonic_Counter =>
            Mark_Seen (Seen.Monotonic_Counter, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            if not Parse_Unsigned_64 (Value_Text, Parsed_U64) then
               Status := OpenCL.Errors.OCLW_Pack_Format_Error;
               return;
            end if;
            Meta.Monotonic_Counter := Parsed_U64;
            Meta.Monotonic_Counter_Present := True;

         when Manifest_Key_Kernel_Name =>
            Mark_Seen (Seen.Kernel_Name, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Kernel_Name := Value;

         when Manifest_Key_Signature_Required =>
            Mark_Seen (Seen.Signature_Required, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            if not Parse_Boolean_01 (Value_Text, Parsed_Boolean) then
               Status := OpenCL.Errors.OCLW_Pack_Format_Error;
               return;
            end if;
            Meta.Signature_Required := Parsed_Boolean;

         when Manifest_Key_Signature_Alg =>
            Mark_Seen (Seen.Signature_Alg, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Signature_Alg := Value;

         when Manifest_Key_Signature_Value =>
            Mark_Seen (Seen.Signature_Value, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Signature_Value := Value;

         when Manifest_Key_Signer_Id =>
            Mark_Seen (Seen.Signer_Id, Status);
            if Status /= OpenCL.Errors.Success then
               return;
            end if;
            Meta.Signer_Id := Value;
      end case;
   end Apply_Manifest_Entry;

   function Required_Fields_Present
     (Seen : Manifest_Seen_Flags) return Boolean
   is
   begin
      return
        Seen.Kpack_Version
        and Seen.Pack_Id
        and Seen.Created_Utc
        and Seen.Platform_Name
        and Seen.Platform_Vendor
        and Seen.Platform_Version
        and Seen.Device_Name
        and Seen.Device_Vendor
        and Seen.Device_Version
        and Seen.Driver_Version
        and Seen.Binary_Size
        and Seen.Binary_FNV1a32
        and Seen.Kernel_Name;
   end Required_Fields_Present;

   procedure Read_Manifest
     (Path : String;
      Meta : out Pack_Metadata;
      Status : out Status_Code)
   is
      Parsed_Key_Count : Natural := 0;
      Max_RT_Binary_Size : constant Interfaces.C.size_t :=
        Effective_Max_RT_Binary_Size;
      Seen : Manifest_Seen_Flags := (others => False);
      Snapshot : OpenCL.RT.FS.File_Snapshot;
      Manifest_Data : OpenCL.Core.Programs.Byte_Array (1 .. Max_Manifest_Bytes);
      Manifest_Used : Natural := 0;

      procedure Parse_Line_Or_Fail (Raw_Line : String) is
         Parsed : Boolean := False;
         Entry_Key : Manifest_Key := Manifest_Key_None;
         Entry_Value : Bounded_String := Fields.To_Bounded_String ("");
      begin
         if Raw_Line'Length > Max_Manifest_Line_Length then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            return;
         end if;

         Parse_Manifest_Line
           (Raw_Line => Raw_Line,
            Parsed => Parsed,
            Key => Entry_Key,
            Decoded_Value => Entry_Value,
            Status => Status);
         if Status /= OpenCL.Errors.Success then
            return;
         end if;

         if Parsed then
            if Parsed_Key_Count = Max_Manifest_Key_Count then
               Status := OpenCL.Errors.OCLW_Limit_Exceeded;
               return;
            end if;

            Parsed_Key_Count := Parsed_Key_Count + 1;
            Apply_Manifest_Entry
              (Key => Entry_Key,
               Value => Entry_Value,
               Meta => Meta,
               Seen => Seen,
               Max_RT_Binary_Size => Max_RT_Binary_Size,
               Status => Status);
         end if;
      end Parse_Line_Or_Fail;
   begin
      Meta := (others => <>);
      Status := OpenCL.Errors.Success;

      declare
         Path_Status : constant Status_Code := Validate_Input_File_Path (Path);
      begin
         if Path_Status /= OpenCL.Errors.Success then
            Status := Path_Status;
            return;
         end if;
      end;

      OpenCL.RT.FS.Open_Snapshot
        (Path => Path,
         Snap => Snapshot,
         Status => Status);
      if Status /= OpenCL.Errors.Success then
         return;
      end if;

      OpenCL.RT.FS.Read_All
        (Snap => Snapshot,
         Data => Manifest_Data,
         Used => Manifest_Used,
         Status => Status);
      OpenCL.RT.FS.Close (Snapshot);
      if Status /= OpenCL.Errors.Success then
         return;
      end if;

      if Manifest_Used > Max_Manifest_Bytes then
         Status := OpenCL.Errors.OCLW_Limit_Exceeded;
         return;
      end if;

      if Manifest_Used > 0 then
         declare
            Manifest_Text : String (1 .. Manifest_Used);
         begin
            for I in 0 .. Manifest_Used - 1 loop
               Manifest_Text (I + 1) :=
                 Character'Val (Manifest_Data (Manifest_Data'First + I));
            end loop;

            declare
               Line_Start : Positive := Manifest_Text'First;
            begin
               while Line_Start <= Manifest_Text'Last loop
                  declare
                     LF_Pos : Natural := Line_Start;
                  begin
                     while LF_Pos <= Manifest_Text'Last
                       and then Manifest_Text (LF_Pos) /= Ada.Characters.Latin_1.LF
                     loop
                        LF_Pos := LF_Pos + 1;
                     end loop;

                     declare
                        Line_End : constant Natural :=
                          (if LF_Pos <= Manifest_Text'Last
                           then LF_Pos - 1
                           else Manifest_Text'Last);
                     begin
                        if Line_End < Line_Start then
                           Parse_Line_Or_Fail ("");
                        else
                           declare
                              Raw_Line : constant String :=
                                Manifest_Text (Line_Start .. Line_End);
                           begin
                              if Raw_Line'Length > 0
                                and then Raw_Line (Raw_Line'Last) = Ada.Characters.Latin_1.CR
                              then
                                 if Raw_Line'Length = 1 then
                                    Parse_Line_Or_Fail ("");
                                 else
                                    Parse_Line_Or_Fail
                                      (Raw_Line (Raw_Line'First .. Raw_Line'Last - 1));
                                 end if;
                              else
                                 Parse_Line_Or_Fail (Raw_Line);
                              end if;
                           end;
                        end if;
                     end;

                     if Status /= OpenCL.Errors.Success then
                        return;
                     end if;

                     if LF_Pos > Manifest_Text'Last then
                        exit;
                     end if;

                     Line_Start := LF_Pos + 1;
                  end;
               end loop;
            end;
         end;
      end if;

      if not Required_Fields_Present (Seen) then
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
         return;
      end if;

      if Meta.Signature_Required then
         if not Seen.Signature_Alg
           or else not Seen.Signature_Value
           or else To_String (Meta.Signature_Alg)'Length = 0
           or else To_String (Meta.Signature_Value)'Length = 0
         then
            Status := OpenCL.Errors.OCLW_Pack_Format_Error;
            return;
         end if;
      end if;
   exception
      when Constraint_Error =>
         OpenCL.RT.FS.Close (Snapshot);
         Status := OpenCL.Errors.OCLW_Pack_Format_Error;
      when others =>
         OpenCL.RT.FS.Close (Snapshot);
         Status := OpenCL.Errors.OCLW_IO_Error;
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

      if Meta.Pack_Version_Present then
         Write_Field ("pack_version", U32_Image (Meta.Pack_Version));
         if Status /= OpenCL.Errors.Success then
            SIO.Close (File);
            return;
         end if;
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

      if Meta.Monotonic_Counter_Present then
         Write_Field ("monotonic_counter", U64_Image (Meta.Monotonic_Counter));
         if Status /= OpenCL.Errors.Success then
            SIO.Close (File);
            return;
         end if;
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
      if Meta.Pack_Version_Present then
         if not Append_Field_Line ("pack_version", U32_Image (Meta.Pack_Version)) then
            return "";
         end if;
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
      if Meta.Monotonic_Counter_Present then
         if not Append_Field_Line
             ("monotonic_counter", U64_Image (Meta.Monotonic_Counter))
         then
            return "";
         end if;
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
      Snapshot : OpenCL.RT.FS.File_Snapshot;
      Max_RT_Binary_Size : constant Interfaces.C.size_t :=
        Effective_Max_RT_Binary_Size;
   begin
      Status := OpenCL.Errors.Success;
      Used := 0;

      for I in Buffer'Range loop
         Buffer (I) := 0;
      end loop;

      declare
         Path_Status : constant Status_Code := Validate_Input_File_Path (Path);
      begin
         if Path_Status /= OpenCL.Errors.Success then
            Status := Path_Status;
            return;
         end if;
      end;

      OpenCL.RT.FS.Open_Snapshot
        (Path => Path,
         Snap => Snapshot,
         Status => Status);
      if Status /= OpenCL.Errors.Success then
         return;
      end if;

      OpenCL.RT.FS.Read_All
        (Snap => Snapshot,
         Data => Buffer,
         Used => Used,
         Status => Status);
      OpenCL.RT.FS.Close (Snapshot);
      if Status /= OpenCL.Errors.Success then
         return;
      end if;

      if Interfaces.C.size_t (Used) > Max_RT_Binary_Size then
         Status := OpenCL.Errors.OCLW_Limit_Exceeded;
         return;
      end if;
   exception
      when Constraint_Error =>
         OpenCL.RT.FS.Close (Snapshot);
         Status := OpenCL.Errors.OCLW_IO_Error;
      when others =>
         OpenCL.RT.FS.Close (Snapshot);
         Status := OpenCL.Errors.OCLW_IO_Error;
   end Read_Binary;

   procedure Verify_Binary
     (Meta : Pack_Metadata;
      Buffer : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Status : out Status_Code)
   is
      Calculated : Interfaces.Unsigned_32 := 0;
      Max_RT_Binary_Size : constant Interfaces.C.size_t :=
        Effective_Max_RT_Binary_Size;
   begin
      Status := OpenCL.Errors.Success;

      if Used = 0 or else Used > Buffer'Length then
         Status := OpenCL.Errors.OCLW_Hash_Mismatch;
         return;
      end if;

      if Interfaces.C.size_t (Used) > Max_RT_Binary_Size
        or else Meta.Binary_Size > Max_RT_Binary_Size
      then
         Status := OpenCL.Errors.OCLW_Limit_Exceeded;
         return;
      end if;

      if Meta.Binary_Size /= Interfaces.C.size_t (Used) then
         Status := OpenCL.Errors.OCLW_Hash_Mismatch;
         return;
      end if;

      Calculated := OpenCL.RT.Hash.FNV1a_32 (Data => Buffer, Used => Used);
      if not OpenCL.RT.Constant_Time.Ct_Equal
          (OpenCL.RT.Hash.Hex_Image (Calculated),
           OpenCL.RT.Hash.Hex_Image (Meta.Binary_FNV1a32))
      then
         Status := OpenCL.Errors.OCLW_Hash_Mismatch;
         return;
      end if;
   end Verify_Binary;

end OpenCL.RT.Packs;
