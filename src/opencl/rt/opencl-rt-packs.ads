with Ada.Strings.Bounded;
with Interfaces;
with Interfaces.C;
with OpenCL.Core.Programs;
with OpenCL.Errors;

package OpenCL.RT.Packs is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   Max_Field_Length : constant Positive := 512;
   package Fields is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Field_Length);
   subtype Bounded_String is Fields.Bounded_String;

   function To_String (Value : Bounded_String) return String
     renames Fields.To_String;

   function To_Bounded (Value : String) return Bounded_String;

   type Pack_Metadata is record
      Kpack_Version : Natural := 0;
      Pack_Id : Bounded_String := Fields.To_Bounded_String ("");
      Created_Utc : Bounded_String := Fields.To_Bounded_String ("");

      Platform_Name : Bounded_String := Fields.To_Bounded_String ("");
      Platform_Vendor : Bounded_String := Fields.To_Bounded_String ("");
      Platform_Version : Bounded_String := Fields.To_Bounded_String ("");

      Device_Name : Bounded_String := Fields.To_Bounded_String ("");
      Device_Vendor : Bounded_String := Fields.To_Bounded_String ("");
      Device_Version : Bounded_String := Fields.To_Bounded_String ("");
      Driver_Version : Bounded_String := Fields.To_Bounded_String ("");

      OpenCL_C_Version : Bounded_String := Fields.To_Bounded_String ("");
      Build_Options : Bounded_String := Fields.To_Bounded_String ("");

      Binary_Size : Interfaces.C.size_t := 0;
      Binary_FNV1a32 : Interfaces.Unsigned_32 := 0;
      Kernel_Name : Bounded_String := Fields.To_Bounded_String ("");
   end record;

   procedure Read_Manifest
     (Path : String;
      Meta : out Pack_Metadata;
      Status : out Status_Code);

   procedure Write_Manifest
     (Path : String;
      Meta : Pack_Metadata;
      Status : out Status_Code);

   procedure Read_Binary
     (Path : String;
      Buffer : out OpenCL.Core.Programs.Byte_Array;
      Used : out Natural;
      Status : out Status_Code);

   procedure Verify_Binary
     (Meta : Pack_Metadata;
      Buffer : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Status : out Status_Code);
end OpenCL.RT.Packs;
