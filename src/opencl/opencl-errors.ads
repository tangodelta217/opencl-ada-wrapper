with Interfaces.C;

package OpenCL.Errors is
   type Status_Code is new Interfaces.C.int;

   Success : constant Status_Code := 0;
   Device_Not_Found : constant Status_Code := Status_Code (-1);
   Device_Not_Available : constant Status_Code := Status_Code (-2);
   Compiler_Not_Available : constant Status_Code := Status_Code (-3);
   Mem_Object_Allocation_Failure : constant Status_Code := Status_Code (-4);
   Out_Of_Resources : constant Status_Code := Status_Code (-5);
   Out_Of_Host_Memory : constant Status_Code := Status_Code (-6);
   Profiling_Info_Not_Available : constant Status_Code := Status_Code (-7);
   Mem_Copy_Overlap : constant Status_Code := Status_Code (-8);
   Image_Format_Mismatch : constant Status_Code := Status_Code (-9);
   Image_Format_Not_Supported : constant Status_Code := Status_Code (-10);
   Build_Program_Failure : constant Status_Code := Status_Code (-11);
   Map_Failure : constant Status_Code := Status_Code (-12);

   Invalid_Value : constant Status_Code := Status_Code (-30);
   Invalid_Device_Type : constant Status_Code := Status_Code (-31);
   Invalid_Platform : constant Status_Code := Status_Code (-32);
   Invalid_Device : constant Status_Code := Status_Code (-33);
   Invalid_Context : constant Status_Code := Status_Code (-34);
   Invalid_Command_Queue : constant Status_Code := Status_Code (-36);
   Invalid_Mem_Object : constant Status_Code := Status_Code (-38);
   Invalid_Binary : constant Status_Code := Status_Code (-42);
   Invalid_Build_Options : constant Status_Code := Status_Code (-43);
   Invalid_Program : constant Status_Code := Status_Code (-44);
   Invalid_Program_Executable : constant Status_Code := Status_Code (-45);
   Invalid_Kernel_Name : constant Status_Code := Status_Code (-46);
   Invalid_Kernel_Definition : constant Status_Code := Status_Code (-47);
   Invalid_Kernel : constant Status_Code := Status_Code (-48);
   Invalid_Arg_Index : constant Status_Code := Status_Code (-49);
   Invalid_Arg_Value : constant Status_Code := Status_Code (-50);
   Invalid_Arg_Size : constant Status_Code := Status_Code (-51);
   Invalid_Kernel_Args : constant Status_Code := Status_Code (-52);
   Invalid_Work_Dimension : constant Status_Code := Status_Code (-53);
   Invalid_Work_Group_Size : constant Status_Code := Status_Code (-54);
   Invalid_Work_Item_Size : constant Status_Code := Status_Code (-55);
   Invalid_Global_Offset : constant Status_Code := Status_Code (-56);
   Invalid_Event_Wait_List : constant Status_Code := Status_Code (-57);
   Invalid_Event : constant Status_Code := Status_Code (-58);
   Invalid_Operation : constant Status_Code := Status_Code (-59);
   Invalid_GL_Object : constant Status_Code := Status_Code (-60);
   Invalid_Buffer_Size : constant Status_Code := Status_Code (-61);
   Invalid_Mip_Level : constant Status_Code := Status_Code (-62);
   Invalid_Global_Work_Size : constant Status_Code := Status_Code (-63);

   Platform_Not_Found_KHR : constant Status_Code := Status_Code (-1001);

   --  Wrapper-internal status domain (outside standard OpenCL error range).
   OCLW_Fingerprint_Mismatch : constant Status_Code := Status_Code (-32_001);
   OCLW_Pack_Format_Error : constant Status_Code := Status_Code (-32_002);
   OCLW_Hash_Mismatch : constant Status_Code := Status_Code (-32_003);
   OCLW_IO_Error : constant Status_Code := Status_Code (-32_004);

   function Is_Success (Code : Status_Code) return Boolean;
   function Image (Code : Status_Code) return String;
end OpenCL.Errors;
