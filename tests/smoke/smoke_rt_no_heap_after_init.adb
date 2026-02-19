with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Buffers;
with OpenCL.Core.Contexts;
with OpenCL.Core.Kernels;
with OpenCL.Core.Programs;
with OpenCL.Core.Queues;
with OpenCL.Errors;
with OpenCL.RT.Loader;
with OpenCL.RT.Memtrack;
with OpenCL.RT.Packs;

procedure Smoke_RT_No_Heap_After_Init is
   package Core renames OpenCL.Core;
   package Buffers renames OpenCL.Core.Buffers;
   package Contexts renames OpenCL.Core.Contexts;
   package Errors renames OpenCL.Errors;
   package Kernels renames OpenCL.Core.Kernels;
   package Loader renames OpenCL.RT.Loader;
   package Memtrack renames OpenCL.RT.Memtrack;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Queues renames OpenCL.Core.Queues;

   use type Errors.Status_Code;
   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_8;

   Default_Pack_Dir : constant String :=
     "docs/VV/Execution_Logs/local/pack_rt_no_heap_after_init";
   Transfer_Bytes : constant Interfaces.C.size_t := 4096;
   Steady_Iterations : constant Positive := 8;

   subtype Byte is Interfaces.Unsigned_8;
   subtype Byte_Index is Natural range 0 .. Natural (Transfer_Bytes) - 1;
   type Host_Byte_Array is array (Byte_Index) of aliased Byte;

   type Program_Byte_Array_Access is access all Programs.Byte_Array;
   procedure Free_Program_Byte_Array is new Ada.Unchecked_Deallocation
     (Object => Programs.Byte_Array,
      Name => Program_Byte_Array_Access);

   Input_Data : Host_Byte_Array := (others => 0);
   Output_Data : Host_Byte_Array := (others => 0);

   Meta : Packs.Pack_Metadata;
   Binary_Data : Program_Byte_Array_Access := null;
   Binary_Used : Natural := 0;

   Platform : Core.Platform;
   Device : Core.Device;
   Ctx : Contexts.Context;
   Q : Queues.Queue;
   In_Buffer : Buffers.Buffer;
   Out_Buffer : Buffers.Buffer;
   Prg : Programs.Program;
   K : Kernels.Kernel;

   Status : Errors.Status_Code := Errors.Success;
   Failed : Boolean := False;

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function Resolve_Pack_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("OCLW_PACK_DIR") then
         declare
            Value : constant String := Ada.Environment_Variables.Value ("OCLW_PACK_DIR");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return Default_Pack_Dir;
   end Resolve_Pack_Dir;

   function Candidate_From_Self (Relative_Path : String) return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Parent_1 : constant String := Ada.Directories.Containing_Directory (Self_Dir);
      Parent_2 : constant String := Ada.Directories.Containing_Directory (Parent_1);
   begin
      if Parent_2'Length = 0 then
         return Relative_Path;
      else
         return Parent_2 & "/" & Relative_Path;
      end if;
   exception
      when others =>
         return Relative_Path;
   end Candidate_From_Self;

   function Locate_Gen_Pack_Add1 return String is
      Self_Path : constant String := Ada.Command_Line.Command_Name;
      Self_Dir : constant String := Ada.Directories.Containing_Directory (Self_Path);
      Candidate_1 : constant String := Self_Dir & "/gen_pack_add1";
      Candidate_2 : constant String := "tests/bin/gen_pack_add1";
      Candidate_3 : constant String := Candidate_From_Self ("tests/bin/gen_pack_add1");
   begin
      if Ada.Directories.Exists (Candidate_1) then
         return Candidate_1;
      elsif Ada.Directories.Exists (Candidate_2) then
         return Candidate_2;
      elsif Ada.Directories.Exists (Candidate_3) then
         return Candidate_3;
      else
         return "";
      end if;
   end Locate_Gen_Pack_Add1;

   function Ensure_Base_Pack
     (Pack_Dir : String;
      Manifest_Path : String;
      Binary_Path : String) return Boolean
   is
      Gen_Exec : constant String := Locate_Gen_Pack_Add1;
      Args : GNAT.OS_Lib.Argument_List (1 .. 1);
      Success : Boolean := False;
      Return_Code : Integer := 0;
      Gen_Log_Path : constant String := Pack_Dir & "/gen_pack_add1.log";
   begin
      if Gen_Exec'Length = 0 then
         Ada.Text_IO.Put_Line ("INFO skip_reason=missing_gen_pack_add1_executable");
         return False;
      end if;

      if not Ada.Directories.Exists (Pack_Dir) then
         Ada.Directories.Create_Path (Pack_Dir);
      end if;

      Ada.Environment_Variables.Set ("OCLW_PACK_DIR", Pack_Dir);
      Args (1) := new String'("");
      GNAT.OS_Lib.Spawn
        (Program_Name => Gen_Exec,
         Args => Args,
         Output_File => Gen_Log_Path,
         Success => Success,
         Return_Code => Return_Code,
         Err_To_Out => True);
      GNAT.OS_Lib.Free (Args (1));

      Ada.Text_IO.Put_Line
        ("INFO gen_pack_add1_return_code="
         & Trim_Int_Image (Interfaces.C.int (Return_Code))
         & " log="
         & Gen_Log_Path);

      return
        Success
        and then Return_Code = 0
        and then Ada.Directories.Exists (Manifest_Path)
        and then Ada.Directories.Exists (Binary_Path);
   end Ensure_Base_Pack;

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
      Programs.Release (Prg => Prg, Status => Release_Status);
      Buffers.Release (B => Out_Buffer, Status => Release_Status);
      Buffers.Release (B => In_Buffer, Status => Release_Status);
      Queues.Release (Q => Q, Status => Release_Status);
      Contexts.Release (Ctx => Ctx, Status => Release_Status);

      if Binary_Data /= null then
         Free_Program_Byte_Array (Binary_Data);
      end if;
   end Cleanup;

