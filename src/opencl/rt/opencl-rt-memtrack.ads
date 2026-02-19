with System.Storage_Elements;
with System.Storage_Pools;

package OpenCL.RT.Memtrack is
   subtype Storage_Count is System.Storage_Elements.Storage_Count;

   Default_Pool_Bytes : constant Storage_Count := 1_048_576;
   Max_Pool_Bytes : constant Storage_Count := 8_388_608;

   type Fixed_Tracking_Pool is new System.Storage_Pools.Root_Storage_Pool with null record;

   overriding procedure Allocate
     (Pool : in out Fixed_Tracking_Pool;
      Storage_Address : out System.Address;
      Size_In_Storage_Elements : Storage_Count;
      Alignment : Storage_Count);

   overriding procedure Deallocate
     (Pool : in out Fixed_Tracking_Pool;
      Storage_Address : System.Address;
      Size_In_Storage_Elements : Storage_Count;
      Alignment : Storage_Count);

   overriding function Storage_Size
     (Pool : Fixed_Tracking_Pool) return Storage_Count;

   RT_Pool : aliased Fixed_Tracking_Pool;

   procedure Freeze;
   procedure Enable_Fail_On_Alloc_After_Freeze (Enable : Boolean);
   function Allocs_After_Freeze return Natural;

   function Total_Allocs return Natural;
   function Total_Bytes return Storage_Count;
   function Pool_Bytes return Storage_Count;
end OpenCL.RT.Memtrack;
