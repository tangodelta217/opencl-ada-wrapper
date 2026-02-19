with Ada.Strings;
with Ada.Strings.Fixed;
with OpenCL.RT.Constant_Time;
with Smoke_RT_Test_Verifier;

package body Smoke_RT_Build_Options_Verifier is

   use type OpenCL.Errors.Status_Code;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Verify
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code
   is
      Signature_Value : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Value));
      Expected : constant String :=
        Smoke_RT_Test_Verifier.Compute_Test_Signature
          (Signing_Text => Signing_Text,
           Bin => Bin,
           Used => Used);
   begin
      if Signature_Value'Length = 0 then
         return OpenCL.Errors.OCLW_Signature_Missing;
      end if;

      if Expected'Length = 0 then
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;

      if OpenCL.RT.Constant_Time.Ct_Equal (Signature_Value, Expected) then
         return OpenCL.Errors.Success;
      else
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;
   end Verify;

end Smoke_RT_Build_Options_Verifier;
