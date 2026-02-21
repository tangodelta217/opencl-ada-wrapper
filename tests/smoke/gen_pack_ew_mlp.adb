with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with EW_MLP_Kernel_Source;
with Interfaces;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.Raw.API;
with OpenCL.RT.Hash;
with OpenCL.RT.Packs;
with System;

procedure Gen_Pack_EW_MLP is
   package Core renames OpenCL.Core;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Programs renames OpenCL.Core.Programs;
   package API renames OpenCL.Raw.API;
   package Packs renames OpenCL.RT.Packs;
   package SIO renames Ada.Streams.Stream_IO;

   use type Errors.Status_Code;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.size_t;
   use type Interfaces.C.int;
   use type Interfaces.Unsigned_32;
   use type API.cl_int;
   use type API.cl_uint;
   use type API.cl_device_id;
   use type API.size_t;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;

   Ctx : Contexts.Context;
   Prg : Programs.Program;
   Binary_Data : Program_Byte_Array_Access := null;
   Binary_Bytes : Interfaces.C.size_t := 0;
   Binary_Used : Natural := 0;
   Binary_FNV1a32 : Interfaces.Unsigned_32 := 0;

   Failed : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Trim_Natural_Image (Value : Natural) return String is
      Raw : constant String := Natural'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Natural_Image;

   function Trim_U32_Image (Value : Interfaces.Unsigned_32) return String is
      Raw : constant String := Interfaces.Unsigned_32'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_U32_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function UTC_Now_ISO return String is
      Raw : constant String :=
        Ada.Calendar.Formatting.Image
          (Date => Ada.Calendar.Clock,
           Include_Time_Fraction => False,
           Time_Zone => 0);
   begin
      if Raw'Length >= 19 then
         return
           Raw (Raw'First .. Raw'First + 9)
           & "T"
           & Raw (Raw'First + 11 .. Raw'First + 18)
           & "Z";
      else
         return Raw;
      end if;
   end UTC_Now_ISO;

   function Resolve_Pack_Dir
     (Resolved : out Packs.Bounded_String;
      Op_Status : out Errors.Status_Code) return Boolean
   is
   begin
      Resolved := Packs.To_Bounded ("");
      Op_Status := Errors.Success;

      if not Ada.Environment_Variables.Exists ("OCLW_PACK_DIR") then
         Op_Status := Errors.Invalid_Value;
         return False;
      end if;

      declare
         Value : constant String :=
           Ada.Strings.Fixed.Trim
             (Ada.Environment_Variables.Value ("OCLW_PACK_DIR"),
              Ada.Strings.Both);
      begin
         if Value'Length = 0 then
            Op_Status := Errors.Invalid_Value;
            return False;
         end if;

         if not Ada.Directories.Exists (Value)
           or else Ada.Directories.Kind (Value) /= Ada.Directories.Directory
         then
            Op_Status := Errors.OCLW_IO_Error;
            return False;
         end if;

         Resolved := Packs.To_Bounded (Value);
         return True;
      end;
   end Resolve_Pack_Dir;

   function Query_First_Device_OpenCL_C_Version return String is
      Platform_Count : aliased API.cl_uint := 0;
      First_Platform : aliased API.cl_platform_id := null;
      Device_Count : aliased API.cl_uint := 0;
      First_Device : aliased API.cl_device_id := null;
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Needed : aliased API.size_t := 0;
      Max_Bytes : constant Positive := 256;
   begin
      Raw_Status := API.clGetPlatformIDs
        (num_entries => 0,
         platforms => null,
         num_platforms => Platform_Count'Access);
      if Raw_Status /= API.CL_SUCCESS or else Platform_Count = 0 then
         return "";
      end if;

      Raw_Status := API.clGetPlatformIDs
        (num_entries => 1,
         platforms => First_Platform'Access,
         num_platforms => null);
      if Raw_Status /= API.CL_SUCCESS then
         return "";
      end if;

      Raw_Status := API.clGetDeviceIDs
        (platform => First_Platform,
         device_type => API.CL_DEVICE_TYPE_ALL,
         num_entries => 0,
         devices => null,
         num_devices => Device_Count'Access);
      if Raw_Status /= API.CL_SUCCESS or else Device_Count = 0 then
         return "";
      end if;

      Raw_Status := API.clGetDeviceIDs
        (platform => First_Platform,
         device_type => API.CL_DEVICE_TYPE_ALL,
         num_entries => 1,
         devices => First_Device'Access,
         num_devices => null);
      if Raw_Status /= API.CL_SUCCESS or else First_Device = null then
         return "";
      end if;

      Raw_Status := API.clGetDeviceInfo
        (device => First_Device,
         param_name => API.CL_DEVICE_OPENCL_C_VERSION,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);
      if Raw_Status /= API.CL_SUCCESS or else Needed = 0 then
         return "";
      end if;

      declare
         Copy_Size : constant API.size_t :=
           (if Needed > API.size_t (Max_Bytes)
            then API.size_t (Max_Bytes)
            else Needed);
         subtype Info_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      begin
         Raw_Status := API.clGetDeviceInfo
           (device => First_Device,
            param_name => API.CL_DEVICE_OPENCL_C_VERSION,
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);
         if Raw_Status /= API.CL_SUCCESS then
            return "";
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         return Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
      end;
   end Query_First_Device_OpenCL_C_Version;

   procedure Write_Binary_File
     (Path : String;
      Data : Programs.Byte_Array;
      Used : Natural;
      Op_Status : out Errors.Status_Code)
   is
      File : SIO.File_Type;
   begin
      Op_Status := Errors.Success;
      SIO.Create (File => File, Mode => SIO.Out_File, Name => Path);

      if Used > Data'Length then
         Op_Status := Errors.Invalid_Value;
         SIO.Close (File);
         return;
      end if;

      if Used > 0 then
         declare
            Raw : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Used));
         begin
            for Offset in 0 .. Used - 1 loop
               Raw
                 (Raw'First + Ada.Streams.Stream_Element_Offset (Offset)) :=
                 Ada.Streams.Stream_Element
                   (Data (Data'First + Integer (Offset)));
            end loop;
            SIO.Write (File => File, Item => Raw);
         end;
      end if;

      SIO.Close (File);
   exception
      when SIO.Name_Error
         | SIO.Use_Error
         | SIO.Status_Error
         | SIO.Device_Error
         | Constraint_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Op_Status := Errors.OCLW_IO_Error;
      when others =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Op_Status := Errors.OCLW_IO_Error;
   end Write_Binary_File;

   procedure Mark_Fail (Step : String; Code : Errors.Status_Code) is
   begin
      Ada.Text_IO.Put_Line
        ("ERROR "
         & Step
         & ": "
         & Errors.Image (Code)
         & " status_int="
         & Status_Int_Image (Code));
      Failed := True;
   end Mark_Fail;

   procedure Cleanup is
      Release_Status : Errors.Status_Code := Errors.Success;
   begin
      Programs.Release (Prg => Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_program: " & Errors.Image (Release_Status));
      end if;

      Contexts.Release (Ctx => Ctx, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_context: " & Errors.Image (Release_Status));
      end if;

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;
   end Cleanup;

begin
   declare
      Pack_Dir_Value : Packs.Bounded_String := Packs.To_Bounded ("");
      Pack_Dir_Status : Errors.Status_Code := Errors.Success;
      OpenCL_C_Version : constant String := Query_First_Device_OpenCL_C_Version;
   begin
      if not Resolve_Pack_Dir
               (Resolved => Pack_Dir_Value,
                Op_Status => Pack_Dir_Status)
      then
         Ada.Text_IO.Put_Line
           ("ERROR invalid_pack_dir_env: "
            & Errors.Image (Pack_Dir_Status)
            & " status_int="
            & Status_Int_Image (Pack_Dir_Status));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      declare
         Pack_Dir : constant String := Packs.To_String (Pack_Dir_Value);
         Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
         Binary_Path : constant String := Pack_Dir & "/program.bin";
      begin
         Core.Enumerate_Platforms
           (Out_Platforms => Platforms,
            Used => Platform_Used,
            Status => Status);
         if Platform_Used = 0 then
            Ada.Text_IO.Put_Line ("RESULT=SKIP reason=" & Errors.Image (Status));
            return;
         end if;

         Core.Enumerate_Devices
           (P => Platforms (Platforms'First),
            Out_Devices => Devices,
            Used => Device_Used,
            Status => Status);
         if Device_Used = 0 then
            Ada.Text_IO.Put_Line ("RESULT=SKIP reason=" & Errors.Image (Status));
            return;
         end if;

         Contexts.Create
           (Device => Devices (Devices'First),
            Ctx => Ctx,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_context", Status);
         end if;

         if not Failed then
            Programs.Create_From_Source
              (Ctx => Ctx,
               Source => EW_MLP_Kernel_Source.Source,
               Prg => Prg,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("create_program_from_source", Status);
            end if;
         end if;

         if not Failed then
            Programs.Build
              (Prg => Prg,
               Dev => Devices (Devices'First),
               Options => EW_MLP_Kernel_Source.Build_Options,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Ada.Text_IO.Put_Line
                 ("ERROR build_program: "
                  & Errors.Image (Status)
                  & " status_int="
                  & Status_Int_Image (Status));
               Ada.Text_IO.Put_Line ("BUILD_LOG_BEGIN");
               Ada.Text_IO.Put_Line
                 (Programs.Build_Log
                    (Prg => Prg,
                     Dev => Devices (Devices'First),
                     Status => Status,
                     Max_Bytes => 65_536));
               Ada.Text_IO.Put_Line ("BUILD_LOG_END");
               Failed := True;
            end if;
         end if;

         if not Failed then
            Programs.Binary_Size
              (Prg => Prg,
               Bytes => Binary_Bytes,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("binary_size", Status);
            elsif Binary_Bytes = 0 then
               Mark_Fail ("binary_size_zero", Errors.Invalid_Binary);
            elsif Binary_Bytes > Interfaces.C.size_t (Positive'Last) then
               Mark_Fail ("binary_size_too_large", Errors.Invalid_Value);
            end if;
         end if;

         if not Failed then
            Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Binary_Bytes)));
            Programs.Get_Binary
              (Prg => Prg,
               Data => Binary_Data.all,
               Used => Binary_Used,
               Status => Status);

            if not Errors.Is_Success (Status) then
               Mark_Fail ("get_binary", Status);
            elsif Binary_Used = 0 then
               Mark_Fail ("get_binary_used_zero", Errors.Invalid_Binary);
            elsif Binary_Used > Natural (Binary_Bytes) then
               Mark_Fail ("get_binary_used_range", Errors.Invalid_Value);
            else
               Binary_FNV1a32 :=
                 OpenCL.RT.Hash.FNV1a_32
                   (Data => Binary_Data.all,
                    Used => Binary_Used);
            end if;
         end if;

         if not Failed then
            declare
               Meta : Packs.Pack_Metadata;
               Field_Status : Errors.Status_Code := Errors.Success;
            begin
               Meta.Kpack_Version := 1;
               Meta.Pack_Id := Packs.To_Bounded ("kpack_ew_mlp");
               Meta.Created_Utc := Packs.To_Bounded (UTC_Now_ISO);

               Meta.Platform_Name := Packs.To_Bounded
                 (Core.Get_Platform_Info
                    (P => Platforms (Platforms'First),
                     What => Core.Name,
                     Status => Field_Status,
                     Max_Bytes => Core.Default_Max_Info_Bytes));
               if not Errors.Is_Success (Field_Status) then
                  Mark_Fail ("platform_name", Field_Status);
               end if;

               if not Failed then
                  Meta.Platform_Vendor := Packs.To_Bounded
                    (Core.Get_Platform_Info
                       (P => Platforms (Platforms'First),
                        What => Core.Vendor,
                        Status => Field_Status,
                        Max_Bytes => Core.Default_Max_Info_Bytes));
                  if not Errors.Is_Success (Field_Status) then
                     Mark_Fail ("platform_vendor", Field_Status);
                  end if;
               end if;

               if not Failed then
                  Meta.Platform_Version := Packs.To_Bounded
                    (Core.Get_Platform_Info
                       (P => Platforms (Platforms'First),
                        What => Core.Version,
                        Status => Field_Status,
                        Max_Bytes => Core.Default_Max_Info_Bytes));
                  if not Errors.Is_Success (Field_Status) then
                     Mark_Fail ("platform_version", Field_Status);
                  end if;
               end if;

               if not Failed then
                  Meta.Device_Name := Packs.To_Bounded
                    (Core.Get_Device_Info
                       (D => Devices (Devices'First),
                        What => Core.Name,
                        Status => Field_Status,
                        Max_Bytes => Core.Default_Max_Info_Bytes));
                  if not Errors.Is_Success (Field_Status) then
                     Mark_Fail ("device_name", Field_Status);
                  end if;
               end if;

               if not Failed then
                  Meta.Device_Vendor := Packs.To_Bounded
                    (Core.Get_Device_Info
                       (D => Devices (Devices'First),
                        What => Core.Vendor,
                        Status => Field_Status,
                        Max_Bytes => Core.Default_Max_Info_Bytes));
                  if not Errors.Is_Success (Field_Status) then
                     Mark_Fail ("device_vendor", Field_Status);
                  end if;
               end if;

               if not Failed then
                  Meta.Device_Version := Packs.To_Bounded
                    (Core.Get_Device_Info
                       (D => Devices (Devices'First),
                        What => Core.Version,
                        Status => Field_Status,
                        Max_Bytes => Core.Default_Max_Info_Bytes));
                  if not Errors.Is_Success (Field_Status) then
                     Mark_Fail ("device_version", Field_Status);
                  end if;
               end if;

               if not Failed then
                  Meta.Driver_Version := Packs.To_Bounded
                    (Core.Get_Device_Info
                       (D => Devices (Devices'First),
                        What => Core.Driver_Version,
                        Status => Field_Status,
                        Max_Bytes => Core.Default_Max_Info_Bytes));
                  if not Errors.Is_Success (Field_Status) then
                     Mark_Fail ("driver_version", Field_Status);
                  end if;
               end if;

               if not Failed then
                  Meta.OpenCL_C_Version := Packs.To_Bounded (OpenCL_C_Version);
                  Meta.Build_Options := Packs.To_Bounded (EW_MLP_Kernel_Source.Build_Options);
                  Meta.Kernel_Name := Packs.To_Bounded (EW_MLP_Kernel_Source.Kernel_Name);
                  Meta.Binary_Size := Interfaces.C.size_t (Binary_Used);
                  Meta.Binary_FNV1a32 := Binary_FNV1a32;

                  Packs.Write_Manifest
                    (Path => Manifest_Path,
                     Meta => Meta,
                     Status => Status);
                  if not Errors.Is_Success (Status) then
                     Mark_Fail ("write_manifest", Status);
                  end if;
               end if;
            end;
         end if;

         if not Failed then
            Write_Binary_File
              (Path => Binary_Path,
               Data => Binary_Data.all,
               Used => Binary_Used,
               Op_Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("write_binary", Status);
            end if;
         end if;

         Cleanup;

         if Failed then
            Ada.Text_IO.Put_Line ("RESULT=FAIL");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         else
            Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
            Ada.Text_IO.Put_Line ("INFO manifest_path=" & Manifest_Path);
            Ada.Text_IO.Put_Line ("INFO binary_path=" & Binary_Path);
            Ada.Text_IO.Put_Line ("INFO binary_size=" & Trim_Natural_Image (Binary_Used));
            Ada.Text_IO.Put_Line ("INFO binary_fnv1a32=" & Trim_U32_Image (Binary_FNV1a32));
            Ada.Text_IO.Put_Line ("RESULT=PASS");
         end if;
      exception
         when others =>
            Cleanup;
            Ada.Text_IO.Put_Line
              ("ERROR unhandled_exception: "
               & Errors.Image (Errors.OCLW_IO_Error)
               & " status_int="
               & Status_Int_Image (Errors.OCLW_IO_Error));
            Ada.Text_IO.Put_Line ("RESULT=FAIL");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end;
   end;
end Gen_Pack_EW_MLP;
