with Interfaces.C;
with OpenCL.Core.Contexts;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.Raw.API;
with System;

package OpenCL.Core.Images is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Image is private;

   procedure Create_Image2D_RGBA8
     (Ctx : OpenCL.Core.Contexts.Context;
      Width : Interfaces.C.size_t;
      Height : Interfaces.C.size_t;
      Img : out Image;
      Status : out Status_Code);

   procedure Write
     (Q : OpenCL.Core.Queues.Queue;
      Img : Image;
      Host : System.Address;
      Width : Interfaces.C.size_t;
      Height : Interfaces.C.size_t;
      Row_Pitch : Interfaces.C.size_t := 0;
      Status : out Status_Code);

   procedure Read
     (Q : OpenCL.Core.Queues.Queue;
      Img : Image;
      Host : System.Address;
      Width : Interfaces.C.size_t;
      Height : Interfaces.C.size_t;
      Row_Pitch : Interfaces.C.size_t := 0;
      Status : out Status_Code);

   procedure Release
     (Img : in out Image;
      Status : out Status_Code);

   --  Helper required by sibling child packages (Kernels).
   function Raw_Handle (Img : Image) return OpenCL.Raw.API.cl_mem;

private
   package API renames OpenCL.Raw.API;

   type Image is record
      Handle : API.cl_mem := null;
   end record;
end OpenCL.Core.Images;
