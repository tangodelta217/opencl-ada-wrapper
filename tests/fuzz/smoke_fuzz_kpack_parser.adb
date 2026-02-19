with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;
with Interfaces.C;
with OpenCL.Errors;
with OpenCL.RT.Packs;

procedure Smoke_Fuzz_Kpack_Parser is
   --  OCLW-TST-1501: Deterministic fuzzing for kpack manifest parser.

   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package SIO renames Ada.Streams.Stream_IO;
   package US renames Ada.Strings.Unbounded;

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Ada.Streams.Stream_Element_Offset;
   use type Errors.Status_Code;
   use type Interfaces.Unsigned_32;
   use type SIO.Count;

   Corpus_Dir : constant String := "tests/fuzz/corpus";
   Local_Log_Dir : constant String := "docs/VV/Execution_Logs/local";
   Working_Path : constant String := Local_Log_Dir & "/fuzz_case_current.kpack";

   Default_Seed : constant Interfaces.Unsigned_32 := 1;
   Default_Iterations : constant Positive := 2_000;
   Time_Budget_Ms : constant Natural := 2_000;

   Max_Corpus_Bytes : constant Natural := 16_384;
   Corpus_Count : constant Positive := 10;

   type Corpus_Text_Array is array (Positive range <>) of US.Unbounded_String;

   subtype U32 is Interfaces.Unsigned_32;
   type PRNG_State is new U32;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Trim_Natural_Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Natural_Image;

   function Trim_U32_Image (Value : U32) return String is
      Raw : constant String := U32'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_U32_Image;

   function UTC_Timestamp_Compact return String is
      Raw : constant String :=
        Ada.Calendar.Formatting.Image
          (Date => Ada.Calendar.Clock,
           Include_Time_Fraction => False,
           Time_Zone => 0);
      F : constant Positive := Raw'First;
   begin
      if Raw'Length >= 19 then
         return
           Raw (F .. F + 3)
           & Raw (F + 5 .. F + 6)
           & Raw (F + 8 .. F + 9)
           & "T"
           & Raw (F + 11 .. F + 12)
           & Raw (F + 14 .. F + 15)
           & Raw (F + 17 .. F + 18)
           & "Z";
      else
         return "00000000T000000Z";
      end if;
   end UTC_Timestamp_Compact;

   function Parse_Natural_Env
     (Name : String;
      Default : Natural) return Natural
   is
      Acc : Natural := 0;
   begin
      if not Ada.Environment_Variables.Exists (Name) then
         return Default;
      end if;

      declare
         Raw : constant String :=
           Ada.Strings.Fixed.Trim
             (Ada.Environment_Variables.Value (Name),
              Ada.Strings.Both);
      begin
         if Raw'Length = 0 then
            return Default;
         end if;

         for C of Raw loop
            if C < '0' or else C > '9' then
               return Default;
            end if;

            declare
               Digit : constant Natural := Character'Pos (C) - Character'Pos ('0');
            begin
               if Acc > (Natural'Last - Digit) / 10 then
                  return Default;
               end if;
               Acc := Acc * 10 + Digit;
            end;
         end loop;
      end;

      return Acc;
   end Parse_Natural_Env;

   function Parse_U32_Env
     (Name : String;
      Default : U32) return U32
   is
      Acc : U32 := 0;
   begin
      if not Ada.Environment_Variables.Exists (Name) then
         return Default;
      end if;

      declare
         Raw : constant String :=
           Ada.Strings.Fixed.Trim
             (Ada.Environment_Variables.Value (Name),
              Ada.Strings.Both);
      begin
         if Raw'Length = 0 then
            return Default;
         end if;

         for C of Raw loop
            if C < '0' or else C > '9' then
               return Default;
            end if;

            declare
               Digit : constant U32 := U32 (Character'Pos (C) - Character'Pos ('0'));
            begin
               if Acc > (U32'Last - Digit) / 10 then
                  return Default;
               end if;
               Acc := Acc * 10 + Digit;
            end;
         end loop;
      end;

      return Acc;
   end Parse_U32_Env;

   procedure Seed_PRNG (State : out PRNG_State; Seed : U32) is
   begin
      if Seed = 0 then
         State := PRNG_State (1);
      else
         State := PRNG_State (Seed);
      end if;
   end Seed_PRNG;

   function Next_U32 (State : in out PRNG_State) return U32 is
      Next : constant U32 :=
        U32 (State) * U32 (1_664_525) + U32 (1_013_904_223);
   begin
      State := PRNG_State (Next);
      return Next;
   end Next_U32;

   function Next_Bounded
     (State : in out PRNG_State;
      Upper_Exclusive : Positive) return Natural
   is
   begin
      return Natural (Next_U32 (State) mod U32 (Upper_Exclusive));
   end Next_Bounded;

   function Corpus_File_Name (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "01_empty.kpack";
         when 2 =>
            return "02_no_equals.kpack";
         when 3 =>
            return "03_duplicate_keys.kpack";
         when 4 =>
            return "04_huge_value.kpack";
         when 5 =>
            return "05_invalid_chars.kpack";
         when 6 =>
            return "06_truncated_escape.kpack";
         when 7 =>
            return "07_signature_malformed.kpack";
         when 8 =>
            return "08_binary_hash_malformed.kpack";
         when 9 =>
            return "09_rollback_inconsistent.kpack";
         when 10 =>
            return "10_unknown_key.kpack";
         when others =>
            return "";
      end case;
   end Corpus_File_Name;

   function Required_Key (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "kpack_version";
         when 2 =>
            return "pack_id";
         when 3 =>
            return "created_utc";
         when 4 =>
            return "platform_name";
         when 5 =>
            return "platform_vendor";
         when 6 =>
            return "platform_version";
         when 7 =>
            return "device_name";
         when 8 =>
            return "device_vendor";
         when 9 =>
            return "device_version";
         when 10 =>
            return "driver_version";
         when 11 =>
            return "binary_size";
         when 12 =>
            return "binary_fnv1a32";
         when 13 =>
            return "kernel_name";
         when others =>
            return "";
      end case;
   end Required_Key;

   function Has_Minimum_Required_Keys (Input : String) return Boolean is
      Lowered : String := Input;
   begin
      for I in Lowered'Range loop
         Lowered (I) := Ada.Characters.Handling.To_Lower (Lowered (I));
      end loop;

      for K in 1 .. 13 loop
         if Ada.Strings.Fixed.Index (Lowered, Required_Key (K) & "=") = 0 then
            return False;
         end if;
      end loop;

      return True;
   end Has_Minimum_Required_Keys;

   procedure Read_File_As_String
     (Path : String;
      Text : out US.Unbounded_String;
      Ok : out Boolean)
   is
      File : SIO.File_Type;
      File_Size : SIO.Count := 0;
   begin
      Text := US.Null_Unbounded_String;
      Ok := False;

      if not Ada.Directories.Exists (Path) then
         return;
      end if;

      SIO.Open (File => File, Mode => SIO.In_File, Name => Path);
      File_Size := SIO.Size (File);

      if File_Size = 0 then
         SIO.Close (File);
         Ok := True;
         return;
      end if;

      if File_Size > SIO.Count (Max_Corpus_Bytes) then
         SIO.Close (File);
         return;
      end if;

      declare
         Raw : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (File_Size));
         Last : Ada.Streams.Stream_Element_Offset := 0;
      begin
         SIO.Read (File => File, Item => Raw, Last => Last);
         SIO.Close (File);

         if Last = 0 then
            Text := US.Null_Unbounded_String;
            Ok := True;
            return;
         end if;

         declare
            Buffer : String (1 .. Natural (Last));
         begin
            for I in Buffer'Range loop
               Buffer (I) :=
                 Character'Val
                   (Integer
                      (Raw
                         (Raw'First
                          + Ada.Streams.Stream_Element_Offset (I - Buffer'First))));
            end loop;
            Text := US.To_Unbounded_String (Buffer);
            Ok := True;
         end;
      end;
   exception
      when SIO.Name_Error
         | SIO.Use_Error
         | SIO.Status_Error
         | SIO.Device_Error
         | Constraint_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Text := US.Null_Unbounded_String;
         Ok := False;
      when others =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Text := US.Null_Unbounded_String;
         Ok := False;
   end Read_File_As_String;

   procedure Write_String_As_File
     (Path : String;
      Text : String;
      Ok : out Boolean)
   is
      File : SIO.File_Type;
   begin
      Ok := False;
      SIO.Create (File => File, Mode => SIO.Out_File, Name => Path);

      if Text'Length > 0 then
         declare
            Raw : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
         begin
            for I in Text'Range loop
               Raw
                 (Raw'First + Ada.Streams.Stream_Element_Offset (I - Text'First)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Text (I)));
            end loop;
            SIO.Write (File => File, Item => Raw);
         end;
      end if;

      SIO.Close (File);
      Ok := True;
   exception
      when SIO.Name_Error
         | SIO.Use_Error
         | SIO.Status_Error
         | SIO.Device_Error
         | Constraint_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Ok := False;
      when others =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Ok := False;
   end Write_String_As_File;

   function Fuzz_Char (Selector : Natural) return Character is
   begin
      case Selector is
         when 0 =>
            return '=';
         when 1 =>
            return '#';
         when 2 =>
            return '\';
         when 3 =>
            return Ada.Characters.Latin_1.LF;
         when 4 =>
            return ' ';
         when 5 =>
            return 'A';
         when 6 =>
            return '0';
         when 7 =>
            return '/';
         when 8 =>
            return Ada.Characters.Latin_1.HT;
         when others =>
            return Character'Val (16#7F#);
      end case;
   end Fuzz_Char;

   function Shuffle_Lines
     (Input : String;
      State : in out PRNG_State) return String
   is
      Max_Lines : constant Positive := 128;
      type Line_Array is
        array (Positive range 1 .. Max_Lines) of US.Unbounded_String;
      Lines : Line_Array := (others => US.Null_Unbounded_String);
      Count : Natural := 0;
      Start : Natural := 0;
      Result : US.Unbounded_String := US.Null_Unbounded_String;
   begin
      if Input'Length = 0 then
         return Input;
      end if;

      Start := Input'First;
      for I in Input'Range loop
         if Input (I) = Ada.Characters.Latin_1.LF then
            if Count = Max_Lines then
               return Input;
            end if;

            Count := Count + 1;
            Lines (Count) := US.To_Unbounded_String (Input (Start .. I));
            Start := I + 1;
         end if;
      end loop;

      if Start <= Input'Last then
         if Count = Max_Lines then
            return Input;
         end if;

         Count := Count + 1;
         Lines (Count) := US.To_Unbounded_String (Input (Start .. Input'Last));
      end if;

      if Count < 2 then
         return Input;
      end if;

      declare
         Shift : constant Positive := 1 + Next_Bounded (State, Count - 1);
      begin
         for I in 1 .. Count loop
            declare
               Source : constant Positive := ((I + Shift - 1) mod Count) + 1;
            begin
               US.Append (Result, US.To_String (Lines (Source)));
            end;
         end loop;
      end;

      return US.To_String (Result);
   end Shuffle_Lines;

   function Mutate
     (Input : String;
      State : in out PRNG_State) return String
   is
      Current : US.Unbounded_String := US.To_Unbounded_String (Input);
      Operation_Count : constant Positive := 1 + Next_Bounded (State, 3);
   begin
      for Op in 1 .. Operation_Count loop
         declare
            S : constant String := US.To_String (Current);
            L : constant Natural := S'Length;
            Choice : constant Natural := Next_Bounded (State, 4);
         begin
            case Choice is
               when 0 =>
                  if L = 0 then
                     Current := US.To_Unbounded_String (String'(1 => Fuzz_Char (0)));
                  else
                     declare
                        Offset : constant Natural := Next_Bounded (State, L);
                        Pos : constant Positive := S'First + Integer (Offset);
                        Bit : constant Natural := Next_Bounded (State, 8);
                        Byte : U32 := U32 (Character'Pos (S (Pos)));
                        Mutated : String := S;
                     begin
                        Byte := Byte xor U32 (2 ** Bit);
                        Mutated (Pos) := Character'Val (Integer (Byte mod 256));
                        Current := US.To_Unbounded_String (Mutated);
                     end;
                  end if;
               when 1 =>
                  if L > 0 then
                     declare
                        Offset : constant Natural := Next_Bounded (State, L);
                        Pos : constant Positive := S'First + Integer (Offset);
                     begin
                        if L = 1 then
                           Current := US.Null_Unbounded_String;
                        elsif Pos = S'First then
                           Current := US.To_Unbounded_String (S (S'First + 1 .. S'Last));
                        elsif Pos = S'Last then
                           Current := US.To_Unbounded_String (S (S'First .. S'Last - 1));
                        else
                           Current :=
                             US.To_Unbounded_String
                               (S (S'First .. Pos - 1) & S (Pos + 1 .. S'Last));
                        end if;
                     end;
                  end if;
               when 2 =>
                  declare
                     Insert_At : constant Natural := Next_Bounded (State, L + 1);
                     C : constant Character := Fuzz_Char (Next_Bounded (State, 10));
                  begin
                     if L = 0 then
                        Current := US.To_Unbounded_String (String'(1 => C));
                     elsif Insert_At = 0 then
                        Current := US.To_Unbounded_String (String'(1 => C) & S);
                     elsif Insert_At = L then
                        Current := US.To_Unbounded_String (S & String'(1 => C));
                     else
                        declare
                           Split : constant Positive := S'First + Integer (Insert_At) - 1;
                        begin
                           Current :=
                             US.To_Unbounded_String
                               (S (S'First .. Split)
                                & String'(1 => C)
                                & S (Split + 1 .. S'Last));
                        end;
                     end if;
                  end;
               when others =>
                  Current := US.To_Unbounded_String (Shuffle_Lines (S, State));
            end case;
         end;
      end loop;

      return US.To_String (Current);
   end Mutate;

   function Save_Artifact
     (Input : String;
      Iteration : Natural) return String
   is
      Path : constant String :=
        Local_Log_Dir
        & "/fuzz_fail_"
        & UTC_Timestamp_Compact
        & "_"
        & Trim_Natural_Image (Iteration)
        & ".bin";
      Ok : Boolean := False;
   begin
      Write_String_As_File (Path => Path, Text => Input, Ok => Ok);
      if Ok then
         return Path;
      else
         return "<artifact_save_failed>";
      end if;
   end Save_Artifact;

   procedure Cleanup_Working_File is
   begin
      if Ada.Directories.Exists (Working_Path) then
         Ada.Directories.Delete_File (Working_Path);
      end if;
   exception
      when others =>
         null;
   end Cleanup_Working_File;

   Corpus_Texts : Corpus_Text_Array (1 .. Corpus_Count) :=
     (others => US.Null_Unbounded_String);
   Corpus_Loaded : Natural := 0;

   Seed_Value : U32 := Default_Seed;
   Requested_Iterations : Positive := Default_Iterations;
   Executed_Iterations : Natural := 0;

   Failure_Count : Natural := 0;
   Crash_Count : Natural := 0;
   Saved_Artifact_Path : US.Unbounded_String := US.To_Unbounded_String ("<none>");

   RNG : PRNG_State := PRNG_State (1);
begin
   Ada.Directories.Create_Path (Local_Log_Dir);

   declare
      Parsed_Seed : constant U32 :=
        Parse_U32_Env ("OCLW_FUZZ_SEED", Default_Seed);
      Parsed_Iters : constant Natural :=
        Parse_Natural_Env ("OCLW_FUZZ_ITERS", Default_Iterations);
   begin
      Seed_Value := Parsed_Seed;

      if Parsed_Iters > 0 and then Parsed_Iters <= Positive'Last then
         Requested_Iterations := Positive (Parsed_Iters);
      else
         Requested_Iterations := Default_Iterations;
      end if;
   end;

   Seed_PRNG (State => RNG, Seed => Seed_Value);

   for I in Corpus_Texts'Range loop
      declare
         Path : constant String := Corpus_Dir & "/" & Corpus_File_Name (I);
         Text : US.Unbounded_String := US.Null_Unbounded_String;
         Ok : Boolean := False;
      begin
         Read_File_As_String
           (Path => Path,
            Text => Text,
            Ok => Ok);

         if Ok then
            Corpus_Texts (I) := Text;
            Corpus_Loaded := Corpus_Loaded + 1;
         else
            Ada.Text_IO.Put_Line ("WARN corpus_read_failed=" & Path);
         end if;
      end;
   end loop;

   if Corpus_Loaded = 0 then
      Ada.Text_IO.Put_Line ("INFO iters=0");
      Ada.Text_IO.Put_Line ("INFO seed=" & Trim_U32_Image (Seed_Value));
      Ada.Text_IO.Put_Line ("INFO corpus_cases=0");
      Ada.Text_IO.Put_Line ("INFO failures=1");
      Ada.Text_IO.Put_Line ("INFO crashes=0");
      Ada.Text_IO.Put_Line ("INFO saved_artifact=<none>");
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Cleanup_Working_File;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Budget : constant Ada.Real_Time.Time_Span :=
        Ada.Real_Time.Milliseconds (Integer (Time_Budget_Ms));
      Start_Time : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Parser_Status : Errors.Status_Code := Errors.Success;
      Meta : Packs.Pack_Metadata;
      Current_Input : US.Unbounded_String := US.Null_Unbounded_String;
      Write_Ok : Boolean := False;
   begin
      for Iter in 1 .. Requested_Iterations loop
         exit when Ada.Real_Time.Clock - Start_Time >= Budget;

         Executed_Iterations := Executed_Iterations + 1;

         begin
            declare
               Base_Index : constant Positive :=
                 Positive (1 + Next_Bounded (RNG, Corpus_Loaded));
            begin
               Current_Input :=
                 US.To_Unbounded_String
                   (Mutate (US.To_String (Corpus_Texts (Base_Index)), RNG));
            end;

            Write_String_As_File
              (Path => Working_Path,
               Text => US.To_String (Current_Input),
               Ok => Write_Ok);

            if not Write_Ok then
               Failure_Count := Failure_Count + 1;
               if US.To_String (Saved_Artifact_Path) = "<none>" then
                  Saved_Artifact_Path :=
                    US.To_Unbounded_String
                      (Save_Artifact (US.To_String (Current_Input), Iter));
               end if;
            else
               Packs.Read_Manifest
                 (Path => Working_Path,
                  Meta => Meta,
                  Status => Parser_Status);

               if Parser_Status = Errors.Success
                 and then not Has_Minimum_Required_Keys (US.To_String (Current_Input))
               then
                  Failure_Count := Failure_Count + 1;
                  if US.To_String (Saved_Artifact_Path) = "<none>" then
                     Saved_Artifact_Path :=
                       US.To_Unbounded_String
                         (Save_Artifact (US.To_String (Current_Input), Iter));
                  end if;
               end if;
            end if;
         exception
            when others =>
               Crash_Count := Crash_Count + 1;
               if US.To_String (Saved_Artifact_Path) = "<none>" then
                  Saved_Artifact_Path :=
                    US.To_Unbounded_String
                      (Save_Artifact (US.To_String (Current_Input), Iter));
               end if;
         end;
      end loop;
   end;

   if Corpus_Loaded /= Corpus_Count then
      Failure_Count := Failure_Count + (Corpus_Count - Corpus_Loaded);
   end if;

   Ada.Text_IO.Put_Line
     ("INFO iters=" & Trim_Natural_Image (Executed_Iterations));
   Ada.Text_IO.Put_Line
     ("INFO seed=" & Trim_U32_Image (Seed_Value));
   Ada.Text_IO.Put_Line
     ("INFO corpus_cases=" & Trim_Natural_Image (Corpus_Loaded));
   Ada.Text_IO.Put_Line
     ("INFO failures=" & Trim_Natural_Image (Failure_Count));
   Ada.Text_IO.Put_Line
     ("INFO crashes=" & Trim_Natural_Image (Crash_Count));
   Ada.Text_IO.Put_Line
     ("INFO saved_artifact=" & US.To_String (Saved_Artifact_Path));

   if Failure_Count = 0 and then Crash_Count = 0 then
      Ada.Text_IO.Put_Line ("RESULT=PASS");
   else
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Cleanup_Working_File;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Cleanup_Working_File;
exception
   when others =>
      Cleanup_Working_File;
      Ada.Text_IO.Put_Line
        ("ERROR unexpected_failure="
         & Errors.Image (Errors.OCLW_IO_Error)
         & " status_int="
         & Trim_Int_Image (Interfaces.C.int (Errors.OCLW_IO_Error)));
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Smoke_Fuzz_Kpack_Parser;
