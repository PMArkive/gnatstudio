-----------------------------------------------------------------------
--                                                                   --
--                     Copyright (C) 2001                            --
--                          ACT-Europe                               --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Glib;                use Glib;
with Gtk.Box;             use Gtk.Box;
with Gtk.Button;          use Gtk.Button;
with Gtk.Check_Button;    use Gtk.Check_Button;
with Gtk.Combo;           use Gtk.Combo;
with Gtk.Dialog;          use Gtk.Dialog;
with Gtk.GEntry;          use Gtk.GEntry;
with Gtk.Handlers;        use Gtk.Handlers;
with Gtk.Label;           use Gtk.Label;
with Gtk.List;            use Gtk.List;
with Gtk.Notebook;        use Gtk.Notebook;
with Gtk.Radio_Button;    use Gtk.Radio_Button;
with Gtk.Spin_Button;     use Gtk.Spin_Button;
with Gtk.Stock;           use Gtk.Stock;
with Gtk.Style;           use Gtk.Style;
with Gtk.Table;           use Gtk.Table;
with Gtk.Widget;          use Gtk.Widget;
with Gtkada.Handlers;     use Gtkada.Handlers;
with Pango.Font;          use Pango.Font;

with GNAT.OS_Lib;         use GNAT.OS_Lib;
with Unchecked_Deallocation;

with Prj_API;              use Prj_API;
with Prj_Normalize;        use Prj_Normalize;
with Glide_Kernel;         use Glide_Kernel;
with Glide_Kernel.Project; use Glide_Kernel.Project;
with String_Utils;         use String_Utils;
with Switches_Editor_Pkg;  use Switches_Editor_Pkg;

with Namet;               use Namet;
with Stringt;             use Stringt;
with Types;               use Types;
with Prj;                 use Prj;
with Prj.Tree;            use Prj.Tree;