begin
   declare
      Pack_Dir : constant String := Resolve_Pack_Dir;
      Manifest_Path : constant String := Pack_Dir & "/manifest.kpack";
      Binary_Path : constant String := Pack_Dir & "/program.bin";
   begin
      Ada.Text_IO.Put_Line ("INFO pack_dir=" & Pack_Dir);
      Ada.Text_IO.Put_Line ("INFO manifest_path=" & Manifest_Path);
      Ada.Text_IO.Put_Line ("INFO binary_path=" & Binary_Path);
      Ada.Text_IO.Put_Line ("INFO mem_pool_bytes=" & Interfaces.C.size_t'Image (Interfaces.C.size_t (Memtrack.Pool_Bytes)));

      if not Ensure_Base_Pack
          (Pack_Dir => Pack_Dir,
           Manifest_Path => Manifest_Path,
           Binary_Path => Binary_Path)
      then
         Ada.Text_IO.Put_Line ("RESULT=SKIP");
         return;
      end if;

      Packs.Read_Manifest
        (Path => Manifest_Path,
         Meta => Meta,
         Status => Status);
      if not Errors.Is_Success (Status) then
         Mark_Fail ("read_manifest", Status);
      end if;

      if not Failed then
         if Meta.Binary_Size = 0 then
            Mark_Fail ("manifest_binary_size_zero", Errors.OCLW_Pack_Format_Error);
         elsif Meta.Binary_Size > Interfaces.C.size_t (Positive'Last) then
            Mark_Fail ("manifest_binary_size_too_large", Errors.OCLW_Pack_Format_Error);
         else
            Binary_Data := new Programs.Byte_Array (1 .. Positive (Integer (Meta.Binary_Size)));
         end if;
      end if;

      if not Failed then
         Packs.Read_Binary
           (Path => Binary_Path,
            Buffer => Binary_Data.all,
            Used => Binary_Used,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("read_binary", Status);
         end if;
      end if;

      if not Failed then
         Packs.Verify_Binary
           (Meta => Meta,
            Buffer => Binary_Data.all,
            Used => Binary_Used,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("verify_binary", Status);
         end if;
      end if;

      if not Failed then
         Loader.Select_Device
           (Meta => Meta,
            Platform => Platform,
            Device => Device,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("select_device", Status);
         end if;
      end if;

      if not Failed then
         Contexts.Create
           (Device => Device,
            Ctx => Ctx,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_context", Status);
         end if;
      end if;

      if not Failed then
         Queues.Create
           (Ctx => Ctx,
            Dev => Device,
            Q => Q,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_queue", Status);
         end if;
      end if;

      if not Failed then
         Loader.Create_Program_From_Pack
           (Ctx => Ctx,
            Dev => Device,
            Meta => Meta,
            Bin => Binary_Data.all,
            Used => Binary_Used,
            Prg => Prg,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_program_from_pack", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => In_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_in_buffer", Status);
         end if;
      end if;

      if not Failed then
         Buffers.Create
           (Ctx => Ctx,
            Bytes => Transfer_Bytes,
            B => Out_Buffer,
            Status => Status);
         if not Errors.Is_Success (Status) then
            Mark_Fail ("create_out_buffer", Status);
         end if;
      end if;

      if not Failed then
         declare
            Kernel_Name : constant String :=
              Ada.Strings.Fixed.Trim
                (Packs.To_String (Meta.Kernel_Name),
                 Ada.Strings.Both);
         begin
            if Kernel_Name'Length = 0 then
               Mark_Fail ("kernel_name_empty", Errors.OCLW_Pack_Format_Error);
            else
               Kernels.Create
                 (Prg => Prg,
                  Name => Kernel_Name,
                  K => K,
                  Status => Status);
               if not Errors.Is_Success (Status) then
                  Mark_Fail ("create_kernel", Status);
               end if;
            end if;
         end;
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
         Memtrack.Enable_Fail_On_Alloc_After_Freeze (Enable => True);
         Memtrack.Freeze;
         Ada.Text_IO.Put_Line
           ("INFO freeze_applied=1 total_allocs_before_freeze="
            & Natural'Image (Memtrack.Total_Allocs)
            & " total_bytes_before_freeze="
            & Interfaces.C.size_t'Image
                (Interfaces.C.size_t (Memtrack.Total_Bytes)));
      end if;

      if not Failed then
         for Iteration in 1 .. Steady_Iterations loop
            for I in Input_Data'Range loop
               Input_Data (I) := Byte ((I + Iteration) mod 256);
               Output_Data (I) := 0;
            end loop;

            Buffers.Write
              (Q => Q,
               B => In_Buffer,
               Host => Input_Data (Input_Data'First)'Address,
               Bytes => Transfer_Bytes,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("write_in_buffer", Status);
               exit;
            end if;

            Kernels.Enqueue_1D
              (Q => Q,
               K => K,
               Global_Size => Transfer_Bytes,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("enqueue_1d", Status);
               exit;
            end if;

            Buffers.Read
              (Q => Q,
               B => Out_Buffer,
               Host => Output_Data (Output_Data'First)'Address,
               Bytes => Transfer_Bytes,
               Status => Status);
            if not Errors.Is_Success (Status) then
               Mark_Fail ("read_out_buffer", Status);
               exit;
            end if;

            for I in Output_Data'Range loop
               declare
                  Expected : constant Byte := Byte ((I + Iteration + 1) mod 256);
               begin
                  if Output_Data (I) /= Expected then
                     Ada.Text_IO.Put_Line
                       ("ERROR output_mismatch iter="
                        & Natural'Image (Iteration)
                        & " index="
                        & Natural'Image (I));
                     Mark_Fail ("verify_output", Errors.Invalid_Value);
                     exit;
                  end if;
               end;
            end loop;

            exit when Failed;
         end loop;
      end if;

      if not Failed then
         declare
            Post_Freeze_Allocs : constant Natural := Memtrack.Allocs_After_Freeze;
         begin
            Ada.Text_IO.Put_Line ("INFO iterations=" & Natural'Image (Steady_Iterations));
            Ada.Text_IO.Put_Line ("INFO allocs_after_freeze=" & Natural'Image (Post_Freeze_Allocs));
            if Post_Freeze_Allocs /= 0 then
               Mark_Fail ("allocs_after_freeze_nonzero", Errors.OCLW_Limit_Exceeded);
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
end Smoke_RT_No_Heap_After_Init;
