with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Kernels;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.Raw.API;
with Ada.Strings;
with Ada.Strings.Fixed;
with System;

procedure Smoke_Kernel_Add1 is
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;
   package API renames OpenCL.Raw.API;

   use type Errors.Status_Code;
   use type API.cl_bool;
   use type API.cl_device_id;
   use type API.cl_int;
   use type API.cl_program;
   use type API.cl_uint;
   use type API.size_t;
   use type Interfaces.C.unsigned_char;

   Max_Platforms : constant Positive := 8;
   Max_Devices : constant Positive := 16;
   N_Bytes : constant Interfaces.C.size_t := 4096;
   Max_Info_Bytes : constant Positive := 4_096;
   Truncated_Suffix : constant String := "[TRUNCATED]";

   Kernel_Source : constant String :=
     "__kernel void add1(__global const uchar* src, __global uchar* dst) "
     & "{ const size_t gid = get_global_id(0); "
     & "dst[gid] = (uchar)(src[gid] + (uchar)1); }";

   subtype Byte is Interfaces.C.unsigned_char;
   subtype Byte_Index is Natural range 0 .. Natural (N_Bytes) - 1;
   type Byte_Array is array (Byte_Index) of aliased Byte;

   Platforms : Core.Platform_List (1 .. Max_Platforms);
   Devices : Core.Device_List (1 .. Max_Devices);
   Input_Data : Byte_Array := (others => 0);
   Output_Data : Byte_Array := (others => 0);

   Platform_Used : Natural := 0;
   Device_Used : Natural := 0;
   Status : Errors.Status_Code := Errors.Success;

   Ctx : Contexts.Context;
   Q : Queues.Queue;
   In_Buffer : Buffers.Buffer;
   Out_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Failed : Boolean := False;
   Raw_Device_For_Diagnostics : API.cl_device_id := null;

   function Trimmed_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trimmed_Int_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trimmed_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function Size_T_Image (Value : API.size_t) return String is
      Raw : constant String := API.size_t'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Size_T_Image;

   function Build_Status_Image (Value : API.cl_build_status) return String is
   begin
      case Value is
         when API.CL_BUILD_SUCCESS =>
            return "CL_BUILD_SUCCESS";
         when API.CL_BUILD_NONE =>
            return "CL_BUILD_NONE";
         when API.CL_BUILD_ERROR =>
            return "CL_BUILD_ERROR";
         when API.CL_BUILD_IN_PROGRESS =>
            return "CL_BUILD_IN_PROGRESS";
         when others =>
            return
              "CL_BUILD_STATUS_UNKNOWN("
              & Trimmed_Int_Image (Interfaces.C.int (Value))
              & ")";
      end case;
   end Build_Status_Image;

   function Raw_Program_Build_Info_String
     (Prg : API.cl_program;
      Dev : API.cl_device_id;
      Param : API.cl_program_build_info;
      Status : out API.cl_int;
      Reported_Bytes : out API.size_t;
      Max_Bytes : Positive := 65_536) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
   begin
      Reported_Bytes := 0;

      Status := API.clGetProgramBuildInfo
        (program => Prg,
         device => Dev,
         param_name => Param,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Status /= API.CL_SUCCESS then
         return "";
      end if;

      Reported_Bytes := Needed;
      if Needed = 0 then
         return "";
      end if;

      if Needed > API.size_t (Max_Bytes) then
         Copy_Size := API.size_t (Max_Bytes);
      else
         Copy_Size := Needed;
      end if;

      declare
         subtype Info_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      begin
         Status := API.clGetProgramBuildInfo
           (program => Prg,
            device => Dev,
            param_name => Param,
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Status /= API.CL_SUCCESS then
            return "";
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         declare
            Text : constant String := Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
         begin
            if Needed > API.size_t (Max_Bytes) then
               return Text & Truncated_Suffix;
            else
               return Text;
            end if;
         end;
      end;
   end Raw_Program_Build_Info_String;

   function Raw_Device_Info_String
     (Device : API.cl_device_id;
      Param : API.cl_device_info;
      Status : out API.cl_int;
      Max_Bytes : Positive := Max_Info_Bytes) return String
   is
      Needed : aliased API.size_t := 0;
      Copy_Size : API.size_t := 0;
   begin
      Status := API.clGetDeviceInfo
        (device => Device,
         param_name => Param,
         param_value_size => 0,
         param_value => System.Null_Address,
         param_value_size_ret => Needed'Access);

      if Status /= API.CL_SUCCESS then
         return "";
      end if;

      if Needed = 0 then
         return "";
      end if;

      if Needed > API.size_t (Max_Bytes) then
         Copy_Size := API.size_t (Max_Bytes);
      else
         Copy_Size := Needed;
      end if;

      declare
         subtype Info_Buffer is Interfaces.C.char_array (0 .. Copy_Size - 1);
         Buffer : aliased Info_Buffer := (others => Interfaces.C.nul);
      begin
         Status := API.clGetDeviceInfo
           (device => Device,
            param_name => Param,
            param_value_size => Copy_Size,
            param_value => Buffer (Buffer'First)'Address,
            param_value_size_ret => null);

         if Status /= API.CL_SUCCESS then
            return "";
         end if;

         Buffer (Buffer'Last) := Interfaces.C.nul;
         declare
            Text : constant String := Interfaces.C.To_Ada (Buffer, Trim_Nul => True);
         begin
            if Needed > API.size_t (Max_Bytes) then
               return Text & Truncated_Suffix;
            else
               return Text;
            end if;
         end;
      end;
   end Raw_Device_Info_String;

   procedure Query_First_Raw_Device
     (Device : out API.cl_device_id;
      Status : out API.cl_int)
   is
      Platform_Count : aliased API.cl_uint := 0;
      First_Platform : aliased API.cl_platform_id := null;
      Device_Count : aliased API.cl_uint := 0;
      First_Device : aliased API.cl_device_id := null;
   begin
      Device := null;
      Status := API.clGetPlatformIDs
        (num_entries => 0,
         platforms => null,
         num_platforms => Platform_Count'Access);
      if Status /= API.CL_SUCCESS then
         return;
      end if;

      if Platform_Count = 0 then
         Status := API.CL_PLATFORM_NOT_FOUND_KHR;
         return;
      end if;

      Status := API.clGetPlatformIDs
        (num_entries => 1,
         platforms => First_Platform'Access,
         num_platforms => null);
      if Status /= API.CL_SUCCESS then
         return;
      end if;

      Status := API.clGetDeviceIDs
        (platform => First_Platform,
         device_type => API.CL_DEVICE_TYPE_ALL,
         num_entries => 0,
         devices => null,
         num_devices => Device_Count'Access);
      if Status /= API.CL_SUCCESS then
         return;
      end if;

      if Device_Count = 0 then
         Status := API.CL_DEVICE_NOT_FOUND;
         return;
      end if;

      Status := API.clGetDeviceIDs
        (platform => First_Platform,
         device_type => API.CL_DEVICE_TYPE_ALL,
         num_entries => 1,
         devices => First_Device'Access,
         num_devices => null);
      if Status = API.CL_SUCCESS then
         Device := First_Device;
      end if;
   end Query_First_Raw_Device;

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
      Kernels.Release (K => K, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_kernel: " & Errors.Image (Release_Status));
      end if;

      Programs.Release (Prg => Prg, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_program: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => Out_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_out_buffer: " & Errors.Image (Release_Status));
      end if;

      Buffers.Release (B => In_Buffer, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_in_buffer: " & Errors.Image (Release_Status));
      end if;

      Queues.Release (Q => Q, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_queue: " & Errors.Image (Release_Status));
      end if;

      Contexts.Release (Ctx => Ctx, Status => Release_Status);
      if not Errors.Is_Success (Release_Status) then
         Ada.Text_IO.Put_Line
           ("WARN release_context: " & Errors.Image (Release_Status));
      end if;
   end Cleanup;

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

   declare
      Raw_Status : API.cl_int := API.CL_SUCCESS;
      Compiler_Available : aliased API.cl_bool := API.CL_FALSE;
   begin
      Query_First_Raw_Device
        (Device => Raw_Device_For_Diagnostics,
         Status => Raw_Status);

      if Raw_Status = API.CL_PLATFORM_NOT_FOUND_KHR
        or else Raw_Status = API.CL_DEVICE_NOT_FOUND
      then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason="
            & Errors.Image (Errors.Status_Code (Raw_Status)));
         return;
      elsif Raw_Status /= API.CL_SUCCESS or else Raw_Device_For_Diagnostics = null then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason=CL_DEVICE_COMPILER_AVAILABLE_query_failed:"
            & Errors.Image (Errors.Status_Code (Raw_Status)));
         return;
      end if;

      Raw_Status := API.clGetDeviceInfo
        (device => Raw_Device_For_Diagnostics,
         param_name => API.CL_DEVICE_COMPILER_AVAILABLE,
         param_value_size => API.size_t (API.cl_bool'Size / System.Storage_Unit),
         param_value => Compiler_Available'Address,
         param_value_size_ret => null);

      if Raw_Status /= API.CL_SUCCESS then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason=CL_DEVICE_COMPILER_AVAILABLE_query_failed:"
            & Errors.Image (Errors.Status_Code (Raw_Status)));
         return;
      end if;

      if Compiler_Available = API.CL_FALSE then
         Ada.Text_IO.Put_Line
           ("RESULT=SKIP reason=CL_DEVICE_COMPILER_AVAILABLE=false");
         return;
      end if;

      declare
         OpenCL_C_Status : API.cl_int := API.CL_SUCCESS;
         OpenCL_C_Version : constant String :=
           Raw_Device_Info_String
             (Device => Raw_Device_For_Diagnostics,
              Param => API.CL_DEVICE_OPENCL_C_VERSION,
              Status => OpenCL_C_Status,
              Max_Bytes => 256);
      begin
         if OpenCL_C_Status = API.CL_SUCCESS then
            Ada.Text_IO.Put_Line ("INFO device_opencl_c_version=" & OpenCL_C_Version);
         else
            Ada.Text_IO.Put_Line
              ("WARN device_opencl_c_version_query_failed="
               & Errors.Image (Errors.Status_Code (OpenCL_C_Status)));
         end if;
      end;
   end;

   Contexts.Create
     (Device => Devices (Devices'First),
      Ctx => Ctx,
      Status => Status);
   if not Errors.Is_Success (Status) then
      Mark_Fail ("create_context", Status);
   end if;

   if not Failed then
      Queues.Create
        (Ctx => Ctx,
         Dev => Devices (Devices'First),
         Q => Q,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_queue", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => N_Bytes,
         B => In_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_in_buffer", Status);
      end if;
   end if;

   if not Failed then
      Buffers.Create
        (Ctx => Ctx,
         Bytes => N_Bytes,
         B => Out_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_out_buffer", Status);
      end if;
   end if;

   if not Failed then
      for I in Input_Data'Range loop
         Input_Data (I) := Byte (I mod 256);
      end loop;

      Buffers.Write
        (Q => Q,
         B => In_Buffer,
         Host => Input_Data (Input_Data'First)'Address,
         Bytes => N_Bytes,
         Status => Status);

      if not Errors.Is_Success (Status) then
         Mark_Fail ("write_in_buffer", Status);
      end if;
   end if;

   if not Failed then
      Programs.Create_From_Source
        (Ctx => Ctx,
         Source => Kernel_Source,
         Prg => Prg,
         Status => Status);

      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_program_from_source", Status);
      end if;
   end if;

   if not Failed then
      declare
         First_Build_Status : Errors.Status_Code := Errors.Success;
      begin
         Programs.Build
           (Prg => Prg,
            Dev => Devices (Devices'First),
            Options => "",
            Status => First_Build_Status);

         if First_Build_Status = Errors.Compiler_Not_Available then
            Cleanup;
            Ada.Text_IO.Put_Line
              ("RESULT=SKIP reason="
               & Errors.Image (First_Build_Status)
               & " status_int="
               & Status_Int_Image (First_Build_Status));
            return;
         elsif Errors.Is_Success (First_Build_Status) then
            Status := First_Build_Status;
         else
            Ada.Text_IO.Put_Line
              ("INFO build_retry first_status="
               & Errors.Image (First_Build_Status)
               & " status_int="
               & Status_Int_Image (First_Build_Status)
               & " retry_options=-cl-std=CL1.2");

            Programs.Build
              (Prg => Prg,
               Dev => Devices (Devices'First),
               Options => "-cl-std=CL1.2",
               Status => Status);

            if Status = Errors.Compiler_Not_Available then
               Cleanup;
               Ada.Text_IO.Put_Line
                 ("RESULT=SKIP reason="
                  & Errors.Image (Status)
                  & " status_int="
                  & Status_Int_Image (Status));
               return;
            elsif not Errors.Is_Success (Status) then
               declare
                  Raw_Build_Status : aliased API.cl_build_status := API.CL_BUILD_NONE;
                  Raw_Build_Status_Query : API.cl_int := API.CL_SUCCESS;
                  Source_Status : Errors.Status_Code := Errors.Success;
                  Source_Text : constant String :=
                    Programs.Source
                      (Prg => Prg,
                       Status => Source_Status,
                       Max_Bytes => 16_384);
                  Source_Head_Len : constant Natural :=
                    (if Source_Text'Length > 200 then 200 else Source_Text'Length);
               begin
                  Ada.Text_IO.Put_Line
                    ("ERROR build_program: "
                     & Errors.Image (Status)
                     & " status_int="
                     & Status_Int_Image (Status));

                  if Programs.Raw_Handle (Prg) /= null
                    and then Raw_Device_For_Diagnostics /= null
                  then
                     Raw_Build_Status_Query := API.clGetProgramBuildInfo
                       (program => Programs.Raw_Handle (Prg),
                        device => Raw_Device_For_Diagnostics,
                        param_name => API.CL_PROGRAM_BUILD_STATUS,
                        param_value_size =>
                          API.size_t (API.cl_build_status'Size / System.Storage_Unit),
                        param_value => Raw_Build_Status'Address,
                        param_value_size_ret => null);
                     if Raw_Build_Status_Query = API.CL_SUCCESS then
                        Ada.Text_IO.Put_Line
                          ("BUILD_STATUS=" & Build_Status_Image (Raw_Build_Status));
                     else
                        Ada.Text_IO.Put_Line
                          ("BUILD_STATUS_UNAVAILABLE="
                           & Errors.Image
                               (Errors.Status_Code (Raw_Build_Status_Query))
                           & " status_int="
                           & Trimmed_Int_Image (Interfaces.C.int (Raw_Build_Status_Query)));
                     end if;

                     declare
                        Build_Options_Query_Status : API.cl_int := API.CL_SUCCESS;
                        Build_Options_Bytes : API.size_t := 0;
                        Build_Options_Text : constant String :=
                          Raw_Program_Build_Info_String
                            (Prg => Programs.Raw_Handle (Prg),
                             Dev => Raw_Device_For_Diagnostics,
                             Param => API.CL_PROGRAM_BUILD_OPTIONS,
                             Status => Build_Options_Query_Status,
                             Reported_Bytes => Build_Options_Bytes,
                             Max_Bytes => 4_096);
                        Build_Log_Query_Status : API.cl_int := API.CL_SUCCESS;
                        Build_Log_Bytes : API.size_t := 0;
                        Build_Log_Text : constant String :=
                          Raw_Program_Build_Info_String
                            (Prg => Programs.Raw_Handle (Prg),
                             Dev => Raw_Device_For_Diagnostics,
                             Param => API.CL_PROGRAM_BUILD_LOG,
                             Status => Build_Log_Query_Status,
                             Reported_Bytes => Build_Log_Bytes,
                             Max_Bytes => 65_536);
                     begin
                        if Build_Options_Query_Status = API.CL_SUCCESS then
                           Ada.Text_IO.Put_Line
                             ("build_options_bytes_reported="
                              & Size_T_Image (Build_Options_Bytes));
                           if Build_Options_Text'Length = 0 then
                              Ada.Text_IO.Put_Line ("BUILD_OPTIONS=<empty>");
                           else
                              Ada.Text_IO.Put_Line
                                ("BUILD_OPTIONS=" & Build_Options_Text);
                           end if;
                        else
                           Ada.Text_IO.Put_Line
                             ("build_options_bytes_reported=<unavailable>");
                           Ada.Text_IO.Put_Line
                             ("BUILD_OPTIONS_UNAVAILABLE="
                              & Errors.Image
                                  (Errors.Status_Code (Build_Options_Query_Status))
                              & " status_int="
                              & Trimmed_Int_Image
                                  (Interfaces.C.int (Build_Options_Query_Status)));
                        end if;

                        if Build_Log_Query_Status = API.CL_SUCCESS then
                           Ada.Text_IO.Put_Line
                             ("build_log_bytes_reported="
                              & Size_T_Image (Build_Log_Bytes));
                           Ada.Text_IO.Put_Line ("BUILD_LOG_BEGIN");
                           if Build_Log_Text'Length = 0 then
                              Ada.Text_IO.Put_Line ("<empty>");
                           else
                              Ada.Text_IO.Put_Line (Build_Log_Text);
                           end if;
                           Ada.Text_IO.Put_Line ("BUILD_LOG_END");
                        else
                           Ada.Text_IO.Put_Line
                             ("build_log_bytes_reported=<unavailable>");
                           Ada.Text_IO.Put_Line
                             ("BUILD_LOG_UNAVAILABLE="
                              & Errors.Image
                                  (Errors.Status_Code (Build_Log_Query_Status))
                              & " status_int="
                              & Trimmed_Int_Image
                                  (Interfaces.C.int (Build_Log_Query_Status)));
                        end if;
                     end;
                  else
                     Ada.Text_IO.Put_Line
                       ("BUILD_STATUS_UNAVAILABLE="
                        & Errors.Image (Errors.Invalid_Device)
                        & " status_int="
                        & Status_Int_Image (Errors.Invalid_Device));
                     Ada.Text_IO.Put_Line ("BUILD_OPTIONS_UNAVAILABLE=<invalid_device>");
                     Ada.Text_IO.Put_Line ("build_log_bytes_reported=<unavailable>");
                     Ada.Text_IO.Put_Line ("BUILD_LOG_UNAVAILABLE=<invalid_device>");
                  end if;

                  if Errors.Is_Success (Source_Status) then
                     Ada.Text_IO.Put_Line ("PROGRAM_SOURCE_HEAD_BEGIN");
                     if Source_Head_Len = 0 then
                        Ada.Text_IO.Put_Line ("<empty>");
                     else
                        Ada.Text_IO.Put_Line
                          (Source_Text
                             (Source_Text'First
                              .. Source_Text'First + Source_Head_Len - 1));
                     end if;
                     Ada.Text_IO.Put_Line ("PROGRAM_SOURCE_HEAD_END");
                  else
                     Ada.Text_IO.Put_Line
                       ("ERROR program_source: "
                        & Errors.Image (Source_Status)
                        & " status_int="
                        & Status_Int_Image (Source_Status));
                  end if;
               end;
               Failed := True;
            end if;
         end if;
      end;
   end if;

   if not Failed then
      Kernels.Create
        (Prg => Prg,
         Name => "add1",
         K => K,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("create_kernel", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => 0,
         B => In_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_0_in_buffer", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Set_Arg_Buffer
        (K => K,
         Index => 1,
         B => Out_Buffer,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("set_arg_1_out_buffer", Status);
      end if;
   end if;

   if not Failed then
      Kernels.Enqueue_1D
        (Q => Q,
         K => K,
         Global_Size => N_Bytes,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("enqueue_1d", Status);
      end if;
   end if;

   if not Failed then
      Queues.Finish (Q => Q, Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("finish_queue", Status);
      end if;
   end if;

   if not Failed then
      for I in Output_Data'Range loop
         Output_Data (I) := 0;
      end loop;

      Buffers.Read
        (Q => Q,
         B => Out_Buffer,
         Host => Output_Data (Output_Data'First)'Address,
         Bytes => N_Bytes,
         Status => Status);

      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_out_buffer", Status);
      end if;
   end if;

   if not Failed then
      declare
         Mismatch_Count : Natural := 0;
         First_Mismatch_Index : Natural := 0;
         First_Expected : Byte := 0;
         First_Actual : Byte := 0;
      begin
         for I in Output_Data'Range loop
            declare
               Expected : constant Byte :=
                 Byte ((Integer (Input_Data (I)) + 1) mod 256);
            begin
               if Output_Data (I) /= Expected then
                  if Mismatch_Count = 0 then
                     First_Mismatch_Index := I;
                     First_Expected := Expected;
                     First_Actual := Output_Data (I);
                  end if;
                  Mismatch_Count := Mismatch_Count + 1;
               end if;
            end;
         end loop;

         if Mismatch_Count > 0 then
            Ada.Text_IO.Put_Line
              ("ERROR kernel_add1_mismatch count="
               & Natural'Image (Mismatch_Count));
            Ada.Text_IO.Put_Line
              ("ERROR first_mismatch index=" & Natural'Image (First_Mismatch_Index)
               & " expected=" & Byte'Image (First_Expected)
               & " actual=" & Byte'Image (First_Actual));
            Failed := True;
         end if;
      end;
   end if;

   Cleanup;

   if Failed then
      Ada.Text_IO.Put_Line ("RESULT=FAIL");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Text_IO.Put_Line ("RESULT=PASS");
   end if;
end Smoke_Kernel_Add1;
