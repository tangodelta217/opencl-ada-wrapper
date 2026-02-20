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
with EW_MLP_Kernel_Source;
with EW_MLP_Model;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Kernels;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.RT.Loader;
with OpenCL.RT.Packs;
with System;

procedure Bench_RT_Pack_EW_MLP is
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Model renames EW_MLP_Model;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.C.unsigned_char;
   use type Interfaces.Unsigned_64;

   Default_Warmup : constant Positive := 10;
   Default_Iterations : constant Positive := 200;
   Default_Batch : constant Positive := 256;

   Local_Log_Dir : constant String := "docs/VV/Execution_Logs/local";
   Default_Pack_Dir_Prefix : constant String := Local_Log_Dir & "/";

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   type Sample_Array is array (Positive range <>) of Interfaces.Unsigned_64;
   type Sample_Array_Access is access all Sample_Array;
   procedure Free_Sample_Array is new Ada.Unchecked_Deallocation
     (Object => Sample_Array,
      Name => Sample_Array_Access);

   type Metric_Summary is record
      P50 : Interfaces.Unsigned_64 := 0;
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

      return Default_Pack_Dir_Prefix & Timestamp_Compact & "_bench_rt_pack_ew_mlp";
   end Resolve_Pack_Dir;

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

   function Locate_Gen_Pack_EW_MLP return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Candidate_1 : constant String := Self_Dir & "/gen_pack_ew_mlp";
      Candidate_2 : constant String := "tests/bin/gen_pack_ew_mlp";
      Candidate_3 : constant String := Candidate_From_Self ("tests/bin/gen_pack_ew_mlp");
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
   end Locate_Gen_Pack_EW_MLP;

   function Ensure_Base_Pack
     (Pack_Dir : String;
      Manifest_Path : String;
      Binary_Path : String;
      Gen_Log_Path : String) return Boolean
   is
      Gen_Exec : constant String := Locate_Gen_Pack_EW_MLP;
      Args : GNAT.OS_Lib.Argument_List (1 .. 1);
      Success : Boolean := False;
      Return_Code : Integer := 0;
   begin
      if Gen_Exec'Length = 0 then
         Ada.Text_IO.Put_Line ("ERROR missing_gen_pack_ew_mlp_executable");
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
        ("INFO gen_pack_ew_mlp_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Gen_Log_Path);

      return
        Success
        and then Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Ensure_Base_Pack;

   type Expected_Class_Array is array (Natural range <>) of Natural;

   function Compute_Vectors_Per_Second
     (Batch : Positive;
      Iterations : Positive;
      Total_Host_Ns : Interfaces.Unsigned_64) return Interfaces.Unsigned_64
   is
   begin
      if Total_Host_Ns = 0 then
         return 0;
      end if;

      declare
         Numerator : constant Interfaces.Unsigned_64 :=
           Interfaces.Unsigned_64 (Batch)
           * Interfaces.Unsigned_64 (Iterations)
           * Interfaces.Unsigned_64 (1_000_000_000);
      begin
         return Numerator / Total_Host_Ns;
      end;
   end Compute_Vectors_Per_Second;

   Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;

   Meta_RT : Packs.Pack_Metadata;
   Binary_Data : Program_Byte_Array_Access := null;
   Binary_Used : Natural := 0;

   Platform : Core.Platform;
   Device : Core.Device;
   Ctx : Contexts.Context;
   Q : Queues.Queue;
   X_Buffer : Buffers.Buffer;
   Logits_Buffer : Buffers.Buffer;
   Class_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Host_Samples : Sample_Array_Access := null;

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

   procedure Cleanup is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Kernels.Release (K => K, Status => Release_Status);
      Programs.Release (Prg => Prg, Status => Release_Status);
      Buffers.Release (B => Class_Buffer, Status => Release_Status);
      Buffers.Release (B => Logits_Buffer, Status => Release_Status);
      Buffers.Release (B => X_Buffer, Status => Release_Status);
      Queues.Release (Q => Q, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;

      if Host_Samples /= null then
         Free_Sample_Array (Host_Samples);
      end if;
   end Cleanup;

begin
   declare
      Warmup : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_WARMUP", Default_Warmup);
      Iterations : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_ITERS", Default_Iterations);
      Batch : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_BATCH", Default_Batch);

      subtype Sample_Index is Natural range 0 .. Batch - 1;
      X_Batch : Model.Batch_Byte_Array (Sample_Index);
      Labels_Expected : Model.Batch_Class_Array (Sample_Index);
      Classes_CPU : Model.Batch_Class_Array (Sample_Index);
      Logits_CPU : Model.Batch_Logit_Array (Sample_Index);

      type Input_Flat_Array is
        array (Natural range 0 .. Batch * Model.Input_Size - 1) of
          aliased Interfaces.C.unsigned_char;
      type Class_Flat_Array is
        array (Natural range 0 .. Batch - 1) of
          aliased Interfaces.C.unsigned_char;

      Input_Bytes : constant Interfaces.C.size_t :=
        Interfaces.C.size_t (Batch * Model.Input_Size);
      Logits_Bytes : constant Interfaces.C.size_t :=
        Interfaces.C.size_t
          (Batch
           * Model.Output_Size
           * (Interfaces.C.int'Size / System.Storage_Unit));
      Class_Bytes : constant Interfaces.C.size_t :=
        Interfaces.C.size_t (Batch);

      X_Flat : Input_Flat_Array := (others => 0);
      Classes_Device : Class_Flat_Array := (others => 0);
      Classes_Expected : Expected_Class_Array (Sample_Index) := (others => 0);

      Timestamp_Compact : constant String := UTC_Timestamp_Compact;
      Pack_Dir : constant String := Resolve_Pack_Dir (Timestamp_Compact);
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
      Gen_Log_Path : constant String := Pack_Dir & "/bench_gen_pack_ew_mlp.log";

      Init_Start : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Init_End : Ada.Real_Time.Time := Init_Start;
      Init_Ns : Interfaces.Unsigned_64 := 0;

      Host_Summary : Metric_Summary := (others => 0);
      Total_Host_Ns : Interfaces.Unsigned_64 := 0;
      Vectors_Per_Second : Interfaces.Unsigned_64 := 0;

      procedure Run_One_Iteration
        (Record_Sample : Boolean;
         Sample_Pos : Positive := 1)
      is
         Iter_Start : Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Iter_End : Ada.Real_Time.Time := Iter_Start;
      begin
         Buffers.Write
           (Q => Q,
            B => X_Buffer,
            Host => X_Flat (X_Flat'First)'Address,
            Bytes => Input_Bytes,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("write_x", Status);
            return;
         end if;

         Kernels.Enqueue_1D
           (Q => Q,
            K => K,
            Global_Size => Interfaces.C.size_t (Batch),
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("enqueue_1d", Status);
            return;
         end if;

         Queues.Finish (Q => Q, Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("finish_queue", Status);
            return;
         end if;

         Buffers.Read
           (Q => Q,
            B => Class_Buffer,
            Host => Classes_Device (Classes_Device'First)'Address,
            Bytes => Class_Bytes,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("read_classes", Status);
            return;
         end if;

         Iter_End := Ada.Real_Time.Clock;

         if Record_Sample then
            Host_Samples (Sample_Pos) := To_Nanoseconds (Iter_End - Iter_Start);
         end if;

         for S in Sample_Index loop
            if Natural (Classes_Device (S)) /= Classes_Expected (S) then
               Mark_Fail ("class_mismatch", Errors.Invalid_Value);
               return;
            end if;
         end loop;
      end Run_One_Iteration;
   begin
      Ada.Text_IO.Put_Line
        ("INFO warmup="
         & Trim_Natural_Image (Warmup)
         & " iterations="
         & Trim_Natural_Image (Iterations));
      Ada.Text_IO.Put_Line ("INFO batch=" & Trim_Natural_Image (Batch));
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);

      if not Model.Self_Check then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Model.Make_Batch
        (X => X_Batch,
         Labels => Labels_Expected,
         Start_Sample_Index => 0);
      Model.Infer_CPU_Batch
        (X => X_Batch,
         Logits => Logits_CPU,
         Classes => Classes_CPU);

      for S in Sample_Index loop
         Classes_Expected (S) := Natural (Classes_CPU (S));
         for F in Model.Feature_Index loop
            X_Flat (Natural (S) * Model.Input_Size + Natural (F)) :=
              Interfaces.C.unsigned_char (X_Batch (S) (F));
         end loop;
      end loop;

      if not Ensure_Base_Pack
               (Pack_Dir => Pack_Dir,
                Manifest_Path => Manifest_Path,
                Binary_Path => Binary_Path,
                Gen_Log_Path => Gen_Log_Path)
      then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=pack_generation_failed");
         return;
      end if;

      Host_Samples := new Sample_Array (1 .. Iterations);
      Host_Samples.all := (others => 0);

      Init_Start := Ada.Real_Time.Clock;

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
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("create_queue", Status);
         end if;
      end if;

      if not Failed then
         Loader.Create_Program_From_Pack
           (Ctx => Ctx,
            Dev => Device,
            Meta => Meta_RT,
            Bin => Binary_Data.all,
            Used => Binary_Used,
            Prg => Prg,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("create_program_from_pack", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Input_Bytes,
            B => X_Buffer,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("create_x_buffer", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Logits_Bytes,
            B => Logits_Buffer,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("create_logits_buffer", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Class_Bytes,
            B => Class_Buffer,
            Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("create_class_buffer", Status);
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
               Mark_Fail ("kernel_name_empty", Errors.OCLW_Pack_Format_Error);
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
         Kernels.Set_Arg_Buffer (K => K, Index => EW_MLP_Kernel_Source.Arg_X, B => X_Buffer, Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("set_arg_x", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer (K => K, Index => EW_MLP_Kernel_Source.Arg_Logits, B => Logits_Buffer, Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("set_arg_logits", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer (K => K, Index => EW_MLP_Kernel_Source.Arg_Cls, B => Class_Buffer, Status => Status);
         if Status /= Errors.Success then
            Mark_Fail ("set_arg_cls", Status);
         end if;
      end if;

      Init_End := Ada.Real_Time.Clock;
      Init_Ns := To_Nanoseconds (Init_End - Init_Start);

      if not Failed then
         for I in 1 .. Warmup loop
            Run_One_Iteration (Record_Sample => False);
            exit when Failed;
         end loop;
      end if;

      if not Failed then
         for I in 1 .. Iterations loop
            Run_One_Iteration
              (Record_Sample => True,
               Sample_Pos => I);
            exit when Failed;
         end loop;
      end if;

      if not Failed then
         Host_Summary := Summarize (Host_Samples.all);
         for S of Host_Samples.all loop
            Total_Host_Ns := Total_Host_Ns + S;
         end loop;
         Vectors_Per_Second :=
           Compute_Vectors_Per_Second
             (Batch => Batch,
              Iterations => Iterations,
              Total_Host_Ns => Total_Host_Ns);
      end if;

      Cleanup;

      if Failed then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      else
         Ada.Text_IO.Put_Line ("INFO init_ns=" & Trim_U64_Image (Init_Ns));
         Ada.Text_IO.Put_Line
           ("INFO exec_host_ns_p50=" & Trim_U64_Image (Host_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO exec_host_ns_p99=" & Trim_U64_Image (Host_Summary.P99));
         Ada.Text_IO.Put_Line
           ("INFO vectors_per_sec=" & Trim_U64_Image (Vectors_Per_Second));
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      end if;
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
end Bench_RT_Pack_EW_MLP;
