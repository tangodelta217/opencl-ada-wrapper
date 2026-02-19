with Interfaces;

package body OpenCL.RT.Constant_Time is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   function Max_Natural (A, B : Natural) return Natural is
   begin
      if A >= B then
         return A;
      else
         return B;
      end if;
   end Max_Natural;

   function Ct_Equal
     (A : OpenCL.Core.Programs.Byte_Array;
      B : OpenCL.Core.Programs.Byte_Array) return Boolean
   is
      Acc : Interfaces.Unsigned_64 := 0;
      Max_Len : constant Natural := Max_Natural (A'Length, B'Length);
   begin
      if Max_Len > 0 then
         for Offset in 0 .. Max_Len - 1 loop
            declare
               A_Byte : Interfaces.Unsigned_8 := 0;
               B_Byte : Interfaces.Unsigned_8 := 0;
            begin
               if Offset < A'Length then
                  A_Byte :=
                    Interfaces.Unsigned_8
                      (A (A'First + Integer (Offset)));
               end if;

               if Offset < B'Length then
                  B_Byte :=
                    Interfaces.Unsigned_8
                      (B (B'First + Integer (Offset)));
               end if;

               Acc :=
                 Acc
                 or Interfaces.Unsigned_64 (A_Byte xor B_Byte);
            end;
         end loop;
      end if;

      Acc :=
        Acc
        or
          (Interfaces.Unsigned_64 (A'Length)
           xor Interfaces.Unsigned_64 (B'Length));

      return Acc = 0;
   end Ct_Equal;

   function Ct_Equal (A, B : String) return Boolean is
      Acc : Interfaces.Unsigned_64 := 0;
      Max_Len : constant Natural := Max_Natural (A'Length, B'Length);
   begin
      if Max_Len > 0 then
         for Offset in 0 .. Max_Len - 1 loop
            declare
               A_Byte : Interfaces.Unsigned_8 := 0;
               B_Byte : Interfaces.Unsigned_8 := 0;
            begin
               if Offset < A'Length then
                  A_Byte :=
                    Interfaces.Unsigned_8
                      (Character'Pos (A (A'First + Integer (Offset))));
               end if;

               if Offset < B'Length then
                  B_Byte :=
                    Interfaces.Unsigned_8
                      (Character'Pos (B (B'First + Integer (Offset))));
               end if;

               Acc :=
                 Acc
                 or Interfaces.Unsigned_64 (A_Byte xor B_Byte);
            end;
         end loop;
      end if;

      Acc :=
        Acc
        or
          (Interfaces.Unsigned_64 (A'Length)
           xor Interfaces.Unsigned_64 (B'Length));

      return Acc = 0;
   end Ct_Equal;

end OpenCL.RT.Constant_Time;
