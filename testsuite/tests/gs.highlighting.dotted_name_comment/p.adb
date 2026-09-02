package body P is

   procedure Test (V : in out T) is
   begin
      V.X := 0;
      V
        .  --  Comment
          X := 10;
      V.X := 20;
   end Test;

end P;
