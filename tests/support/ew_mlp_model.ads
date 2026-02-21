with Interfaces;

package EW_MLP_Model is
   Input_Size : constant Positive := 64;
   Hidden_Size : constant Positive := 96;
   Output_Size : constant Positive := 4;

   subtype Byte is Interfaces.Unsigned_8;
   subtype Logit is Interfaces.Integer_32;

   subtype Feature_Index is Natural range 0 .. Input_Size - 1;
   subtype Hidden_Index is Natural range 0 .. Hidden_Size - 1;
   subtype Output_Index is Natural range 0 .. Output_Size - 1;
   subtype Class_Label is Natural range 0 .. Output_Size - 1;

   type Byte_Array_64 is array (Feature_Index) of Byte;
   subtype Byte_Array is Byte_Array_64;

   type Logit_Array_4 is array (Output_Index) of Logit;

   type Batch_Byte_Array is array (Natural range <>) of Byte_Array_64;
   type Batch_Logit_Array is array (Natural range <>) of Logit_Array_4;
   type Batch_Class_Array is array (Natural range <>) of Class_Label;

   function W1 (Neuron : Hidden_Index; Feature : Feature_Index) return Integer;
   function B1 (Neuron : Hidden_Index) return Integer;
   function W2 (Out_Class : Output_Index; Neuron : Hidden_Index) return Integer;
   function B2 (Out_Class : Output_Index) return Integer;

   procedure Infer_CPU
     (X : in Byte_Array;
      Logits : out Logit_Array_4;
      Class : out Natural);

   procedure Infer_CPU_Batch
     (X : in Batch_Byte_Array;
      Logits : out Batch_Logit_Array;
      Classes : out Batch_Class_Array)
   with
     Pre =>
       X'First = Logits'First
       and then X'Last = Logits'Last
       and then X'First = Classes'First
       and then X'Last = Classes'Last;

   function Make_Sample
     (Class_Id : Natural;
      Sample_Index : Natural) return Byte_Array_64;

   procedure Make_Batch
     (X : out Batch_Byte_Array;
      Labels : out Batch_Class_Array;
      Start_Sample_Index : Natural := 0)
   with
     Pre => X'First = Labels'First and then X'Last = Labels'Last;

   function Self_Check (Samples_Per_Class : Positive := 8) return Boolean;
end EW_MLP_Model;