package body Switches_Editors is

   Switches_Editor_Title_Font : constant String := "helvetica bold oblique 14";
   --  <preference> Font to use for the switches editor dialog

   procedure Filter_Switches
     (Editor   : access Switches_Edit_Record'Class;
      Tool     : Tool_Names;
      Switches : in out GNAT.OS_Lib.Argument_List);
   --  Remove from Switches all the ones that can be set directly from
   --  the GUI. As a result, on exit Switches will only contain non-null
   --  values for the switches that were set manually by the user, and that
   --  don't have GUI equivalents

   function Get_Switches_From_GUI
     (Editor : access Switches_Edit_Record; Tool : Tool_Names)
      return Argument_List;
   --  Return the list of switches that are set in the GUI (as opposed to the
   --  one in the command lines).

   type Switch_Editor_User_Data is record
      Kernel    : Kernel_Handle;
      Project   : Project_Id;
      Switches  : Switches_Edit;
      File_Name : String_Id;
      Directory : String_Id;
   end record;

   package Switch_Callback is new Gtk.Handlers.User_Callback
     (Gtk_Widget_Record, Switch_Editor_User_Data);

   procedure Close_Switch_Editor
     (Button : access Gtk_Widget_Record'Class;
      Data   : Switch_Editor_User_Data);
   --  See Cancel_Switch_Editor below.

   procedure Cancel_Switch_Editor
     (Dialog : access Gtk_Widget_Record'Class);
   --  Called when the user has closed a switch editor for a specific file.
   --  The first version is the callback for the Close button, the second one
   --  is for the "cancel".
   --  If Data.File_Name is No_String, then this sets the default switches for
   --  the project.
   --  The switches for all the tools (gnatmake, compiler,...) are set if the
   --  switch editor had a page for these.


   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New (Editor : out Switches_Edit) is
   begin
      Editor := new Switches_Edit_Record;
      Initialize (Editor);
   end Gtk_New;

   -------------------
   -- Destroy_Pages --
   -------------------

   procedure Destroy_Pages
     (Editor : access Switches_Edit_Record; Pages : Page_Filter) is
   begin
      Editor.Pages := not Pages;

      if (Pages and Gnatmake_Page) /= 0 then
         Destroy (Editor.Make_Switches);
         Editor.Make_Switches := null;
      end if;

      if (Pages and Compiler_Page) /= 0 then
         Destroy (Editor.Compiler_Switches);
         Editor.Compiler_Switches := null;
      end if;

      if (Pages and Binder_Page) /= 0 then
         Destroy (Editor.Binder_Switches);
         Editor.Binder_Switches := null;
      end if;

      if (Pages and Linker_Page) /= 0 then
         Destroy (Editor.Linker_Switches);
         Editor.Linker_Switches := null;
      end if;
   end Destroy_Pages;

   ---------------
   -- Get_Pages --
   ---------------

   function Get_Pages
     (Editor : access Switches_Edit_Record) return Page_Filter is
   begin
      return Editor.Pages;
   end Get_Pages;

   ----------------
   -- Get_Window --
   ----------------

   function Get_Window
     (Editor : access Switches_Edit_Record) return Gtk.Widget.Gtk_Widget is
   begin
      if Get_Parent (Editor.Vbox2) = Gtk_Widget (Editor) then
         Ref (Editor.Vbox2);
         Unparent (Editor.Vbox2);
      end if;
      return Gtk_Widget (Editor.Vbox2);
   end Get_Window;

   ------------------
   -- Get_Switches --
   ------------------

   function Get_Switches
     (Editor : access Switches_Edit_Record; Tool : Tool_Names)
      return Argument_List
   is
      Cmd_Line : Gtk_Entry;
      Null_Argument_List : Argument_List (1 .. 0);
   begin
      case Tool is
         when Gnatmake => Cmd_Line := Editor.Make_Switches_Entry;
         when Compiler => Cmd_Line := Editor.Compiler_Switches_Entry;
         when Binder   => Cmd_Line := Editor.Binder_Switches_Entry;
         when Linker   => Cmd_Line := Editor.Linker_Switches_Entry;
      end case;

      --  ??? Do we have a memory leak here ? We can't free the
      --  ??? list contained, but should free the array access.
      declare
         Str : constant String := Get_Chars (Cmd_Line);
      begin
         if Str /= "" then
            return Argument_String_To_List (Str).all;
         end if;
      end;
      return Null_Argument_List;
   end Get_Switches;

   ---------------------------
   -- Get_Switches_From_GUI --
   ---------------------------

   function Get_Switches_From_GUI
     (Editor : access Switches_Edit_Record; Tool : Tool_Names)
      return Argument_List
   is
      procedure Check_Toggle
        (Button : Gtk_Check_Button;
         Str    : String;
         Arr    : in out Argument_List;
         Index  : in out Natural);

      procedure Check_Combo
        (Combo  : Gtk_Combo;
         Switch : String;
         Arr    : in out Argument_List;
         Index  : in out Natural);
      --  Set the parameter (starting with Switch, followed by a numeric
      --  argument) to use if Switch is set.
      --  If the numeric argument is 0, nothing is inserted into Arr.

      ------------------
      -- Check_Toggle --
      ------------------

      procedure Check_Toggle
        (Button : Gtk_Check_Button;
         Str    : String;
         Arr    : in out Argument_List;
         Index  : in out Natural) is
      begin
         if Get_Active (Button) then
            Arr (Index) := new String' (Str);
            Index := Index + 1;
         end if;
      end Check_Toggle;

      -----------------
      -- Check_Combo --
      -----------------

      procedure Check_Combo
        (Combo  : Gtk_Combo;
         Switch : String;
         Arr    : in out Argument_List;
         Index  : in out Natural)
      is
         use Widget_List;
         List  : Gtk_List := Get_List (Combo);
         Value : Integer;

      begin
         --  Check whether there is an actual selection. With gtk+2.0, the
         --  entry emits the "changed" signal more often, even in some cases
         --  where there is no actual selection in the list. However, the
         --  callback is called again later on.

         if Get_Selection (List) /= Null_List then
            Value := Integer (Child_Position
              (List, Get_Data (Get_Selection (List))));

            if Value /= 0 then
               Arr (Index) := new String' (Switch & Image (Value));
               Index := Index + 1;
            end if;
         end if;
      end Check_Combo;

      Num_Switches : Natural;

   begin
      case Tool is
         when Gnatmake => Num_Switches :=  6 + 1;  --  +1 is for arg to -j
         when Compiler => Num_Switches := 20 + 1;  --  +1 is for -g
         when Binder   => Num_Switches :=  3 + 1;  --  +1 is for -g
         when Linker   => Num_Switches :=  1 + 1;  --  +1 is for -g
      end case;

      declare
         Arr   : Argument_List (1 .. Num_Switches);
         Index : Natural := Arr'First;

      begin
         case Tool is
            when Gnatmake =>
               Check_Toggle (Editor.Make_All_Files, "-a", Arr, Index);
               Check_Toggle (Editor.Make_Recompile_Switches, "-s", Arr, Index);
               Check_Toggle (Editor.Make_Minimal_Recompile, "-m", Arr, Index);
               Check_Toggle (Editor.Make_Keep_Going, "-k", Arr, Index);
               Check_Toggle (Editor.Make_Debug, "-g", Arr, Index);

               if Get_Active (Editor.Make_Multiprocessing) then
                  Arr (Index) := new String' ("-j" &
                    Image (Integer (Get_Value_As_Int (Editor.Num_Processes))));
                  Index := Index + 1;
               end if;

            when Compiler =>
               Check_Combo (Editor.Optimization_Level, "-O", Arr, Index);
               Check_Combo (Editor.Compile_Representation_Info,
                           "-gnatR", Arr, Index);
               Check_Toggle
                 (Editor.Compile_No_Inline, "-fno-inline", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Interunit_Inlining, "-gnatN", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Unroll_Loops, "-funroll-loops", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Full_Errors, "-gnatf", Arr, Index);
               Check_Toggle
                 (Editor.Compile_No_Warnings, "-gnatws", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Warning_Error, "-gnatwe", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Elab_Warning, "-gnatwl", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Unused_Warning, "-gnatwu", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Style_Checks, "-gnaty", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Overflow_Checking, "-gnato", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Suppress_All_Checks, "-gnatp", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Stack_Checking, "-fstack-check", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Dynamic_Elaboration, "-gnatE", Arr, Index);
               Check_Toggle (Editor.Compile_Assertions, "-gnata", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Debug_Expanded_Code, "-gnatD", Arr, Index);
               Check_Toggle
                 (Editor.Compile_Language_Extensions, "-gnatX", Arr, Index);
               Check_Toggle (Editor.Compile_Ada83_Mode, "-gnat83", Arr, Index);

            when Binder =>
               Check_Toggle (Editor.Binder_Tracebacks, "-E", Arr, Index);

               if Get_Active (Editor.Binder_Static_Gnat) then
                  Arr (Index) := new String' ("-static");
               else
                  Arr (Index) := new String' ("-shared");
               end if;

               Index := Index + 1;

            when Linker =>
               Check_Toggle (Editor.Linker_Strip, "-s", Arr, Index);
         end case;

         return Arr (Arr'First .. Index - 1);
      end;
   end Get_Switches_From_GUI;

   ------------------
   -- Set_Switches --
   ------------------

   procedure Set_Switches
     (Editor   : access Switches_Edit_Record;
      Tool     : Tool_Names;
      Switches : Argument_List)
   is
      function Is_Set (Switch : String) return Boolean;
      --  True if Switch is set in Switches

      procedure Set_Combo (Combo : Gtk_Combo; Switch : String);
      --  Check if a switch starts with Switch, and get the numeric argument
      --  after it (set in the combo box)

      ------------
      -- Is_Set --
      ------------

      function Is_Set (Switch : String) return Boolean is
      begin
         for J in Switches'Range loop
            if Switches (J) /= null
              and then Switches (J).all = Switch
            then
               return True;
            end if;
         end loop;

         return False;
      end Is_Set;

      ---------------
      -- Set_Combo --
      ---------------

      procedure Set_Combo (Combo : Gtk_Combo; Switch : String) is
         Level : Gint;
      begin
         for J in Switches'Range loop
            if Switches (J) /= null
              and then Switches (J)'Length >= Switch'Length
              and then Switches (J) (Switches (J)'First
                                     .. Switches (J)'First + Switch'Length - 1)
              = Switch
            then
               if Switches (J)'Length > Switch'Length then
                  Level := Gint'Value
                    (Switches (J)(Switches (J)'First + Switch'Length
                                  .. Switches (J)'Last));
               else
                  Level := 0;
               end if;

               if Switch = "-gnatR"
                 and then Switches (J).all = "-gnatR"
               then
                  Select_Item (Get_List (Combo), 1);

               elsif Switch = "-O"
                 and then Switches (J).all = "-O"
               then
                  Select_Item (Get_List (Combo), 1);

               else
                  Select_Item (Get_List (Combo), Level);
               end if;

               return;
            else
               Select_Item (Get_List (Combo), 0);
            end if;
         end loop;
      end Set_Combo;

      Cmd_Line : Gtk_Entry;

   begin
      pragma Assert
        (Tool /= Gnatmake or else (Editor.Pages and Gnatmake_Page) /= 0);
      pragma Assert
        (Tool /= Compiler or else (Editor.Pages and Compiler_Page) /= 0);
      pragma Assert
        (Tool /= Binder or else (Editor.Pages and Binder_Page) /= 0);
      pragma Assert
        (Tool /= Linker or else (Editor.Pages and Linker_Page) /= 0);

      case Tool is
         when Gnatmake =>
            Set_Active (Editor.Make_All_Files, Is_Set ("-a"));
            Set_Active (Editor.Make_Recompile_Switches, Is_Set ("-s"));
            Set_Active (Editor.Make_Minimal_Recompile, Is_Set ("-m"));
            Set_Active (Editor.Make_Keep_Going, Is_Set ("-k"));
            Set_Active (Editor.Make_Debug, Is_Set ("-g"));
            Set_Active (Editor.Make_Multiprocessing, False);

            for J in Switches'Range loop
               if Switches (J) /= null
                 and then Switches (J)'Length > 1
                 and then Switches (J) (Switches (J)'First + 1) = 'j'
               then
                  Set_Active (Editor.Make_Multiprocessing, True);
                  if Switches (J)'Length > 2 then
                     Set_Value
                       (Editor.Num_Processes, Grange_Float'Value (Switches (J)
                          (Switches (J)'First + 2 .. Switches  (J)'Last)));
                  else
                     Set_Value (Editor.Num_Processes, 0.0);
                  end if;
               end if;
            end loop;

            Cmd_Line := Editor.Make_Switches_Entry;

         when Compiler =>
            Set_Combo (Editor.Optimization_Level, "-O");
            Set_Combo (Editor.Compile_Representation_Info, "-gnatR");
            Set_Active (Editor.Compile_No_Inline, Is_Set ("-fno-inline"));
            Set_Active (Editor.Compile_Interunit_Inlining, Is_Set ("-gnatN"));
            Set_Active
              (Editor.Compile_Unroll_Loops, Is_Set ("-funroll-loops"));
            Set_Active (Editor.Compile_Full_Errors, Is_Set ("-gnatf"));
            Set_Active (Editor.Compile_No_Warnings, Is_Set ("-gnatws"));
            Set_Active (Editor.Compile_Warning_Error, Is_Set ("-gnatwe"));
            Set_Active (Editor.Compile_Elab_Warning, Is_Set ("-gnatwl"));
            Set_Active (Editor.Compile_Unused_Warning, Is_Set ("-gnatwu"));
            Set_Active (Editor.Compile_Style_Checks, Is_Set ("-gnaty"));
            Set_Active (Editor.Compile_Overflow_Checking, Is_Set ("-gnato"));
            Set_Active (Editor.Compile_Suppress_All_Checks, Is_Set ("-gnatp"));
            Set_Active
              (Editor.Compile_Stack_Checking, Is_Set ("-fstack-check"));
            Set_Active (Editor.Compile_Dynamic_Elaboration, Is_Set ("-gnatE"));
            Set_Active (Editor.Compile_Assertions, Is_Set ("-gnata"));
            Set_Active (Editor.Compile_Debug_Expanded_Code, Is_Set ("-gnatD"));
            Set_Active (Editor.Compile_Language_Extensions, Is_Set ("-gnatX"));
            Set_Active (Editor.Compile_Ada83_Mode, Is_Set ("-gnat83"));

            Cmd_Line := Editor.Compiler_Switches_Entry;

         when Binder =>
            Set_Active (Editor.Binder_Tracebacks, Is_Set ("-E"));
            Set_Active (Editor.Binder_Static_Gnat, Is_Set ("-static"));
            Set_Active (Editor.Binder_Shared_Gnat, Is_Set ("-shared"));

            Cmd_Line := Editor.Binder_Switches_Entry;

         when Linker =>
            Set_Active (Editor.Linker_Strip, Is_Set ("-s"));

            Cmd_Line := Editor.Linker_Switches_Entry;
      end case;

      Editor.Block_Refresh := True;

      Set_Text (Cmd_Line, "");

      for K in Switches'Range loop
         if Switches (K) /= null then
            Append_Text (Cmd_Line, Switches (K).all & " ");
         end if;
      end loop;

      Editor.Block_Refresh := False;
   end Set_Switches;

   ---------------------
   -- Filter_Switches --
   ---------------------

   procedure Filter_Switches
     (Editor   : access Switches_Edit_Record'Class;
      Tool     : Tool_Names;
      Switches : in out GNAT.OS_Lib.Argument_List) is
   begin
      --  Note: We do not filter if the page is not displayed, so that the
      --  switches do not actually disappear when the switches editor is
      --  closed.

      case Tool is
         when Gnatmake =>
            if (Editor.Pages and Gnatmake_Page) /= 0 then
               for J in Switches'Range loop
                  if Switches (J) /= null
                    and then
                    (Switches (J).all = "-a"
                     or else Switches (J).all = "-s"
                     or else Switches (J).all = "-m"
                     or else Switches (J).all = "-k"
                     or else Switches (J).all = "-g"
                     or else
                     (Switches (J)'Length >= 2
                      and then Switches (J)
                      (Switches (J)'First .. Switches (J)'First + 1) = "-j"))
                  then
                     Free (Switches (J));
                  end if;
               end loop;
            end if;

         when Compiler =>
            if (Editor.Pages and Compiler_Page) /= 0 then
               for J in Switches'Range loop
                  if Switches (J) /= null
                    and then
                    ((Switches (J)'Length >= 2
                      and then Switches (J)
                      (Switches (J)'First .. Switches (J)'First + 1) = "-O")
                     or else
                     (Switches (J)'Length >= 6
                      and then Switches (J)
                      (Switches (J)'First .. Switches (J)'First + 5) =
                      "-gnatR")
                     or else Switches (J).all = "-fno-inline"
                     or else Switches (J).all = "-gnatN"
                     or else Switches (J).all = "-funroll-loops"
                     or else Switches (J).all = "-gnatf"
                     or else Switches (J).all = "-gnatws"
                     or else Switches (J).all = "-gnatwe"
                     or else Switches (J).all = "-gnatwl"
                     or else Switches (J).all = "-gnatwu"
                     or else Switches (J).all = "-gnaty"
                     or else Switches (J).all = "-gnato"
                     or else Switches (J).all = "-gnatp"
                     or else Switches (J).all = "-fstack-check"
                     or else Switches (J).all = "-gnatE"
                     or else Switches (J).all = "-gnata"
                     or else Switches (J).all = "-gnatD"
                     or else Switches (J).all = "-gnatX"
                     or else Switches (J).all = "-gnat83")
                  then
                     Free (Switches (J));
                  end if;
               end loop;
            end if;

         when Binder =>
            if (Editor.Pages and Binder_Page) /= 0 then
               for J in Switches'Range loop
                  if Switches (J) /= null
                    and then
                    (Switches (J).all = "-E"
                     or else Switches (J).all = "-static"
                     or else Switches (J).all = "-shared")
                  then
                     Free (Switches (J));
                  end if;
               end loop;
            end if;

         when Linker =>
            if (Editor.Pages and Linker_Page) /= 0 then
               for J in Switches'Range loop
                  if Switches (J) /= null and then Switches (J).all = "-s" then
                     Free (Switches (J));
                  end if;
               end loop;
            end if;

      end case;
   end Filter_Switches;

   --------------------
   -- Update_Cmdline --
   --------------------

   procedure Update_Cmdline
     (Editor : access Switches_Edit_Record; Tool : Tool_Names)
   is
      Cmd_Line : Gtk_Entry;
   begin
      --  Don't do anything if the callbacks were blocked, to avoid infinite
      --  loops while we are updating the command line, and it is updating
      --  the buttons, that are updating the command line,...
      if Editor.Block_Refresh then
         return;
      end if;

      case Tool is
         when Gnatmake => Cmd_Line := Editor.Make_Switches_Entry;
         when Compiler => Cmd_Line := Editor.Compiler_Switches_Entry;
         when Binder   => Cmd_Line := Editor.Binder_Switches_Entry;
         when Linker   => Cmd_Line := Editor.Linker_Switches_Entry;
      end case;

      declare
         Str     : constant String := Get_Text (Cmd_Line);
         Arr     : Argument_List := Get_Switches_From_GUI (Editor, Tool);
         Current : Argument_List_Access;

      begin
         if Str'Length = 0 then
            Current := new Argument_List (1 .. 0);
         else
            Current := Argument_String_To_List (Str);
         end if;

         Editor.Block_Refresh := True;
         Set_Text (Cmd_Line, "");

         for J in Arr'Range loop
            Append_Text (Cmd_Line, Arr (J).all & " ");
         end loop;

         --  Keep the switches set manually by the user

         Filter_Switches (Editor, Tool, Current.all);

         for K in Current'Range loop
            if Current (K) /= null then
               Append_Text (Cmd_Line, Current (K).all & " ");
            end if;
         end loop;

         Editor.Block_Refresh := False;

         Free (Arr);
         Free (Current);
      end;
   end Update_Cmdline;

   -----------------------------
   -- Update_Gui_From_Cmdline --
   -----------------------------

   procedure Update_Gui_From_Cmdline
     (Editor : access Switches_Edit_Record; Tool : Tool_Names)
   is
      Cmd_Line : Gtk_Entry;
   begin
      if Editor.Block_Refresh then
         return;
      end if;

      case Tool is
         when Gnatmake => Cmd_Line := Editor.Make_Switches_Entry;
         when Compiler => Cmd_Line := Editor.Compiler_Switches_Entry;
         when Binder   => Cmd_Line := Editor.Binder_Switches_Entry;
         when Linker   => Cmd_Line := Editor.Linker_Switches_Entry;
      end case;

      declare
         Arg : Argument_List_Access :=
           Argument_String_To_List (Get_Chars (Cmd_Line));

      begin
         Editor.Block_Refresh := True;
         Set_Switches (Editor, Tool, Arg.all);
         Free (Arg);
         Editor.Block_Refresh := False;
      end;
   end Update_Gui_From_Cmdline;

   ----------
   -- Free --
   ----------

   procedure Free (Switches : in out Argument_List) is
   begin
      for J in Switches'Range loop
         Free (Switches (J));
      end loop;
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (Switches : in out GNAT.OS_Lib.Argument_List_Access) is
      procedure Internal is new Unchecked_Deallocation
        (Argument_List, Argument_List_Access);
   begin
      Free (Switches.all);
      Internal (Switches);
   end Free;

   --------------
   -- Set_Page --
   --------------

   procedure Set_Page
     (Editor : access Switches_Edit_Record; Tool : Tool_Names) is
   begin
      Set_Page (Editor.Notebook1, Tool_Names'Pos (Tool));
   end Set_Page;

   -------------------------
   -- Close_Switch_Editor --
   -------------------------

   procedure Close_Switch_Editor
     (Button : access Gtk_Widget_Record'Class;
      Data   : Switch_Editor_User_Data)
   is
      S             : Switches_Edit   := Data.Switches;
      Project       : Project_Node_Id := Get_Project_From_View (Data.Project);
      Switches_Name : Name_Id;

      procedure Change_Switches (Tool : Tool_Names; Pkg_Name : String);
      --  Changes the switches for a specific package and tool.

      ---------------------
      -- Change_Switches --
      ---------------------

      procedure Change_Switches (Tool : Tool_Names; Pkg_Name : String) is
         List : Project_Node_Id := Empty_Node;
         Case_Item, Decl, Expr, Pkg : Project_Node_Id;
         Found, F : Boolean := False;
      begin
         --  Create the string list for all the switches

         declare
            Args : Argument_List := Get_Switches (S, Tool);
         begin
            if Args'Length /= 0 then
               List := Default_Project_Node (N_Literal_String_List, Prj.List);

               for A in Args'Range loop
                  Start_String;
                  Store_String_Chars (Args (A).all);
                  Expr := String_As_Expression (End_String);
                  Set_Next_Expression_In_List
                    (Expr, First_Expression_In_List (List));
                  Set_First_Expression_In_List (List, Expr);
               end loop;

               Free (Args);
            end if;
         end;

         --  ??? Shouldn't exist if there is already such a package => remove
         --  the previous declaration.
         if List = Empty_Node then
            return;
         end if;

         --  Do we already have some declarations for this variable ? If yes,
         --  we simply update them. Note that we need to update all of the
         --  declarations, in case the user has put multiple of these.

         Pkg := Get_Or_Create_Package (Project, Pkg_Name);
         Case_Item := Current_Scenario_Case_Item (Project, Pkg);

         Decl := First_Declarative_Item_Of (Case_Item);
         while Decl /= Empty_Node loop
            Expr := Current_Item_Node (Decl);

            if Kind_Of (Expr) = N_Attribute_Declaration
              and then Name_Of (Expr) = Switches_Name
            then
               F := False;
               if Data.File_Name = No_String then
                  F := (Associative_Array_Index_Of (Expr) = No_String);
               else
                  F := Associative_Array_Index_Of (Expr) /= No_String
                    and then String_Equal
                    (Associative_Array_Index_Of (Expr), Data.File_Name);
               end if;

               if F then
                  --  ??? Should handle the case where List is Empty_Node
                  Set_Current_Term (First_Term (Expression_Of (Expr)), List);
                  Found := True;
               end if;
            end if;

            Decl := Next_Declarative_Item (Decl);
         end loop;

         --  Create the new instruction to be added to the project

         if List /= Empty_Node and then not Found then
            Decl := Get_Or_Create_Attribute
              (Case_Item, "switches", Data.File_Name);
            Set_Expression_Of (Decl, Enclose_In_Expression (List));
         end if;
      end Change_Switches;

   begin
      pragma Assert (Project /= Empty_Node);

      --  Normalize the subproject we are currently working on, since we only
      --  know how to modify normalized subprojects.
      --  ??? Should check whether the project is already normalized.

      Normalize_Project (Project);

      Name_Len := 8;
      Name_Buffer (1 .. Name_Len) := "switches";
      Switches_Name := Name_Find;

      if (Get_Pages (S) and Gnatmake_Page) /= 0 then
         Change_Switches (Gnatmake, "gnatmake");
      end if;

      if (Get_Pages (S) and Compiler_Page) /= 0 then
         Change_Switches (Compiler, "compiler");
      end if;

      if (Get_Pages (S) and Binder_Page) /= 0 then
         Change_Switches (Binder, "gnatbind");
      end if;

      if (Get_Pages (S) and Linker_Page) /= 0 then
         Change_Switches (Linker, "gnatlink");
      end if;

      Recompute_View (Data.Kernel);
      Destroy (Get_Toplevel (Button));
   end Close_Switch_Editor;

   --------------------------
   -- Cancel_Switch_Editor --
   --------------------------

   procedure Cancel_Switch_Editor
     (Dialog : access Gtk_Widget_Record'Class) is
   begin
      Destroy (Dialog);
   end Cancel_Switch_Editor;

   -------------------
   -- Edit_Switches --
   -------------------

   procedure Edit_Switches
     (Kernel       : access Glide_Kernel.Kernel_Handle_Record'Class;
      Project_View : Prj.Project_Id;
      File_Name    : Types.String_Id := No_String;
      Directory    : Types.String_Id := No_String)
   is
      File : Name_Id := No_Name;
      Switches : Switches_Edit;
      Dialog : Gtk_Dialog;
      Button : Gtk_Button;
      Label  : Gtk_Label;
      Value : Variable_Value;
      Is_Default : Boolean;
      Desc : Pango_Font_Description;
      Style : Gtk_Style;

   begin
      pragma Assert (Project_View /= No_Project);

      Gtk_New (Dialog);

      if File_Name /= No_String then
         String_To_Name_Buffer (File_Name);
         File := Name_Find;
         Gtk_New
           (Label, "Editing switches for " & Name_Buffer (1 .. Name_Len));
      else
         Gtk_New
           (Label, "Editing default switches for project "
            & Get_Name_String (Prj.Projects.Table (Project_View).Name));
      end if;

      Pack_Start (Get_Vbox (Dialog), Label, Padding => 10);

      Style := Copy (Get_Style (Label));
      Desc := From_String (Switches_Editor_Title_Font);
      Set_Font_Description (Style, Desc);
      Set_Style (Label, Style);

      Gtk_New (Switches);
      Pack_Start (Get_Vbox (Dialog),
                  Get_Window (Switches), Fill => True, Expand => True);

      if File_Name /= No_String then
         Destroy_Pages (Switches, Gnatmake_Page or Binder_Page or Linker_Page);
      end if;

      --  Set the switches for all the pages
      if (Get_Pages (Switches) and Gnatmake_Page) /= 0 then
         Get_Switches (Project_View, "gnatmake", File, Value, Is_Default);
         declare
            List : Argument_List := To_Argument_List (Value);
         begin
            Set_Switches (Switches, Gnatmake, List);
            Free (List);
         end;
      end if;

      if (Get_Pages (Switches) and Compiler_Page) /= 0 then
         Get_Switches (Project_View, "compiler", File, Value, Is_Default);
         declare
            List : Argument_List := To_Argument_List (Value);
         begin
            Set_Switches (Switches, Compiler, List);
            Free (List);
         end;
      end if;

      if (Get_Pages (Switches) and Binder_Page) /= 0 then
         Get_Switches (Project_View, "gnatbind", File, Value, Is_Default);
         declare
            List : Argument_List := To_Argument_List (Value);
         begin
            Set_Switches (Switches, Binder, List);
            Free (List);
         end;
      end if;

      if (Get_Pages (Switches) and Linker_Page) /= 0 then
         Get_Switches (Project_View, "gnatlink", File, Value, Is_Default);
         declare
            List : Argument_List := To_Argument_List (Value);
         begin
            Set_Switches (Switches, Linker, List);
            Free (List);
         end;
      end if;

      Gtk_New_From_Stock (Button, Stock_Ok);
      Pack_Start
        (Get_Action_Area (Dialog), Button, Fill => False, Expand => False);
      Switch_Callback.Connect
        (Button, "clicked",
         Switch_Callback.To_Marshaller (Close_Switch_Editor'Access),
         (Kernel    => Kernel_Handle (Kernel),
          Project   => Project_View,
          Switches  => Switches,
          File_Name => File_Name,
          Directory => Directory));

      Gtk_New_From_Stock (Button, Stock_Cancel);
      Pack_Start
        (Get_Action_Area (Dialog), Button, Fill => False, Expand => False);
      Widget_Callback.Object_Connect
        (Button, "clicked",
         Widget_Callback.To_Marshaller (Cancel_Switch_Editor'Access), Dialog);

      Show_All (Dialog);
   end Edit_Switches;

   -----------------------------------
   -- Edit_Switches_From_Contextual --
   -----------------------------------

   procedure Edit_Switches_From_Contextual
     (Item : access Gtk.Widget.Gtk_Widget_Record'Class;
      Data : Contextual_User_Data) is
   begin
      if Data.File_Name = No_String then
         Edit_Switches (Data.Kernel, Data.Project, No_String, No_String);
      else
         Edit_Switches
           (Data.Kernel, Data.Project, Data.File_Name, Data.Directory);
      end if;
   end Edit_Switches_From_Contextual;

end Switches_Editors;
