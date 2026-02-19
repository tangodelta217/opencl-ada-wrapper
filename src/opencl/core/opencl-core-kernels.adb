with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.Core.Buffers;
with OpenCL.Core.Events;
with OpenCL.Core.Images;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Core.Samplers;
with System;

package body OpenCL.Core.Kernels is

   use type API.cl_command_queue;
   use type API.cl_event;
   use type API.cl_int;
   use type API.cl_kernel;
   use type API.cl_mem;
   use type API.cl_program;
   use type API.cl_sampler;
   use type API.size_t;
   use type Interfaces.C.unsigned_long_long;
   use type OpenCL.Errors.Status_Code;

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

   procedure Set_Arg_Image
     (K : Kernel;
      Index : Natural;
      Img : OpenCL.Core.Images.Image;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Image : aliased API.cl_mem := null;
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

      Raw_Image := OpenCL.Core.Images.Raw_Handle (Img);
      if Raw_Image = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      Raw_Status := API.clSetKernelArg
        (kernel => K.Handle,
         arg_index => API.cl_uint (Index_Wide),
         arg_size => Arg_Size,
         arg_value => Raw_Image'Address);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Set_Arg_Image;

   procedure Set_Arg_Sampler
     (K : Kernel;
      Index : Natural;
      S : OpenCL.Core.Samplers.Sampler;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Sampler : aliased API.cl_sampler := null;
      Arg_Size : constant API.size_t :=
        API.size_t (API.cl_sampler'Size / System.Storage_Unit);
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

      Raw_Sampler := OpenCL.Core.Samplers.Raw_Handle (S);
      if Raw_Sampler = null then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Raw_Status := API.clSetKernelArg
        (kernel => K.Handle,
         arg_index => API.cl_uint (Index_Wide),
         arg_size => Arg_Size,
         arg_value => Raw_Sampler'Address);

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Set_Arg_Sampler;

   procedure Enqueue_1D
     (Q : OpenCL.Core.Queues.Queue;
      K : Kernel;
      Global_Size : Interfaces.C.size_t;
      Status : out Status_Code)
   is
      Ev : OpenCL.Core.Events.Event;
      Release_Status : Status_Code := OpenCL.Errors.Success;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      Enqueue_1D
        (Q => Q,
         K => K,
         Global_Size => Global_Size,
         Ev => Ev,
         Status => Status);
      if Status /= OpenCL.Errors.Success then
         return;
      end if;

      Raw_Status := API.clFinish (Raw_Queue);
      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;

      OpenCL.Core.Events.Release
        (Ev => Ev,
         Status => Release_Status);
      if Status = OpenCL.Errors.Success and then Release_Status /= OpenCL.Errors.Success then
         Status := Release_Status;
      end if;
   end Enqueue_1D;

   procedure Enqueue_1D
     (Q : OpenCL.Core.Queues.Queue;
      K : Kernel;
      Global_Size : Interfaces.C.size_t;
      Ev : out OpenCL.Core.Events.Event;
      Status : out Status_Code)
   is
      Empty_Wait_List : OpenCL.Core.Events.Event_List (1 .. 0);
   begin
      Enqueue_1D
        (Q => Q,
         K => K,
         Global_Size => Global_Size,
         Wait_List => Empty_Wait_List,
         Ev => Ev,
         Status => Status);
   end Enqueue_1D;

   procedure Enqueue_1D
     (Q : OpenCL.Core.Queues.Queue;
      K : Kernel;
      Global_Size : Interfaces.C.size_t;
      Wait_List : OpenCL.Core.Events.Event_List;
      Ev : out OpenCL.Core.Events.Event;
      Status : out Status_Code)
   is
      package Events renames OpenCL.Core.Events;

      type Size_Vector is array (0 .. 0) of aliased API.size_t;

      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Global_Work_Size : aliased Size_Vector := (0 => API.size_t (Global_Size));
      Raw_Event : aliased API.cl_event := null;
      Count_Wide : Interfaces.C.unsigned_long_long := 0;
   begin
      Events.Adopt (Raw => null, Ev => Ev);
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

      Count_Wide := Interfaces.C.unsigned_long_long (Wait_List'Length);
      if Count_Wide > Interfaces.C.unsigned_long_long (API.cl_uint'Last) then
         Status := OpenCL.Errors.Invalid_Event_Wait_List;
         return;
      end if;

      if Wait_List'Length = 0 then
         Raw_Status := API.clEnqueueNDRangeKernel
           (command_queue => Raw_Queue,
            kernel => K.Handle,
            work_dim => 1,
            global_work_offset => System.Null_Address,
            global_work_size => Global_Work_Size (0)'Address,
            local_work_size => System.Null_Address,
            num_events_in_wait_list => 0,
            event_wait_list => null,
            event => Raw_Event'Access);
      else
         declare
            Raw_Wait_List : API.cl_event_array (0 .. API.size_t (Wait_List'Length - 1));
         begin
            for Pos in 0 .. Wait_List'Length - 1 loop
               Raw_Wait_List (API.size_t (Pos)) :=
                 Events.Raw_Handle (Wait_List (Wait_List'First + Pos));
               if Raw_Wait_List (API.size_t (Pos)) = null then
                  Status := OpenCL.Errors.Invalid_Event_Wait_List;
                  return;
               end if;
            end loop;

            Raw_Status := API.clEnqueueNDRangeKernel
              (command_queue => Raw_Queue,
               kernel => K.Handle,
               work_dim => 1,
               global_work_offset => System.Null_Address,
               global_work_size => Global_Work_Size (0)'Address,
               local_work_size => System.Null_Address,
               num_events_in_wait_list => API.cl_uint (Count_Wide),
               event_wait_list => Raw_Wait_List (Raw_Wait_List'First)'Access,
               event => Raw_Event'Access);
         end;
      end if;

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
         return;
      end if;

      if Raw_Event = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;

      Events.Adopt (Raw => Raw_Event, Ev => Ev);
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
