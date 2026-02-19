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

procedure Bench_Pipeline_H2D_Kernel_D2H is
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

   use type Errors.Status_Code;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;
   Warmup_Iterations : constant Positive := 10;
   Measurement_Iterations : constant Positive := 200;

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
      P50 : Interfaces.Unsigned_64 := 0;
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

   Write_Samples : Sample_Array := (others => 0);
   Kernel_Samples : Sample_Array := (others => 0);
   Read_Samples : Sample_Array := (others => 0);
   E2E_Samples : Sample_Array := (others => 0);

   Failed : Boolean := False;
   Skipped : Boolean := False;

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
        (P50 => Sorted (Percentile_Index (Samples'Length, 50, 100)),
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

   procedure Mark_Skip (Reason : String) is
   begin
      Ada.Text_IO.Put_Line ("INFO skip_reason=" & Reason);
      Skipped := True;
   end Mark_Skip;

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
      if not Errors.Is_Success (Status) then
         Mark_Skip ("profiling_queue_unavailable");
      elsif not Profiling.Is_Profiling_Available (Q) then
         Mark_Skip ("profiling_not_available");
      else
         Ada.Text_IO.Put_Line ("INFO profiling=AVAILABLE");
      end if;
   end if;

   if not Failed and then not Skipped then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => Transfer_Bytes,
         B => In_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_in_buffer", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => Transfer_Bytes,
         B => Out_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_out_buffer", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Programs.Create_From_Source
        (Ctx => Ctx,
         Source => Kernel_Source,
         Prg => Prg,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_program_from_source", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Programs.Build
        (Prg => Prg,
         Dev => Devices (Devices'First),
         Options => "-cl-std=CL1.2",
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("build_program", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Kernels.Create
        (Prg => Prg,
         Name => "add1",
         K => K,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_kernel", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => 0,
         B => In_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_0", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => 1,
         B => Out_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_1", Status);
      end if;
   end if;

   if not Failed and then not Skipped then
      Ada.Text_IO.Put_Line
        ("INFO warmup_iterations=" & Trim_Integer_Image (Warmup_Iterations));
      Ada.Text_IO.Put_Line
        ("INFO measure_iterations=" & Trim_Integer_Image (Measurement_Iterations));

      for Iteration in 1 .. Warmup_Iterations + Measurement_Iterations loop
         declare
            Is_Measured : constant Boolean := Iteration > Warmup_Iterations;
            Sample_Id : Sample_Index := Sample_Index'First;
            Write_Ev : Events.Event;
            Kernel_Ev : Events.Event;
            Read_Ev : Events.Event;
            Empty_Wait : Events.Event_List (1 .. 0);
            Write_Ns : Interfaces.Unsigned_64 := 0;
            Kernel_Ns : Interfaces.Unsigned_64 := 0;
            Read_Ns : Interfaces.Unsigned_64 := 0;
         begin
            for I in Input_Data'Range loop
               Input_Data (I) := Byte ((I + Iteration) mod 251);
               Output_Data (I) := 0;
            end loop;

            Buffers.Write
              (Q => Q,
               B => In_Buffer,
               Host => Input_Data (Input_Data'First)'Address,
               Bytes => Transfer_Bytes,
               Wait_List => Empty_Wait,
               Ev => Write_Ev,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("write_enqueue", Status);
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            declare
               Write_Wait : constant Events.Event_List (0 .. 0) :=
                 (0 => Write_Ev);
            begin
               Kernels.Enqueue_1D
                 (Q => Q,
                  K => K,
                  Global_Size => Transfer_Bytes,
                  Wait_List => Write_Wait,
                  Ev => Kernel_Ev,
                  Status => Status);
            end;
            if not Errors.Is_Success (Status) then
               Mark_Fail ("kernel_enqueue", Status);
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            declare
               Kernel_Wait : constant Events.Event_List (0 .. 0) :=
                 (0 => Kernel_Ev);
            begin
               Buffers.Read
                 (Q => Q,
                  B => Out_Buffer,
                  Host => Output_Data (Output_Data'First)'Address,
                  Bytes => Transfer_Bytes,
                  Wait_List => Kernel_Wait,
                  Ev => Read_Ev,
                  Status => Status);
            end;
            if not Errors.Is_Success (Status) then
               Mark_Fail ("read_enqueue", Status);
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            Events.Wait_For (Ev => Read_Ev, Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("wait_for_read_event", Status);
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            Write_Ns := Profiling.Duration_Ns (Ev => Write_Ev, Status => Profile_Status);
            if not Errors.Is_Success (Profile_Status) then
               Mark_Skip ("profiling_not_available_runtime");
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            Kernel_Ns := Profiling.Duration_Ns (Ev => Kernel_Ev, Status => Profile_Status);
            if not Errors.Is_Success (Profile_Status) then
               Mark_Skip ("profiling_not_available_runtime");
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            Read_Ns := Profiling.Duration_Ns (Ev => Read_Ev, Status => Profile_Status);
            if not Errors.Is_Success (Profile_Status) then
               Mark_Skip ("profiling_not_available_runtime");
               Release_Event_Safe (Read_Ev);
               Release_Event_Safe (Kernel_Ev);
               Release_Event_Safe (Write_Ev);
               exit;
            end if;

            for J in Output_Data'Range loop
               if Output_Data (J) /= Byte ((Natural (Input_Data (J)) + 1) mod 256) then
                  Mark_Fail ("validate_output", Errors.Invalid_Value);
                  exit;
               end if;
            end loop;

            if Is_Measured and then not Failed and then not Skipped then
               Sample_Id := Sample_Index (Iteration - Warmup_Iterations);
               Write_Samples (Sample_Id) := Write_Ns;
               Kernel_Samples (Sample_Id) := Kernel_Ns;
               Read_Samples (Sample_Id) := Read_Ns;
               E2E_Samples (Sample_Id) := Write_Ns + Kernel_Ns + Read_Ns;
            end if;

            Release_Event_Safe (Read_Ev);
            Release_Event_Safe (Kernel_Ev);
            Release_Event_Safe (Write_Ev);

            exit when Failed or else Skipped;
         end;

         exit when Failed or else Skipped;
      end loop;
   end if;

   if not Failed and then not Skipped then
      declare
         Write_Summary : constant Metric_Summary := Summarize (Write_Samples);
         Kernel_Summary : constant Metric_Summary := Summarize (Kernel_Samples);
         Read_Summary : constant Metric_Summary := Summarize (Read_Samples);
         E2E_Summary : constant Metric_Summary := Summarize (E2E_Samples);
      begin
         Ada.Text_IO.Put_Line
           ("INFO write_ns_p50=" & Trim_U64_Image (Write_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO write_ns_p99=" & Trim_U64_Image (Write_Summary.P99));
         Ada.Text_IO.Put_Line
           ("INFO kernel_ns_p50=" & Trim_U64_Image (Kernel_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO kernel_ns_p99=" & Trim_U64_Image (Kernel_Summary.P99));
         Ada.Text_IO.Put_Line
           ("INFO read_ns_p50=" & Trim_U64_Image (Read_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO read_ns_p99=" & Trim_U64_Image (Read_Summary.P99));
         Ada.Text_IO.Put_Line
           ("INFO e2e_ns_p50=" & Trim_U64_Image (E2E_Summary.P50));
         Ada.Text_IO.Put_Line
           ("INFO e2e_ns_p99=" & Trim_U64_Image (E2E_Summary.P99));
      end;
   end if;

   Cleanup;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      return;
   end if;

   if Skipped then
      Ada.Text_IO.Put_Line ("RESULT=SKIP");
      return;
   end if;

   Ada.Text_IO.Put_Line ("RESULT=PASS");
end Bench_Pipeline_H2D_Kernel_D2H;
