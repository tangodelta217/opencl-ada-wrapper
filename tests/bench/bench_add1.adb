with Ada.Directories;
with Ada.Real_Time;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
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

procedure Bench_Add1 is
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Events renames OpenCL.Core.Events;
   package Kernels renames OpenCL.Core.Kernels;
   package Profiling renames OpenCL.Core.Profiling;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package API renames OpenCL.Raw.API;

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Errors.Status_Code;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;
   Warmup_Iterations : constant Positive := 10;
   Measurement_Iterations : constant Positive := 200;
   Local_Log_Dir : constant String := "docs/VV/Execution_Logs/local";
   CSV_Path : constant String := Local_Log_Dir & "/bench_add1.csv";

   Kernel_Source : constant String :=
     "__kernel void add1(__global const uchar* src, __global uchar* dst) "
     & "{ const size_t gid = get_global_id(0); "
     & "dst[gid] = (uchar)(src[gid] + (uchar)1); }";

   subtype Byte is Interfaces.Unsigned_8;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Host_Byte_Array is array (Byte_Index) of aliased Byte;

   subtype Sample_Index is Positive range 1 .. Measurement_Iterations;
   type Sample_Array is array (Sample_Index) of Interfaces.Unsigned_64;

   type Metric_Summary is record
      Min : Interfaces.Unsigned_64 := 0;
      Avg : Interfaces.Unsigned_64 := 0;
      P50 : Interfaces.Unsigned_64 := 0;
      P95 : Interfaces.Unsigned_64 := 0;
      P99 : Interfaces.Unsigned_64 := 0;
   end record;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;

   Status : Errors.Status_Code := Errors.Success;
   Profile_Status : Errors.Status_Code := Errors.Success;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   In_Buffer : Buffers.Buffer;
   Out_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Input_Data : Host_Byte_Array := (others => 0);
   Output_Data : Host_Byte_Array := (others => 0);

   Host_Samples : Sample_Array := (others => 0);
   Device_Samples : Sample_Array := (others => 0);

   Profiling_Enabled : Boolean := False;
   Profiling_Announced : Boolean := False;
   Failed : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Trim_U64_Image (Value : Interfaces.Unsigned_64) return String is
      Raw : constant String := Interfaces.Unsigned_64'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_U64_Image;

   function Trim_Integer_Image (Value : Integer) return String is
      Raw : constant String := Integer'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Integer_Image;

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
      Min_Value : Interfaces.Unsigned_64 := Interfaces.Unsigned_64'Last;
      Sum : Long_Long_Float := 0.0;
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

      for I in Samples'Range loop
         if Samples (I) < Min_Value then
            Min_Value := Samples (I);
         end if;

         Sum := Sum + Long_Long_Float (Samples (I));
      end loop;

      return
        (Min => Min_Value,
         Avg => Interfaces.Unsigned_64
           (Long_Long_Integer (Sum / Long_Long_Float (Samples'Length))),
         P50 => Sorted (Percentile_Index (Samples'Length, 50, 100)),
         P95 => Sorted (Percentile_Index (Samples'Length, 95, 100)),
         P99 => Sorted (Percentile_Index (Samples'Length, 99, 100)));
   end Summarize;

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
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_kernel: " & Errors.Image (Release_Status));
      end if;

      Programs.Release (Prg => Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_program: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => Out_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_out_buffer: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => In_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_in_buffer: " & Errors.Image (Release_Status));
      end if;

      Queues.Release (Q => Q, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_queue: " & Errors.Image (Release_Status));
      end if;

      Contexts.Release (Ctx => Ctx, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_context: " & Errors.Image (Release_Status));
      end if;
   end Cleanup;

begin
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

   Ada.Text_IO.Put_Line
     ("INFO platform_name="
      & Core.Get_Platform_Info
        (P => Platforms (Platforms'First),
         What => Core.Name,
         Status => Status));
   Ada.Text_IO.Put_Line
     ("INFO platform_vendor="
      & Core.Get_Platform_Info
        (P => Platforms (Platforms'First),
         What => Core.Vendor,
         Status => Status));
   Ada.Text_IO.Put_Line
     ("INFO device_name="
      & Core.Get_Device_Info
        (D => Devices (Devices'First),
         What => Core.Name,
         Status => Status));
   Ada.Text_IO.Put_Line
     ("INFO driver_version="
      & Core.Get_Device_Info
        (D => Devices (Devices'First),
         What => Core.Driver_Version,
         Status => Status));

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
         Properties => API.CL_QUEUE_PROFILING_ENABLE,
         Q => Q,
         Status => Status);

      if Errors.Is_Success (Status) then
         Profiling_Enabled := Profiling.Is_Profiling_Available (Q);
      else
         Ada.Text_IO.Put_Line
           ("INFO profiling_queue_create_status="
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));

         Queues.Create
           (Ctx => Ctx,
            Dev => Devices (Devices'First),
            Q => Q,
            Status => Status);

         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_queue", Status);
         else
            Profiling_Enabled := False;
         end if;
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
         Ada.Text_IO.Put_Line
           ("ERROR build_program: "
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         Ada.Text_IO.Put_Line ("BUILD_LOG_BEGIN");
         Ada.Text_IO.Put_Line
           (Programs.Build_Log
              (Prg => Prg,
               Dev => Devices (Devices'First),
               Status => Profile_Status,
               Max_Bytes => 65_536));
         Ada.Text_IO.Put_Line ("BUILD_LOG_END");
         Failed := True;
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
      for I in Input_Data'Range loop
         Input_Data (I) := Byte (I mod 251);
      end loop;

      Ada.Directories.Create_Path (Local_Log_Dir);
      declare
         CSV : Ada.Text_IO.File_Type;
         Host_Summary : Metric_Summary;
         Device_Summary : Metric_Summary;
      begin
         Ada.Text_IO.Create (CSV, Ada.Text_IO.Out_File, CSV_Path);
         Ada.Text_IO.Put_Line (CSV, "iteration,host_ns,device_ns");

         for Iteration in 1 .. Warmup_Iterations + Measurement_Iterations loop
            declare
               Is_Measured : constant Boolean := Iteration > Warmup_Iterations;
               Sample_Id : Sample_Index := Sample_Index'First;
               Start_Time : Ada.Real_Time.Time := Ada.Real_Time.Clock;
               End_Time : Ada.Real_Time.Time := Start_Time;
               Host_Ns : Interfaces.Unsigned_64 := 0;
               Device_Ns : Interfaces.Unsigned_64 := 0;
               Ev : Events.Event;
            begin
               Buffers.Write
                 (Q => Q,
                  B => In_Buffer,
                  Host => Input_Data (Input_Data'First)'Address,
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
                  Device_Ns := Profiling.Duration_Ns (Ev => Ev, Status => Profile_Status);
                  if not Errors.Is_Success (Profile_Status) then
                     if Profile_Status = Errors.Profiling_Info_Not_Available then
                        Profiling_Enabled := False;
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
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("read_buffer", Status);
                  exit;
               end if;

               End_Time := Ada.Real_Time.Clock;
               Host_Ns := To_Nanoseconds (End_Time - Start_Time);

               for J in Output_Data'Range loop
                  if Output_Data (J) /= Byte ((Natural (Input_Data (J)) + 1) mod 256) then
                     Mark_Fail ("validate_output", Errors.Invalid_Value);
                     exit;
                  end if;
               end loop;

               if Failed then
                  exit;
               end if;

               if Is_Measured then
                  Sample_Id := Sample_Index (Iteration - Warmup_Iterations);
                  Host_Samples (Sample_Id) := Host_Ns;
                  if Profiling_Enabled then
                     Device_Samples (Sample_Id) := Device_Ns;
                  end if;

                  if Profiling_Enabled then
                     Ada.Text_IO.Put_Line
                       (CSV,
                        Trim_Integer_Image (Iteration - Warmup_Iterations)
                        & ","
                        & Trim_U64_Image (Host_Ns)
                        & ","
                        & Trim_U64_Image (Device_Ns));
                  else
                     Ada.Text_IO.Put_Line
                       (CSV,
                        Trim_Integer_Image (Iteration - Warmup_Iterations)
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

         Ada.Text_IO.Close (CSV);

         if not Failed then
            Host_Summary := Summarize (Host_Samples);

            Ada.Text_IO.Put_Line
              ("INFO warmup_iterations=" & Trim_Integer_Image (Warmup_Iterations));
            Ada.Text_IO.Put_Line
              ("INFO measure_iterations=" & Trim_Integer_Image (Measurement_Iterations));
            Ada.Text_IO.Put_Line ("INFO csv_path=" & CSV_Path);

            if Profiling_Enabled then
               Ada.Text_IO.Put_Line ("INFO profiling=AVAILABLE");
            elsif not Profiling_Announced then
               Ada.Text_IO.Put_Line ("INFO profiling=UNAVAILABLE");
            end if;

            Ada.Text_IO.Put_Line ("INFO host_ns_min=" & Trim_U64_Image (Host_Summary.Min));
            Ada.Text_IO.Put_Line ("INFO host_ns_avg=" & Trim_U64_Image (Host_Summary.Avg));
            Ada.Text_IO.Put_Line ("INFO host_ns_p50=" & Trim_U64_Image (Host_Summary.P50));
            Ada.Text_IO.Put_Line ("INFO host_ns_p95=" & Trim_U64_Image (Host_Summary.P95));
            Ada.Text_IO.Put_Line ("INFO host_ns_p99=" & Trim_U64_Image (Host_Summary.P99));

            if Profiling_Enabled then
               Device_Summary := Summarize (Device_Samples);
               Ada.Text_IO.Put_Line
                 ("INFO device_ns_min=" & Trim_U64_Image (Device_Summary.Min));
               Ada.Text_IO.Put_Line
                 ("INFO device_ns_avg=" & Trim_U64_Image (Device_Summary.Avg));
               Ada.Text_IO.Put_Line
                 ("INFO device_ns_p50=" & Trim_U64_Image (Device_Summary.P50));
               Ada.Text_IO.Put_Line
                 ("INFO device_ns_p95=" & Trim_U64_Image (Device_Summary.P95));
               Ada.Text_IO.Put_Line
                 ("INFO device_ns_p99=" & Trim_U64_Image (Device_Summary.P99));
            end if;
         end if;
      end;
   end if;

   Cleanup;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      return;
   end if;

   Ada.Text_IO.Put_Line ("RESULT=PASS");
end Bench_Add1;
