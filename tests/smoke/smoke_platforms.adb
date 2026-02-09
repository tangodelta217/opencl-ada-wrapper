with Ada.Text_IO;
with Interfaces.C;
with OpenCL.Raw.API;
with System;

procedure Smoke_Platforms is
   --  OCLW-TST-0002: Enumerate OpenCL platforms/devices via thin raw API.

   package API renames OpenCL.Raw.API;

   use type API.cl_int;
   use type API.cl_uint;
   use type API.cl_device_type_mask;
   use type API.size_t;

   Max_Platforms : constant Natural := 16;
   Max_Devices_Per_Platform : constant Natural := 64;
   Max_Info_Bytes : constant API.size_t := 4096;

   subtype Platform_Index is Positive range 1 .. Max_Platforms;
   subtype Device_Index is Positive range 1 .. Max_Devices_Per_Platform;

   type Platform_Array is array (Platform_Index) of aliased API.cl_platform_id;
   type Device_Array is array (Device_Index) of aliased API.cl_device_id;

   subtype Info_Buffer is Interfaces.C.char_array (0 .. Max_Info_Bytes - 1);

   Null_Platform : constant API.cl_platform_id := null;
   Null_Device : constant API.cl_device_id := null;

   procedure Print_Error (Step : String; Code : API.cl_int) is
   begin
      Ada.Text_IO.Put_Line ("ERROR " & Step & " =>" & API.cl_int'Image (Code));
   end Print_Error;

   procedure Print_Warning (Message : String) is
   begin
      Ada.Text_IO.Put_Line ("WARN " & Message);
   end Print_Warning;

   function Clamp_Count
     (Reported : API.cl_uint;
      Limit : Natural;
      Label : String) return Natural
   is
   begin
      if Reported > API.cl_uint (Limit) then
         Print_Warning
           (Label & " reported=" & API.cl_uint'Image (Reported)
            & " exceeds limit=" & Natural'Image (Limit) & "; clamped");
         return Limit;
      end if;

      return Natural (Reported);
   end Clamp_Count;

   function Get_Platform_Info_String
     (Platform : API.cl_platform_id;
      Param : API.cl_platform_info) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
      Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := API.clGetPlatformInfo
        (platform => Platform,
         param_name => Param,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Status /= API.CL_SUCCESS then
         Print_Error
           ("clGetPlatformInfo(size,param=" & API.cl_platform_info'Image (Param) & ")",
            Status);
         return "<error>";
      end if;

      if Needed = 0 then
         return "<empty>";
      end if;

      if Needed > Max_Info_Bytes then
         Print_Warning
           ("clGetPlatformInfo(param=" & API.cl_platform_info'Image (Param)
            & ") size=" & API.size_t'Image (Needed)
            & " exceeds limit=" & API.size_t'Image (Max_Info_Bytes)
            & "; truncating");
         Copy_Size := Max_Info_Bytes;
      else
         Copy_Size := Needed;
      end if;

      Status := API.clGetPlatformInfo
        (platform => Platform,
         param_name => Param,
         param_value_size => Copy_Size,
         param_value => Buffer (Buffer'First)'Address,
         param_value_size_ret => null);

      if Status /= API.CL_SUCCESS then
         Print_Error
           ("clGetPlatformInfo(value,param=" & API.cl_platform_info'Image (Param) & ")",
            Status);
         return "<error>";
      end if;

      Buffer (Buffer'Last) := Interfaces.C.nul;
      return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
   end Get_Platform_Info_String;

   function Get_Device_Info_String
     (Device : API.cl_device_id;
      Param : API.cl_device_info) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
      Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      Status : API.cl_int := API.CL_SUCCESS;
   begin
      Status := API.clGetDeviceInfo
        (device => Device,
         param_name => Param,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Status /= API.CL_SUCCESS then
         Print_Error
           ("clGetDeviceInfo(size,param=" & API.cl_device_info'Image (Param) & ")",
            Status);
         return "<error>";
      end if;

      if Needed = 0 then
         return "<empty>";
      end if;

      if Needed > Max_Info_Bytes then
         Print_Warning
           ("clGetDeviceInfo(param=" & API.cl_device_info'Image (Param)
            & ") size=" & API.size_t'Image (Needed)
            & " exceeds limit=" & API.size_t'Image (Max_Info_Bytes)
            & "; truncating");
         Copy_Size := Max_Info_Bytes;
      else
         Copy_Size := Needed;
      end if;

      Status := API.clGetDeviceInfo
        (device => Device,
         param_name => Param,
         param_value_size => Copy_Size,
         param_value => Buffer (Buffer'First)'Address,
         param_value_size_ret => null);

      if Status /= API.CL_SUCCESS then
         Print_Error
           ("clGetDeviceInfo(value,param=" & API.cl_device_info'Image (Param) & ")",
            Status);
         return "<error>";
      end if;

      Buffer (Buffer'Last) := Interfaces.C.nul;
      return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
   end Get_Device_Info_String;

   function Get_Device_Type
     (Device : API.cl_device_id;
      Ok : out Boolean) return API.cl_device_type_mask
   is
      Value : aliased API.cl_device_type_mask := 0;
      Status : API.cl_int := API.CL_SUCCESS;
      Type_Size : constant API.size_t :=
        API.size_t (API.cl_device_type_mask'Size / System.Storage_Unit);
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

   function Platform_Less
     (Left : API.cl_platform_id;
      Right : API.cl_platform_id) return Boolean
   is
      Left_Vendor : constant String :=
        Get_Platform_Info_String (Left, API.CL_PLATFORM_VENDOR);
      Right_Vendor : constant String :=
        Get_Platform_Info_String (Right, API.CL_PLATFORM_VENDOR);
      Left_Name : constant String :=
        Get_Platform_Info_String (Left, API.CL_PLATFORM_NAME);
      Right_Name : constant String :=
        Get_Platform_Info_String (Right, API.CL_PLATFORM_NAME);
   begin
      if Left_Vendor < Right_Vendor then
         return True;
      elsif Left_Vendor > Right_Vendor then
         return False;
      end if;

      return Left_Name < Right_Name;
   end Platform_Less;

   function Device_Less
     (Left : API.cl_device_id;
      Right : API.cl_device_id) return Boolean
   is
      Left_Vendor : constant String :=
        Get_Device_Info_String (Left, API.CL_DEVICE_VENDOR);
      Right_Vendor : constant String :=
        Get_Device_Info_String (Right, API.CL_DEVICE_VENDOR);
      Left_Name : constant String :=
        Get_Device_Info_String (Left, API.CL_DEVICE_NAME);
      Right_Name : constant String :=
        Get_Device_Info_String (Right, API.CL_DEVICE_NAME);
   begin
      if Left_Vendor < Right_Vendor then
         return True;
      elsif Left_Vendor > Right_Vendor then
         return False;
      end if;

      return Left_Name < Right_Name;
   end Device_Less;

   procedure Sort_Platforms
     (Items : in out Platform_Array;
      Count : Natural)
   is
      Min_Pos : Natural := 0;
   begin
      if Count < 2 then
         return;
      end if;

      for I in 1 .. Count - 1 loop
         Min_Pos := I;
         for J in I + 1 .. Count loop
            if Platform_Less
              (Items (Platform_Index (J)), Items (Platform_Index (Min_Pos)))
            then
               Min_Pos := J;
            end if;
         end loop;

         if Min_Pos /= I then
            declare
               Temp : constant API.cl_platform_id := Items (Platform_Index (I));
            begin
               Items (Platform_Index (I)) := Items (Platform_Index (Min_Pos));
               Items (Platform_Index (Min_Pos)) := Temp;
            end;
         end if;
      end loop;
   end Sort_Platforms;

   procedure Sort_Devices
     (Items : in out Device_Array;
      Count : Natural)
   is
      Min_Pos : Natural := 0;
   begin
      if Count < 2 then
         return;
      end if;

      for I in 1 .. Count - 1 loop
         Min_Pos := I;
         for J in I + 1 .. Count loop
            if Device_Less (Items (Device_Index (J)), Items (Device_Index (Min_Pos))) then
               Min_Pos := J;
            end if;
         end loop;

         if Min_Pos /= I then
            declare
               Temp : constant API.cl_device_id := Items (Device_Index (I));
            begin
               Items (Device_Index (I)) := Items (Device_Index (Min_Pos));
               Items (Device_Index (Min_Pos)) := Temp;
            end;
         end if;
      end loop;
   end Sort_Devices;

   Status : API.cl_int := API.CL_SUCCESS;
   Platform_Count_Raw : aliased API.cl_uint := 0;
   Platforms : Platform_Array := (others => Null_Platform);
begin
   Status := API.clGetPlatformIDs
     (num_entries => 0,
      platforms => null,
      num_platforms => Platform_Count_Raw'Access);

   if Status = API.CL_PLATFORM_NOT_FOUND_KHR then
      Ada.Text_IO.Put_Line ("platform_count_reported= 0");
      Ada.Text_IO.Put_Line ("platform_count_used= 0");
      Ada.Text_IO.Put_Line ("INFO no platforms: CL_PLATFORM_NOT_FOUND_KHR");
      return;
   elsif Status /= API.CL_SUCCESS then
      Print_Error ("clGetPlatformIDs(count)", Status);
      return;
   end if;

   Ada.Text_IO.Put_Line
     ("platform_count_reported=" & API.cl_uint'Image (Platform_Count_Raw));

   declare
      Platform_Count : constant Natural :=
        Clamp_Count (Platform_Count_Raw, Max_Platforms, "platform_count");
   begin
      Ada.Text_IO.Put_Line ("platform_count_used=" & Natural'Image (Platform_Count));

      if Platform_Count = 0 then
         return;
      end if;

      Status := API.clGetPlatformIDs
        (num_entries => API.cl_uint (Platform_Count),
         platforms => Platforms (Platform_Index'First)'Access,
         num_platforms => null);

      if Status /= API.CL_SUCCESS then
         Print_Error ("clGetPlatformIDs(list)", Status);
         return;
      end if;

      Sort_Platforms (Platforms, Platform_Count);

      for Platform_Pos in 1 .. Platform_Count loop
         declare
            Platform : constant API.cl_platform_id :=
              Platforms (Platform_Index (Platform_Pos));
            Platform_Name : constant String :=
              Get_Platform_Info_String (Platform, API.CL_PLATFORM_NAME);
            Platform_Vendor : constant String :=
              Get_Platform_Info_String (Platform, API.CL_PLATFORM_VENDOR);
            Platform_Version : constant String :=
              Get_Platform_Info_String (Platform, API.CL_PLATFORM_VERSION);
            Device_Count_Raw : aliased API.cl_uint := 0;
            Devices : Device_Array := (others => Null_Device);
            Device_Count : Natural := 0;
         begin
            Ada.Text_IO.Put_Line
              ("Platform[" & Natural'Image (Platform_Pos - 1) & "]");
            Ada.Text_IO.Put_Line ("  name    : " & Platform_Name);
            Ada.Text_IO.Put_Line ("  vendor  : " & Platform_Vendor);
            Ada.Text_IO.Put_Line ("  version : " & Platform_Version);

            Status := API.clGetDeviceIDs
              (platform => Platform,
               device_type => API.CL_DEVICE_TYPE_ALL,
               num_entries => 0,
               devices => null,
               num_devices => Device_Count_Raw'Access);

            if Status = API.CL_DEVICE_NOT_FOUND then
               Ada.Text_IO.Put_Line ("  device_count_reported= 0");
               Ada.Text_IO.Put_Line ("  device_count_used= 0");
               Ada.Text_IO.Put_Line ("  INFO no devices: CL_DEVICE_NOT_FOUND");
            elsif Status /= API.CL_SUCCESS then
               Print_Error ("clGetDeviceIDs(count)", Status);
               Ada.Text_IO.Put_Line ("  device_count_reported=<error>");
               Ada.Text_IO.Put_Line ("  device_count_used=<error>");
            else
               Ada.Text_IO.Put_Line
                 ("  device_count_reported=" & API.cl_uint'Image (Device_Count_Raw));

               Device_Count :=
                 Clamp_Count
                   (Device_Count_Raw,
                    Max_Devices_Per_Platform,
                    "device_count(platform=" & Natural'Image (Platform_Pos - 1) & ")");

               Ada.Text_IO.Put_Line
                 ("  device_count_used=" & Natural'Image (Device_Count));

               if Device_Count > 0 then
                  Status := API.clGetDeviceIDs
                    (platform => Platform,
                     device_type => API.CL_DEVICE_TYPE_ALL,
                     num_entries => API.cl_uint (Device_Count),
                     devices => Devices (Device_Index'First)'Access,
                     num_devices => null);

                  if Status = API.CL_DEVICE_NOT_FOUND then
                     Ada.Text_IO.Put_Line ("  INFO no devices while listing");
                     Device_Count := 0;
                  elsif Status /= API.CL_SUCCESS then
                     Print_Error ("clGetDeviceIDs(list)", Status);
                     Device_Count := 0;
                  end if;
               end if;

               if Device_Count > 0 then
                  Sort_Devices (Devices, Device_Count);

                  for Device_Pos in 1 .. Device_Count loop
                     declare
                        Device : constant API.cl_device_id :=
                          Devices (Device_Index (Device_Pos));
                        Device_Name : constant String :=
                          Get_Device_Info_String (Device, API.CL_DEVICE_NAME);
                        Device_Vendor : constant String :=
                          Get_Device_Info_String (Device, API.CL_DEVICE_VENDOR);
                        Device_Driver : constant String :=
                          Get_Device_Info_String (Device, API.CL_DRIVER_VERSION);
                        Device_Version : constant String :=
                          Get_Device_Info_String (Device, API.CL_DEVICE_VERSION);
                        Device_Type_Ok : Boolean := False;
                        Device_Type : API.cl_device_type_mask :=
                          Get_Device_Type (Device => Device, Ok => Device_Type_Ok);
                     begin
                        Ada.Text_IO.Put_Line
                          ("  Device[" & Natural'Image (Device_Pos - 1) & "]");
                        Ada.Text_IO.Put_Line ("    name    : " & Device_Name);
                        Ada.Text_IO.Put_Line ("    vendor  : " & Device_Vendor);
                        Ada.Text_IO.Put_Line ("    driver  : " & Device_Driver);
                        Ada.Text_IO.Put_Line ("    version : " & Device_Version);

                        if Device_Type_Ok then
                           Ada.Text_IO.Put_Line
                             ("    type    :" & API.cl_device_type_mask'Image (Device_Type));
                        else
                           Ada.Text_IO.Put_Line ("    type    : <error>");
                        end if;
                     end;
                  end loop;
               end if;
            end if;
         end;
      end loop;
   end;
end Smoke_Platforms;
