with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;

package OpenCL.RT.Loader is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   procedure Select_Device
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Platform : out OpenCL.Core.Platform;
      Device : out OpenCL.Core.Device;
      Status : out Status_Code);

   procedure Create_Program_From_Pack
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Meta : OpenCL.RT.Packs.Pack_Metadata;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Prg : out OpenCL.Core.Programs.Program;
      Status : out Status_Code);
end OpenCL.RT.Loader;
