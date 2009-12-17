-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                 Copyright (C) 2002-2009, AdaCore                  --
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

package Codefix.Text_Manager.Commands is

   ----------------------------------------------------------------------------
   --  type Text_Command
   ----------------------------------------------------------------------------

   ------------------
   -- Text_Command --
   ------------------

   type Fix_Complexity is (Simple, Complex);

   type Text_Command
     (Complexity : Fix_Complexity) is abstract tagged private;
   --  A Text_Command is a modification in the text that can be defined one
   --  time, and made later, with taking into account others possible changes.

   type Ptr_Command is access all Text_Command'Class;

   procedure Execute
     (This         : Text_Command;
      Current_Text : in out Text_Navigator_Abstr'Class) is null;
   --  New version of Execute. Reset success to True if the command is in the
   --  new kind, false if the old execute has still to be called.

   type Execute_Corrupted_Record is abstract tagged null record;

   type Execute_Corrupted is access all Execute_Corrupted_Record'Class;

   procedure Panic
     (Corruption : access Execute_Corrupted_Record; Error_Message : String)
   is abstract;
   --  This primitive is called when a Codefix_Panic is caught while applying a
   --  fix.

   procedure Obsolescent
     (Corruption : access Execute_Corrupted_Record; Error_Message : String)
   is abstract;
   --  This primitive is called when a Obsolescent_Fix is caught while applying
   --  a fix.

   procedure Free (Corruption : in out Execute_Corrupted);

   procedure Secured_Execute
     (This         : Text_Command'Class;
      Current_Text : in out Text_Navigator_Abstr'Class;
      Error_Cb     : Execute_Corrupted := null);
   --  Same as execute, but catches exception. Error_Cb.Panic is called in case
   --  of a Codefix_Panic, and Error_Cb.Obsolescent is called in case of an
   --  Obsolescent fix caught.
   --  ??? Cases where Obsolescent_Fix should be raised instead of
   --  Codefix_Panic should be investigated further.

   procedure Free (This : in out Text_Command);
   --  Free the memory associated to a Text_Command

   procedure Free_Data (This : in out Text_Command'Class);
   --  Free the memory associated to a Text_Command

   procedure Free (This : in out Ptr_Command);
   --  Free the data associated to a Ptr_Command

   procedure Set_Caption
     (This : in out Text_Command'Class;
      Caption : String);
   --  Define the caption that describes the action of a Text_Command

   function Get_Caption (This : Text_Command'Class) return String;
   --  Return the caption associated to a Text_Command

   function Get_Parser (This : Text_Command'Class) return Error_Parser_Access;

   procedure Set_Parser
     (This : in out Text_Command'Class;
      Parser : Error_Parser_Access);

   ---------------------
   -- Remove_Word_Cmd --
   ---------------------

   type Remove_Word_Cmd is new Text_Command with private;

   procedure Initialize
     (This         : in out Remove_Word_Cmd;
      Current_Text : Text_Navigator_Abstr'Class;
      Word         : Word_Cursor'Class);
   --  Set all the marks that will be necessary later to remove the word

   overriding
   procedure Free (This : in out Remove_Word_Cmd);
   --  Free the memory associated to a Remove_Word_Cmd

   overriding
   procedure Execute
     (This         : Remove_Word_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the word removed

   ---------------------
   -- Insert_Word_Cmd --
   ---------------------

   type Insert_Word_Cmd
     (Complexity : Fix_Complexity) is new Text_Command with private;

   procedure Initialize
     (This            : in out Insert_Word_Cmd;
      Current_Text    : Text_Navigator_Abstr'Class;
      Word            : Word_Cursor'Class;
      New_Position    : File_Cursor'Class;
      After_Pattern   : String := "";
      Add_Spaces      : Boolean := True;
      Position        : Relative_Position := Specified;
      Insert_New_Line : Boolean := False);
   --  Set all the marks that will be necessary later to insert the word

   overriding
   procedure Free (This : in out Insert_Word_Cmd);
   --  Fre the memory associated to an Insert_Word_Cmd

   overriding
   procedure Execute
     (This         : Insert_Word_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the word inserted

   --------------------
   -- Move_Word_Cmd  --
   --------------------

   type Move_Word_Cmd (Complexity : Fix_Complexity)
     is new Text_Command with private;

   procedure Initialize
     (This            : in out Move_Word_Cmd;
      Current_Text    : Text_Navigator_Abstr'Class;
      Word            : Word_Cursor'Class;
      New_Position    : File_Cursor'Class;
      Insert_New_Line : Boolean := False);
   --  Set all the marks that will be needed to move the word later

   overriding
   procedure Free (This : in out Move_Word_Cmd);
   --  Free the memory associated to a Move_Word_Cmd

   overriding
   procedure Execute
     (This         : Move_Word_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the word moved

   ----------------------
   -- Replace_Word_Cmd --
   ----------------------

   type Replace_Word_Cmd is new Text_Command with private;

   procedure Initialize
     (This           : in out Replace_Word_Cmd;
      Current_Text   : Text_Navigator_Abstr'Class;
      Word           : Word_Cursor'Class;
      New_Word       : String;
      Do_Indentation : Boolean := False);
   --  Set all the marks that will be needed to replace the word later

   overriding
   procedure Free (This : in out Replace_Word_Cmd);
   --  Free the memory associated to a Replace_Word_Cmd

   overriding
   procedure Execute
     (This         : Replace_Word_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the word replaced

   ----------------------
   -- Invert_Words_Cmd --
   ----------------------

   type Invert_Words_Cmd is new Text_Command with private;

   procedure Initialize
     (This         : in out Invert_Words_Cmd;
      Current_Text : Text_Navigator_Abstr'Class;
      Message_Loc  : File_Cursor'Class;
      First_Word   : String;
      Second_Word  : String);
   --  Set all the marks that will be needed to invert the two words later

   overriding
   procedure Free (This : in out Invert_Words_Cmd);
   --  Free the memory associated to an Invert_Word_Cmd

   overriding
   procedure Execute
     (This         : Invert_Words_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the invertion of the two word

   ------------------
   -- Add_Line_Cmd --
   ------------------

   type Add_Line_Cmd is new Text_Command with private;

   procedure Initialize
     (This         : in out Add_Line_Cmd;
      Current_Text : Text_Navigator_Abstr'Class;
      Position     : File_Cursor'Class;
      Line         : String;
      Indent       : Boolean);
   --  Set all the marks that will be needed to add the line later

   overriding
   procedure Free (This : in out Add_Line_Cmd);
   --  Free the memory associated to an Add_Line_Cmd

   overriding
   procedure Execute
     (This         : Add_Line_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the invertion add of the line

   -----------------------
   -- Replace_Slice_Cmd --
   -----------------------

   type Replace_Slice_Cmd is new Text_Command with private;

   procedure Initialize
     (This                     : in out Replace_Slice_Cmd;
      Current_Text             : Text_Navigator_Abstr'Class;
      Start_Cursor, End_Cursor : File_Cursor'Class;
      New_Text                 : String);
   --  Set all the marks that will be necessary later to remove the slice

   overriding
   procedure Free (This : in out Replace_Slice_Cmd);
   --  Free the memory associated to a Remove_Sloce_Cmd

   overriding
   procedure Execute
     (This         : Replace_Slice_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the slice removed

   ----------------------------
   -- Remove_Blank_Lines_Cmd --
   ----------------------------

   type Remove_Blank_Lines_Cmd is new Text_Command (Simple) with private;

   procedure Initialize
     (This         : in out Remove_Blank_Lines_Cmd;
      Current_Text : Text_Navigator_Abstr'Class;
      Start_Cursor : File_Cursor'Class);
   --  Set all the marks that will be necessary later to remove the blank lines

   overriding
   procedure Free (This : in out Remove_Blank_Lines_Cmd);
   --  Free the memory associated to a Remove_Sloce_Cmd

   overriding
   procedure Execute
     (This         : Remove_Blank_Lines_Cmd;
      Current_Text : in out Text_Navigator_Abstr'Class);
   --  Set an extract with the slice removed

   procedure Remove_Blank_Lines
     (Current_Text : in out Text_Navigator_Abstr'Class;
      Cursor       : File_Cursor'Class);
   --  Remove all consecutive blank lines starting at the location given
   --  in parameter. This helper function may be used directly in commands.

private

   ----------------------------------------------------------------------------
   --  type Text_Command
   ----------------------------------------------------------------------------

   type Text_Command (Complexity : Fix_Complexity) is abstract tagged record
      Caption : GNAT.Strings.String_Access;
      Parser  : Error_Parser_Access;
      --  ??? To be set right after the validated fix!
   end record;

   type Remove_Word_Cmd is new Text_Command with record
      Word : Word_Mark;
   end record;

   type Insert_Word_Cmd (Complexity : Fix_Complexity)
     is new Text_Command (Complexity) with record
      Word            : Word_Mark;
      Add_Spaces      : Boolean := True;
      Position        : Relative_Position := Specified;
      New_Position    : Word_Mark;
      Insert_New_Line : Boolean := False;
      After_Pattern   : String_Access;
   end record;

   type Move_Word_Cmd (Complexity : Fix_Complexity)
     is new Text_Command (Complexity)
   with record
      Step_Remove : Remove_Word_Cmd (Complexity);
      Step_Insert : Insert_Word_Cmd (Complexity);
   end record;

   type Replace_Word_Cmd is new Text_Command with record
      Mark           : Word_Mark;
      Str_Expected   : GNAT.Strings.String_Access;
      Do_Indentation : Boolean := False;
   end record;

   type Invert_Words_Cmd is new Text_Command with record
      Location                : Ptr_Mark;
      First_Word, Second_Word : String_Access;
   end record;

   type Add_Line_Cmd is new Text_Command with record
      Line     : GNAT.Strings.String_Access;
      Position : Ptr_Mark;
      Indent   : Boolean;
   end record;

   type Replace_Slice_Cmd is new Text_Command with record
      Start_Mark : Ptr_Mark;
      End_Mark   : Ptr_Mark;
      New_Text   : GNAT.Strings.String_Access;
   end record;

   type Remove_Blank_Lines_Cmd is new Text_Command (Simple) with record
      Start_Mark : Ptr_Mark;
   end record;

end Codefix.Text_Manager.Commands;
