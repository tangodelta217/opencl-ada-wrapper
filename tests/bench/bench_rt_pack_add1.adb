with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Events;
with OpenCL.Core.Kernels;
with OpenCL.Core.Profiling;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.Raw.API;
with OpenCL.RT.Loader;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;
with Smoke_RT_Test_Verifier;

procedure Bench_RT_Pack_Add1 is
   package API renames OpenCL.Raw.API;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Events renames OpenCL.Core.Events;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Packs renames OpenCL.RT.Packs;
   package Profiling renames OpenCL.Core.Profiling;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package Security renames OpenCL.RT.Security;

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;

   Transfer_Bytes : constant Interfaces.C.size_t := 4096;

   Default_Warmup : constant Positive := 10;
   Default_Iterations : constant Positive := 200;

   Local_Log_Dir : constant String := "docs/VV/Execution_Logs/local";
   Default_Pack_Dir_Prefix : constant String := Local_Log_Dir & "/";

   Plugin_Symbol : constant String := "oclw_kpack_verify_v1";
   Plugin_SO_Rel : constant String :=
     "tools/crypto_provider_ref/liboclw_crypto_provider_ref.so";

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   subtype Byte is Interfaces.Unsigned_8;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Host_Byte_Array is array (Byte_Index) of aliased Byte;

   type Sample_Array is array (Positive range <>) of Interfaces.Unsigned_64;
   type Sample_Array_Access is access all Sample_Array;
   procedure Free_Sample_Array is new Ada.Unchecked_Deallocation
     (Object => Sample_Array,
      Name => Sample_Array_Access);

   type Metric_Summary is record
      P50 : Interfaces.Unsigned_64 := 0;
      P95 : Interfaces.Unsigned_64 := 0;
      P99 : Interfaces.Unsigned_64 := 0;
   end record;

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

   function Trim_U64_Image (Value : Interfaces.Unsigned_64) return String is
      Raw : constant String := Interfaces.Unsigned_64'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_U64_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function To_Nanoseconds (Span : Ada.Real_Time.Time_Span)
      return Interfaces.Unsigned_64
   is
      Seconds : constant Long_Long_Float :=
        Long_Long_Float (Ada.Real_Time.To_Duration (Span));
      Value : constant Long_Long_Float := Seconds * 1_000_000_000.0;
   begin
      if Value <= 0.0 then
         return 0;
      end if;

      return Interfaces.Unsigned_64 (Long_Long_Integer (Value));
   end To_Nanoseconds;

   function Percentile_Index
     (Count : Positive;
      Numerator : Positive;
      Denominator : Positive) return Positive
   is
   begin
      return Positive ((Count * Numerator + Denominator - 1) / Denominator);
   end Percentile_Index;

   function Summarize (Samples : Sample_Array) return Metric_Summary is
      Sorted : Sample_Array := Samples;
   begin
      for I in Sorted'First + 1 .. Sorted'Last loop
         declare
            Key : constant Interfaces.Unsigned_64 := Sorted (I);
            J : Positive := I;
         begin
            while J > Sorted'First and then Sorted (J - 1) > Key loop
               Sorted (J) := Sorted (J - 1);
               J := J - 1;
            end loop;
            Sorted (J) := Key;
         end;
      end loop;

      return
        (P50 => Sorted (Percentile_Index (Sorted'Length, 50, 100)),
         P95 => Sorted (Percentile_Index (Sorted'Length, 95, 100)),
         P99 => Sorted (Percentile_Index (Sorted'Length, 99, 100)));
   end Summarize;

   function Parse_Positive_Env
     (Name : String;
      Default : Positive) return Positive
   is
      Acc : Natural := 0;
   begin
      if not Ada.Environment_Variables.Exists (Name) then
         return Default;
      end if;

      declare
         Raw : constant String :=
           Ada.Strings.Fixed.Trim
             (Ada.Environment_Variables.Value (Name), Ada.Strings.Both);
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

      if Acc = 0 or else Acc > Positive'Last then
         return Default;
      end if;

      return Positive (Acc);
   end Parse_Positive_Env;

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

   function Resolve_Pack_Dir (Timestamp_Compact : String) return String is
   begin
      if Ada.Environment_Variables.Exists ("OCLW_PACK_DIR") then
         declare
            Value : constant String :=
              Ada.Strings.Fixed.Trim
                (Ada.Environment_Variables.Value ("OCLW_PACK_DIR"),
                 Ada.Strings.Both);
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return Default_Pack_Dir_Prefix & Timestamp_Compact & "_bench_rt_pack";
   end Resolve_Pack_Dir;

   function Resolve_CSV_Path (Timestamp_Compact : String) return String is
   begin
      return Local_Log_Dir & "/" & Timestamp_Compact & "_bench_rt_pack_add1.csv";
   end Resolve_CSV_Path;

   function Candidate_From_Self (Relative_Path : String) return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Parent_1 : constant String := Ada.Directories.Containing_Directory (Self_Dir);
      Parent_2 : constant String := Ada.Directories.Containing_Directory (Parent_1);
   begin
      if Parent_2'Length = 0 then
         return Relative_Path;
      else
         return Parent_2 & "/" & Relative_Path;
      end if;
   exception
      when others =>
         return Relative_Path;
   end Candidate_From_Self;

   function Locate_Path (Relative_Path : String) return String is
      Candidate_1 : constant String := Relative_Path;
      Candidate_2 : constant String := Candidate_From_Self (Relative_Path);
   begin
      if Ada.Directories.Exists (Candidate_1) then
         return Candidate_1;
      elsif Ada.Directories.Exists (Candidate_2) then
         return Candidate_2;
      else
         return Relative_Path;
      end if;
   end Locate_Path;

   function Locate_Gen_Pack_Add1 return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Candidate_1 : constant String := Self_Dir & "/gen_pack_add1";
      Candidate_2 : constant String := "tests/bin/gen_pack_add1";
      Candidate_3 : constant String := Candidate_From_Self ("tests/bin/gen_pack_add1");
   begin
      if Ada.Directories.Exists (Candidate_1) then
         return Candidate_1;
      elsif Ada.Directories.Exists (Candidate_2) then
         return Candidate_2;
      elsif Ada.Directories.Exists (Candidate_3) then
         return Candidate_3;
      else
         return "";
      end if;
   end Locate_Gen_Pack_Add1;

   function Resolve_Plugin_Path return String is
   begin
      if Ada.Environment_Variables.Exists ("OCLW_CRYPTO_PLUGIN") then
         declare
            Candidate : constant String :=
              Ada.Strings.Fixed.Trim
                (Ada.Environment_Variables.Value ("OCLW_CRYPTO_PLUGIN"),
                 Ada.Strings.Both);
         begin
            if Candidate'Length > 0 then
               if Ada.Directories.Exists (Candidate) then
                  return Ada.Directories.Full_Name (Candidate);
               else
                  return Candidate;
               end if;
            end if;
         end;
      end if;

      declare
         Candidate : constant String := Locate_Path (Plugin_SO_Rel);
      begin
         if Candidate'Length > 0 and then Ada.Directories.Exists (Candidate) then
            return Ada.Directories.Full_Name (Candidate);
         end if;
      end;

      return "";
   end Resolve_Plugin_Path;

   function Ensure_Base_Pack
     (Pack_Dir : String;
      Manifest_Path : String;
      Binary_Path : String;
      Gen_Log_Path : String) return Boolean
   is
      Gen_Exec : constant String := Locate_Gen_Pack_Add1;
      Args : GNAT.OS_Lib.Argument_List (1 .. 1);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      if Gen_Exec'Length = 0 then
         Ada.Text_IO.Put_Line ("ERROR missing_gen_pack_add1_executable");
         return False;
      end if;

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      Ada.Environment_Variables.Set ("OCLW_PACK_DIR", Pack_Dir);
      Args (1) := new String'("");
      GNAT.OS_Lib.Spawn
        (Program_Name => Gen_Exec,
         Args => Args,
         Output_File => Gen_Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));

      Ada.Text_IO.Put_Line
        ("INFO gen_pack_add1_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Gen_Log_Path);

      return
        Success
        and then Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Ensure_Base_Pack;

   procedure Prepare_Offline_Signed_Pack
     (Manifest_Path : String;
      Binary_Path : String;
      Status : out Errors.Status_Code)
   is
      Meta : Packs.Pack_Metadata;
      Binary_Data : Program_Byte_Array_Access := null;
      Binary_Used : Natural := 0;
   begin
      Status := Errors.Success;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if Status /= Errors.Success then
         return;
      end if;

      if Meta.Binary_Size = 0
        or else Meta.Binary_Size > Interfaces.C.size_t (Positive'Last)
      then
         Status := Errors.OCLW_Pack_Format_Error;
         return;
      end if;

      Binary_Data :=
        new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));

      Packs.Read_Binary
        (Path => Binary_Path,
         Buffer => Binary_Data.all,
         Used => Binary_Used,
         Status => Status);
      if Status /= Errors.Success then
         Free_Program_Byte_Array (Binary_Data);
         return;
      end if;

      if Binary_Used = 0 then
         Status := Errors.OCLW_Pack_Format_Error;
         Free_Program_Byte_Array (Binary_Data);
         return;
      end if;

      Meta.Signature_Required := True;
      Meta.Signature_Alg := Packs.To_Bounded ("CMS-PKCS7-SHA256");
      Meta.Signer_Id := Packs.To_Bounded ("OCLW-BENCH-RT-PACK");
      Meta.Signature_Value := Packs.To_Bounded ("");

      declare
         Signing_Text : constant String := Packs.Canonical_Signing_Text (Meta);
         Signature : constant String :=
           Smoke_RT_Test_Verifier.Compute_Test_Signature
             (Signing_Text => Signing_Text,
              Bin => Binary_Data.all,
              Used => Binary_Used);
      begin
         if Signing_Text'Length = 0 then
            Status := Errors.OCLW_Pack_Format_Error;
            Free_Program_Byte_Array (Binary_Data);
            return;
         end if;

         if Signature'Length = 0 then
            Status := Errors.OCLW_Signature_Invalid;
            Free_Program_Byte_Array (Binary_Data);
            return;
         end if;

         Meta.Signature_Value := Packs.To_Bounded (Signature);
      end;

      Packs.Write_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);

      Free_Program_Byte_Array (Binary_Data);
   exception
      when others =>
         if Binary_Data /= null then
            Free_Program_Byte_Array (Binary_Data);
         end if;
         Status := Errors.OCLW_IO_Error;
   end Prepare_Offline_Signed_Pack;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;

   Status : Errors.Status_Code := Errors.Success;
   Profile_Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;

   Platform : Core.Platform;
   Device : Core.Device;
   Ctx : Contexts.Context;
   Q : Queues.Queue;
   In_Buffer : Buffers.Buffer;
   Out_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Input_Data : Host_Byte_Array := (others => 0);
   Output_Data : Host_Byte_Array := (others => 0);

   Binary_Data : Program_Byte_Array_Access := null;
   Binary_Used : Natural := 0;
   Meta_RT : Packs.Pack_Metadata;

   Host_Samples : Sample_Array_Access := null;
   Device_Samples : Sample_Array_Access := null;

   Profiling_Enabled : Boolean := False;
   Profiling_Metrics_Available : Boolean := False;
   Profiling_Announced : Boolean := False;

   CSV_File : Ada.Text_IO.File_Type;
   CSV_Open : Boolean := False;

   procedure Mark_Fail (Step : String; Code : Errors.Status_Code) is
   begin
      Ada.Text_IO.Put_Line
        ("ERROR "
         & Step
         & ": "
         & Errors.Image (Code)
         & " status_int="
         & Status_Int_Image (Code));
      Failed := True;
   end Mark_Fail;

   procedure Release_Event_Safe (Ev : in out Events.Event) is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Events.Release (Ev => Ev, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_event: "
            & Errors.Image (Release_Status)
            & " status_int="
            & Status_Int_Image (Release_Status));
      end if;
   end Release_Event_Safe;

   procedure Cleanup is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      if CSV_Open and then Ada.Text_IO.Is_Open (CSV_File) then
         Ada.Text_IO.Close (CSV_File);
         CSV_Open := False;
      end if;

      Kernels.Release (K => K, Status => Release_Status);
      Buffers.Release (B => Out_Buffer, Status => Release_Status);
      Buffers.Release (B => In_Buffer, Status => Release_Status);
      Programs.Release (Prg => Prg, Status => Release_Status);
      Queues.Release (Q => Q, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;

      if Host_Samples /= null then
         Free_Sample_Array (Host_Samples);
      end if;

      if Device_Samples /= null then
         Free_Sample_Array (Device_Samples);
      end if;
   end Cleanup;

begin
   declare
      Timestamp_Compact : constant String := UTC_Timestamp_Compact;
      Warmup : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_WARMUP", Default_Warmup);
      Iterations : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_ITERS", Default_Iterations);
      Pack_Dir : constant String := Resolve_Pack_Dir (Timestamp_Compact);
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      CSV_Path : constant String := Resolve_CSV_Path (Timestamp_Compact);
      Plugin_Path : constant String := Resolve_Plugin_Path;
      Gen_Log_Path : constant String := Pack_Dir & "/bench_gen_pack_add1.log";

      Init_Start : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Init_End : Ada.Real_Time.Time := Init_Start;
      Init_Ns : Interfaces.Unsigned_64 := 0;
      Verify_Start : Ada.Real_Time.Time := Init_Start;
      Verify_End : Ada.Real_Time.Time := Init_Start;
      Verify_Ns : Interfaces.Unsigned_64 := 0;
      Create_Ctx_Start : Ada.Real_Time.Time := Init_Start;
      Create_Ctx_End : Ada.Real_Time.Time := Init_Start;
      Create_Ctx_Ns : Interfaces.Unsigned_64 := 0;
      Create_Prog_Start : Ada.Real_Time.Time := Init_Start;
      Create_Prog_End : Ada.Real_Time.Time := Init_Start;
      Create_Prog_Ns : Interfaces.Unsigned_64 := 0;
      Build_Start : Ada.Real_Time.Time := Init_Start;
      Build_End : Ada.Real_Time.Time := Init_Start;
      Build_Ns : Interfaces.Unsigned_64 := 0;
      Kernel_Setup_Start : Ada.Real_Time.Time := Init_Start;
      Kernel_Setup_End : Ada.Real_Time.Time := Init_Start;
      Kernel_Setup_Ns : Interfaces.Unsigned_64 := 0;

      Host_Summary : Metric_Summary := (others => 0);
      Device_Summary : Metric_Summary := (others => 0);
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line
        ("INFO warmup="
         & Trim_Natural_Image (Warmup)
         & " iterations="
         & Trim_Natural_Image (Iterations));

      Core.Enumerate_Platforms
        (Out_Platforms => Platforms,
         Used => Platform_Used,
         Status => Status);
      if Platform_Used = 0 then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=" & Errors.Image (Status));
         return;
      end if;

      Core.Enumerate_Devices
        (P => Platforms (Platforms'First),
         Out_Devices => Devices,
         Used => Device_Used,
         Status => Status);
      if Device_Used = 0 then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=" & Errors.Image (Status));
         return;
      end if;

      if Plugin_Path'Length = 0 then
         Ada.Text_IO.Put_Line ("INFO plugin_path=<unset>");
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=plugin_not_found");
         return;
      end if;

      Ada.Text_IO.Put_Line ("INFO plugin_path=" & Plugin_Path);
      Ada.Environment_Variables.Set
        (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
         Value => Ada.Directories.Containing_Directory (Plugin_Path));

      Security.Install_Verifier (V => null);
      Security.Configure_Plugin
        (Path => Plugin_Path,
         Symbol => Plugin_Symbol,
         Status => Status);
      if Status /= Errors.Success then
         Mark_Fail ("configure_plugin", Status);
      end if;

      if not Failed then
         if not Ada.Directories.Exists (Pack_Dir) then
            Ada.Directories.Create_Path (Pack_Dir);
         end if;

         if not Ensure_Base_Pack
                  (Pack_Dir => Pack_Dir,
                   Manifest_Path => Manifest_Path,
                   Binary_Path => Binary_Path,
                   Gen_Log_Path => Gen_Log_Path)
         then
            Mark_Fail ("offline_pack_generation", Errors.OCLW_IO_Error);
         end if;
      end if;

      if not Failed then
         Prepare_Offline_Signed_Pack
           (Manifest_Path => Manifest_Path,
            Binary_Path => Binary_Path,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("offline_pack_sign", Status);
         else
            Ada.Text_IO.Put_Line ("INFO offline_pack_generated=1");
         end if;
      end if;

      if not Failed then
         Host_Samples := new Sample_Array (1 .. Iterations);
         Device_Samples := new Sample_Array (1 .. Iterations);
         Host_Samples.all := (others => 0);
         Device_Samples.all := (others => 0);

         Ada.Directories.Create_Path (Local_Log_Dir);
         Ada.Text_IO.Create (CSV_File, Ada.Text_IO.Out_File, CSV_Path);
         CSV_Open := True;
         Ada.Text_IO.Put_Line (CSV_File, "iter,host_ns,dev_ns");

         Init_Start := Ada.Real_Time.Clock;
         Verify_Start := Init_Start;

         Packs.Read_Manifest
           (Path => Manifest_Path,
            Meta => Meta_RT,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("read_manifest", Status);
         end if;

         if not Failed then
            if Meta_RT.Binary_Size = 0
              or else Meta_RT.Binary_Size > Interfaces.C.size_t (Positive'Last)
            then
               Mark_Fail ("manifest_binary_size", Errors.OCLW_Pack_Format_Error);
            end if;
         end if;

         if not Failed then
            Binary_Data :=
              new Programs.Byte_Array (1 .. Positive (Integer (Meta_RT.Binary_Size)));

            Packs.Read_Binary
              (Path => Binary_Path,
               Buffer => Binary_Data.all,
               Used => Binary_Used,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("read_binary", Status);
            end if;
         end if;

         if not Failed then
            Packs.Verify_Binary
              (Meta => Meta_RT,
               Buffer => Binary_Data.all,
               Used => Binary_Used,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("verify_binary", Status);
            end if;
         end if;

         if not Failed then
            Loader.Select_Device
              (Meta => Meta_RT,
               Platform => Platform,
               Device => Device,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("select_device", Status);
            end if;
         end if;

         Verify_End := Ada.Real_Time.Clock;
         Verify_Ns := To_Nanoseconds (Verify_End - Verify_Start);

         Create_Ctx_Start := Ada.Real_Time.Clock;

         if not Failed then
            Contexts.Create
              (Device => Device,
               Ctx => Ctx,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("create_context", Status);
            end if;
         end if;

         if not Failed then
            Queues.Create
              (Ctx => Ctx,
               Dev => Device,
               Q => Q,
               Status => Status,
               Properties => API.CL_QUEUE_PROFILING_ENABLE);

            if Status = Errors.Success then
               Profiling_Enabled := Profiling.Is_Profiling_Available (Q);
               Profiling_Metrics_Available := Profiling_Enabled;
            else
               Ada.Text_IO.Put_Line
                 ("INFO profiling_queue_create_status="
                  & Errors.Image (Status)
                  & " status_int="
                  & Status_Int_Image (Status));

               Queues.Create
                 (Ctx => Ctx,
                  Dev => Device,
                  Q => Q,
                  Status => Status);
               if Status /= Errors.Success then
                  Mark_Fail ("create_queue", Status);
               else
                  Profiling_Enabled := False;
                  Profiling_Metrics_Available := False;
               end if;
            end if;
         end if;

         Create_Ctx_End := Ada.Real_Time.Clock;
         Create_Ctx_Ns := To_Nanoseconds (Create_Ctx_End - Create_Ctx_Start);

         Create_Prog_Start := Ada.Real_Time.Clock;

         if not Failed then
            Loader.Create_Program_From_Pack_Strict_RT
              (Ctx => Ctx,
               Dev => Device,
               Meta => Meta_RT,
               Bin => Binary_Data.all,
               Used => Binary_Used,
               Prg => Prg,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("create_program_from_pack_strict_rt", Status);
            end if;
         end if;

         Create_Prog_End := Ada.Real_Time.Clock;
         Create_Prog_Ns := To_Nanoseconds (Create_Prog_End - Create_Prog_Start);
         Build_Start := Create_Prog_Start;
         Build_End := Create_Prog_End;
         Build_Ns := To_Nanoseconds (Build_End - Build_Start);

         Kernel_Setup_Start := Ada.Real_Time.Clock;

         if not Failed then
            Buffers.Create
              (Ctx => Ctx,
               Bytes => Transfer_Bytes,
               B => In_Buffer,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("create_in_buffer", Status);
            end if;
         end if;

         if not Failed then
            Buffers.Create
              (Ctx => Ctx,
               Bytes => Transfer_Bytes,
               B => Out_Buffer,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("create_out_buffer", Status);
            end if;
         end if;

         if not Failed then
            declare
               Kernel_Name : constant String :=
                 Ada.Strings.Fixed.Trim
                   (Packs.To_String (Meta_RT.Kernel_Name),
                    Ada.Strings.Both);
            begin
               if Kernel_Name'Length = 0 then
                  Mark_Fail ("kernel_name", Errors.OCLW_Pack_Format_Error);
               else
                  Kernels.Create
                    (Prg => Prg,
                     Name => Kernel_Name,
                     K => K,
                     Status => Status);
                  if Status /= Errors.Success then
                     Mark_Fail ("create_kernel", Status);
                  end if;
               end if;
            end;
         end if;

         if not Failed then
            Kernels.Set_Arg_Buffer
              (K => K,
               Index => 0,
               B => In_Buffer,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("set_arg_0", Status);
            end if;
         end if;

         if not Failed then
            Kernels.Set_Arg_Buffer
              (K => K,
               Index => 1,
               B => Out_Buffer,
               Status => Status);
            if Status /= Errors.Success then
               Mark_Fail ("set_arg_1", Status);
            end if;
         end if;

         Kernel_Setup_End := Ada.Real_Time.Clock;
         Kernel_Setup_Ns :=
           To_Nanoseconds (Kernel_Setup_End - Kernel_Setup_Start);

         Init_End := Ada.Real_Time.Clock;
         Init_Ns := To_Nanoseconds (Init_End - Init_Start);

         if not Failed then
            for Iteration in 1 .. Warmup + Iterations loop
               declare
                  Is_Measured : constant Boolean := Iteration > Warmup;
                  Sample_Id : Positive := 1;
                  Start_Time : Ada.Real_Time.Time := Ada.Real_Time.Clock;
                  End_Time : Ada.Real_Time.Time := Start_Time;
                  Host_Ns : Interfaces.Unsigned_64 := 0;
                  Device_Ns : Interfaces.Unsigned_64 := 0;
                  Ev : Events.Event;
               begin
                  for I in Input_Data'Range loop
                     Input_Data (I) := Byte ((I + Iteration) mod 251);
                  end loop;

                  Start_Time := Ada.Real_Time.Clock;

                  Buffers.Write
                    (Q => Q,
                     B => In_Buffer,
                     Host => Input_Data (Input_Data'First)'Address,
                     Bytes => Transfer_Bytes,
                     Status => Status);
                  if Status /= Errors.Success then
                     Mark_Fail ("write_buffer", Status);
                     Release_Event_Safe (Ev);
                     exit;
                  end if;

                  Kernels.Enqueue_1D
                    (Q => Q,
                     K => K,
                     Global_Size => Transfer_Bytes,
                     Ev => Ev,
                     Status => Status);
                  if Status /= Errors.Success then
                     Mark_Fail ("enqueue_1d", Status);
                     Release_Event_Safe (Ev);
                     exit;
                  end if;

                  Queues.Finish
                    (Q => Q,
                     Status => Status);
                  if Status /= Errors.Success then
                     Mark_Fail ("queue_finish", Status);
                     Release_Event_Safe (Ev);
                     exit;
                  end if;

                  if Profiling_Enabled then
                     Device_Ns :=
                       Profiling.Duration_Ns
                         (Ev => Ev,
                          Status => Profile_Status);

                     if not Errors.Is_Success (Profile_Status) then
                        if Profile_Status = Errors.Profiling_Info_Not_Available then
                           Profiling_Enabled := False;
                           Profiling_Metrics_Available := False;
                           if not Profiling_Announced then
                              Ada.Text_IO.Put_Line
                                ("INFO profiling=UNAVAILABLE reason="
                                 & Errors.Image (Profile_Status));
                              Profiling_Announced := True;
                           end if;
                        else
                           Mark_Fail ("profiling_duration", Profile_Status);
                           Release_Event_Safe (Ev);
                           exit;
                        end if;
                     end if;
                  end if;

                  Release_Event_Safe (Ev);

                  Buffers.Read
                    (Q => Q,
                     B => Out_Buffer,
                     Host => Output_Data (Output_Data'First)'Address,
                     Bytes => Transfer_Bytes,
                     Status => Status);
                  if Status /= Errors.Success then
                     Mark_Fail ("read_buffer", Status);
                     exit;
                  end if;

                  End_Time := Ada.Real_Time.Clock;
                  Host_Ns := To_Nanoseconds (End_Time - Start_Time);

                  if Iteration = 1 or else Iteration = Warmup + Iterations then
                     for J in Output_Data'Range loop
                        if Output_Data (J) /=
                          Byte ((Natural (Input_Data (J)) + 1) mod 256)
                        then
                           Mark_Fail ("validate_output", Errors.Invalid_Value);
                           exit;
                        end if;
                     end loop;

                     if Failed then
                        exit;
                     end if;
                  end if;

                  if Is_Measured then
                     Sample_Id := Positive (Iteration - Warmup);
                     Host_Samples (Sample_Id) := Host_Ns;
                     if Profiling_Enabled then
                        Device_Samples (Sample_Id) := Device_Ns;
                     end if;

                     if Profiling_Enabled then
                        Ada.Text_IO.Put_Line
                          (CSV_File,
                           Trim_Natural_Image (Sample_Id)
                           & ","
                           & Trim_U64_Image (Host_Ns)
                           & ","
                           & Trim_U64_Image (Device_Ns));
                     else
                        Ada.Text_IO.Put_Line
                          (CSV_File,
                           Trim_Natural_Image (Sample_Id)
                           & ","
                           & Trim_U64_Image (Host_Ns)
                           & ",");
                     end if;
                  end if;
               end;

               if Failed then
                  exit;
               end if;
            end loop;
         end if;
      end if;

      if CSV_Open and then Ada.Text_IO.Is_Open (CSV_File) then
         Ada.Text_IO.Close (CSV_File);
         CSV_Open := False;
      end if;

      if not Failed then
         Host_Summary := Summarize (Host_Samples.all);
         if Profiling_Metrics_Available then
            Device_Summary := Summarize (Device_Samples.all);
         end if;

         Ada.Text_IO.Put_Line ("INFO init_ns=" & Trim_U64_Image (Init_Ns));
         Ada.Text_IO.Put_Line ("INFO phase_verify_ns=" & Trim_U64_Image (Verify_Ns));
         Ada.Text_IO.Put_Line
           ("INFO phase_create_ctx_ns=" & Trim_U64_Image (Create_Ctx_Ns));
         Ada.Text_IO.Put_Line
           ("INFO phase_create_prog_ns=" & Trim_U64_Image (Create_Prog_Ns));
         Ada.Text_IO.Put_Line ("INFO phase_build_ns=" & Trim_U64_Image (Build_Ns));
         Ada.Text_IO.Put_Line ("INFO phase_build_ns_mode=INCLUDED_IN_CREATE_PROG");
         Ada.Text_IO.Put_Line
           ("INFO phase_kernel_setup_ns=" & Trim_U64_Image (Kernel_Setup_Ns));
         Ada.Text_IO.Put_Line
           ("INFO phase_exec_ns_p50=" & Trim_U64_Image (Host_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO phase_exec_ns_p99=" & Trim_U64_Image (Host_Summary.P99));
         Ada.Text_IO.Put_Line
           ("INFO exec_host_ns_p50=" & Trim_U64_Image (Host_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO exec_host_ns_p95=" & Trim_U64_Image (Host_Summary.P95));
         Ada.Text_IO.Put_Line
           ("INFO exec_host_ns_p99=" & Trim_U64_Image (Host_Summary.P99));

         if Profiling_Metrics_Available then
            Ada.Text_IO.Put_Line ("INFO profiling=AVAILABLE");
            Ada.Text_IO.Put_Line
              ("INFO exec_dev_ns_p50=" & Trim_U64_Image (Device_Summary.P50));
            Ada.Text_IO.Put_Line
              ("INFO exec_dev_ns_p95=" & Trim_U64_Image (Device_Summary.P95));
            Ada.Text_IO.Put_Line
              ("INFO exec_dev_ns_p99=" & Trim_U64_Image (Device_Summary.P99));
         else
            Ada.Text_IO.Put_Line ("INFO profiling=UNAVAILABLE");
         end if;

         Ada.Text_IO.Put_Line ("INFO csv_path=" & CSV_Path);
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      else
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;

      Cleanup;
   exception
      when others =>
         Cleanup;
         Ada.Text_IO.Put_Line
           ("ERROR unhandled_exception: "
            & Errors.Image (Errors.OCLW_IO_Error)
            & " status_int="
            & Status_Int_Image (Errors.OCLW_IO_Error));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end;
end Bench_RT_Pack_Add1;
