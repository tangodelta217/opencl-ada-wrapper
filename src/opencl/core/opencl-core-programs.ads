with Interfaces;
with Interfaces.C;
with OpenCL.Core.Contexts;
with OpenCL.Errors;
with OpenCL.Raw.API;
with System;

package OpenCL.Core.Programs is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Program is private;

   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Positive range <>) of Byte;
   type Size_T_Array is array (Positive range <>) of Interfaces.C.size_t;
   type Buffer_Ptr_Array is array (Positive range <>) of System.Address;

   Max_Binary_Devices : constant Positive := 16;

   procedure Create_From_Source
     (Ctx : OpenCL.Core.Contexts.Context;
      Source : String;
      Prg : out Program;
      Status : out Status_Code);

   procedure Create_From_IL
     (Ctx : OpenCL.Core.Contexts.Context;
      Data : Byte_Array;
      Prg : out Program;
      Status : out Status_Code);

   procedure Build
     (Prg : Program;
      Dev : OpenCL.Core.Device;
      Options : String;
      Status : out Status_Code);

   function Build_Log
     (Prg : Program;
      Dev : OpenCL.Core.Device;
      Status : out Status_Code;
      Max_Bytes : Positive := 65_536) return String;

   function Source
     (Prg : Program;
      Status : out Status_Code;
      Max_Bytes : Positive := 16_384) return String;

   procedure Num_Devices
     (Prg : Program;
      N : out Interfaces.C.size_t;
      Status : out Status_Code);

   procedure Binary_Size_At
     (Prg : Program;
      Index : Natural;
      Bytes : out Interfaces.C.size_t;
      Status : out Status_Code);

   --  Multi-device extraction path:
   --  caller provides one pointer and capacity entry per program device.
   procedure Get_Binaries
     (Prg : Program;
      Ptrs : Buffer_Ptr_Array;
      Sizes : Size_T_Array;
      Status : out Status_Code);

   procedure Binary_Size
     (Prg : Program;
      Bytes : out Interfaces.C.size_t;
      Status : out Status_Code);

   procedure Get_Binary
     (Prg : Program;
      Data : out Byte_Array;
      Used : out Natural;
      Status : out Status_Code);

   --  Single-device wrapper:
   --  requires program associated with exactly one device and Index = 0.
   procedure Get_Binary_At
     (Prg : Program;
      Index : Natural;
      Data : out Byte_Array;
      Used : out Natural;
      Status : out Status_Code);

   procedure Create_From_Binary_At
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Data : Byte_Array;
      Prg : out Program;
      Binary_Status : out OpenCL.Errors.Status_Code;
      Status : out OpenCL.Errors.Status_Code);

   procedure Create_From_Binary
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Data : Byte_Array;
      Prg : out Program;
      Binary_Status : out OpenCL.Errors.Status_Code;
      Status : out OpenCL.Errors.Status_Code);

   procedure Release
     (Prg : in out Program;
      Status : out Status_Code);

   --  Helper required by sibling child package Kernels.
   function Raw_Handle (Prg : Program) return OpenCL.Raw.API.cl_program;

private
   package API renames OpenCL.Raw.API;

   type Program is record
      Handle : API.cl_program := null;
   end record;
end OpenCL.Core.Programs;
