package body OpenCL.Core.Events is

   use type API.cl_event;
   use type API.cl_int;

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

   function Raw_Handle (Ev : Event) return OpenCL.Raw.API.cl_event is
   begin
      return Ev.Handle;
   end Raw_Handle;

end OpenCL.Core.Events;
