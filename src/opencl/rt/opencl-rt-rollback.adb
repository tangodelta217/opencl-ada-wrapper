with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Bounded;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;
with OpenCL.Errors;

package body OpenCL.RT.Rollback is

   use type Interfaces.Unsigned_64;
   use type OpenCL.Errors.Status_Code;

   package TIO renames Ada.Text_IO;
   package Bounded_Keys is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => 256);
   subtype Bounded_Key is Bounded_Keys.Bounded_String;

   Max_State_Line_Length : constant Positive := 512;
   Max_State_Entries : constant Positive := 256;

   type Entry_Record is record
      Used : Boolean := False;
      Key : Bounded_Key := Bounded_Keys.To_Bounded_String ("");
      Value : Interfaces.Unsigned_64 := 0;
   end record;

   type Entry_Array is array (Positive range <>) of Entry_Record;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Resolve_State_File return String is
   begin
      if not Ada.Environment_Variables.Exists ("OCLW_ROLLBACK_STATE_FILE") then
         return "";
      end if;

      return Trimmed (Ada.Environment_Variables.Value ("OCLW_ROLLBACK_STATE_FILE"));
   exception
      when others =>
         return "";
   end Resolve_State_File;

   function Parse_U64
     (Text : String;
      Value : out Interfaces.Unsigned_64) return Boolean
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
   end Parse_U64;

   function U64_Image (Value : Interfaces.Unsigned_64) return String is
      Raw : constant String := Interfaces.Unsigned_64'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end U64_Image;

   function Key_Valid (Key : String) return Boolean is
   begin
      if Key'Length = 0 or else Key'Length > 256 then
         return False;
      end if;

      for C of Key loop
         if C = '='
           or else C = Ada.Characters.Latin_1.LF
           or else C = Ada.Characters.Latin_1.CR
         then
            return False;
         end if;
      end loop;

      return True;
   end Key_Valid;

   function Load_Entries
     (Path : String;
      Entries : out Entry_Array;
      Used : out Natural) return OpenCL.Errors.Status_Code
   is
      File : TIO.File_Type;
      Line_Buffer : String (1 .. Max_State_Line_Length);
      Last : Natural := 0;
   begin
      for I in Entries'Range loop
         Entries (I) := (others => <>);
      end loop;
      Used := 0;

      if not Ada.Directories.Exists (Path) then
         return OpenCL.Errors.Success;
      end if;

      TIO.Open (File => File, Mode => TIO.In_File, Name => Path);

      while not TIO.End_Of_File (File) loop
         TIO.Get_Line (File, Line_Buffer, Last);

         if Last = Line_Buffer'Last and then not TIO.End_Of_Line (File) then
            TIO.Close (File);
            return OpenCL.Errors.OCLW_IO_Error;
         end if;

         declare
            Raw_Line : constant String :=
              (if Last = 0 then "" else Line_Buffer (1 .. Last));
            Line : constant String := Trimmed (Raw_Line);
         begin
            if Line'Length = 0 then
               null;
            elsif Line (Line'First) = '#' then
               null;
            else
               declare
                  Sep : Natural := 0;
               begin
                  for I in Line'Range loop
                     if Line (I) = '=' then
                        Sep := I;
                        exit;
                     end if;
                  end loop;

                  if Sep = 0 or else Sep = Line'First then
                     TIO.Close (File);
                     return OpenCL.Errors.OCLW_IO_Error;
                  end if;

                  declare
                     Key : constant String := Line (Line'First .. Sep - 1);
                     Value_Text : constant String :=
                       (if Sep < Line'Last then Line (Sep + 1 .. Line'Last) else "");
                     Parsed : Interfaces.Unsigned_64 := 0;
                  begin
                     if not Key_Valid (Key)
                       or else not Parse_U64 (Value_Text, Parsed)
                     then
                        TIO.Close (File);
                        return OpenCL.Errors.OCLW_IO_Error;
                     end if;

                     if Used = Entries'Length then
                        TIO.Close (File);
                        return OpenCL.Errors.OCLW_Limit_Exceeded;
                     end if;

                     Used := Used + 1;
                     Entries (Entries'First + Used - 1).Used := True;
                     Entries (Entries'First + Used - 1).Key :=
                       Bounded_Keys.To_Bounded_String (Key);
                     Entries (Entries'First + Used - 1).Value := Parsed;
                  end;
               end;
            end if;
         end;
      end loop;

      TIO.Close (File);
      return OpenCL.Errors.Success;
   exception
      when TIO.Name_Error
         | TIO.Use_Error
         | TIO.Status_Error
         | TIO.Device_Error
         | TIO.End_Error
         | Constraint_Error =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         return OpenCL.Errors.OCLW_IO_Error;
      when others =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         return OpenCL.Errors.OCLW_IO_Error;
   end Load_Entries;

   function Write_Entries
     (Path : String;
      Entries : Entry_Array;
      Used : Natural) return OpenCL.Errors.Status_Code
   is
      File : TIO.File_Type;
   begin
      if Used > Entries'Length then
         return OpenCL.Errors.OCLW_Limit_Exceeded;
      end if;

      declare
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent'Length > 0 and then not Ada.Directories.Exists (Parent) then
            Ada.Directories.Create_Path (Parent);
         end if;
      exception
         when others =>
            return OpenCL.Errors.OCLW_IO_Error;
      end;

      TIO.Create (File => File, Mode => TIO.Out_File, Name => Path);

      for Pos in 1 .. Used loop
         declare
            Item_Entry : constant Entry_Record :=
              Entries (Entries'First + Pos - 1);
         begin
            if Item_Entry.Used then
               TIO.Put_Line
                 (File => File,
                  Item =>
                    Bounded_Keys.To_String (Item_Entry.Key)
                    & "="
                    & U64_Image (Item_Entry.Value));
            end if;
         end;
      end loop;

      TIO.Close (File);
      return OpenCL.Errors.Success;
   exception
      when TIO.Name_Error
         | TIO.Use_Error
         | TIO.Status_Error
         | TIO.Device_Error
         | Constraint_Error =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         return OpenCL.Errors.OCLW_IO_Error;
      when others =>
         if TIO.Is_Open (File) then
            TIO.Close (File);
         end if;
         return OpenCL.Errors.OCLW_IO_Error;
   end Write_Entries;

   function Get_Last
     (Key : String;
      Value : out Interfaces.Unsigned_64) return OpenCL.Errors.Status_Code
   is
      State_File : constant String := Resolve_State_File;
      Entries : Entry_Array (1 .. Max_State_Entries);
      Used : Natural := 0;
      Status : OpenCL.Errors.Status_Code := OpenCL.Errors.Success;
   begin
      Value := 0;

      if State_File'Length = 0 then
         return OpenCL.Errors.OCLW_Rollback_Not_Implemented;
      end if;

      if not Key_Valid (Key) then
         return OpenCL.Errors.Invalid_Value;
      end if;

      Status := Load_Entries (Path => State_File, Entries => Entries, Used => Used);
      if Status /= OpenCL.Errors.Success then
         return Status;
      end if;

      for Pos in 1 .. Used loop
         declare
            Item_Entry : constant Entry_Record :=
              Entries (Entries'First + Pos - 1);
         begin
            if Item_Entry.Used
              and then Bounded_Keys.To_String (Item_Entry.Key) = Key
            then
               Value := Item_Entry.Value;
            end if;
         end;
      end loop;

      return OpenCL.Errors.Success;
   end Get_Last;

   function Set_Last
     (Key : String;
      Value : Interfaces.Unsigned_64) return OpenCL.Errors.Status_Code
   is
      State_File : constant String := Resolve_State_File;
      Entries : Entry_Array (1 .. Max_State_Entries);
      Used : Natural := 0;
      Status : OpenCL.Errors.Status_Code := OpenCL.Errors.Success;
      Found : Boolean := False;
   begin
      if State_File'Length = 0 then
         return OpenCL.Errors.OCLW_Rollback_Not_Implemented;
      end if;

      if not Key_Valid (Key) then
         return OpenCL.Errors.Invalid_Value;
      end if;

      Status := Load_Entries (Path => State_File, Entries => Entries, Used => Used);
      if Status /= OpenCL.Errors.Success then
         return Status;
      end if;

      for Pos in 1 .. Used loop
         if Entries (Entries'First + Pos - 1).Used
           and then Bounded_Keys.To_String
             (Entries (Entries'First + Pos - 1).Key) = Key
         then
            Entries (Entries'First + Pos - 1).Value := Value;
            Found := True;
         end if;
      end loop;

      if not Found then
         if Used = Entries'Length then
            return OpenCL.Errors.OCLW_Limit_Exceeded;
         end if;

         Used := Used + 1;
         Entries (Entries'First + Used - 1).Used := True;
         Entries (Entries'First + Used - 1).Key :=
           Bounded_Keys.To_Bounded_String (Key);
         Entries (Entries'First + Used - 1).Value := Value;
      end if;

      return Write_Entries (Path => State_File, Entries => Entries, Used => Used);
   end Set_Last;

end OpenCL.RT.Rollback;
