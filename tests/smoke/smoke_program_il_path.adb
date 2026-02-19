with Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;

procedure Smoke_Program_IL_Path is
   --  OCLW-TST-0023: clCreateProgramWithIL path readiness / controlled skip.
   package Core renames OpenCL.Core;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Programs renames OpenCL.Core.Programs;

   use type Errors.Status_Code;
   use type Interfaces.C.int;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;

   --  Dummy IL blob (SPIR-V magic + placeholder bytes). Expected to fail on
   --  most runtimes with a controlled OpenCL status.
   Dummy_IL : Programs.Byte_Array (1 .. 8) :=
     (16#03#, 16#02#, 16#23#, 16#07#,
      16#00#, 16#00#, 16#00#, 16#00#);

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;

   Ctx : Contexts.Context;
   Prg : Programs.Program;

   Status : Errors.Status_Code := Errors.Success;
   Build_Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

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
      Programs.Release (Prg => Prg, Status => Release_Status);
      if Release_Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("WARN release_program=" & Errors.Image (Release_Status));
      end if;

      Contexts.Release (Ctx => Ctx, Status => Release_Status);
      if Release_Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("WARN release_context=" & Errors.Image (Release_Status));
      end if;
   end Cleanup;

begin
   Ada.Text_IO.Put_Line ("INFO il_dummy_bytes=" & Natural'Image (Dummy_IL'Length));

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
   if Status /= Errors.Success then
      Mark_Fail ("create_context", Status);
   end if;

   if not Failed then
      Programs.Create_From_IL
        (Ctx => Ctx,
         Data => Dummy_IL,
         Prg => Prg,
         Status => Status);

      Ada.Text_IO.Put_Line
        ("INFO create_from_il_status="
         & Errors.Image (Status)
         & " status_int="
         & Status_Int_Image (Status));

      if Status = Errors.Success then
         Programs.Build
           (Prg => Prg,
            Dev => Devices (Devices'First),
            Options => "",
            Status => Build_Status);

         Ada.Text_IO.Put_Line
           ("INFO il_build_status="
            & Errors.Image (Build_Status)
            & " status_int="
            & Status_Int_Image (Build_Status));

         if Build_Status = Errors.Success then
            Ada.Text_IO.Put_Line ("RESULT=PASS");
         elsif Build_Status = Errors.Invalid_Binary
           or else Build_Status = Errors.Build_Program_Failure
           or else Build_Status = Errors.Invalid_Operation
           or else Build_Status = Errors.Invalid_Value
           or else Build_Status = Errors.Compiler_Not_Available
         then
            Ada.Text_IO.Put_Line
              ("RESULT=SKIP reason=il_build_controlled_failure");
         else
            Mark_Fail ("build_il_program", Build_Status);
         end if;
      elsif Status = Errors.Invalid_Operation then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=il_not_supported");
      elsif Status = Errors.Invalid_Value
        or else Status = Errors.Invalid_Binary
        or else Status = Errors.Compiler_Not_Available
      then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=il_create_controlled_failure");
      else
         Mark_Fail ("create_program_from_il", Status);
      end if;
   end if;

   Cleanup;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
exception
   when others =>
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Smoke_Program_IL_Path;
