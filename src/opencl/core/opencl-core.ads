with OpenCL.Errors;
with OpenCL.Raw.API;

package OpenCL.Core is
   subtype Status_Code is OpenCL.Errors.Status_Code;

   Default_Max_Info_Bytes : constant Positive := 4096;

   type Platform is private;
   type Device is private;

   type Platform_List is array (Positive range <>) of Platform;
   type Device_List is array (Positive range <>) of Device;

   type Platform_Info_Kind is (Name, Vendor, Version);
   type Device_Info_Kind is (Name, Vendor, Version, Driver_Version);

   procedure Enumerate_Platforms
     (Out_Platforms : out Platform_List;
      Used : out Natural;
      Status : out OpenCL.Errors.Status_Code);

   procedure Enumerate_Devices
     (P : Platform;
      Out_Devices : out Device_List;
      Used : out Natural;
      Status : out Status_Code);

   function Get_Platform_Info
     (P : Platform;
      What : Platform_Info_Kind;
      Status : out OpenCL.Errors.Status_Code;
      Max_Bytes : Positive := Default_Max_Info_Bytes) return String;

   function Get_Device_Info
     (D : Device;
      What : Device_Info_Kind;
      Status : out OpenCL.Errors.Status_Code;
      Max_Bytes : Positive := Default_Max_Info_Bytes) return String;

   function Device_Image_Support
     (D : Device;
      Status : out OpenCL.Errors.Status_Code) return Boolean;

private
   package API renames OpenCL.Raw.API;

   type Platform is record
      Handle : API.cl_platform_id := null;
   end record;

   type Device is record
      Handle : API.cl_device_id := null;
   end record;
end OpenCL.Core;
