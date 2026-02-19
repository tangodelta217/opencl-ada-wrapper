with OpenCL.Core.Contexts;
with OpenCL.Core.Events;
with OpenCL.Core.Queues;
with System;

package body OpenCL.Core.Buffers is

   use type API.cl_command_queue;
   use type API.cl_context;
   use type API.cl_event;
   use type API.cl_int;
   use type API.cl_uint;
   use type API.cl_mem;
   use type API.size_t;
   use type Interfaces.C.unsigned_long_long;
   use type System.Address;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Create
     (Ctx : OpenCL.Core.Contexts.Context;
      Bytes : Interfaces.C.size_t;
      B : out Buffer;
      Status : out Status_Code)
   is
      Error_Code : aliased API.cl_int := API.CL_SUCCESS;
      Raw_Ctx : constant API.cl_context := OpenCL.Core.Contexts.Raw_Handle (Ctx);
   begin
      B.Handle := null;
      Status := OpenCL.Errors.Success;

      if Raw_Ctx = null then
         Status := OpenCL.Errors.Invalid_Context;
         return;
      end if;

      B.Handle := API.clCreateBuffer
        (context => Raw_Ctx,
         flags => API.CL_MEM_READ_WRITE,
         size => API.size_t (Bytes),
         host_ptr => System.Null_Address,
         errcode_ret => Error_Code'Access);

      if Error_Code /= API.CL_SUCCESS then
         Status := To_Status (Error_Code);
         return;
      end if;

      if B.Handle = null then
         Status := OpenCL.Errors.Out_Of_Resources;
         return;
      end if;
   end Create;

   procedure Release
     (B : in out Buffer;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if B.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseMemObject (B.Handle);
      if Raw_Status = API.CL_SUCCESS then
         B.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   procedure Write
     (Q : OpenCL.Core.Queues.Queue;
      B : Buffer;
      Host : System.Address;
      Bytes : size_t;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
   begin
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if B.Handle = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      if Host = System.Null_Address and then Bytes /= 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Raw_Status := API.clEnqueueWriteBuffer
        (command_queue => Raw_Queue,
         buffer => B.Handle,
         blocking_write => API.CL_TRUE,
         offset => 0,
         size => API.size_t (Bytes),
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

   procedure Write
     (Q : OpenCL.Core.Queues.Queue;
      B : Buffer;
      Host : System.Address;
      Bytes : size_t;
      Wait_List : OpenCL.Core.Events.Event_List;
      Ev : out OpenCL.Core.Events.Event;
      Status : out Status_Code)
   is
      package Events renames OpenCL.Core.Events;

      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Raw_Event : aliased API.cl_event := null;
      Count_Wide : Interfaces.C.unsigned_long_long := 0;
   begin
      Events.Adopt (Raw => null, Ev => Ev);
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if B.Handle = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      if Host = System.Null_Address and then Bytes /= 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Count_Wide := Interfaces.C.unsigned_long_long (Wait_List'Length);
      if Count_Wide > Interfaces.C.unsigned_long_long (API.cl_uint'Last) then
         Status := OpenCL.Errors.Invalid_Event_Wait_List;
         return;
      end if;

      if Wait_List'Length = 0 then
         Raw_Status := API.clEnqueueWriteBuffer
           (command_queue => Raw_Queue,
            buffer => B.Handle,
            blocking_write => API.CL_FALSE,
            offset => 0,
            size => API.size_t (Bytes),
            ptr => Host,
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

            Raw_Status := API.clEnqueueWriteBuffer
              (command_queue => Raw_Queue,
               buffer => B.Handle,
               blocking_write => API.CL_FALSE,
               offset => 0,
               size => API.size_t (Bytes),
               ptr => Host,
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
   end Write;

   procedure Read
     (Q : OpenCL.Core.Queues.Queue;
      B : Buffer;
      Host : System.Address;
      Bytes : size_t;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
   begin
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if B.Handle = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      if Host = System.Null_Address and then Bytes /= 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Raw_Status := API.clEnqueueReadBuffer
        (command_queue => Raw_Queue,
         buffer => B.Handle,
         blocking_read => API.CL_TRUE,
         offset => 0,
         size => API.size_t (Bytes),
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

   procedure Read
     (Q : OpenCL.Core.Queues.Queue;
      B : Buffer;
      Host : System.Address;
      Bytes : size_t;
      Wait_List : OpenCL.Core.Events.Event_List;
      Ev : out OpenCL.Core.Events.Event;
      Status : out Status_Code)
   is
      package Events renames OpenCL.Core.Events;

      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Raw_Queue : constant API.cl_command_queue := OpenCL.Core.Queues.Raw_Handle (Q);
      Raw_Event : aliased API.cl_event := null;
      Count_Wide : Interfaces.C.unsigned_long_long := 0;
   begin
      Events.Adopt (Raw => null, Ev => Ev);
      Status := OpenCL.Errors.Success;

      if Raw_Queue = null then
         Status := OpenCL.Errors.Invalid_Command_Queue;
         return;
      end if;

      if B.Handle = null then
         Status := OpenCL.Errors.Invalid_Mem_Object;
         return;
      end if;

      if Host = System.Null_Address and then Bytes /= 0 then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      Count_Wide := Interfaces.C.unsigned_long_long (Wait_List'Length);
      if Count_Wide > Interfaces.C.unsigned_long_long (API.cl_uint'Last) then
         Status := OpenCL.Errors.Invalid_Event_Wait_List;
         return;
      end if;

      if Wait_List'Length = 0 then
         Raw_Status := API.clEnqueueReadBuffer
           (command_queue => Raw_Queue,
            buffer => B.Handle,
            blocking_read => API.CL_FALSE,
            offset => 0,
            size => API.size_t (Bytes),
            ptr => Host,
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

            Raw_Status := API.clEnqueueReadBuffer
              (command_queue => Raw_Queue,
               buffer => B.Handle,
               blocking_read => API.CL_FALSE,
               offset => 0,
               size => API.size_t (Bytes),
               ptr => Host,
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
   end Read;

   function Raw_Handle (B : Buffer) return OpenCL.Raw.API.cl_mem is
   begin
      return B.Handle;
   end Raw_Handle;

end OpenCL.Core.Buffers;
