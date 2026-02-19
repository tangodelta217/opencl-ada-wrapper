with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with System.Storage_Elements;

package body OpenCL.RT.Memtrack is

   use type System.Storage_Elements.Integer_Address;
   use type System.Storage_Elements.Storage_Count;

   Buffer : aliased System.Storage_Elements.Storage_Array
     (1 .. System.Storage_Elements.Storage_Offset (Max_Pool_Bytes));
   Current_Pool_Bytes : Storage_Count := Default_Pool_Bytes;
   Next_Free_Offset : Storage_Count := 0;

   Frozen : Boolean := False;
   Fail_On_Alloc_After_Freeze : Boolean := False;
   Allocs_After_Freeze_Count : Natural := 0;
   Total_Allocation_Count : Natural := 0;
   Total_Allocated_Bytes : Storage_Count := 0;

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Parse_Storage_Count
     (Text : String;
      Value : out Storage_Count) return Boolean
   is
      Acc : Storage_Count := 0;
      Clean : constant String := Trimmed (Text);
   begin
      Value := 0;

      if Clean'Length = 0 then
         return False;
      end if;

      for C of Clean loop
         if C < '0' or else C > '9' then
            return False;
         end if;

         declare
            Digit : constant Storage_Count :=
              Storage_Count (Character'Pos (C) - Character'Pos ('0'));
         begin
            if Acc > (Storage_Count'Last - Digit) / 10 then
               return False;
            end if;

            Acc := (Acc * 10) + Digit;
         end;
      end loop;

      Value := Acc;
      return True;
   end Parse_Storage_Count;

   function Resolve_Pool_Bytes return Storage_Count is
      Parsed : Storage_Count := 0;
   begin
      if not Ada.Environment_Variables.Exists ("OCLW_RT_MEM_POOL_BYTES") then
         return Default_Pool_Bytes;
      end if;

      if not Parse_Storage_Count
        (Text => Ada.Environment_Variables.Value ("OCLW_RT_MEM_POOL_BYTES"),
         Value => Parsed)
      then
         return Default_Pool_Bytes;
      end if;

      if Parsed = 0 then
         return Default_Pool_Bytes;
      elsif Parsed > Max_Pool_Bytes then
         return Max_Pool_Bytes;
      else
         return Parsed;
      end if;
   exception
      when others =>
         return Default_Pool_Bytes;
   end Resolve_Pool_Bytes;

   function Align_Up
     (Value : System.Storage_Elements.Integer_Address;
      Alignment : System.Storage_Elements.Integer_Address)
      return System.Storage_Elements.Integer_Address
   is
      Aln : constant System.Storage_Elements.Integer_Address :=
        (if Alignment <= 1 then 1 else Alignment);
   begin
      return ((Value + Aln - 1) / Aln) * Aln;
   end Align_Up;

   overriding procedure Allocate
     (Pool : in out Fixed_Tracking_Pool;
      Storage_Address : out System.Address;
      Size_In_Storage_Elements : Storage_Count;
      Alignment : Storage_Count)
   is
      pragma Unreferenced (Pool);

      Base_Address : constant System.Storage_Elements.Integer_Address :=
        System.Storage_Elements.To_Integer (Buffer (Buffer'First)'Address);
      Limit_Address : constant System.Storage_Elements.Integer_Address :=
        Base_Address + System.Storage_Elements.Integer_Address (Current_Pool_Bytes);
      Current_Address : constant System.Storage_Elements.Integer_Address :=
        Base_Address + System.Storage_Elements.Integer_Address (Next_Free_Offset);
      Aligned_Address : constant System.Storage_Elements.Integer_Address :=
        Align_Up
          (Value => Current_Address,
           Alignment => System.Storage_Elements.Integer_Address (Alignment));
      End_Address : constant System.Storage_Elements.Integer_Address :=
        Aligned_Address
        + System.Storage_Elements.Integer_Address (Size_In_Storage_Elements);
   begin
      if Frozen then
         if Allocs_After_Freeze_Count < Natural'Last then
            Allocs_After_Freeze_Count := Allocs_After_Freeze_Count + 1;
         end if;

         if Fail_On_Alloc_After_Freeze then
            raise Storage_Error;
         end if;
      end if;

      if Size_In_Storage_Elements = 0 then
         Storage_Address := System.Null_Address;
         return;
      end if;

      if End_Address > Limit_Address then
         raise Storage_Error;
      end if;

      Storage_Address := System.Storage_Elements.To_Address (Aligned_Address);
      Next_Free_Offset := Storage_Count (End_Address - Base_Address);

      if Total_Allocation_Count < Natural'Last then
         Total_Allocation_Count := Total_Allocation_Count + 1;
      end if;

      if Size_In_Storage_Elements > Storage_Count'Last - Total_Allocated_Bytes then
         Total_Allocated_Bytes := Storage_Count'Last;
      else
         Total_Allocated_Bytes :=
           Total_Allocated_Bytes + Size_In_Storage_Elements;
      end if;
   end Allocate;

   overriding procedure Deallocate
     (Pool : in out Fixed_Tracking_Pool;
      Storage_Address : System.Address;
      Size_In_Storage_Elements : Storage_Count;
      Alignment : Storage_Count)
   is
      pragma Unreferenced (Pool);
      pragma Unreferenced (Storage_Address);
      pragma Unreferenced (Size_In_Storage_Elements);
      pragma Unreferenced (Alignment);
   begin
      null;
   end Deallocate;

   overriding function Storage_Size
     (Pool : Fixed_Tracking_Pool) return Storage_Count
   is
      pragma Unreferenced (Pool);
   begin
      return Current_Pool_Bytes;
   end Storage_Size;

   procedure Freeze is
   begin
      Frozen := True;
      Allocs_After_Freeze_Count := 0;
   end Freeze;

   procedure Enable_Fail_On_Alloc_After_Freeze (Enable : Boolean) is
   begin
      Fail_On_Alloc_After_Freeze := Enable;
   end Enable_Fail_On_Alloc_After_Freeze;

   function Allocs_After_Freeze return Natural is
   begin
      return Allocs_After_Freeze_Count;
   end Allocs_After_Freeze;

   function Total_Allocs return Natural is
   begin
      return Total_Allocation_Count;
   end Total_Allocs;

   function Total_Bytes return Storage_Count is
   begin
      return Total_Allocated_Bytes;
   end Total_Bytes;

   function Pool_Bytes return Storage_Count is
   begin
      return Current_Pool_Bytes;
   end Pool_Bytes;

begin
   Current_Pool_Bytes := Resolve_Pool_Bytes;
end OpenCL.RT.Memtrack;
