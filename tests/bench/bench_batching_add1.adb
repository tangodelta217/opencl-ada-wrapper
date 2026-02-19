with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
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

procedure Bench_Batching_Add1 is
   package API renames OpenCL.Raw.API;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Events renames OpenCL.Core.Events;
   package Kernels renames OpenCL.Core.Kernels;
   package Profiling renames OpenCL.Core.Profiling;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;

   Default_Transfer_Bytes : constant Interfaces.C.size_t := 4096;
   Default_Warmup_Batches : constant Positive := 2;
   Default_Batches : constant Positive := 30;
   Default_Batch_Iterations : constant Positive := 16;

   Kernel_Source : constant String :=
     "__kernel void add1(__global const uchar* src, __global uchar* dst) "
     & "{ const size_t gid = get_global_id(0); "
     & "dst[gid] = (uchar)(src[gid] + (uchar)1); }";

   subtype Byte is Interfaces.Unsigned_8;
   type Host_Byte_Array is array (Positive range <>) of aliased Byte;
   type Host_Byte_Array_Access is access all Host_Byte_Array;
   procedure Free_Host_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Host_Byte_Array,
      Name => Host_Byte_Array_Access);

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

   function Parse_Size_Env
     (Name : String;
      Default : Interfaces.C.size_t) return Interfaces.C.size_t
   is
      Parsed : constant Positive :=
        Parse_Positive_Env (Name => Name, Default => Positive (Integer (Default)));
   begin
      return Interfaces.C.size_t (Parsed);
   exception
      when others =>
         return Default;
   end Parse_Size_Env;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;

   Status : Errors.Status_Code := Errors.Success;
   Profile_Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;
   Profiling_Enabled : Boolean := False;
   Profiling_Metrics_Available : Boolean := False;
   Profiling_Announced : Boolean := False;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   In_Buffer : Buffers.Buffer;
   Out_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Input_Data : Host_Byte_Array_Access := null;
   Output_Data : Host_Byte_Array_Access := null;
   Host_Batch_Samples : Sample_Array_Access := null;
   Device_Batch_Samples : Sample_Array_Access := null;

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
      Kernels.Release (K => K, Status => Release_Status);
      Programs.Release (Prg => Prg, Status => Release_Status);
      Buffers.Release (B => Out_Buffer, Status => Release_Status);
      Buffers.Release (B => In_Buffer, Status => Release_Status);
      Queues.Release (Q => Q, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Input_Data /= null then
         Free_Host_Byte_Array (Input_Data);
      end if;
      if Output_Data /= null then
         Free_Host_Byte_Array (Output_Data);
      end if;
      if Host_Batch_Samples /= null then
         Free_Sample_Array (Host_Batch_Samples);
      end if;
      if Device_Batch_Samples /= null then
         Free_Sample_Array (Device_Batch_Samples);
      end if;
   end Cleanup;

begin
   declare
      Transfer_Bytes : constant Interfaces.C.size_t :=
        Parse_Size_Env
          (Name => "OCLW_BENCH_TRANSFER_BYTES",
           Default => Default_Transfer_Bytes);
      Transfer_Bytes_Natural : constant Natural := Natural (Transfer_Bytes);
      Warmup_Batches : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_BATCH_WARMUP", Default_Warmup_Batches);
      Batches : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_BATCHES", Default_Batches);
      Batch_Iterations : constant Positive :=
        Parse_Positive_Env
          ("OCLW_BENCH_BATCH_ITERATIONS", Default_Batch_Iterations);

      Host_Summary : Metric_Summary := (others => 0);
      Device_Summary : Metric_Summary := (others => 0);
      Total_Host_Ns : Interfaces.Unsigned_64 := 0;
      Throughput_Iter_Per_Sec : Interfaces.Unsigned_64 := 0;
      Total_Iterations : Natural := 0;
   begin
      if Transfer_Bytes = 0 or else Transfer_Bytes_Natural = 0 then
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Ada.Text_IO.Put_Line
        ("INFO transfer_bytes="
         & Trim_U64_Image (Interfaces.Unsigned_64 (Transfer_Bytes_Natural)));
      Ada.Text_IO.Put_Line
        ("INFO warmup_batches=" & Trim_Natural_Image (Warmup_Batches));
      Ada.Text_IO.Put_Line ("INFO batches=" & Trim_Natural_Image (Batches));
      Ada.Text_IO.Put_Line
        ("INFO batch_iterations=" & Trim_Natural_Image (Batch_Iterations));

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

      Contexts.Create
        (Device => Devices (Devices'First),
         Ctx => Ctx,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_context", Status);
      end if;

      if not Failed then
         Queues.Create
           (Ctx => Ctx,
            Dev => Devices (Devices'First),
            Q => Q,
            Status => Status,
            Properties => API.CL_QUEUE_PROFILING_ENABLE);
         if Status = Errors.Success then
            Profiling_Enabled := Profiling.Is_Profiling_Available (Q);
            Profiling_Metrics_Available := Profiling_Enabled;
         else
            Queues.Create
              (Ctx => Ctx,
               Dev => Devices (Devices'First),
               Q => Q,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("create_queue", Status);
            else
               Profiling_Enabled := False;
               Profiling_Metrics_Available := False;
            end if;
         end if;
      end if;

      if not Failed then
         Programs.Create_From_Source
           (Ctx => Ctx,
            Source => Kernel_Source,
            Prg => Prg,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_program_from_source", Status);
         end if;
      end if;

      if not Failed then
         Programs.Build
           (Prg => Prg,
            Dev => Devices (Devices'First),
            Options => "-cl-std=CL1.2",
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("build_program", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Create
           (Prg => Prg,
            Name => "add1",
            K => K,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_kernel", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => In_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_in_buffer", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => Out_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_out_buffer", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer
           (K => K,
            Index => 0,
            B => In_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_0", Status);
         end if;
      end if;

      if not Failed then
         Kernels.Set_Arg_Buffer
           (K => K,
            Index => 1,
            B => Out_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("set_arg_1", Status);
         end if;
      end if;

      if not Failed then
         Input_Data := new Host_Byte_Array (1 .. Transfer_Bytes_Natural);
         Output_Data := new Host_Byte_Array (1 .. Transfer_Bytes_Natural);
         Input_Data.all := (others => 0);
         Output_Data.all := (others => 0);
         Host_Batch_Samples := new Sample_Array (1 .. Batches);
         Device_Batch_Samples := new Sample_Array (1 .. Batches);
         Host_Batch_Samples.all := (others => 0);
         Device_Batch_Samples.all := (others => 0);
      end if;

      if not Failed then
         for Batch in 1 .. Warmup_Batches + Batches loop
            declare
               Is_Measured : constant Boolean := Batch > Warmup_Batches;
               Sample_Id : Positive := 1;
               Batch_Start : Ada.Real_Time.Time := Ada.Real_Time.Clock;
               Batch_End : Ada.Real_Time.Time := Batch_Start;
               Batch_Host_Ns : Interfaces.Unsigned_64 := 0;
               Batch_Device_Ns : Interfaces.Unsigned_64 := 0;
            begin
               Batch_Start := Ada.Real_Time.Clock;

               for Iter in 1 .. Batch_Iterations loop
                  declare
                     Ev : Events.Event;
                     Device_Ns : Interfaces.Unsigned_64 := 0;
                  begin
                     for I in Input_Data.all'Range loop
                        Input_Data (I) := Byte ((I + Iter + Batch) mod 251);
                     end loop;

                     Buffers.Write
                       (Q => Q,
                        B => In_Buffer,
                        Host => Input_Data.all (Input_Data.all'First)'Address,
                        Bytes => Transfer_Bytes,
                        Status => Status);
                     if not Errors.Is_Success (Status) then
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
                     if not Errors.Is_Success (Status) then
                        Mark_Fail ("enqueue_1d", Status);
                        Release_Event_Safe (Ev);
                        exit;
                     end if;

                     Queues.Finish (Q => Q, Status => Status);
                     if not Errors.Is_Success (Status) then
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
                              Mark_Fail ("kernel_profiling", Profile_Status);
                              Release_Event_Safe (Ev);
                              exit;
                           end if;
                        end if;
                     end if;

                     Release_Event_Safe (Ev);

                     Buffers.Read
                       (Q => Q,
                        B => Out_Buffer,
                        Host => Output_Data.all (Output_Data.all'First)'Address,
                        Bytes => Transfer_Bytes,
                        Status => Status);
                     if not Errors.Is_Success (Status) then
                        Mark_Fail ("read_buffer", Status);
                        exit;
                     end if;

                     if (Batch = 1 and then Iter = 1)
                       or else
                         (Batch = Warmup_Batches + Batches
                          and then Iter = Batch_Iterations)
                     then
                        if Output_Data.all (Output_Data.all'First) /=
                          Byte ((Natural (Input_Data.all (Input_Data.all'First)) + 1) mod 256)
                          or else Output_Data.all (Output_Data.all'Last) /=
                            Byte ((Natural (Input_Data.all (Input_Data.all'Last)) + 1) mod 256)
                        then
                           Mark_Fail ("validate_output", Errors.Invalid_Value);
                           exit;
                        end if;
                     end if;

                     if Profiling_Enabled then
                        Batch_Device_Ns := Batch_Device_Ns + Device_Ns;
                     end if;
                  end;

                  exit when Failed;
               end loop;

               Batch_End := Ada.Real_Time.Clock;
               Batch_Host_Ns := To_Nanoseconds (Batch_End - Batch_Start);

               if Is_Measured then
                  Sample_Id := Positive (Batch - Warmup_Batches);
                  Host_Batch_Samples (Sample_Id) := Batch_Host_Ns;
                  if Profiling_Enabled then
                     Device_Batch_Samples (Sample_Id) := Batch_Device_Ns;
                  end if;
               end if;
            end;

            exit when Failed;
         end loop;
      end if;

      if not Failed then
         Host_Summary := Summarize (Host_Batch_Samples.all);
         if Profiling_Metrics_Available then
            Device_Summary := Summarize (Device_Batch_Samples.all);
         end if;

         Total_Host_Ns := 0;
         for I in Host_Batch_Samples.all'Range loop
            Total_Host_Ns := Total_Host_Ns + Host_Batch_Samples (I);
         end loop;

         Total_Iterations := Batches * Batch_Iterations;
         if Total_Host_Ns > 0 then
            Throughput_Iter_Per_Sec :=
              (Interfaces.Unsigned_64 (Total_Iterations) * 1_000_000_000)
              / Total_Host_Ns;
         else
            Throughput_Iter_Per_Sec := 0;
         end if;

         Ada.Text_IO.Put_Line
           ("INFO total_iterations=" & Trim_Natural_Image (Total_Iterations));
         Ada.Text_IO.Put_Line
           ("INFO throughput_iter_per_sec="
            & Trim_U64_Image (Throughput_Iter_Per_Sec));
         Ada.Text_IO.Put_Line
           ("INFO batch_host_ns_p50=" & Trim_U64_Image (Host_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO batch_host_ns_p99=" & Trim_U64_Image (Host_Summary.P99));

         if Profiling_Metrics_Available then
            Ada.Text_IO.Put_Line ("INFO profiling=AVAILABLE");
            Ada.Text_IO.Put_Line
              ("INFO batch_dev_ns_p50=" & Trim_U64_Image (Device_Summary.P50));
            Ada.Text_IO.Put_Line
              ("INFO batch_dev_ns_p99=" & Trim_U64_Image (Device_Summary.P99));
         else
            Ada.Text_IO.Put_Line ("INFO profiling=UNAVAILABLE");
         end if;

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
end Bench_Batching_Add1;
