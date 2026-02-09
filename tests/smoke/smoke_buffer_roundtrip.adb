with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with System;

procedure Smoke_Buffer_Roundtrip is
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Queues renames OpenCL.Core.Queues;

   use type Errors.Status_Code;
   use type Interfaces.C.unsigned_char;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;

   subtype Byte is Interfaces.C.unsigned_char;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Byte_Array is array (Byte_Index) of aliased Byte;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Host_Data : Byte_Array := (others => 0);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   B : Buffers.Buffer;

   Failed : Boolean := False;

   procedure Mark_Fail (Step : String; Code : Errors.Status_Code) is
   begin
      Ada.Text_IO.Put_Line ("ERROR " & Step & ": " & Errors.Image (Code));
      Failed := True;
   end Mark_Fail;

   procedure Cleanup is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Buffers.Release (B => B, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_buffer: " & Errors.Image (Release_Status));
      end if;

      Queues.Release (Q => Q, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_queue: " & Errors.Image (Release_Status));
      end if;

      Contexts.Release (Ctx => Ctx, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_context: " & Errors.Image (Release_Status));
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

   Contexts.Create
     (Device => Devices (Devices'First),
      Ctx => Ctx,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_context", Status);
      Cleanup;
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Queues.Create
     (Ctx => Ctx,
      Dev => Devices (Devices'First),
      Q => Q,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_queue", Status);
      Cleanup;
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Buffers.Create
     (Ctx => Ctx,
      Bytes => Transfer_Bytes,
      B => B,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_buffer", Status);
      Cleanup;
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   for I in Host_Data'Range loop
      Host_Data (I) := Byte (I mod 256);
   end loop;

   Buffers.Write
     (Q => Q,
      B => B,
      Host => Host_Data (Host_Data'First)'Address,
      Bytes => Transfer_Bytes,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("write_buffer", Status);
   end if;

   if not Failed then
      for I in Host_Data'Range loop
         Host_Data (I) := 0;
      end loop;

      Buffers.Read
        (Q => Q,
         B => B,
         Host => Host_Data (Host_Data'First)'Address,
         Bytes => Transfer_Bytes,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_buffer", Status);
      end if;
   end if;

   if not Failed then
      declare
         Mismatch_Count : Natural := 0;
         First_Mismatch_Index : Natural := 0;
         First_Expected : Byte := 0;
         First_Actual : Byte := 0;
      begin
         for I in Host_Data'Range loop
            declare
               Expected : constant Byte := Byte (I mod 256);
            begin
               if Host_Data (I) /= Expected then
                  if Mismatch_Count = 0 then
                     First_Mismatch_Index := I;
                     First_Expected := Expected;
                     First_Actual := Host_Data (I);
                  end if;
                  Mismatch_Count := Mismatch_Count + 1;
               end if;
            end;
         end loop;

         if Mismatch_Count > 0 then
            Ada.Text_IO.Put_Line
              ("ERROR roundtrip_mismatch count=" & Natural'Image (Mismatch_Count));
            Ada.Text_IO.Put_Line
              ("ERROR first_mismatch index=" & Natural'Image (First_Mismatch_Index)
               & " expected=" & Byte'Image (First_Expected)
               & " actual=" & Byte'Image (First_Actual));
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
end Smoke_Buffer_Roundtrip;
