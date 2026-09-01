with Ada.Text_IO; use Ada.Text_IO;

procedure T is
begin
   loop
      Put_Line ("Enter your name:");

      declare
         Name : constant String := Get_Line;
      begin
         exit when Name = "";
         Put_Line ("Hi " & Name & "!");
      end;
   end loop;
end T;
