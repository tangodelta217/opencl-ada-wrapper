with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with GNAT.OS_Lib;
with Interfaces.C;
with Interfaces.C.Strings;
with OpenCL.Errors;
with OpenCL.RT.Memtrack;
with OpenCL.RT.Packs;
with System;

package body OpenCL.RT.Security is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   use type Interfaces.C.int;
   use type Interfaces.C.size_t;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.Strings.chars_ptr;
   use type OpenCL.Errors.Status_Code;
   use type System.Address;

   --  Dynamic loader ABI (POSIX).
   function dlopen
     (Filename : Interfaces.C.Strings.chars_ptr;
      Flags : Interfaces.C.int) return System.Address;
   pragma Import (C, dlopen, "dlopen");

   function dlsym
     (Handle : System.Address;
      Symbol : Interfaces.C.Strings.chars_ptr) return System.Address;
   pragma Import (C, dlsym, "dlsym");

   function dlclose (Handle : System.Address) return Interfaces.C.int;
   pragma Import (C, dlclose, "dlclose");

   function dlerror return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, dlerror, "dlerror");

   RTLD_NOW : constant Interfaces.C.int := 2;
   Default_Crypto_Symbol : constant String := "oclw_kpack_verify_v1";
   Max_Canonical_Path_Length : constant Positive := 4_096;
   Allowlist_Separator : constant Character := ':';
   subtype Mode_T is Interfaces.C.unsigned;
   S_IFMT : constant Mode_T := 16#F000#;
   S_IFDIR : constant Mode_T := 16#4000#;
   S_IFREG : constant Mode_T := 16#8000#;
   S_IFLNK : constant Mode_T := 16#A000#;
   S_IWOTH : constant Mode_T := 16#0002#;

   type Time_Spec is record
      Tv_Sec : Interfaces.C.long;
      Tv_Nsec : Interfaces.C.long;
   end record;
   pragma Convention (C, Time_Spec);

   type Stat_Buffer is record
      St_Dev : Interfaces.C.unsigned_long;
      St_Ino : Interfaces.C.unsigned_long;
      St_Nlink : Interfaces.C.unsigned_long;
      St_Mode : Mode_T;
      St_Uid : Interfaces.C.unsigned;
      St_Gid : Interfaces.C.unsigned;
      Pad_0 : Interfaces.C.int;
      St_Rdev : Interfaces.C.unsigned_long;
      St_Size : Interfaces.C.long;
      St_Blksize : Interfaces.C.long;
      St_Blocks : Interfaces.C.long;
      St_Atim : Time_Spec;
      St_Mtim : Time_Spec;
      St_Ctim : Time_Spec;
      Glibc_Reserved_0 : Interfaces.C.long;
      Glibc_Reserved_1 : Interfaces.C.long;
      Glibc_Reserved_2 : Interfaces.C.long;
   end record;
   pragma Convention (C, Stat_Buffer);

   function C_Stat
     (Path : Interfaces.C.Strings.chars_ptr;
      Info : access Stat_Buffer) return Interfaces.C.int;
   pragma Import (C, C_Stat, "stat");

   function C_Lstat
     (Path : Interfaces.C.Strings.chars_ptr;
      Info : access Stat_Buffer) return Interfaces.C.int;
   pragma Import (C, C_Lstat, "lstat");

   function C_Realpath
     (Path : Interfaces.C.Strings.chars_ptr;
      Resolved_Path : System.Address) return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, C_Realpath, "realpath");

   type Plugin_Verify_Fn is access function
     (Signature_Alg : Interfaces.C.Strings.chars_ptr;
      Signer_Id : Interfaces.C.Strings.chars_ptr;
      Signature_Value : Interfaces.C.Strings.chars_ptr;
      Signing_Text : System.Address;
      Signing_Text_Len : Interfaces.C.size_t;
      Program_Bin : System.Address;
      Program_Bin_Len : Interfaces.C.size_t) return Interfaces.C.int;
   pragma Convention (C, Plugin_Verify_Fn);

   function To_Plugin_Verify_Fn is new Ada.Unchecked_Conversion
     (Source => System.Address,
      Target => Plugin_Verify_Fn);

   type Plugin_State_Kind is (Not_Attempted, Loaded, Unavailable);

   Installed_Verifier : Verify_Fn := null;
   Plugin_State : Plugin_State_Kind := Not_Attempted;
   Plugin_Handle : System.Address := System.Null_Address;
   Plugin_Verifier : Plugin_Verify_Fn := null;
   Plugin_Path_Buffer : String (1 .. Max_Canonical_Path_Length) := (others => ' ');
   Plugin_Path_Last : Natural := 0;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Optional_Env
     (Name : String;
      Default : String := "") return String;

   procedure Free_If_Needed
     (Ptr : in out Interfaces.C.Strings.chars_ptr)
   is
   begin
      if Ptr /= Interfaces.C.Strings.Null_Ptr then
         Interfaces.C.Strings.Free (Ptr);
         Ptr := Interfaces.C.Strings.Null_Ptr;
      end if;
   end Free_If_Needed;

   function Is_Regular_File (Mode : Mode_T) return Boolean is
   begin
      return (Mode and S_IFMT) = S_IFREG;
   end Is_Regular_File;

   function Is_Directory (Mode : Mode_T) return Boolean is
   begin
      return (Mode and S_IFMT) = S_IFDIR;
   end Is_Directory;

   function Is_Symlink (Mode : Mode_T) return Boolean is
   begin
      return (Mode and S_IFMT) = S_IFLNK;
   end Is_Symlink;

   procedure Set_Plugin_Path (Path : String) is
   begin
      Plugin_Path_Last := 0;
      if Path'Length = 0 then
         return;
      end if;

      if Path'Length > Plugin_Path_Buffer'Length then
         Plugin_Path_Buffer := (others => ' ');
         Plugin_Path_Buffer (1 .. Plugin_Path_Buffer'Length) :=
           Path (Path'First .. Path'First + Plugin_Path_Buffer'Length - 1);
         Plugin_Path_Last := Plugin_Path_Buffer'Length;
      else
         Plugin_Path_Buffer := (others => ' ');
         Plugin_Path_Buffer (1 .. Path'Length) := Path;
         Plugin_Path_Last := Path'Length;
      end if;
   end Set_Plugin_Path;

   function Current_Plugin_Path return String is
   begin
      if Plugin_Path_Last = 0 then
         return "";
      else
         return Plugin_Path_Buffer (1 .. Plugin_Path_Last);
      end if;
   end Current_Plugin_Path;

   function Canonicalize_Path
     (Path : String;
      Canonical : out OpenCL.RT.Packs.Bounded_String) return Boolean
   is
      package C renames Interfaces.C;
      package CString renames Interfaces.C.Strings;

      C_Path : CString.chars_ptr := CString.Null_Ptr;
      Buffer : aliased C.char_array (0 .. C.size_t (Max_Canonical_Path_Length));
      Resolved : CString.chars_ptr := CString.Null_Ptr;
   begin
      Canonical := OpenCL.RT.Packs.To_Bounded ("");

      if Path'Length = 0 then
         return False;
      end if;

      C_Path := CString.New_String (Path);
      Buffer := (others => C.nul);
      Resolved :=
        C_Realpath
          (Path => C_Path,
           Resolved_Path => Buffer (Buffer'First)'Address);
      Free_If_Needed (C_Path);

      if Resolved = CString.Null_Ptr then
         return False;
      end if;

      declare
         Canon_Text : constant String :=
           Trimmed (C.To_Ada (Item => Buffer, Trim_Nul => True));
      begin
         if Canon_Text'Length = 0 then
            return False;
         end if;

         Canonical := OpenCL.RT.Packs.To_Bounded (Canon_Text);
         return True;
      end;
   exception
      when others =>
         Free_If_Needed (C_Path);
         Canonical := OpenCL.RT.Packs.To_Bounded ("");
         return False;
   end Canonicalize_Path;

   function Path_Is_Under_Dir
     (Path : String;
      Dir : String) return Boolean
   is
   begin
      if Dir'Length = 0 then
         return False;
      end if;

      if Dir = "/" then
         return Path'Length > 0 and then Path (Path'First) = '/';
      end if;

      if Path'Length < Dir'Length then
         return False;
      end if;

      if Path (Path'First .. Path'First + Dir'Length - 1) /= Dir then
         return False;
      end if;

      if Path'Length = Dir'Length then
         return True;
      end if;

      if Dir (Dir'Last) = '/' then
         return True;
      end if;

      return Path (Path'First + Dir'Length) = '/';
   end Path_Is_Under_Dir;

   function Path_Is_Allowed_By_Allowlist
     (Plugin_Canonical_Path : String;
      Strict : Boolean) return Boolean
   is
      package CString renames Interfaces.C.Strings;

      Allowlist_Raw : constant String :=
        Optional_Env ("OCLW_RT_PLUGIN_ALLOWLIST");
      Scan : Positive := 1;
   begin
      if Allowlist_Raw'Length = 0 then
         return not Strict;
      end if;

      while Scan <= Allowlist_Raw'Length loop
         declare
            Next_Sep : Natural := Scan;
         begin
            while Next_Sep <= Allowlist_Raw'Length
              and then Allowlist_Raw (Next_Sep) /= Allowlist_Separator
            loop
               Next_Sep := Next_Sep + 1;
            end loop;

            declare
               Entry_Raw : constant String :=
                 (if Next_Sep = Scan then ""
                  elsif Next_Sep <= Allowlist_Raw'Length
                  then Trimmed (Allowlist_Raw (Scan .. Next_Sep - 1))
                  else Trimmed (Allowlist_Raw (Scan .. Allowlist_Raw'Length)));
               Entry_Canonical : OpenCL.RT.Packs.Bounded_String :=
                 OpenCL.RT.Packs.To_Bounded ("");
               Entry_C_Path : CString.chars_ptr := CString.Null_Ptr;
               Entry_Stat : aliased Stat_Buffer;
               Entry_Is_Dir : Boolean := False;
            begin
               if Entry_Raw'Length > 0
                 and then Canonicalize_Path (Entry_Raw, Entry_Canonical)
               then
                  Entry_C_Path :=
                    CString.New_String (OpenCL.RT.Packs.To_String (Entry_Canonical));
                  Entry_Is_Dir :=
                    (C_Stat (Path => Entry_C_Path, Info => Entry_Stat'Access) = 0)
                    and then Is_Directory (Entry_Stat.St_Mode);
                  Free_If_Needed (Entry_C_Path);

                  if Entry_Is_Dir
                    and then Path_Is_Under_Dir
                               (Path => Plugin_Canonical_Path,
                                Dir => OpenCL.RT.Packs.To_String (Entry_Canonical))
                  then
                     return True;
                  end if;
               end if;
            exception
               when others =>
                  Free_If_Needed (Entry_C_Path);
            end;

            if Next_Sep > Allowlist_Raw'Length then
               exit;
            end if;
            Scan := Next_Sep + 1;
         end;
      end loop;

      return False;
   end Path_Is_Allowed_By_Allowlist;

   procedure Validate_Plugin_Path
     (Path : String;
      Strict : Boolean;
      Canonical : out OpenCL.RT.Packs.Bounded_String;
      Status : out OpenCL.Errors.Status_Code)
   is
      package CString renames Interfaces.C.Strings;

      Effective_Path : constant String := Trimmed (Path);
      C_Path : CString.chars_ptr := CString.Null_Ptr;
      Lstat_Info : aliased Stat_Buffer;
   begin
      Canonical := OpenCL.RT.Packs.To_Bounded ("");
      Status := OpenCL.Errors.Success;

      if Effective_Path'Length = 0
        or else not GNAT.OS_Lib.Is_Absolute_Path (Effective_Path)
      then
         Status := OpenCL.Errors.OCLW_Plugin_Path_Not_Allowed;
         return;
      end if;

      C_Path := CString.New_String (Effective_Path);
      if C_Lstat (Path => C_Path, Info => Lstat_Info'Access) /= 0 then
         Free_If_Needed (C_Path);
         Status := OpenCL.Errors.OCLW_Plugin_Untrusted;
         return;
      end if;
      Free_If_Needed (C_Path);

      if Is_Symlink (Lstat_Info.St_Mode) then
         Status := OpenCL.Errors.OCLW_FS_Policy_Violation;
         return;
      end if;

      if not Is_Regular_File (Lstat_Info.St_Mode) then
         Status := OpenCL.Errors.OCLW_FS_Policy_Violation;
         return;
      end if;

      if (Lstat_Info.St_Mode and S_IWOTH) /= 0 then
         Status := OpenCL.Errors.OCLW_Plugin_Unsafe_Perms;
         return;
      end if;

      if not Canonicalize_Path (Path => Effective_Path, Canonical => Canonical) then
         Status := OpenCL.Errors.OCLW_Plugin_Untrusted;
         return;
      end if;

      if not Path_Is_Allowed_By_Allowlist
               (Plugin_Canonical_Path => OpenCL.RT.Packs.To_String (Canonical),
                Strict => Strict)
      then
         Status := OpenCL.Errors.OCLW_Plugin_Path_Not_Allowed;
         return;
      end if;
   exception
      when others =>
         Free_If_Needed (C_Path);
         Canonical := OpenCL.RT.Packs.To_Bounded ("");
         Status := OpenCL.Errors.OCLW_Plugin_Untrusted;
   end Validate_Plugin_Path;

   procedure Reset_Cached_Plugin is
   begin
      if Plugin_Handle /= System.Null_Address then
         declare
            Close_Result : constant Interfaces.C.int :=
              dlclose (Handle => Plugin_Handle);
         begin
            if Close_Result /= 0 then
               null;
            end if;
         end;
      end if;

      Plugin_Handle := System.Null_Address;
      Plugin_Verifier := null;
      Plugin_State := Not_Attempted;
      Set_Plugin_Path ("");
   end Reset_Cached_Plugin;

   procedure Mark_Unavailable is
   begin
      Plugin_Handle := System.Null_Address;
      Plugin_Verifier := null;
      Plugin_State := Unavailable;
      Set_Plugin_Path ("");
   end Mark_Unavailable;

   function Optional_Env
     (Name : String;
      Default : String := "") return String
   is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         declare
            Value : constant String :=
              Trimmed (Ada.Environment_Variables.Value (Name));
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return Default;
   end Optional_Env;

   function Load_Plugin
     (Path : String;
      Symbol : String) return OpenCL.Errors.Status_Code
   is
      Path_Ptr : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Symbol_Ptr : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Handle : System.Address := System.Null_Address;
      Symbol_Address : System.Address := System.Null_Address;
      Verifier : Plugin_Verify_Fn := null;
      Effective_Path : constant String := Trimmed (Path);
      Effective_Symbol : constant String := Trimmed (Symbol);
   begin
      if Effective_Path'Length = 0 or else Effective_Symbol'Length = 0 then
         Mark_Unavailable;
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      Path_Ptr := Interfaces.C.Strings.New_String (Effective_Path);
      Symbol_Ptr := Interfaces.C.Strings.New_String (Effective_Symbol);

      declare
         Ignored_DLError : Interfaces.C.Strings.chars_ptr := dlerror;
      begin
         if Ignored_DLError /= Interfaces.C.Strings.Null_Ptr then
            null;
         end if;
      end;

      Handle := dlopen (Filename => Path_Ptr, Flags => RTLD_NOW);
      if Handle = System.Null_Address then
         Mark_Unavailable;
         Free_If_Needed (Path_Ptr);
         Free_If_Needed (Symbol_Ptr);
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      declare
         Ignored_DLError : Interfaces.C.Strings.chars_ptr := dlerror;
      begin
         if Ignored_DLError /= Interfaces.C.Strings.Null_Ptr then
            null;
         end if;
      end;

      Symbol_Address := dlsym (Handle => Handle, Symbol => Symbol_Ptr);
      if Symbol_Address = System.Null_Address then
         declare
            Close_Result : constant Interfaces.C.int := dlclose (Handle => Handle);
         begin
            if Close_Result /= 0 then
               null;
            end if;
         end;
         Mark_Unavailable;
         Free_If_Needed (Path_Ptr);
         Free_If_Needed (Symbol_Ptr);
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      Verifier := To_Plugin_Verify_Fn (Symbol_Address);
      if Verifier = null then
         declare
            Close_Result : constant Interfaces.C.int := dlclose (Handle => Handle);
         begin
            if Close_Result /= 0 then
               null;
            end if;
         end;
         Mark_Unavailable;
         Free_If_Needed (Path_Ptr);
         Free_If_Needed (Symbol_Ptr);
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      --  Replace previously cached plugin after successful resolution.
      if Plugin_Handle /= System.Null_Address then
         declare
            Close_Result : constant Interfaces.C.int :=
              dlclose (Handle => Plugin_Handle);
         begin
            if Close_Result /= 0 then
               null;
            end if;
         end;
      end if;

      Plugin_Handle := Handle;
      Plugin_Verifier := Verifier;
      Plugin_State := Loaded;
      Set_Plugin_Path (Effective_Path);

      Free_If_Needed (Path_Ptr);
      Free_If_Needed (Symbol_Ptr);
      return OpenCL.Errors.Success;
   end Load_Plugin;

   procedure Configure_Plugin
     (Path : String;
      Symbol : String := "oclw_kpack_verify_v1";
      Status : out OpenCL.Errors.Status_Code)
   is
      Effective_Symbol : constant String :=
        (if Trimmed (Symbol)'Length = 0
         then Default_Crypto_Symbol
         else Trimmed (Symbol));
      Canonical_Path : OpenCL.RT.Packs.Bounded_String :=
        OpenCL.RT.Packs.To_Bounded ("");
      Enforce_Allowlist : constant Boolean :=
        Optional_Env ("OCLW_RT_PLUGIN_ALLOWLIST")'Length > 0;
   begin
      Reset_Cached_Plugin;

      Validate_Plugin_Path
        (Path => Path,
         Strict => Enforce_Allowlist,
         Canonical => Canonical_Path,
         Status => Status);
      if Status /= OpenCL.Errors.Success then
         Mark_Unavailable;
         return;
      end if;

      Status := Load_Plugin
        (Path => OpenCL.RT.Packs.To_String (Canonical_Path),
         Symbol => Effective_Symbol);
   end Configure_Plugin;

   function Ensure_Plugin_Available
     (Strict : Boolean) return OpenCL.Errors.Status_Code
   is
      Canonical_Path : OpenCL.RT.Packs.Bounded_String :=
        OpenCL.RT.Packs.To_Bounded ("");
      Path_Status : OpenCL.Errors.Status_Code := OpenCL.Errors.Success;
   begin
      if Plugin_State = Loaded and then Plugin_Verifier /= null then
         if Strict then
            Validate_Plugin_Path
              (Path => Current_Plugin_Path,
               Strict => True,
               Canonical => Canonical_Path,
               Status => Path_Status);
            if Path_Status /= OpenCL.Errors.Success then
               return Path_Status;
            end if;
         end if;
         return OpenCL.Errors.Success;
      end if;

      --  Strict mode disables env-var plugin discovery; only explicit
      --  configuration (Configure_Plugin) is allowed.
      if Strict then
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      if Plugin_State = Unavailable then
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      declare
         Plugin_Path : constant String := Optional_Env ("OCLW_CRYPTO_PLUGIN");
         Symbol_Name : constant String :=
           Optional_Env
             (Name => "OCLW_CRYPTO_SYMBOL",
              Default => Default_Crypto_Symbol);
      begin
         return Load_Plugin (Path => Plugin_Path, Symbol => Symbol_Name);
      end;
   end Ensure_Plugin_Available;

   function Verify_With_Plugin
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural) return OpenCL.Errors.Status_Code
   is
      package C renames Interfaces.C;
      package CString renames Interfaces.C.Strings;

      Signature_Alg_Ptr : CString.chars_ptr := CString.Null_Ptr;
      Signer_Id_Ptr : CString.chars_ptr := CString.Null_Ptr;
      Signature_Value_Ptr : CString.chars_ptr := CString.Null_Ptr;

      Signing_Text_C : C.char_array := C.To_C (Signing_Text, Append_Nul => False);
      Signing_Text_Address : System.Address := System.Null_Address;
      Program_Bin_Address : System.Address := System.Null_Address;
      Plugin_Result : C.int := -1;

      Signature_Alg : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Alg));
      Signer_Id : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Signer_Id));
      Signature_Value : constant String :=
        Trimmed (OpenCL.RT.Packs.To_String (Meta.Signature_Value));
   begin
      if Plugin_Verifier = null then
         return OpenCL.Errors.OCLW_Signature_Not_Implemented;
      end if;

      if Used = 0 or else Used > Bin'Length then
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;

      Signature_Alg_Ptr := CString.New_String (Signature_Alg);
      Signature_Value_Ptr := CString.New_String (Signature_Value);
      if Signer_Id'Length > 0 then
         Signer_Id_Ptr := CString.New_String (Signer_Id);
      end if;

      if Signing_Text_C'Length > 0 then
         Signing_Text_Address :=
           Signing_Text_C (Signing_Text_C'First)'Address;
      end if;
      Program_Bin_Address := Bin (Bin'First)'Address;

      --  Integration point only: production RT must use an approved provider.
      Plugin_Result :=
        Plugin_Verifier
          (Signature_Alg => Signature_Alg_Ptr,
           Signer_Id => Signer_Id_Ptr,
           Signature_Value => Signature_Value_Ptr,
           Signing_Text => Signing_Text_Address,
           Signing_Text_Len => C.size_t (Signing_Text'Length),
           Program_Bin => Program_Bin_Address,
           Program_Bin_Len => C.size_t (Used));

      Free_If_Needed (Signature_Alg_Ptr);
      Free_If_Needed (Signer_Id_Ptr);
      Free_If_Needed (Signature_Value_Ptr);

      if Plugin_Result = 0 then
         return OpenCL.Errors.Success;
      else
         return OpenCL.Errors.OCLW_Signature_Invalid;
      end if;
   end Verify_With_Plugin;

   procedure Install_Verifier (V : Verify_Fn) is
   begin
      Installed_Verifier := V;
   end Install_Verifier;

   function Verify
     (Meta : OpenCL.RT.Packs.Pack_Metadata;
      Signing_Text : String;
      Bin : OpenCL.Core.Programs.Byte_Array;
      Used : Natural;
      Strict : Boolean := False) return OpenCL.Errors.Status_Code
   is
      Plugin_Status : OpenCL.Errors.Status_Code := OpenCL.Errors.Success;
   begin
      --  Ada verifier has priority and acts as explicit override.
      if Installed_Verifier /= null then
         return Installed_Verifier
           (Meta => Meta,
            Signing_Text => Signing_Text,
            Bin => Bin,
            Used => Used);
      end if;

      Plugin_Status := Ensure_Plugin_Available (Strict => Strict);
      if Plugin_Status /= OpenCL.Errors.Success then
         return Plugin_Status;
      end if;

      return Verify_With_Plugin
        (Meta => Meta,
         Signing_Text => Signing_Text,
         Bin => Bin,
         Used => Used);
   end Verify;

end OpenCL.RT.Security;
