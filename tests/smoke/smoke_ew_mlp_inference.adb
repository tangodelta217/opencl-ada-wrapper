with Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with EW_MLP_Kernel_Source;
with EW_MLP_Model;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Kernels;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with System;

procedure Smoke_EW_MLP_Inference is
   --  OCLW-TST-0401
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package Model renames EW_MLP_Model;

   use type Errors.Status_Code;
   use type Interfaces.C.size_t;
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned_char;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Batch_Samples : constant Positive := 256;

   subtype Sample_Index is Natural range 0 .. Batch_Samples - 1;
   subtype Feature_Index is Model.Feature_Index;
   subtype Output_Index is Model.Output_Index;

   type Input_Flat_Array is
     array (Natural range 0 .. Batch_Samples * Model.Input_Size - 1) of
       aliased Interfaces.C.unsigned_char;
   type Logits_Flat_Array is
     array (Natural range 0 .. Batch_Samples * Model.Output_Size - 1) of
       aliased Interfaces.C.int;
   type Class_Flat_Array is
     array (Natural range 0 .. Batch_Samples - 1) of
       aliased Interfaces.C.unsigned_char;
   type Confusion_Matrix is array (Output_Index, Output_Index) of Natural;

   Input_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Batch_Samples * Model.Input_Size);
   Logits_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t
       (Batch_Samples
        * Model.Output_Size
        * (Interfaces.C.int'Size / System.Storage_Unit));
   Class_Bytes : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (Batch_Samples);

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);

   X_Batch : Model.Batch_Byte_Array (Sample_Index);
   Labels_Expected : Model.Batch_Class_Array (Sample_Index);
   Logits_CPU : Model.Batch_Logit_Array (Sample_Index);
   Classes_CPU : Model.Batch_Class_Array (Sample_Index);

   X_Flat : Input_Flat_Array := (others => 0);
   Logits_Device : Logits_Flat_Array := (others => 0);
   Classes_Device : Class_Flat_Array := (others => 0);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   X_Buffer : Buffers.Buffer;
   Logits_Buffer : Buffers.Buffer;
   Class_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Failed : Boolean := False;

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

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

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
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_kernel: " & Errors.Image (Release_Status));
      end if;

      Programs.Release (Prg => Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_program: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => Class_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_class_buffer: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => Logits_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_logits_buffer: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => X_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line ("WARN release_x_buffer: " & Errors.Image (Release_Status));
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

   if not Model.Self_Check then
      Ada.Text_IO.Put_Line ("ERROR cpu_self_check=FAIL");
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
      for F in Feature_Index loop
         X_Flat (Natural (S) * Model.Input_Size + Natural (F)) :=
           Interfaces.C.unsigned_char (X_Batch (S) (F));
      end loop;
   end loop;

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
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_queue", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => Input_Bytes,
         B => X_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_x_buffer", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => Logits_Bytes,
         B => Logits_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_logits_buffer", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => Class_Bytes,
         B => Class_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_class_buffer", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Write
        (Q => Q,
         B => X_Buffer,
         Host => X_Flat (X_Flat'First)'Address,
         Bytes => Input_Bytes,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("write_x", Status);
      end if;
   end if;

   if not Failed then
      Programs.Create_From_Source
        (Ctx => Ctx,
         Source => EW_MLP_Kernel_Source.Source,
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
         Options => EW_MLP_Kernel_Source.Build_Options,
         Status => Status);
      if not Errors.Is_Success (Status) then
         declare
            Log_Status : Errors.Status_Code := Errors.Success;
            Build_Log : constant String :=
              Programs.Build_Log
                (Prg => Prg,
                 Dev => Devices (Devices'First),
                 Status => Log_Status,
                 Max_Bytes => 65_536);
         begin
            Ada.Text_IO.Put_Line
              ("ERROR build_program: "
               & Errors.Image (Status)
               & " status_int="
               & Status_Int_Image (Status));
            if Errors.Is_Success (Log_Status) then
               Ada.Text_IO.Put_Line ("BUILD_LOG_BEGIN");
               if Build_Log'Length = 0 then
                  Ada.Text_IO.Put_Line ("<empty>");
               else
                  Ada.Text_IO.Put_Line (Build_Log);
               end if;
               Ada.Text_IO.Put_Line ("BUILD_LOG_END");
            else
               Ada.Text_IO.Put_Line
                 ("ERROR build_log: "
                  & Errors.Image (Log_Status)
                  & " status_int="
                  & Status_Int_Image (Log_Status));
            end if;
            Failed := True;
         end;
      end if;
   end if;

   if not Failed then
      Kernels.Create
        (Prg => Prg,
         Name => EW_MLP_Kernel_Source.Kernel_Name,
         K => K,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_kernel", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => EW_MLP_Kernel_Source.Arg_X,
         B => X_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_x", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => EW_MLP_Kernel_Source.Arg_Logits,
         B => Logits_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_logits", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => EW_MLP_Kernel_Source.Arg_Cls,
         B => Class_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_cls", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Enqueue_1D
        (Q => Q,
         K => K,
         Global_Size => Interfaces.C.size_t (Batch_Samples),
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("enqueue_1d", Status);
      end if;
   end if;

   if not Failed then
      Queues.Finish (Q => Q, Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("finish_queue", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Read
        (Q => Q,
         B => Logits_Buffer,
         Host => Logits_Device (Logits_Device'First)'Address,
         Bytes => Logits_Bytes,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_logits", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Read
        (Q => Q,
         B => Class_Buffer,
         Host => Classes_Device (Classes_Device'First)'Address,
         Bytes => Class_Bytes,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_classes", Status);
      end if;
   end if;

   if not Failed then
      declare
         Logit_Mismatch_Count : Natural := 0;
         Class_Mismatch_Count : Natural := 0;
         CPU_Expected_Mismatch_Count : Natural := 0;
         Out_Of_Range_Class_Count : Natural := 0;
         Correct_Count : Natural := 0;
         CM : Confusion_Matrix := (others => (others => 0));
      begin
         for S in Sample_Index loop
            declare
               Expected : constant Natural := Natural (Labels_Expected (S));
               CPU_Class : constant Natural := Natural (Classes_CPU (S));
               Device_Class : constant Natural := Natural (Classes_Device (S));
            begin
               if CPU_Class /= Expected then
                  CPU_Expected_Mismatch_Count := CPU_Expected_Mismatch_Count + 1;
               end if;

               if Device_Class <= Output_Index'Last then
                  CM (Output_Index (Expected), Output_Index (Device_Class)) :=
                    CM (Output_Index (Expected), Output_Index (Device_Class)) + 1;
               else
                  Out_Of_Range_Class_Count := Out_Of_Range_Class_Count + 1;
               end if;

               if Device_Class = Expected then
                  Correct_Count := Correct_Count + 1;
               end if;

               if Device_Class /= CPU_Class or else Device_Class /= Expected then
                  Class_Mismatch_Count := Class_Mismatch_Count + 1;
               end if;

               for O in Output_Index loop
                  declare
                     Flat : constant Natural :=
                       Natural (S) * Model.Output_Size + Natural (O);
                  begin
                     if Integer (Logits_Device (Flat))
                        /= Integer (Logits_CPU (S) (O))
                     then
                        Logit_Mismatch_Count := Logit_Mismatch_Count + 1;
                     end if;
                  end;
               end loop;
            end;
         end loop;

         Ada.Text_IO.Put_Line
           ("INFO batch=" & Trim_Natural_Image (Batch_Samples));
         Ada.Text_IO.Put_Line
           ("INFO accuracy="
            & Trim_Natural_Image (Correct_Count)
            & "/"
            & Trim_Natural_Image (Batch_Samples));
         Ada.Text_IO.Put_Line
           ("INFO logits_mismatches=" & Trim_Natural_Image (Logit_Mismatch_Count));
         Ada.Text_IO.Put_Line
           ("INFO class_mismatches=" & Trim_Natural_Image (Class_Mismatch_Count));
         Ada.Text_IO.Put_Line
           ("INFO cpu_expected_mismatches="
            & Trim_Natural_Image (CPU_Expected_Mismatch_Count));
         Ada.Text_IO.Put_Line
           ("INFO class_out_of_range="
            & Trim_Natural_Image (Out_Of_Range_Class_Count));

         for R in Output_Index loop
            Ada.Text_IO.Put_Line
              ("INFO confusion_row_"
               & Trim_Natural_Image (Natural (R))
               & "="
               & Trim_Natural_Image (CM (R, 0))
               & ","
               & Trim_Natural_Image (CM (R, 1))
               & ","
               & Trim_Natural_Image (CM (R, 2))
               & ","
               & Trim_Natural_Image (CM (R, 3)));
         end loop;

         if Logit_Mismatch_Count > 0
           or else Class_Mismatch_Count > 0
           or else CPU_Expected_Mismatch_Count > 0
           or else Out_Of_Range_Class_Count > 0
         then
            Failed := True;
         end if;
      end;
   end if;

   Cleanup;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
   end if;
end Smoke_EW_MLP_Inference;
