with OpenCL.Errors;
with OpenCL.Raw.API;

package OpenCL.Core.Events is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Event is private;
   type Event_List is array (Natural range <>) of Event;

   --  Helper for sibling child packages that receive raw OpenCL events.
   procedure Adopt
     (Raw : OpenCL.Raw.API.cl_event;
      Ev : out Event);

   procedure Release
     (Ev : in out Event;
      Status : out Status_Code);

   procedure Wait_For
     (Ev : Event;
      Status : out Status_Code);

   procedure Wait_For
     (List : Event_List;
      Status : out Status_Code);

   function Raw_Handle (Ev : Event) return OpenCL.Raw.API.cl_event;

private
   package API renames OpenCL.Raw.API;

   type Event is record
      Handle : API.cl_event := null;
   end record;
end OpenCL.Core.Events;
