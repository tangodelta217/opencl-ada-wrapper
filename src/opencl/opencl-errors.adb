with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces.C;

package body OpenCL.Errors is

   function Is_Success (Code : Status_Code) return Boolean is
   begin
      return Code = Success;
   end Is_Success;

   function Trimmed_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trimmed_Int_Image;

   function Image (Code : Status_Code) return String is
   begin
      case Code is
         when Success =>
            return "CL_SUCCESS";
         when Device_Not_Found =>
            return "CL_DEVICE_NOT_FOUND";
         when Device_Not_Available =>
            return "CL_DEVICE_NOT_AVAILABLE";
         when Compiler_Not_Available =>
            return "CL_COMPILER_NOT_AVAILABLE";
         when Mem_Object_Allocation_Failure =>
            return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
         when Out_Of_Resources =>
            return "CL_OUT_OF_RESOURCES";
         when Out_Of_Host_Memory =>
            return "CL_OUT_OF_HOST_MEMORY";
         when Profiling_Info_Not_Available =>
            return "CL_PROFILING_INFO_NOT_AVAILABLE";
         when Mem_Copy_Overlap =>
            return "CL_MEM_COPY_OVERLAP";
         when Image_Format_Mismatch =>
            return "CL_IMAGE_FORMAT_MISMATCH";
         when Image_Format_Not_Supported =>
            return "CL_IMAGE_FORMAT_NOT_SUPPORTED";
         when Build_Program_Failure =>
            return "CL_BUILD_PROGRAM_FAILURE";
         when Map_Failure =>
            return "CL_MAP_FAILURE";
         when Invalid_Value =>
            return "CL_INVALID_VALUE";
         when Invalid_Device_Type =>
            return "CL_INVALID_DEVICE_TYPE";
         when Invalid_Platform =>
            return "CL_INVALID_PLATFORM";
         when Invalid_Device =>
            return "CL_INVALID_DEVICE";
         when Invalid_Context =>
            return "CL_INVALID_CONTEXT";
         when Invalid_Command_Queue =>
            return "CL_INVALID_COMMAND_QUEUE";
         when Invalid_Mem_Object =>
            return "CL_INVALID_MEM_OBJECT";
         when Invalid_Binary =>
            return "CL_INVALID_BINARY";
         when Invalid_Build_Options =>
            return "CL_INVALID_BUILD_OPTIONS";
         when Invalid_Program =>
            return "CL_INVALID_PROGRAM";
         when Invalid_Program_Executable =>
            return "CL_INVALID_PROGRAM_EXECUTABLE";
         when Invalid_Kernel_Name =>
            return "CL_INVALID_KERNEL_NAME";
         when Invalid_Kernel_Definition =>
            return "CL_INVALID_KERNEL_DEFINITION";
         when Invalid_Kernel =>
            return "CL_INVALID_KERNEL";
         when Invalid_Arg_Index =>
            return "CL_INVALID_ARG_INDEX";
         when Invalid_Arg_Value =>
            return "CL_INVALID_ARG_VALUE";
         when Invalid_Arg_Size =>
            return "CL_INVALID_ARG_SIZE";
         when Invalid_Kernel_Args =>
            return "CL_INVALID_KERNEL_ARGS";
         when Invalid_Work_Dimension =>
            return "CL_INVALID_WORK_DIMENSION";
         when Invalid_Work_Group_Size =>
            return "CL_INVALID_WORK_GROUP_SIZE";
         when Invalid_Work_Item_Size =>
            return "CL_INVALID_WORK_ITEM_SIZE";
         when Invalid_Global_Offset =>
            return "CL_INVALID_GLOBAL_OFFSET";
         when Invalid_Event_Wait_List =>
            return "CL_INVALID_EVENT_WAIT_LIST";
         when Invalid_Event =>
            return "CL_INVALID_EVENT";
         when Invalid_Operation =>
            return "CL_INVALID_OPERATION";
         when Invalid_GL_Object =>
            return "CL_INVALID_GL_OBJECT";
         when Invalid_Buffer_Size =>
            return "CL_INVALID_BUFFER_SIZE";
         when Invalid_Mip_Level =>
            return "CL_INVALID_MIP_LEVEL";
         when Invalid_Global_Work_Size =>
            return "CL_INVALID_GLOBAL_WORK_SIZE";
         when Platform_Not_Found_KHR =>
            return "CL_PLATFORM_NOT_FOUND_KHR";
         when OCLW_Fingerprint_Mismatch =>
            return "OCLW_FINGERPRINT_MISMATCH";
         when OCLW_Pack_Format_Error =>
            return "OCLW_PACK_FORMAT_ERROR";
         when OCLW_Hash_Mismatch =>
            return "OCLW_HASH_MISMATCH";
         when OCLW_IO_Error =>
            return "OCLW_IO_ERROR";
         when OCLW_Signature_Not_Implemented =>
            return "OCLW_SIGNATURE_NOT_IMPLEMENTED";
         when OCLW_Signature_Invalid =>
            return "OCLW_SIGNATURE_INVALID";
         when OCLW_Signature_Missing =>
            return "OCLW_SIGNATURE_MISSING";
         when others =>
            return
              "CL_UNKNOWN_ERROR("
              & Trimmed_Int_Image (Interfaces.C.int (Code))
              & ")";
      end case;
   end Image;

end OpenCL.Errors;
