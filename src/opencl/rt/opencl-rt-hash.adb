with Interfaces;

package body OpenCL.RT.Hash is

   use type Interfaces.Unsigned_32;

   function FNV1a_32
     (Data : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return Interfaces.Unsigned_32
   is
      Offset_Basis : constant Interfaces.Unsigned_32 := 16#811C9DC5#;
      Prime : constant Interfaces.Unsigned_32 := 16#01000193#;
      Hash : Interfaces.Unsigned_32 := Offset_Basis;
      Effective_Used : constant Natural := Natural'Min (Used, Data'Length);
   begin
      if Effective_Used = 0 then
         return Offset_Basis;
      end if;

      for Offset in 0 .. Effective_Used - 1 loop
         declare
            Index : constant Positive := Data'First + Integer (Offset);
         begin
            Hash :=
              (Hash xor Interfaces.Unsigned_32 (Data (Index))) * Prime;
         end;
      end loop;

      return Hash;
   end FNV1a_32;

   function Hex_Image (Value : Interfaces.Unsigned_32) return String is
      Hex_Digits : constant array (Natural range 0 .. 15) of Character :=
        "0123456789ABCDEF";
      Result : String (1 .. 10) := "0x00000000";
   begin
      for Pos in 0 .. 7 loop
         declare
            Shift : constant Natural := (7 - Pos) * 4;
            Nibble : constant Natural :=
              Natural
                ((Interfaces.Shift_Right (Value, Shift))
                 and Interfaces.Unsigned_32 (16#0000_000F#));
         begin
            Result (Pos + 3) := Hex_Digits (Nibble);
         end;
      end loop;

      return Result;
   end Hex_Image;

end OpenCL.RT.Hash;
