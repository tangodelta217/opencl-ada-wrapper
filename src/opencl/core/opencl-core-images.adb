with OpenCL.Core.Contexts;
with OpenCL.Core.Queues;
with System;

package body OpenCL.Core.Images is

   use type API.cl_command_queue;
   use type API.cl_context;
   use type API.cl_int;
   use type API.cl_mem;
   use type API.size_t;
   use type System.Address;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Create_Image2D_RGBA8
     (Ctx : OpenCL.Core.Contexts.Context;
      Width : Interfaces.C.size_t;
      Height : Interfaces.C.size_t;
      Img : out Image;
      Status : out Status_Code)
   is
      Raw_Ctx : constant API.cl_context := OpenCL.Core.Contexts.Raw_Handle (Ctx);
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
      Image_Format : aliased API.cl_image_format :=
        (image_channel_order => API.CL_RGBA,
         image_channel_data_type => API.CL_UNSIGNED_INT8);
      Image_Desc : aliased API.cl_image_desc :=
        (image_type => API.CL_MEM_OBJECT_IMAGE2D,
         image_width => API.size_t (Width),
         image_height => API.size_t (Height),
         image_depth => 0,
         image_array_size => 0,
         image_row_pitch => 0,
         image_slice_pitch => 0,
         num_mip_levels => 0,
         num_samples => 0,
         buffer => null);
   begin
      Img.Handle := null;
      Status := OpenCL.Errors.Success;

      if Raw_Ctx = null then
         Status := OpenCL.Errors.Invalid_Context;
         return;
      end if;

      if Width = 0 or else Height = 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Img.Handle := API.clCreateImage
        (context => Raw_Ctx,
         flags => API.CL_MEM_READ_WRITE,
         image_format => Image_Format'Access,
         image_desc => Image_Desc'Access,
         host_ptr => System.Null_Address,
         errcode_ret => Error_Code'Access);

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if Img.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
      end if;
   end Create_Image2D_RGBA8;

   procedure Write
     (Q : OpenCL.Core.Queues.Queue;
      Img : Image;
      Host : System.Address;
      Width : Interfaces.C.size_t;
      Height : Interfaces.C.size_t;
      Row_Pitch : Interfaces.C.size_t := 0;
      Status : out Status_Code)
   is
      type Size_Vector is array (0 .. 2) of aliased API.size_t;

      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Origin : aliased Size_Vector := (0, 0, 0);
      Region : aliased Size_Vector :=
        (API.size_t (Width), API.size_t (Height), 1);
   begin
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if Img.Handle = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      if Width = 0 or else Height = 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      if Host = System.Null_Address then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Raw_Status := API.clEnqueueWriteImage
        (command_queue => Raw_Queue,
         image => Img.Handle,
         blocking_write => API.CL_TRUE,
         origin => Origin (Origin'First)'Address,
         region => Region (Region'First)'Address,
         input_row_pitch => API.size_t (Row_Pitch),
         input_slice_pitch => 0,
         ptr => Host,
         num_events_in_wait_list => 0,
         event_wait_list => null,
         event => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      Raw_Status := API.clFinish (Raw_Queue);
      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Write;

   procedure Read
     (Q : OpenCL.Core.Queues.Queue;
      Img : Image;
      Host : System.Address;
      Width : Interfaces.C.size_t;
      Height : Interfaces.C.size_t;
      Row_Pitch : Interfaces.C.size_t := 0;
      Status : out Status_Code)
   is
      type Size_Vector is array (0 .. 2) of aliased API.size_t;

      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Origin : aliased Size_Vector := (0, 0, 0);
      Region : aliased Size_Vector :=
        (API.size_t (Width), API.size_t (Height), 1);
   begin
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if Img.Handle = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      if Width = 0 or else Height = 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      if Host = System.Null_Address then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Raw_Status := API.clEnqueueReadImage
        (command_queue => Raw_Queue,
         image => Img.Handle,
         blocking_read => API.CL_TRUE,
         origin => Origin (Origin'First)'Address,
         region => Region (Region'First)'Address,
         row_pitch => API.size_t (Row_Pitch),
         slice_pitch => 0,
         ptr => Host,
         num_events_in_wait_list => 0,
         event_wait_list => null,
         event => null);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      Raw_Status := API.clFinish (Raw_Queue);
      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Read;

   procedure Release
     (Img : in out Image;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if Img.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseMemObject (Img.Handle);
      if Raw_Status = API.CL_SUCCESS then
         Img.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   function Raw_Handle (Img : Image) return OpenCL.Raw.API.cl_mem is
   begin
      return Img.Handle;
   end Raw_Handle;

end OpenCL.Core.Images;
