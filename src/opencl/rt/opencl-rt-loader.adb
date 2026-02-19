with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces;
with Interfaces.C;
with OpenCL.Core;
with OpenCL.Core.Device_Selection;
with OpenCL.Core.Contexts;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;
with OpenCL.RT.Packs;
with OpenCL.RT.Policy;
with OpenCL.RT.Rollback;
with OpenCL.RT.Security;

package body OpenCL.RT.Loader is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_64;
   use type OpenCL.Errors.Status_Code;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Starts_With_Test_Alg
     (Meta : OpenCL.RT.Packs.Pack_Metadata) return Boolean
   is
      Alg_Upper : constant String :=
        Ada.Characters.Handling.To_Upper
          (Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Alg)));
   begin
      if Alg_Upper'Length < 5 then
         return False;
      end if;

      return Alg_Upper (Alg_Upper'First .. Alg_Upper'First + 4) = "TEST-";
   end Starts_With_Test_Alg;

   function Rollback_Key
     (Meta : OpenCL.RT.Packs.Pack_Metadata) return String
   is
      Pack_Id_Text : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Pack_Id));
      Kernel_Text : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Kernel_Name));
   begin
      if Pack_Id_Text'Length = 0 then
         return "default|" & Kernel_Text;
      else
         return Pack_Id_Text & "|" & Kernel_Text;
      end if;
   end Rollback_Key;

   procedure Select_Device
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Platform : out OpenCL.Core.Platform;
      Device : out OpenCL.Core.Device;
      Status : out Status_Code)
   is
      package Errors renames OpenCL.Errors;
      Selection : OpenCL.Core.Device_Selection.Selection_Result;
      Null_Platform : OpenCL.Core.Platform;
      Null_Device : OpenCL.Core.Device;
   begin
      Platform := Null_Platform;
      Device := Null_Device;
      Status := Errors.Success;

      Selection :=
        OpenCL.Core.Device_Selection.Select_Device
          (Expected_Platform_Name =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Platform_Name)),
           Expected_Platform_Vendor =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Platform_Vendor)),
           Expected_Platform_Version =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Platform_Version)),
           Expected_Device_Name =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Device_Name)),
           Expected_Device_Vendor =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Device_Vendor)),
           Expected_Device_Version =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Device_Version)),
           Expected_Driver_Version =>
             Trimmed (OpenCL.RT.Packs.To_String (Meta.Driver_Version)));

      Platform := Selection.Platform;
      Device := Selection.Device;
      Status := Selection.Status;
   end Select_Device;

   procedure Create_Program_From_Pack_Internal
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Meta : OpenCL.RT.Packs.Pack_Metadata;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Prg : out OpenCL.Core.Programs.Program;
      Strict_RT : Boolean;
      Status : out Status_Code)
   is
      package Errors renames OpenCL.Errors;
      package Programs renames OpenCL.Core.Programs;
      package Policy renames OpenCL.RT.Policy;
      package Rollback renames OpenCL.RT.Rollback;
      package Security renames OpenCL.RT.Security;

      Binary_Status : Errors.Status_Code := Errors.Success;
      Build_Status : Errors.Status_Code := Errors.Success;
      Release_Status : Errors.Status_Code := Errors.Success;
      Rollback_Status : Errors.Status_Code := Errors.Success;
      Last_Counter : Interfaces.Unsigned_64 := 0;
      Null_Program : Programs.Program;
      Build_Options_Text : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Build_Options));
   begin
      Prg := Null_Program;
      Status := Errors.Success;

      if Used = 0 or else Used > Bin'Length then
         Status := Errors.Invalid_Value;
         return;
      end if;

      if Interfaces.C.size_t (Used) > OpenCL.RT.Packs.Effective_Max_RT_Binary_Size
        or else Meta.Binary_Size > OpenCL.RT.Packs.Effective_Max_RT_Binary_Size
      then
         Status := Errors.OCLW_Limit_Exceeded;
         return;
      end if;

      if Strict_RT and then not Meta.Signature_Required then
         Status := Errors.OCLW_Signature_Missing;
         return;
      end if;

      if Strict_RT
        and then not Policy.Is_Build_Options_Allowed (Build_Options_Text)
      then
         Status := Errors.OCLW_Build_Options_Disallowed;
         return;
      end if;

      if Meta.Signature_Required then
         if Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Alg))'Length = 0
           or else Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Value))'Length = 0
         then
            Status := Errors.OCLW_Signature_Missing;
            return;
         end if;

         if Strict_RT and then Starts_With_Test_Alg (Meta) then
            Status := Errors.OCLW_Signature_Disallowed;
            return;
         end if;

         declare
            Signing_Text : constant String :=
              OpenCL.RT.Packs.Canonical_Signing_Text (Meta);
            Verify_Status : Errors.Status_Code := Errors.Success;
         begin
            if Signing_Text'Length = 0 then
               Status := Errors.OCLW_Pack_Format_Error;
               return;
            end if;

            Verify_Status :=
              Security.Verify
                (Meta => Meta,
                 Signing_Text => Signing_Text,
                 Bin => Bin,
                 Used => Used,
                 Strict => Strict_RT);
            if Verify_Status /= Errors.Success then
               Status := Verify_Status;
               return;
            end if;
         end;
      end if;

      if Strict_RT and then Meta.Monotonic_Counter_Present then
         Rollback_Status :=
           Rollback.Get_Last
             (Key => Rollback_Key (Meta),
              Value => Last_Counter);
         if Rollback_Status = Errors.OCLW_Rollback_Not_Implemented then
            Status := Errors.OCLW_Rollback_Not_Implemented;
            return;
         elsif Rollback_Status /= Errors.Success then
            Status := Rollback_Status;
            return;
         end if;

         if Meta.Monotonic_Counter < Last_Counter then
            Status := Errors.OCLW_Rollback_Detected;
            return;
         end if;

         Rollback_Status :=
           Rollback.Set_Last
             (Key => Rollback_Key (Meta),
              Value => Meta.Monotonic_Counter);
         if Rollback_Status /= Errors.Success then
            Status := Rollback_Status;
            return;
         end if;
      end if;

      declare
         Last_Index : constant Positive := Bin'First + Integer (Used) - 1;
      begin
         Programs.Create_From_Binary
           (Ctx => Ctx,
            Dev => Dev,
            Data => Bin (Bin'First .. Last_Index),
            Prg => Prg,
            Binary_Status => Binary_Status,
            Status => Status);
      end;

      if Status /= Errors.Success then
         return;
      end if;

      if Binary_Status /= Errors.Success then
         Status := Binary_Status;
         return;
      end if;

      Programs.Build
        (Prg => Prg,
         Dev => Dev,
         Options => Build_Options_Text,
         Status => Build_Status);

      if Build_Status /= Errors.Success then
         Programs.Release (Prg => Prg, Status => Release_Status);
         if Release_Status /= Errors.Success then
            null;
         end if;
         Status := Build_Status;
         return;
      end if;
   end Create_Program_From_Pack_Internal;

   procedure Create_Program_From_Pack
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Meta : OpenCL.RT.Packs.Pack_Metadata;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Prg : out OpenCL.Core.Programs.Program;
      Status : out Status_Code)
   is
   begin
      Create_Program_From_Pack_Internal
        (Ctx => Ctx,
         Dev => Dev,
         Meta => Meta,
         Bin => Bin,
         Used => Used,
         Prg => Prg,
         Strict_RT => False,
         Status => Status);
   end Create_Program_From_Pack;

   procedure Create_Program_From_Pack_Strict_RT
     (Ctx : OpenCL.Core.Contexts.Context;
      Dev : OpenCL.Core.Device;
      Meta : OpenCL.RT.Packs.Pack_Metadata;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Prg : out OpenCL.Core.Programs.Program;
      Status : out Status_Code)
   is
   begin
      Create_Program_From_Pack_Internal
        (Ctx => Ctx,
         Dev => Dev,
         Meta => Meta,
         Bin => Bin,
         Used => Used,
         Prg => Prg,
         Strict_RT => True,
         Status => Status);
   end Create_Program_From_Pack_Strict_RT;

end OpenCL.RT.Loader;
