with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.Core.Buffers;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with System;

package body OpenCL.Core.Kernels is

   use type API.cl_command_queue;
   use type API.cl_int;
   use type API.cl_kernel;
   use type API.cl_mem;
   use type API.cl_program;
   use type API.size_t;
   use type Interfaces.C.unsigned_long_long;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Create
     (Prg : OpenCL.Core.Programs.Program;
      Name : String;
      K : out Kernel;
      Status : out Status_Code)
   is
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
      Name_Ptr : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
   begin
      K.Handle := null;
      Status := OpenCL.Errors.Success;

      if OpenCL.Core.Programs.Raw_Handle (Prg) = null then
         Status := OpenCL.Errors.Invalid_Program;
         return;
      end if;

      if Name'Length = 0 then
         Status := OpenCL.Errors.Invalid_Kernel_Name;
         return;
      end if;

      Name_Ptr := Interfaces.C.Strings.New_String (Name);
      K.Handle := API.clCreateKernel
        (program => OpenCL.Core.Programs.Raw_Handle (Prg),
         kernel_name => Name_Ptr,
         errcode_ret => Error_Code'Access);
      Interfaces.C.Strings.Free (Name_Ptr);

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if K.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;
   end Create;

   procedure Set_Arg_Buffer
     (K : Kernel;
      Index : Natural;
      B : OpenCL.Core.Buffers.Buffer;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Buffer : aliased API.cl_mem := null;
      Arg_Size : constant API.size_t :=
        API.size_t (API.cl_mem'Size / System.Storage_Unit);
      Index_Wide : constant Interfaces.C.unsigned_long_long :=
        Interfaces.C.unsigned_long_long (Index);
   begin
      Status := OpenCL.Errors.Success;

      if K.Handle = null then
         Status := OpenCL.Errors.Invalid_Kernel;
         return;
      end if;

      if Index_Wide > Interfaces.C.unsigned_long_long (API.cl_uint'Last) then
         Status := OpenCL.Errors.Invalid_Arg_Index;
         return;
      end if;

      Raw_Buffer := OpenCL.Core.Buffers.Raw_Handle (B);
      if Raw_Buffer = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      Raw_Status := API.clSetKernelArg
        (kernel => K.Handle,
         arg_index => API.cl_uint (Index_Wide),
         arg_size => Arg_Size,
         arg_value => Raw_Buffer'Address);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Set_Arg_Buffer;

   procedure Enqueue_1D
     (Q : OpenCL.Core.Queues.Queue;
      K : Kernel;
      Global_Size : Interfaces.C.size_t;
      Status : out Status_Code)
   is
      type Size_Vector is array (0 .. 0) of aliased API.size_t;

      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Global_Work_Size : aliased Size_Vector := (0 => API.size_t (Global_Size));
   begin
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if K.Handle = null then
         Status := OpenCL.Errors.Invalid_Kernel;
         return;
      end if;

      if Global_Size = 0 then
         Status := OpenCL.Errors.Invalid_Global_Work_Size;
         return;
      end if;

      Raw_Status := API.clEnqueueNDRangeKernel
        (command_queue => Raw_Queue,
         kernel => K.Handle,
         work_dim => 1,
         global_work_offset => System.Null_Address,
         global_work_size => Global_Work_Size (0)'Address,
         local_work_size => System.Null_Address,
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
   end Enqueue_1D;

   procedure Release
     (K : in out Kernel;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if K.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseKernel (K.Handle);
      if Raw_Status = API.CL_SUCCESS then
         K.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

end OpenCL.Core.Kernels;
