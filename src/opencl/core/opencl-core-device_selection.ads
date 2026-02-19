with OpenCL.Core;
with OpenCL.Errors;

package OpenCL.Core.Device_Selection is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   type Selection_Result is record
      Platform : OpenCL.Core.Platform;
      Device : OpenCL.Core.Device;
      Status : Status_Code := OpenCL.Errors.Success;
   end record;

   --  Deterministic selection policy:
   --  - candidates are filtered by exact fingerprint match for non-empty fields;
   --  - best candidate order is:
   --      1) device_vendor
   --      2) device_name
   --      3) driver_version
   --      4) platform_vendor
   --      5) platform_name
   --      6) platform_index, device_index (enumeration tiebreak)
   --  - if all expected fields are empty, selects deterministic "first" device.
   function Select_Device
     (Expected_Platform_Name : String := "";
      Expected_Platform_Vendor : String := "";
      Expected_Platform_Version : String := "";
      Expected_Device_Name : String := "";
      Expected_Device_Vendor : String := "";
      Expected_Device_Version : String := "";
      Expected_Driver_Version : String := "") return Selection_Result;
end OpenCL.Core.Device_Selection;
