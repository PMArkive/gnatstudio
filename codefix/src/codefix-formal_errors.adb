-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2002                         --
--                            ACT-Europe                             --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Exceptions; use Ada.Exceptions;
with String_Utils; use String_Utils;

with GNAT.Regpat; use GNAT.Regpat;

package body Codefix.Formal_Errors is

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (This : in out Error_Message; Message : String) is
   begin
      Assign (This.Message, Message);
      Parse_Head (Message, This);
   end Initialize;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (This : in out Error_Message; Line, Col : Positive) is
   begin
      Assign (This.Message, "");
      This.Line := Line;
      This.Col := Col;
   end Initialize;

   -----------------
   -- Get_Message --
   -----------------

   function Get_Message (This : Error_Message) return String is
   begin
      return This.Message.all;
   end Get_Message;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Error_Message) is
   begin
      Free (File_Cursor (This));
      Free (This.Message);
   end Free;

   ----------------
   -- Parse_Head --
   ----------------

   procedure Parse_Head (Message : String; This : out Error_Message) is
      Matches : Match_Array (0 .. 3);
      Matcher : constant Pattern_Matcher :=
         Compile ("([^:]*):([0-9]*):([0-9]*)");

   begin
      Match (Matcher, Message, Matches);

      begin
         Assign (This.File_Name,
                 Message (Matches (1).First .. Matches (1).Last));
         This.Line := Positive'Value
            (Message (Matches (2).First .. Matches (2).Last));
         This.Col := Positive'Value
            (Message (Matches (3).First .. Matches (3).Last));

      exception
         when Constraint_Error => -- et tester No_Match
            null; -- Lever une exception due au 'Value
      end;
   end Parse_Head;

   -----------
   -- Clone --
   -----------

   function Clone (This : Error_Message) return Error_Message is
      New_Message : Error_Message;
   begin
      New_Message := (Clone (File_Cursor (This)) with
                        new String'(This.Message.all));
      return New_Message;
   end Clone;

   -----------------
   -- Get_Extract --
   -----------------

   function Get_Extract
     (This     : Solution_List;
      Position : Positive) return Extract'Class
   is
      Current_Node : Extract_List.List_Node;
   begin
      Current_Node := First (This);

      for J in 1 .. Position - 1 loop
         Current_Node := Next (Current_Node);
      end loop;

      return Data (Current_Node);
   end Get_Extract;

   ----------
   -- Free --
   ----------

   procedure Free (This : in out Solution_List) is
   begin
      Free (This, True);
   end Free;

   ---------------
   -- Should_Be --
   ---------------

   function Should_Be
     (Current_Text : Text_Navigator_Abstr'Class;
      Message      : Error_Message;
      Str_Expected : String;
      Str_Red      : String := "";
      Format_Red   : String_Mode := Text_Ascii) return Extract
   is
      New_Extract : Extract;
      Line_Cursor : File_Cursor := File_Cursor (Message);
   begin
      Line_Cursor.Col := 1;
      Get_Line (Current_Text, Line_Cursor, New_Extract);

      if Str_Red = "" then
         Replace_Word
           (New_Extract,
            Message,
            Str_Expected,
            "^([\w]+)",
            Regular_Expression);
         Set_Caption
           (New_Extract,
            "Replace misspelled word by """ & Str_Expected & """");
      else
         Replace_Word
           (New_Extract, Message, Str_Expected, Str_Red, Format_Red);
         Set_Caption
           (New_Extract,
            "Replace """ & Str_Red & """ by """ & Str_Expected & """");
      end if;

      return New_Extract;
   end Should_Be;

   -----------------
   -- Wrong_Order --
   -----------------

   function Wrong_Order
     (Current_Text  : Text_Navigator_Abstr'Class;
      Message       : Error_Message;
      First_String  : String;
      Second_String : String) return Extract
   is
      New_Extract   : Extract;
      Matches       : Match_Array (1 .. 1);
      Matcher       : constant Pattern_Matcher :=
        Compile ("(" & Second_String & ") ", Case_Insensitive);
      Second_Cursor : File_Cursor := File_Cursor (Message);
      Line_Cursor   : File_Cursor := File_Cursor (Message);

   begin
      Second_Cursor.Col := 1;

      loop
         Match (Matcher, Get_Line (Current_Text, Second_Cursor), Matches);
         exit when Matches (1) /= No_Match;
         Second_Cursor.Line := Second_Cursor.Line - 1;
      end loop;

      Line_Cursor.Col := 1;
      Get_Line (Current_Text, Line_Cursor, New_Extract);

      if Message.Line /= Second_Cursor.Line then
         Get_Line (Current_Text, Second_Cursor, New_Extract);
      end if;

      Second_Cursor.Col := Matches (1).First;

      Replace_Word
        (New_Extract,
         Message,
         Second_String,
         "^(" & First_String & ")");

      Replace_Word
        (New_Extract,
         Second_Cursor,
         First_String,
         "^(" & Second_String & ")");

      Set_Caption
        (New_Extract,
         "Invert """ & First_String & """ and """ & Second_String & """");

      return New_Extract;
   end Wrong_Order;

   --------------
   -- Expected --
   --------------

   function Expected
     (Current_Text    : Text_Navigator_Abstr'Class;
      Message         : Error_Message;
      String_Expected : String;
      Add_Spaces      : Boolean := True) return Extract
   is
      New_Extract  : Extract;
      New_Str      : Dynamic_String;
      Line_Cursor  : File_Cursor := File_Cursor (Message);
      Space_Cursor : File_Cursor := File_Cursor (Message);

   begin
      Assign (New_Str, String_Expected);

      Line_Cursor.Col := 1;
      Get_Line (Current_Text, Line_Cursor, New_Extract);

      Space_Cursor.Col := Space_Cursor.Col - 1;

      if Add_Spaces and then
         Message.Col > 1 and then
         Get
          (Current_Text,
           Space_Cursor,
           1) /= " "
      then
         Assign (New_Str, " " & New_Str.all);
      end if;

      Space_Cursor.Col := Space_Cursor.Col + 1;

      if Add_Spaces
        and then Message.Col < Line_Length (Current_Text, Line_Cursor)
        and then Get (Current_Text, Space_Cursor, 1) /= " "
      then
         Assign (New_Str, New_Str.all & " ");
      end if;

      Add_Word (New_Extract, Message, New_Str.all);

      Set_Caption
        (New_Extract,
         "Add expected word """ & New_Str.all & """");

      Free (New_Str);

      return New_Extract;
   end Expected;

   ----------------
   -- Unexpected --
   ----------------

   function Unexpected
     (Current_Text      : Text_Navigator_Abstr'Class;
      Message           : Error_Message;
      String_Unexpected : String;
      Mode              : String_Mode := Text_Ascii) return Extract
   is
      New_Extract : Extract;
      New_Str     : Dynamic_String;
      Line_Cursor : File_Cursor := File_Cursor (Message);

   begin
      Line_Cursor.Col := 1;
      Get_Line (Current_Text, Line_Cursor, New_Extract);

      New_Str := new String'(Get_String (New_Extract));

      case Mode is
         when Text_Ascii =>
            Set_String
              (New_Extract, New_Str (1 .. Message.Col - 1) &
                 New_Str (Message.Col + String_Unexpected'Length
                          .. New_Str'Length));

         when Regular_Expression =>
            Set_String
              (New_Extract, New_Str (1 .. Message.Col - 1) &
                 New_Str
                   (Message.Col +
                      Get_Word_Length (New_Extract, Message, String_Unexpected)
                    .. New_Str'Length));
      end case;

      Set_String
        (New_Extract,
         New_Str (1 .. Message.Col - 1) &
           New_Str (Message.Col + String_Unexpected'Length .. New_Str'Length));

      Set_Caption
        (New_Extract,
         "Remove unexpected word """ & String_Unexpected & """");

      Free (New_Str);

      return New_Extract;
   end Unexpected;

   ------------------
   -- Wrong_Column --
   ------------------

   function Wrong_Column
     (Current_Text    : Text_Navigator_Abstr'Class;
      Message         : Error_Message;
      Column_Expected : Natural := 0) return Extract
   is
      function Closest (Size_Red : Positive) return Positive;
      --  Return the closest indentation modulo Indentation_Width.

      function Closest (Size_Red : Positive) return Positive is
      begin
         case (Size_Red - 1) mod Indentation_Width is
            when 0 =>
               return Size_Red + Indentation_Width;
               --  not - Identation_Width because of the case where
               --  Size_Red = 1
            when 1 =>
               return Size_Red - 1;
            when 2 =>
               return Size_Red + 1;
            when others =>
               Raise_Exception
                 (Codefix_Panic'Identity,
                  "Indentation_With changed, please update Wrong_Column.");
         end case;
      end Closest;

      New_Extract   : Extract;
      Str_Red       : Dynamic_String;
      White_String  : constant String (1 .. 256) := (others => ' ');
      Line_Cursor   : File_Cursor := File_Cursor (Message);
      Column_Chosen : Natural;

   begin
      Line_Cursor.Col := 1;
      Get_Line (Current_Text, Line_Cursor, New_Extract);
      Str_Red := new String'(Get_String (New_Extract));

      if Column_Expected = 0 then
         Column_Chosen := Closest (Message.Col);
      else
         Column_Chosen := Column_Expected;
      end if;

      Set_String
        (New_Extract,
         White_String (1 .. Column_Chosen - 1) &
           Str_Red (Message.Col .. Str_Red'Length));

      Set_Caption
        (New_Extract,
         "Move begin of instruction to column " &
           Integer'Image (Column_Chosen));

      Free (Str_Red);
      return New_Extract;
   end Wrong_Column;

   -------------------------
   -- With_Clause_Missing --
   -------------------------

   function With_Clause_Missing
     (Current_Text   : Text_Navigator_Abstr'Class;
      Cursor         : File_Cursor'Class;
      Missing_Clause : String) return Extract
   is
      pragma Unreferenced (Current_Text);

      New_Cursor  : File_Cursor := (0, 1, Cursor.File_Name);
      New_Extract : Extract;
   begin
      Add_Line
        (New_Extract,
         New_Cursor,
         "with " & Missing_Clause & "; use " & Missing_Clause & ";");

      Set_Caption
        (New_Extract,
         "Add with and use clause for package """ & Missing_Clause &
           """ at the begining of the file");

      return New_Extract;
   end With_Clause_Missing;

   ----------------
   -- Bad_Casing --
   ----------------

   function Bad_Casing
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Correct_Word : String := "";
      Word_Case    : Case_Type := Mixed) return Extract
   is
      function To_Correct_Case (Str : String) return String;
      --  Return the string after having re-cased it (with Word_Case).

      ---------------------
      -- To_Correct_Case --
      ---------------------

      function To_Correct_Case (Str : String) return String is
         New_String : String (Str'Range);
      begin
         case Word_Case is
            when Mixed =>
               New_String := Str;
               Mixed_Case (New_String);

            when Upper =>
               for J in Str'Range loop
                  New_String (J) := To_Upper (Str (J));
               end loop;

            when Lower =>
               for J in Str'Range loop
                  New_String (J) := To_Lower (Str (J));
               end loop;
         end case;

         return New_String;
      end To_Correct_Case;

      New_Extract : Extract;
      Cursor_Line : File_Cursor := File_Cursor (Cursor);
      Word        : constant Pattern_Matcher := Compile ("([\w]+)");
      Matches     : Match_Array (0 .. 1);
      Size        : Integer;
      Line        : Dynamic_String;
      Word_Chosen : Dynamic_String;

   begin
      Cursor_Line.Col := 1;
      Get_Line (Current_Text, Cursor_Line, New_Extract);
      Assign (Line, Get_String (New_Extract));
      Match (Word, Line (Cursor.Col .. Line'Length), Matches);

      Size := Matches (1).Last - Matches (1).First + 1;

      if Correct_Word /= "" then
         Word_Chosen := new String'(Correct_Word);
      else
         Word_Chosen := new String'
           (To_Correct_Case (Line (Matches (1).First .. Matches (1).Last)));
      end if;

      Replace_Word
        (New_Extract,
         Cursor,
         Word_Chosen (Word_Chosen'Last - Size + 1 .. Word_Chosen'Last),
         Size);

      Set_Caption
        (New_Extract,
         "Replace bad-cased word by """ & Word_Chosen.all & """");

      Free (Word_Chosen);

      return New_Extract;
   end Bad_Casing;

   --------------------
   -- Not_Referenced --
   --------------------

   --  Warning : this function is extremely dependent of the respect of the
   --  normalisation. Maybe should be re-programmed in order to make a smarter
   --  one

   function Not_Referenced
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Category     : Language_Category;
      Name         : String) return Solution_List
   is
      function Delete_Var return Extract;
      --  Delete a variable, or a constant.

      function Delete_Entity return Extract;
      --  Delete the body, and if it exisits the declaration, of an unit
      --  (typically, a subprogram).

      function Add_Pragma return Extract;
      --  Add a pragma after the declaration or, if there is no declaration,
      --  after the body.

      function Add_Parameter_Pragma return Extract;

      function Delete_With return Extract;

      ----------------
      -- Delete_Var --
      ----------------

      function Delete_Var return Extract is
         New_Extract : Ada_List;
      begin
         Get_Unit (Current_Text, Cursor, New_Extract);
         Remove_Elements (New_Extract, Name);
         return Extract (New_Extract);
      end Delete_Var;

      -------------------
      -- Delete_Entity --
      -------------------

      function Delete_Entity return Extract is
         New_Extract : Extract;
      begin
         Get_Entity (New_Extract, Current_Text, Cursor);
         Delete_All_Lines (New_Extract);
         return New_Extract;
      end Delete_Entity;

      ----------------
      -- Add_Pragma --
      ----------------

      function Add_Pragma return Extract is
         New_Extract  : Extract;
         New_Position : File_Cursor;
         Declaration  : Construct_Information;
      begin
         Declaration := Get_Unit (Current_Text, Cursor);
         New_Position.Line := Declaration.Sloc_End.Line;
         New_Position.Col  := Declaration.Sloc_End.Column;
         Assign (New_Position.File_Name, Cursor.File_Name);
         Add_Line (New_Extract, New_Position, "pragma Unreferenced (" &
                                              Name & ");");
         return New_Extract;
      end Add_Pragma;

      --------------------------
      -- Add_Parameter_Pragma --
      --------------------------

      function Add_Parameter_Pragma return Extract is
         New_Extract  : Extract;
         New_Position : File_Cursor;
         Declaration  : Construct_Information;

      begin
         Declaration := Get_Unit
           (Current_Text, Cursor, Before, Cat_Procedure, Cat_Function);
         New_Position.Line := Declaration.Sloc_Entity.Line;
         New_Position.Col  := Declaration.Sloc_Entity.Column;
         Assign (New_Position.File_Name, Cursor.File_Name);
         New_Position := File_Cursor
           (Search_String (Current_Text, New_Position, ")"));
         New_Position := File_Cursor
           (Search_String (Current_Text, New_Position, "is"));
         Add_Line (New_Extract, New_Position, "pragma Unreferenced (" &
                                              Name & ");");
         return New_Extract;
      end Add_Parameter_Pragma;

      -----------------
      -- Delete_With --
      -----------------

      function Delete_With return Extract is
         New_Extract               : Extract;
         Extract_Use, Extract_With : Ada_List;
         Use_Info                  : Construct_Information;
         Cursor_Use                : File_Cursor := File_Cursor (Cursor);
         Success                   : Boolean;

      begin
         Use_Info := Search_Unit
             (Current_Text, Cursor.File_Name.all, Cat_Use, Name);

         Get_Unit (Current_Text, Cursor, Extract_With);
         Remove_Elements (Extract_With, Name);

         if Use_Info.Category /= Cat_Unknown then
            Cursor_Use.Col := Use_Info.Sloc_Start.Column;
            Cursor_Use.Line := Use_Info.Sloc_Start.Line;
            Get_Unit (Current_Text, Cursor_Use, Extract_Use);
            Remove_Elements (Extract_Use, Name);
         end if;

         Merge (New_Extract, Extract_With, Extract_Use, Current_Text, Success);

         return New_Extract;

      end Delete_With;

      --  begin of Not_Referenced

      New_Extract   : Extract;
      New_Solutions : Solution_List;


   begin
      case Category is
         when Cat_Variable =>

            New_Extract := Delete_Var;
            Set_Caption
              (New_Extract,
               "Delete variable """ & Name & """");
            Append (New_Solutions, New_Extract);

         when Cat_Function | Cat_Procedure =>

            New_Extract := Delete_Entity;
            Set_Caption
              (New_Extract,
              "Delete subprogram """ & Name & """");
            Append (New_Solutions, New_Extract);

            New_Extract := Add_Pragma;
            Set_Caption
              (New_Extract,
               "Add pragma Unreferenced to subprogram """ & Name & """");
            Append (New_Solutions, New_Extract);

         when Cat_Type =>

            New_Extract := Delete_Entity;
            Set_Caption
              (New_Extract,
               "Delete type """ & Name & """");
            Append (New_Solutions, New_Extract);

            New_Extract := Add_Pragma;
            Set_Caption
              (New_Extract,
               "Add pragma Unreferenced to type """ & Name & """");
            Append (New_Solutions, New_Extract);

         when Cat_Local_Variable =>

            New_Extract := Add_Parameter_Pragma;
            Set_Caption
              (New_Extract,
               "Add pragma Unreferenced to formal parameter """ & Name & """");
            Append (New_Solutions, New_Extract);

         when Cat_With =>

            New_Extract := Delete_With;
            Set_Caption
              (New_Extract,
               "Delete with and use clause for unit """ & Name & """");
            Append (New_Solutions, New_Extract);

         when others =>

            Raise_Exception
              (Codefix_Panic'Identity,
               "Wrong category given : " & Language_Category'Image (Category));
      end case;

      return New_Solutions;
   end Not_Referenced;

   ------------------------
   --  First_Line_Pragma --
   ------------------------

   function First_Line_Pragma
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class) return Extract
   is
      Line_Cursor, Begin_Cursor : File_Cursor := File_Cursor (Cursor);
      New_Extract               : Extract;
   begin
      Line_Cursor.Col := 1;
      Begin_Cursor.Line := 0;
      Begin_Cursor.Col := 1;
      Get_Line (Current_Text, Line_Cursor, New_Extract);
      Add_Line (New_Extract, Begin_Cursor, Get_String (New_Extract, 1));
      Delete_Line (New_Extract, Line_Cursor);

      Set_Caption
        (New_Extract,
         "Move the pragma to the beginnig of the file");

      return New_Extract;
   end First_Line_Pragma;

   ------------------
   -- Not_Modified --
   ------------------

   function Not_Modified
     (Current_Text : Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class;
      Name         : String) return Ada_List is

      New_Extract : Ada_List;
      New_Instr   : Dynamic_String;
      Col_Decl    : Natural;

   begin
      Get_Unit (Current_Text, Cursor, New_Extract);

      if Get_Number_Of_Elements (New_Extract) = 1 then
         Replace_Word
           (New_Extract,
            Search_String (New_Extract, ":"),
            ": constant",
            ":");
      else
         Cut_Off_Elements (New_Extract, New_Instr, Name);

         Col_Decl := New_Instr'First;
         Skip_To_Char (New_Instr.all, Col_Decl, ':');

         Assign
           (New_Instr,
            New_Instr (New_Instr'First .. Col_Decl) & " constant" &
              New_Instr (Col_Decl + 1 .. New_Instr'Last));

         Add_Line (New_Extract, Get_Stop (New_Extract), New_Instr.all);
         Free (New_Instr);
      end if;

      Set_Caption
        (New_Extract,
         "Add ""constant"" to the declaration of """ & Name & """");

      return New_Extract;
   end Not_Modified;

end Codefix.Formal_Errors;
