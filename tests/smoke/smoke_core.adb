with Ada.Text_IO;
with OpenCL.Core;
with OpenCL.Errors;

procedure Smoke_Core is
   package Core renames OpenCL.Core;
   package Errors renames OpenCL.Errors;
   use type Errors.Status_Code;

   Max_Platforms : constant Positive := 16;
   Max_Devices_Per_Platform : constant Positive := 64;
   Max_Info_Bytes : constant Positive := Core.Default_Max_Info_Bytes;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices_Per_Platform);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;

   procedure Print_Field
     (Prefix : String;
      Value : String;
      Field_Status : Errors.Status_Code)
   is
   begin
      if Errors.Is_Success (Field_Status) then
         Ada.Text_IO.Put_Line (Prefix & Value);
      else
         Ada.Text_IO.Put_Line
           (Prefix & "<error: " & Errors.Image (Field_Status) & ">");
      end if;
   end Print_Field;

begin
   Core.Enumerate_Platforms
     (Out_Platforms => Platforms,
      Used => Platform_Used,
      Status => Status);

   Ada.Text_IO.Put_Line ("platform_capacity=" & Positive'Image (Max_Platforms));
   Ada.Text_IO.Put_Line ("platform_count_used=" & Natural'Image (Platform_Used));

   if Platform_Used = 0 then
      Ada.Text_IO.Put_Line ("INFO no platforms: " & Errors.Image (Status));
      return;
   end if;

   if not Errors.Is_Success (Status) then
      Ada.Text_IO.Put_Line
        ("WARN enumerate_platforms status=" & Errors.Image (Status));
   end if;

   for Platform_Pos in 1 .. Platform_Used loop
      declare
         P : constant Core.Platform := Platforms (Platforms'First + Platform_Pos - 1);
      begin
         Ada.Text_IO.Put_Line
           ("Platform[" & Natural'Image (Platform_Pos - 1) & "]");

         declare
            Field_Status : Errors.Status_Code := Errors.Success;
            Field_Value : constant String :=
              Core.Get_Platform_Info
                (P => P,
                 What => Core.Name,
                 Status => Field_Status,
                 Max_Bytes => Max_Info_Bytes);
         begin
            Print_Field ("  name    : ", Field_Value, Field_Status);
         end;

         declare
            Field_Status : Errors.Status_Code := Errors.Success;
            Field_Value : constant String :=
              Core.Get_Platform_Info
                (P => P,
                 What => Core.Vendor,
                 Status => Field_Status,
                 Max_Bytes => Max_Info_Bytes);
         begin
            Print_Field ("  vendor  : ", Field_Value, Field_Status);
         end;

         declare
            Field_Status : Errors.Status_Code := Errors.Success;
            Field_Value : constant String :=
              Core.Get_Platform_Info
                (P => P,
                 What => Core.Version,
                 Status => Field_Status,
                 Max_Bytes => Max_Info_Bytes);
         begin
            Print_Field ("  version : ", Field_Value, Field_Status);
         end;

         Core.Enumerate_Devices
           (P => P,
            Out_Devices => Devices,
            Used => Device_Used,
            Status => Status);

         Ada.Text_IO.Put_Line
           ("  device_capacity=" & Positive'Image (Max_Devices_Per_Platform));
         Ada.Text_IO.Put_Line
           ("  device_count_used=" & Natural'Image (Device_Used));

         if Status = Errors.Device_Not_Found then
            Ada.Text_IO.Put_Line
              ("  INFO no devices: " & Errors.Image (Status));
         elsif not Errors.Is_Success (Status) then
            Ada.Text_IO.Put_Line
              ("  ERROR enumerate_devices: " & Errors.Image (Status));
         else
            for Device_Pos in 1 .. Device_Used loop
               declare
                  D : constant Core.Device :=
                    Devices (Devices'First + Device_Pos - 1);
               begin
                  Ada.Text_IO.Put_Line
                    ("  Device[" & Natural'Image (Device_Pos - 1) & "]");

                  declare
                     Field_Status : Errors.Status_Code := Errors.Success;
                     Field_Value : constant String :=
                       Core.Get_Device_Info
                         (D => D,
                          What => Core.Name,
                          Status => Field_Status,
                          Max_Bytes => Max_Info_Bytes);
                  begin
                     Print_Field ("    name    : ", Field_Value, Field_Status);
                  end;

                  declare
                     Field_Status : Errors.Status_Code := Errors.Success;
                     Field_Value : constant String :=
                       Core.Get_Device_Info
                         (D => D,
                          What => Core.Vendor,
                          Status => Field_Status,
                          Max_Bytes => Max_Info_Bytes);
                  begin
                     Print_Field ("    vendor  : ", Field_Value, Field_Status);
                  end;

                  declare
                     Field_Status : Errors.Status_Code := Errors.Success;
                     Field_Value : constant String :=
                       Core.Get_Device_Info
                         (D => D,
                          What => Core.Version,
                          Status => Field_Status,
                          Max_Bytes => Max_Info_Bytes);
                  begin
                     Print_Field ("    version : ", Field_Value, Field_Status);
                  end;

                  declare
                     Field_Status : Errors.Status_Code := Errors.Success;
                     Field_Value : constant String :=
                       Core.Get_Device_Info
                         (D => D,
                          What => Core.Driver_Version,
                          Status => Field_Status,
                          Max_Bytes => Max_Info_Bytes);
                  begin
                     Print_Field ("    driver  : ", Field_Value, Field_Status);
                  end;
               end;
            end loop;
         end if;
      end;
   end loop;
end Smoke_Core;
