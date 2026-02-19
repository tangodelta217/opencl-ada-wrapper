with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with OpenCL.Core.Programs;
with OpenCL.Errors;
with OpenCL.RT.Packs;
with OpenCL.RT.Security;
with Smoke_RT_Test_Verifier;

procedure Smoke_Crypto_Provider_Conformance is
   package Errors renames OpenCL.Errors;
   package Packs renames OpenCL.RT.Packs;
   package Programs renames OpenCL.Core.Programs;
   package Security renames OpenCL.RT.Security;

   use type Errors.Status_Code;
   use type Interfaces.C.int;

   Default_Symbol : constant String := "oclw_kpack_verify_v1";

   function Trim_Int_Image (Value : Interfaces.C.int) return String is
      Raw : constant String := Interfaces.C.int'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
   end Trim_Int_Image;

   function Status_Int_Image (Code : Errors.Status_Code) return String is
   begin
      return Trim_Int_Image (Interfaces.C.int (Code));
   end Status_Int_Image;

   function Env_Or_Empty (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return
           Ada.Strings.Fixed.Trim
             (Ada.Environment_Variables.Value (Name),
              Ada.Strings.Both);
      end if;
      return "";
   end Env_Or_Empty;

   function Run_Vector
     (Name : String;
      Alg : String;
      Sig : String;
      Signing_Text : String;
      Bin : Programs.Byte_Array;
      Used : Natural;
      Expected : Errors.Status_Code) return Boolean
   is
      Meta : Packs.Pack_Metadata := (others => <>);
      Status : Errors.Status_Code := Errors.Success;
   begin
      Meta.Signature_Required := True;
      Meta.Signature_Alg := Packs.To_Bounded (Alg);
      Meta.Signature_Value := Packs.To_Bounded (Sig);
      Meta.Signer_Id := Packs.To_Bounded ("OCLW-CONFORMANCE");

      Status :=
        Security.Verify
          (Meta => Meta,
           Signing_Text => Signing_Text,
           Bin => Bin,
           Used => Used,
           Strict => True);

      if Status = Expected then
         Ada.Text_IO.Put_Line
           ("INFO "
            & Name
            & "=PASS expected="
            & Errors.Image (Expected));
         return True;
      else
         Ada.Text_IO.Put_Line
           ("INFO "
            & Name
            & "=FAIL expected="
            & Errors.Image (Expected)
            & " got="
            & Errors.Image (Status)
            & " status_int="
            & Status_Int_Image (Status));
         return False;
      end if;
   end Run_Vector;

begin
   declare
      Plugin_Path : constant String := Env_Or_Empty ("OCLW_CRYPTO_PLUGIN");
      Plugin_Symbol_Env : constant String := Env_Or_Empty ("OCLW_CRYPTO_SYMBOL");
      Plugin_Symbol : constant String :=
        (if Plugin_Symbol_Env'Length = 0 then Default_Symbol else Plugin_Symbol_Env);
      Configure_Status : Errors.Status_Code := Errors.Success;
      Signing_Text : constant String :=
        "kpack_version=1" & ASCII.LF
        & "pack_id=conformance" & ASCII.LF
        & "kernel_name=add1" & ASCII.LF;
      Bin : Programs.Byte_Array (1 .. 16) :=
        (16#10#, 16#22#, 16#34#, 16#46#,
         16#58#, 16#6A#, 16#7C#, 16#8E#,
         16#9F#, 16#01#, 16#13#, 16#25#,
         16#37#, 16#49#, 16#5B#, 16#6D#);
      Used : constant Natural := Bin'Length;
      Correct_Signature : constant String :=
        Smoke_RT_Test_Verifier.Compute_Test_Signature
          (Signing_Text => Signing_Text,
           Bin => Bin,
           Used => Used);
      All_Pass : Boolean := True;
   begin
      if Plugin_Path'Length = 0 then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=missing_OCLW_CRYPTO_PLUGIN");
         return;
      end if;

      if not GNAT.OS_Lib.Is_Absolute_Path (Plugin_Path) then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=plugin_path_not_absolute");
         return;
      end if;

      if not Ada.Directories.Exists (Plugin_Path) then
         Ada.Text_IO.Put_Line ("RESULT=SKIP reason=plugin_not_found");
         return;
      end if;

      Ada.Text_IO.Put_Line ("INFO plugin_path=" & Plugin_Path);
      Ada.Text_IO.Put_Line ("INFO plugin_symbol=" & Plugin_Symbol);
      Ada.Environment_Variables.Set
        (Name => "OCLW_RT_PLUGIN_ALLOWLIST",
         Value => Ada.Directories.Containing_Directory (Plugin_Path));

      Security.Install_Verifier (V => null);
      Security.Configure_Plugin
        (Path => Plugin_Path,
         Symbol => Plugin_Symbol,
         Status => Configure_Status);
      if Configure_Status /= Errors.Success then
         Ada.Text_IO.Put_Line
           ("ERROR configure_plugin: "
            & Errors.Image (Configure_Status)
            & " status_int="
            & Status_Int_Image (Configure_Status));
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      if Correct_Signature'Length = 0 then
         Ada.Text_IO.Put_Line ("ERROR signature_generation_failed");
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      All_Pass :=
        Run_Vector
          (Name => "case_valid_signature",
           Alg => "TEST-FNV1A32",
           Sig => Correct_Signature,
           Signing_Text => Signing_Text,
           Bin => Bin,
           Used => Used,
           Expected => Errors.Success)
        and then
        Run_Vector
          (Name => "case_invalid_signature",
           Alg => "TEST-FNV1A32",
           Sig => "DEADBEEF",
           Signing_Text => Signing_Text,
           Bin => Bin,
           Used => Used,
           Expected => Errors.OCLW_Signature_Invalid)
        and then
        Run_Vector
          (Name => "case_unknown_alg",
           Alg => "UNKNOWN-ALG",
           Sig => Correct_Signature,
           Signing_Text => Signing_Text,
           Bin => Bin,
           Used => Used,
           Expected => Errors.OCLW_Signature_Invalid);

      if All_Pass then
         Ada.Text_IO.Put_Line ("RESULT=PASS");
      else
         Ada.Text_IO.Put_Line ("RESULT=FAIL");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end;
end Smoke_Crypto_Provider_Conformance;
