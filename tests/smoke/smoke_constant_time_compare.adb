with Ada.Command_Line;
with Ada.Text_IO;
with OpenCL.Core.Programs;
with OpenCL.RT.Constant_Time;

procedure Smoke_Constant_Time_Compare is
   package Programs renames OpenCL.Core.Programs;
   package Constant_Time renames OpenCL.RT.Constant_Time;

   A : Programs.Byte_Array (1 .. 4) := (16#01#, 16#02#, 16#03#, 16#04#);
   B : Programs.Byte_Array (1 .. 4) := (16#01#, 16#02#, 16#03#, 16#04#);
   C : Programs.Byte_Array (1 .. 4) := (16#01#, 16#02#, 16#03#, 16#05#);
   D : Programs.Byte_Array (1 .. 3) := (16#01#, 16#02#, 16#03#);

   Failed : Boolean := False;

   procedure Expect (Name : String; Condition : Boolean) is
   begin
      if Condition then
         Ada.Text_IO.Put_Line ("INFO " & Name & "=PASS");
      else
         Ada.Text_IO.Put_Line ("ERROR " & Name & "=FAIL");
         Failed := True;
      end if;
   end Expect;
begin
   Expect
     (Name => "bytes_equal",
      Condition => Constant_Time.Ct_Equal (A, B));
   Expect
     (Name => "bytes_not_equal",
      Condition => not Constant_Time.Ct_Equal (A, C));
   Expect
     (Name => "bytes_len_mismatch",
      Condition => not Constant_Time.Ct_Equal (A, D));

   Expect
     (Name => "string_equal",
      Condition => Constant_Time.Ct_Equal ("OCLW-TEST", "OCLW-TEST"));
   Expect
     (Name => "string_not_equal",
      Condition => not Constant_Time.Ct_Equal ("OCLW-TEST", "OCLW-T3ST"));
   Expect
     (Name => "string_len_mismatch",
      Condition => not Constant_Time.Ct_Equal ("OCLW-TEST", "OCLW"));

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
   end if;
end Smoke_Constant_Time_Compare;
