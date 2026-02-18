with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces;

package body Smoke_RT_Test_Verifier is

   use type Interfaces.Unsigned_32;
   use type OpenCL.Errors.Status_Code;

   FNV1A32_Offset_Basis : constant Interfaces.Unsigned_32 := 16#811C9DC5#;
   FNV1A32_Prime : constant Interfaces.Unsigned_32 := 16#01000193#;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Nibble_To_Hex (Nibble : Interfaces.Unsigned_32) return Character is
   begin
      if Nibble < 10 then
         return Character'Val (Character'Pos ('0') + Integer (Nibble));
      else
         return Character'Val (Character'Pos ('A') + Integer (Nibble - 10));
      end if;
   end Nibble_To_Hex;

   function U32_Hex8 (Value : Interfaces.Unsigned_32) return String is
      Result : String (1 .. 8);
   begin
      for I in Result'Range loop
         declare
            Shift : constant Natural := (8 - I) * 4;
            Nibble : constant Interfaces.Unsigned_32 :=
              Interfaces.Shift_Right (Value, Shift) and 16#0F#;
         begin
            Result (I) := Nibble_To_Hex (Nibble);
         end;
      end loop;

      return Result;
   end U32_Hex8;

   function Compute_Test_Signature
     (Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return String
   is
      Hash : Interfaces.Unsigned_32 := FNV1A32_Offset_Basis;

      procedure Update_Hash (Value : Interfaces.Unsigned_8) is
      begin
         Hash := (Hash xor Interfaces.Unsigned_32 (Value)) * FNV1A32_Prime;
      end Update_Hash;
   begin
      if Used = 0 or else Used > Bin'Length then
         return "";
      end if;

      for C of Signing_Text loop
         Update_Hash (Interfaces.Unsigned_8 (Character'Pos (C)));
      end loop;

      for Offset in 0 .. Used - 1 loop
         Update_Hash (Interfaces.Unsigned_8 (Bin (Bin'First + Integer (Offset))));
      end loop;

      return U32_Hex8 (Hash);
   end Compute_Test_Signature;

   function Verify
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code
   is
      Signature_Alg : constant String :=
        Ada.Characters.Handling.To_Upper
          (Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Alg)));
      Signature_Value : constant String :=
        Ada.Characters.Handling.To_Upper
          (Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Value)));
      Expected : constant String :=
        Ada.Characters.Handling.To_Upper
          (Compute_Test_Signature
             (Signing_Text => Signing_Text,
              Bin => Bin,
              Used => Used));
   begin
      if Signature_Alg /= "TEST-FNV1A32" then
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;

      if Signature_Value'Length = 0 then
         return OpenCL.Errors.OCLW_Signature_Missing;
      end if;

      if Expected'Length = 0 then
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;

      if Signature_Value = Expected then
         return OpenCL.Errors.Success;
      else
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;
   end Verify;

end Smoke_RT_Test_Verifier;
