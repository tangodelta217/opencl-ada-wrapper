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
with OpenCL.Core.Profiling;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.Raw.API;

procedure Bench_Transfers_H2D_D2H is
   package API renames OpenCL.Raw.API;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   package Events renames OpenCL.Core.Events;
   package Profiling renames OpenCL.Core.Profiling;
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

   Default_Transfer_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (4 * 1024 * 1024);
   Default_Warmup : constant Positive := 5;
   Default_Iterations : constant Positive := 40;

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
   Buffer : Buffers.Buffer;

   Input_Data : Host_Byte_Array_Access := null;
   Output_Data : Host_Byte_Array_Access := null;

   Write_Host_Samples : Sample_Array_Access := null;
   Read_Host_Samples : Sample_Array_Access := null;
   Write_Device_Samples : Sample_Array_Access := null;
   Read_Device_Samples : Sample_Array_Access := null;

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
      Buffers.Release (B => Buffer, Status => Release_Status);
      Queues.Release (Q => Q, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Input_Data /= null then
         Free_Host_Byte_Array (Input_Data);
      end if;
      if Output_Data /= null then
         Free_Host_Byte_Array (Output_Data);
      end if;
      if Write_Host_Samples /= null then
         Free_Sample_Array (Write_Host_Samples);
      end if;
      if Read_Host_Samples /= null then
         Free_Sample_Array (Read_Host_Samples);
      end if;
      if Write_Device_Samples /= null then
         Free_Sample_Array (Write_Device_Samples);
      end if;
      if Read_Device_Samples /= null then
         Free_Sample_Array (Read_Device_Samples);
      end if;
   end Cleanup;

begin
   declare
      Transfer_Bytes : constant Interfaces.C.size_t :=
        Parse_Size_Env
          (Name => "OCLW_BENCH_TRANSFER_BYTES",
           Default => Default_Transfer_Bytes);
      Transfer_Bytes_Natural : constant Natural := Natural (Transfer_Bytes);
      Warmup : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_WARMUP", Default_Warmup);
      Iterations : constant Positive :=
        Parse_Positive_Env ("OCLW_BENCH_ITERS", Default_Iterations);

      Write_Host_Summary : Metric_Summary := (others => 0);
      Read_Host_Summary : Metric_Summary := (others => 0);
      Write_Device_Summary : Metric_Summary := (others => 0);
      Read_Device_Summary : Metric_Summary := (others => 0);
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
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_buffer", Status);
         end if;
      end if;

      if not Failed then
         Input_Data := new Host_Byte_Array (1 .. Transfer_Bytes_Natural);
         Output_Data := new Host_Byte_Array (1 .. Transfer_Bytes_Natural);
         Input_Data.all := (others => 0);
         Output_Data.all := (others => 0);
         Write_Host_Samples := new Sample_Array (1 .. Iterations);
         Read_Host_Samples := new Sample_Array (1 .. Iterations);
         Write_Device_Samples := new Sample_Array (1 .. Iterations);
         Read_Device_Samples := new Sample_Array (1 .. Iterations);
         Write_Host_Samples.all := (others => 0);
         Read_Host_Samples.all := (others => 0);
         Write_Device_Samples.all := (others => 0);
         Read_Device_Samples.all := (others => 0);
      end if;

      if not Failed then
         for Iteration in 1 .. Warmup + Iterations loop
            declare
               Is_Measured : constant Boolean := Iteration > Warmup;
               Sample_Id : Positive := 1;
               Write_Start : Ada.Real_Time.Time := Ada.Real_Time.Clock;
               Write_End : Ada.Real_Time.Time := Write_Start;
               Read_Start : Ada.Real_Time.Time := Write_Start;
               Read_End : Ada.Real_Time.Time := Write_Start;
               Write_Host_Ns : Interfaces.Unsigned_64 := 0;
               Read_Host_Ns : Interfaces.Unsigned_64 := 0;
               Write_Device_Ns : Interfaces.Unsigned_64 := 0;
               Read_Device_Ns : Interfaces.Unsigned_64 := 0;
               Empty_Wait : Events.Event_List (1 .. 0);
               Write_Ev : Events.Event;
               Read_Ev : Events.Event;
            begin
               for I in Input_Data.all'Range loop
                  Input_Data (I) := Byte ((I + Iteration) mod 251);
               end loop;

               Write_Start := Ada.Real_Time.Clock;
               Buffers.Write
                 (Q => Q,
                  B => Buffer,
                  Host => Input_Data.all (Input_Data.all'First)'Address,
                  Bytes => Transfer_Bytes,
                  Wait_List => Empty_Wait,
                  Ev => Write_Ev,
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("write_enqueue", Status);
                  Release_Event_Safe (Write_Ev);
                  exit;
               end if;

               Events.Wait_For (Ev => Write_Ev, Status => Status);
               Write_End := Ada.Real_Time.Clock;
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("write_wait", Status);
                  Release_Event_Safe (Write_Ev);
                  exit;
               end if;

               Write_Host_Ns := To_Nanoseconds (Write_End - Write_Start);
               if Profiling_Enabled then
                  Write_Device_Ns :=
                    Profiling.Duration_Ns
                      (Ev => Write_Ev,
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
                        Mark_Fail ("write_profiling", Profile_Status);
                        Release_Event_Safe (Write_Ev);
                        exit;
                     end if;
                  end if;
               end if;
               Release_Event_Safe (Write_Ev);

               Read_Start := Ada.Real_Time.Clock;
               Buffers.Read
                 (Q => Q,
                  B => Buffer,
                  Host => Output_Data.all (Output_Data.all'First)'Address,
                  Bytes => Transfer_Bytes,
                  Wait_List => Empty_Wait,
                  Ev => Read_Ev,
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("read_enqueue", Status);
                  Release_Event_Safe (Read_Ev);
                  exit;
               end if;

               Events.Wait_For (Ev => Read_Ev, Status => Status);
               Read_End := Ada.Real_Time.Clock;
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("read_wait", Status);
                  Release_Event_Safe (Read_Ev);
                  exit;
               end if;

               Read_Host_Ns := To_Nanoseconds (Read_End - Read_Start);
               if Profiling_Enabled then
                  Read_Device_Ns :=
                    Profiling.Duration_Ns
                      (Ev => Read_Ev,
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
                        Mark_Fail ("read_profiling", Profile_Status);
                        Release_Event_Safe (Read_Ev);
                        exit;
                     end if;
                  end if;
               end if;
               Release_Event_Safe (Read_Ev);

               if Iteration = 1 or else Iteration = Warmup + Iterations then
                  if Output_Data.all (Output_Data.all'First) /=
                    Input_Data.all (Input_Data.all'First)
                    or else Output_Data.all (Output_Data.all'Last) /=
                      Input_Data.all (Input_Data.all'Last)
                  then
                     Mark_Fail ("transfer_validate", Errors.Invalid_Value);
                     exit;
                  end if;
               end if;

               if Is_Measured then
                  Sample_Id := Positive (Iteration - Warmup);
                  Write_Host_Samples (Sample_Id) := Write_Host_Ns;
                  Read_Host_Samples (Sample_Id) := Read_Host_Ns;
                  if Profiling_Enabled then
                     Write_Device_Samples (Sample_Id) := Write_Device_Ns;
                     Read_Device_Samples (Sample_Id) := Read_Device_Ns;
                  end if;
               end if;
            end;

            exit when Failed;
         end loop;
      end if;

      if not Failed then
         Write_Host_Summary := Summarize (Write_Host_Samples.all);
         Read_Host_Summary := Summarize (Read_Host_Samples.all);
         if Profiling_Metrics_Available then
            Write_Device_Summary := Summarize (Write_Device_Samples.all);
            Read_Device_Summary := Summarize (Read_Device_Samples.all);
         end if;

         if Profiling_Metrics_Available then
            Ada.Text_IO.Put_Line ("INFO profiling=AVAILABLE");
         else
            Ada.Text_IO.Put_Line ("INFO profiling=UNAVAILABLE");
         end if;

         Ada.Text_IO.Put_Line
           ("INFO write_host_ns_p50=" & Trim_U64_Image (Write_Host_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO write_host_ns_p99=" & Trim_U64_Image (Write_Host_Summary.P99));
         Ada.Text_IO.Put_Line
           ("INFO read_host_ns_p50=" & Trim_U64_Image (Read_Host_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO read_host_ns_p99=" & Trim_U64_Image (Read_Host_Summary.P99));

         if Profiling_Metrics_Available then
            Ada.Text_IO.Put_Line
              ("INFO write_dev_ns_p50=" & Trim_U64_Image (Write_Device_Summary.P50));
            Ada.Text_IO.Put_Line
              ("INFO write_dev_ns_p99=" & Trim_U64_Image (Write_Device_Summary.P99));
            Ada.Text_IO.Put_Line
              ("INFO read_dev_ns_p50=" & Trim_U64_Image (Read_Device_Summary.P50));
            Ada.Text_IO.Put_Line
              ("INFO read_dev_ns_p99=" & Trim_U64_Image (Read_Device_Summary.P99));
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
end Bench_Transfers_H2D_D2H;
