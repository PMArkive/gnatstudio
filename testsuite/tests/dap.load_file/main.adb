with Ada.Text_IO;

procedure Main is
   procedure Print (X : Integer) is
   begin
      Ada.Text_IO.Put_Line (Integer'Image (X));
   end Print;
begin
   Print (2);
end Main;
