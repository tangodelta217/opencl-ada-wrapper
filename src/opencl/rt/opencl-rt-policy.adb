with Ada.Characters.Latin_1;
with Ada.Strings;
with Ada.Strings.Fixed;
with OpenCL.RT.Memtrack;

package body OpenCL.RT.Policy is
   pragma Default_Storage_Pool (OpenCL.RT.Memtrack.RT_Pool);

   function Trimmed (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trimmed;

   function Is_Separator (C : Character) return Boolean is
   begin
      return C = ' ' or else C = Ada.Characters.Latin_1.HT;
   end Is_Separator;

   function Is_Denied_Token (Token : String) return Boolean is
   begin
      if Token'Length >= 2
        and then Token (Token'First) = '-'
        and then Token (Token'First + 1) = 'I'
      then
         return True;
      end if;

      if Token'Length >= 2
        and then Token (Token'First) = '-'
        and then Token (Token'First + 1) = 'D'
      then
         return True;
      end if;

      if Token = "-cl-opt-disable" then
         return True;
      end if;

      return False;
   end Is_Denied_Token;

   function Is_Build_Options_Allowed (Options : String) return Boolean is
      Clean : constant String := Trimmed (Options);
      Token_Count : Natural := 0;
      Allowed_Token_Count : Natural := 0;
      I : Natural := 0;
      J : Natural := 0;
   begin
      if Clean'Length = 0 then
         return True;
      end if;

      I := Clean'First;
      while I <= Clean'Last loop
         while I <= Clean'Last and then Is_Separator (Clean (I)) loop
            I := I + 1;
         end loop;

         exit when I > Clean'Last;

         J := I;
         while J <= Clean'Last and then not Is_Separator (Clean (J)) loop
            J := J + 1;
         end loop;

         declare
            Token : constant String := Clean (I .. J - 1);
         begin
            Token_Count := Token_Count + 1;

            if Is_Denied_Token (Token) then
               return False;
            end if;

            if Token = "-cl-std=CL1.2" then
               Allowed_Token_Count := Allowed_Token_Count + 1;
            end if;
         end;

         I := J + 1;
      end loop;

      if Token_Count = 1 and then Allowed_Token_Count = 1 then
         return True;
      end if;

      return False;
   end Is_Build_Options_Allowed;

end OpenCL.RT.Policy;
