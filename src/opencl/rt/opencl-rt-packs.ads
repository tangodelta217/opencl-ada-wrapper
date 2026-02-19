with Ada.Strings.Bounded;
with Interfaces;
with Interfaces.C;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;

package OpenCL.RT.Packs is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   subtype Status_Code is OpenCL.Errors.Status_Code;

   Max_Field_Length : constant Positive := 512;
   Max_Manifest_Line_Length : constant Positive := 2_048;
   Max_Manifest_Bytes : constant Positive := 65_536;
   Max_Manifest_Key_Count : constant Positive := 64;
   Max_RT_Binary_Size_Default : constant Interfaces.C.size_t :=
     Interfaces.C.size_t (16_777_216);

   package Fields is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Field_Length);
   subtype Bounded_String is Fields.Bounded_String;

   function To_String (Value : Bounded_String) return String
     renames Fields.To_String;

   function To_Bounded (Value : String) return Bounded_String;

   type Pack_Metadata is record
      Kpack_Version : Natural := 0;
      Pack_Version : Interfaces.Unsigned_32 := 0;
      Pack_Version_Present : Boolean := False;
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
      Monotonic_Counter : Interfaces.Unsigned_64 := 0;
      Monotonic_Counter_Present : Boolean := False;
      Kernel_Name : Bounded_String := Fields.To_Bounded_String ("");

      Signature_Required : Boolean := False;
      Signature_Alg : Bounded_String := Fields.To_Bounded_String ("");
      Signature_Value : Bounded_String := Fields.To_Bounded_String ("");
      Signer_Id : Bounded_String := Fields.To_Bounded_String ("");
   end record;

   procedure Read_Manifest
     (Path : String;
      Meta : out Pack_Metadata;
      Status : out Status_Code);

   --  Canonical writer policy:
   --  - fixed key order;
   --  - each line encoded as key=value + LF;
   --  - '\' and '=' are escaped as '\\' and '\=';
   --  - values containing LF/CR are rejected (format error).
   procedure Write_Manifest
     (Path : String;
      Meta : Pack_Metadata;
      Status : out Status_Code);

   Max_Canonical_Signing_Text_Length : constant Positive := 20_480;
   --  Returns canonical signing text without signature_* fields and without
   --  comments. Returns the empty string on format/bounds error; callers
   --  should map this to OCLW_PACK_FORMAT_ERROR.
   function Canonical_Signing_Text (Meta : Pack_Metadata) return String;

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

   --  Effective RT binary size limit (bytes). Controlled by optional env var
   --  OCLW_RT_MAX_BINARY_SIZE; invalid/empty values fall back to default.
   function Effective_Max_RT_Binary_Size return Interfaces.C.size_t;
end OpenCL.RT.Packs;
