with Ada.Text_IO;
with Interfaces.C;
with OpenCL.Raw.API;
with System;

procedure Smoke_Platforms is
   --  OCLW-TST-0002: Enumerate OpenCL platforms/devices via thin raw API.

   package API renames OpenCL.Raw.API;

   use type API.cl_int;
   use type API.cl_uint;
   use type API.cl_device_type;
   use type API.size_t;

   procedure Print_Error (Step : String; Code : API.cl_int) is
   begin
      Ada.Text_IO.Put_Line ("ERROR " & Step & " =>" & API.cl_int'Image (Code));
   end Print_Error;

   function Get_Platform_String
     (Platform : API.cl_platform_id;
      Param : API.cl_platform_info;
      Step : String) return String
   is
      Needed : aliased API.size_t := 0;
      Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := API.clGetPlatformInfo
        (platform => Platform,
         param_name => Param,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Status /= API.CL_SUCCESS then
         Print_Error (Step & "(size)", Status);
         return "<error>";
      end if;

      if Needed = 0 then
         return "<empty>";
      end if;

      declare
         Buffer : aliased Interfaces.C.char_array (0 .. Needed - 1);
      begin
         Status := API.clGetPlatformInfo
           (platform => Platform,
            param_name => Param,
            param_value_size => Needed,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Status /= API.CL_SUCCESS then
            Print_Error (Step & "(value)", Status);
            return "<error>";
         end if;

         return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
      end;
   end Get_Platform_String;

   function Get_Device_String
     (Device : API.cl_device_id;
      Param : API.cl_device_info;
      Step : String) return String
   is
      Needed : aliased API.size_t := 0;
      Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := API.clGetDeviceInfo
        (device => Device,
         param_name => Param,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Status /= API.CL_SUCCESS then
         Print_Error (Step & "(size)", Status);
         return "<error>";
      end if;

      if Needed = 0 then
         return "<empty>";
      end if;

      declare
         Buffer : aliased Interfaces.C.char_array (0 .. Needed - 1);
      begin
         Status := API.clGetDeviceInfo
           (device => Device,
            param_name => Param,
            param_value_size => Needed,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Status /= API.CL_SUCCESS then
            Print_Error (Step & "(value)", Status);
            return "<error>";
         end if;

         return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
      end;
   end Get_Device_String;

   function Get_Device_Type
     (Device : API.cl_device_id;
      Ok : out Boolean) return API.cl_device_type
   is
      Value : aliased API.cl_device_type := 0;
      Status : API.cl_int := API.CL_SUCCESS;
      Type_Size : constant API.size_t :=
        API.size_t (API.cl_device_type'Size / System.Storage_Unit);
   begin
      Status := API.clGetDeviceInfo
        (device => Device,
         param_name => API.CL_DEVICE_TYPE,
         param_value_size => Type_Size,
         param_value => Value'Address,
         param_value_size_ret => null);

      if Status /= API.CL_SUCCESS then
         Print_Error ("clGetDeviceInfo(device_type)", Status);
         Ok := False;
         return 0;
      end if;

      Ok := True;
      return Value;
   end Get_Device_Type;

   Status : API.cl_int := API.CL_SUCCESS;
   Platform_Count : aliased API.cl_uint := 0;
begin
   Status := API.clGetPlatformIDs
     (num_entries => 0,
      platforms => null,
      num_platforms => Platform_Count'Access);

   if Status /= API.CL_SUCCESS then
      Print_Error ("clGetPlatformIDs(count)", Status);
      return;
   end if;

   Ada.Text_IO.Put_Line ("platform_count=" & API.cl_uint'Image (Platform_Count));

   if Platform_Count = 0 then
      return;
   end if;

   declare
      Platforms : API.cl_platform_id_array (0 .. API.size_t (Platform_Count) - 1);
   begin
      Status := API.clGetPlatformIDs
        (num_entries => Platform_Count,
         platforms => Platforms (Platforms'First)'Access,
         num_platforms => null);

      if Status /= API.CL_SUCCESS then
         Print_Error ("clGetPlatformIDs(list)", Status);
         return;
      end if;

      for Platform_Index in Platforms'Range loop
         declare
            Platform : constant API.cl_platform_id := Platforms (Platform_Index);
            Platform_Name : constant String :=
              Get_Platform_String
                (Platform => Platform,
                 Param => API.CL_PLATFORM_NAME,
                 Step => "clGetPlatformInfo(platform_name)");
            Platform_Vendor : constant String :=
              Get_Platform_String
                (Platform => Platform,
                 Param => API.CL_PLATFORM_VENDOR,
                 Step => "clGetPlatformInfo(platform_vendor)");
            Platform_Version : constant String :=
              Get_Platform_String
                (Platform => Platform,
                 Param => API.CL_PLATFORM_VERSION,
                 Step => "clGetPlatformInfo(platform_version)");
            Device_Count : aliased API.cl_uint := 0;
         begin
            Ada.Text_IO.Put_Line ("Platform[" & API.size_t'Image (Platform_Index) & "]");
            Ada.Text_IO.Put_Line ("  name    : " & Platform_Name);
            Ada.Text_IO.Put_Line ("  vendor  : " & Platform_Vendor);
            Ada.Text_IO.Put_Line ("  version : " & Platform_Version);

            Status := API.clGetDeviceIDs
              (platform => Platform,
               device_type => API.CL_DEVICE_TYPE_ALL,
               num_entries => 0,
               devices => null,
               num_devices => Device_Count'Access);

            if Status /= API.CL_SUCCESS then
               Print_Error ("clGetDeviceIDs(count)", Status);
               Ada.Text_IO.Put_Line ("  device_count=<error>");
            else
               Ada.Text_IO.Put_Line ("  device_count=" & API.cl_uint'Image (Device_Count));

               if Device_Count > 0 then
                  declare
                     Devices : API.cl_device_id_array (0 .. API.size_t (Device_Count) - 1);
                  begin
                     Status := API.clGetDeviceIDs
                       (platform => Platform,
                        device_type => API.CL_DEVICE_TYPE_ALL,
                        num_entries => Device_Count,
                        devices => Devices (Devices'First)'Access,
                        num_devices => null);

                     if Status /= API.CL_SUCCESS then
                        Print_Error ("clGetDeviceIDs(list)", Status);
                     else
                        for Device_Index in Devices'Range loop
                           declare
                              Device : constant API.cl_device_id := Devices (Device_Index);
                              Device_Name : constant String :=
                                Get_Device_String
                                  (Device => Device,
                                   Param => API.CL_DEVICE_NAME,
                                   Step => "clGetDeviceInfo(device_name)");
                              Device_Vendor : constant String :=
                                Get_Device_String
                                  (Device => Device,
                                   Param => API.CL_DEVICE_VENDOR,
                                   Step => "clGetDeviceInfo(device_vendor)");
                              Device_Version : constant String :=
                                Get_Device_String
                                  (Device => Device,
                                   Param => API.CL_DEVICE_VERSION,
                                   Step => "clGetDeviceInfo(device_version)");
                              Device_Type_Ok : Boolean := False;
                              Device_Type : API.cl_device_type :=
                                Get_Device_Type (Device => Device, Ok => Device_Type_Ok);
                           begin
                              Ada.Text_IO.Put_Line
                                ("  Device[" & API.size_t'Image (Device_Index) & "]");
                              Ada.Text_IO.Put_Line ("    name    : " & Device_Name);
                              Ada.Text_IO.Put_Line ("    vendor  : " & Device_Vendor);
                              Ada.Text_IO.Put_Line ("    version : " & Device_Version);

                              if Device_Type_Ok then
                                 Ada.Text_IO.Put_Line
                                   ("    type    :" & API.cl_device_type'Image (Device_Type));
                              else
                                 Ada.Text_IO.Put_Line ("    type    : <error>");
                              end if;
                           end;
                        end loop;
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
   end;
end Smoke_Platforms;
