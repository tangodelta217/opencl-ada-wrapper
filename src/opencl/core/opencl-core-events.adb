with Interfaces.C;

package body OpenCL.Core.Events is

   use type API.cl_event;
   use type API.cl_int;
   use type API.cl_uint;
   use type API.size_t;
   use type Interfaces.C.unsigned_long_long;

   function To_Status (Code : API.cl_int) return OpenCL.Errors.Status_Code is
   begin
      return OpenCL.Errors.Status_Code (Code);
   end To_Status;

   procedure Adopt
     (Raw : OpenCL.Raw.API.cl_event;
      Ev : out Event)
   is
   begin
      Ev.Handle := Raw;
   end Adopt;

   procedure Release
     (Ev : in out Event;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := OpenCL.Errors.Success;

      if Ev.Handle = null then
         return;
      end if;

      Raw_Status := API.clReleaseEvent (Ev.Handle);
      if Raw_Status = API.CL_SUCCESS then
         Ev.Handle := null;
      else
         Status := To_Status (Raw_Status);
      end if;
   end Release;

   procedure Wait_For
     (Ev : Event;
      Status : out Status_Code)
   is
      List : Event_List (0 .. 0) := (0 => Ev);
   begin
      Wait_For (List => List, Status => Status);
   end Wait_For;

   procedure Wait_For
     (List : Event_List;
      Status : out Status_Code)
   is
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Count_Wide : Interfaces.C.unsigned_long_long := 0;
   begin
      Status := OpenCL.Errors.Success;

      if List'Length = 0 then
         return;
      end if;

      Count_Wide := Interfaces.C.unsigned_long_long (List'Length);
      if Count_Wide > Interfaces.C.unsigned_long_long (API.cl_uint'Last) then
         Status := OpenCL.Errors.Invalid_Value;
         return;
      end if;

      declare
         Raw_List : API.cl_event_array (0 .. API.size_t (List'Length - 1));
      begin
         for Pos in 0 .. List'Length - 1 loop
            Raw_List (API.size_t (Pos)) :=
              Raw_Handle (List (List'First + Pos));
            if Raw_List (API.size_t (Pos)) = null then
               Status := OpenCL.Errors.Invalid_Event_Wait_List;
               return;
            end if;
         end loop;

         Raw_Status := API.clWaitForEvents
           (num_events => API.cl_uint (Count_Wide),
            event_list => Raw_List (Raw_List'First)'Access);
      end;

      if Raw_Status /= API.CL_SUCCESS then
         Status := To_Status (Raw_Status);
      end if;
   end Wait_For;

   function Raw_Handle (Ev : Event) return OpenCL.Raw.API.cl_event is
   begin
      return Ev.Handle;
   end Raw_Handle;

end OpenCL.Core.Events;
