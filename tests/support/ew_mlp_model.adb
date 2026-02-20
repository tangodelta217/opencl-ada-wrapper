with Interfaces;

package body EW_MLP_Model is
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   subtype U32 is Interfaces.Unsigned_32;

   function Hash2 (A : Natural; B : Natural) return U32 is
      H : U32 :=
        U32 (A) * 16#41C6_4E6D#
        + U32 (B) * 12_345
        + 16#9E37_79B9#;
   begin
      H := H xor Interfaces.Shift_Right (H, 16);
      H := H * 16#85EB_CA77#;
      H := H xor Interfaces.Shift_Right (H, 13);
      H := H * 16#C2B2_AE3D#;
      H := H xor Interfaces.Shift_Right (H, 16);
      return H;
   end Hash2;

   function Jitter (Neuron : Hidden_Index; Feature : Feature_Index) return Integer is
   begin
      return Integer (Hash2 (Natural (Neuron), Natural (Feature)) mod 3) - 1;
   end Jitter;

   function Clamp_Byte (Value : Integer) return Byte is
   begin
      if Value < 0 then
         return 0;
      elsif Value > 255 then
         return 255;
      else
         return Byte (Value);
      end if;
   end Clamp_Byte;

   function Noise
     (Class_Id : Output_Index;
      Sample_Index : Natural;
      Feature : Feature_Index) return Integer
   is
      A : constant Natural := Natural (Class_Id) * 257 + Sample_Index;
      B : constant Natural :=
        Natural (Feature) * 17 + Sample_Index * 13 + Natural (Class_Id);
   begin
      return Integer (Hash2 (A, B) mod 11) - 5;
   end Noise;

   function W1 (Neuron : Hidden_Index; Feature : Feature_Index) return Integer is
      Neuron_Group : constant Natural := Natural (Neuron) / 24;
      Feature_Band : constant Natural := Natural (Feature) / 16;
      Base : constant Integer := (if Feature_Band = Neuron_Group then 3 else -1);
   begin
      return Base + Jitter (Neuron, Feature);
   end W1;

   function B1 (Neuron : Hidden_Index) return Integer is
      pragma Unreferenced (Neuron);
   begin
      return -1000;
   end B1;

   function W2 (Out_Class : Output_Index; Neuron : Hidden_Index) return Integer is
   begin
      if Natural (Neuron) / 24 = Natural (Out_Class) then
         return 1;
      else
         return 0;
      end if;
   end W2;

   function B2 (Out_Class : Output_Index) return Integer is
      pragma Unreferenced (Out_Class);
   begin
      return 0;
   end B2;

   procedure Infer_CPU
     (X : in Byte_Array;
      Logits : out Logit_Array_4;
      Class : out Natural)
   is
      Hidden : array (Hidden_Index) of Integer := (others => 0);
      Best_Class : Natural := 0;
      Best_Logit : Integer := 0;
   begin
      for N in Hidden_Index loop
         declare
            Acc : Integer := B1 (N);
         begin
            for F in Feature_Index loop
               Acc := Acc + W1 (N, F) * Integer (X (F));
            end loop;
            Hidden (N) := (if Acc > 0 then Acc else 0);
         end;
      end loop;

      for O in Output_Index loop
         declare
            Acc : Integer := B2 (O);
         begin
            for N in Hidden_Index loop
               Acc := Acc + W2 (O, N) * Hidden (N);
            end loop;

            Logits (O) := Logit (Acc);
            if O = Output_Index'First or else Acc > Best_Logit then
               Best_Logit := Acc;
               Best_Class := Natural (O);
            end if;
         end;
      end loop;

      Class := Best_Class;
   end Infer_CPU;

   procedure Infer_CPU_Batch
     (X : in Batch_Byte_Array;
      Logits : out Batch_Logit_Array;
      Classes : out Batch_Class_Array)
   is
   begin
      for S in X'Range loop
         declare
            Sample_Logits : Logit_Array_4 := (others => 0);
            Sample_Class : Natural := 0;
         begin
            Infer_CPU
              (X => X (S),
               Logits => Sample_Logits,
               Class => Sample_Class);

            Logits (S) := Sample_Logits;
            Classes (S) := Class_Label (Sample_Class);
         end;
      end loop;
   end Infer_CPU_Batch;

   function Make_Sample
     (Class_Id : Natural;
      Sample_Index : Natural) return Byte_Array_64
   is
      C : constant Output_Index := Output_Index (Class_Id mod Output_Size);
      Result : Byte_Array_64 := (others => 0);
   begin
      for F in Feature_Index loop
         declare
            Band : constant Natural := Natural (F) / 16;
            Base : constant Integer := (if Band = Natural (C) then 220 else 30);
            Value : constant Integer := Base + Noise (C, Sample_Index, F);
         begin
            Result (F) := Clamp_Byte (Value);
         end;
      end loop;
      return Result;
   end Make_Sample;

   procedure Make_Batch
     (X : out Batch_Byte_Array;
      Labels : out Batch_Class_Array;
      Start_Sample_Index : Natural := 0)
   is
   begin
      for S in X'Range loop
         declare
            Offset : constant Natural := S - X'First;
            C : constant Natural := Offset mod Output_Size;
            Sample_Id : constant Natural :=
              Start_Sample_Index + (Offset / Output_Size);
            Sample : constant Byte_Array_64 :=
              Make_Sample (Class_Id => C, Sample_Index => Sample_Id);
         begin
            X (S) := Sample;
            Labels (S) := Class_Label (C);
         end;
      end loop;
   end Make_Batch;

   function Self_Check (Samples_Per_Class : Positive := 8) return Boolean is
   begin
      for C in Output_Index loop
         for I in 0 .. Samples_Per_Class - 1 loop
            declare
               X : constant Byte_Array_64 :=
                 Make_Sample (Class_Id => Natural (C), Sample_Index => Natural (I));
               L : Logit_Array_4 := (others => 0);
               Predicted : Natural := 0;
            begin
               Infer_CPU (X => X, Logits => L, Class => Predicted);
               if Predicted /= Natural (C) then
                  return False;
               end if;
            end;
         end loop;
      end loop;
      return True;
   end Self_Check;

end EW_MLP_Model;
