------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2006-2022, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

--  <description>
--  This package provides the graphical user interface subprograms for
--  Code Analysis Module use
--  </description>

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Glib;                  use Glib;
with Gdk.Event;             use Gdk.Event;
with Gtk.Menu;
with Gtk.Box;               use Gtk.Box;
with Gtk.Button;            use Gtk.Button;
with Gtk.Tree_Store;        use Gtk.Tree_Store;
with Gtk.Tree_Model;        use Gtk.Tree_Model;
with Gtk.Tree_View_Column;  use Gtk.Tree_View_Column;
with Gtk.Widget;            use Gtk.Widget;

with Gtkada.Tree_View;      use Gtkada.Tree_View;

with GPS.Kernel;            use GPS.Kernel;
with Code_Analysis;         use Code_Analysis;

package Code_Analysis_GUI is

   Prj_Pixbuf_Cst   : constant String :=
     "gps-emblem-project-closed";
   --  Name of the icon used for project node in the analysis report
   File_Pixbuf_Cst  : constant String :=
     "gps-emblem-file-unmodified";
   --  Name of the icon used for file node in the analysis report
   Subp_Pixbuf_Cst  : constant String :=
     "gps-emblem-entity-subprogram";
   --  Name of the icon used for subprogram node in the analysis report
   Grey_Analysis_Cst   : constant String :=
     "gps-emblem-pencil-grey";
   Purple_Analysis_Cst : constant String :=
     "gps-emblem-pencil-purple";
   Blue_Analysis_Cst   : constant String :=
     "gps-emblem-pencil-blue";
   Red_Analysis_Cst    : constant String :=
     "gps-emblem-pencil-red";
   --  Name of the icons used for posting an analysis

   Icon_Name_Col  : constant := 0;
   --  Gtk_Tree_Model column number dedicated to the icons associated with each
   --  node of code_analysis data structure
   Name_Col : constant := 1;
   --  Gtk_Tree_Model column number dedicated to the name of the nodes of
   --  code_analysis structure
   --  This is a UTF8 representation of the filesystem path.
   Node_Col : constant := 2;
   --  Gtk_Tree_Model column number dedicated to the nodes of code_analysis
   --  structure
   File_Col : constant := 3;
   --  Gtk_Tree_Model column number dedicated to the node corresponding file
   --  of the code_analysis structure (usefull for flat views)
   --  It is filled with :
   --   - nothing if the node is a project
   --   - the file_node itself if its a file
   --   - the parent file_node if its a subprogram
   Prj_Col  : constant := 4;
   --  Gtk_Tree_Model column number dedicated to the node corresponding project
   --  of the code_analysis structure in every circumstance
   --  (usefull for flat views)
   Cov_Col  : constant := 5;
   --  Gtk_Tree_Model column number dedicated to the coverage information
   --  contained in the node coverage records
   Cov_Sort : constant := 6;
   --  Gtk_Tree_Model column number dedicated to some raw coverage information
   --  used to sort rows by not covered lines amount order
   Cov_Bar_Txt : constant := 7;
   --  Ctk_Tree_Model column number dedicated to the coverage percentage column
   Cov_Bar_Val : constant := 8;
   --  Gtk_Tree_Model column number dedicated to the raw coverage percentage
   --  values, in order to be use in sorting operations

   Progress_Bar_Width_Cst : constant Gint := 150;
   --  Constant used to set the width of the progress bars of the analysis
   --  report

   Covered_Line_Pixbuf   : constant Unbounded_String :=
     To_Unbounded_String
       ("gps-emblem-gcov-covered-symbolic");
   Uncovered_Line_Pixbuf : constant Unbounded_String :=
     To_Unbounded_String
       ("gps-emblem-gcov-uncovered-symbolic");
   --  Pixbufs containing the line information icons.
   --  Call Initialize_Graphics before referencing these variables.

   type Code_Analysis_Tree_View_Record is
     new Gtkada.Tree_View.Tree_View_Record with record
      Show_Non_Analyzed : Boolean := True;
      --  Whether we should display nodes that don't have any coverage
      --  (i.e: "n/a" nodes).
   end record;
   type Code_Analysis_Tree_View is
     access all Code_Analysis_Tree_View_Record'Class;
   --  The tree view used for the coverage analysis report.

   overriding function Is_Visible
     (Self       : not null access Code_Analysis_Tree_View_Record;
      Store_Iter : Gtk_Tree_Iter) return Boolean;

   type Code_Analysis_Report is new Gtk_Vbox_Record with record
      Tree             : Code_Analysis_Tree_View;
      Model            : Gtk_Tree_Store;
      Node_Column      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Cov_Column       : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Cov_Percent_Text : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Cov_Percent      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Error_Board      : Gtk_Hbox; --  when there's no data
      Load_Button      : Gtk_Button;
      Empty_Board      : Gtk_Hbox; --  when flat view doesn't allow to see data
      Projects         : Code_Analysis_Tree;
      --  Used by Show_Flat_List_* and Save_Desktop callbacks
      Binary_Mode      : Boolean := True;
   end record;

   type Code_Analysis_Report_Access is access all Code_Analysis_Report;

   function Build_Analysis_Report
     (Kernel      : Kernel_Handle;
      Binary_Mode : Boolean) return Code_Analysis_Report_Access;
   --  Create a new analysis report.
   --  Binary_Mode determines wether we are in binary coverage mode or not. If
   --  True, then no line execution coverage count will be displayed.

   procedure Set_Projects_And_Name
     (Self     : not null access Code_Analysis_Report'Class;
      Name     : Unbounded_String;
      Projects : Code_Analysis_Tree);
   --  Attach a project and a name to the given analysis report. Used mainly
   --  for testsuite purposes.

   function Name (View : access Code_Analysis_Report'Class) return String;
   --  Get the View's name.

   procedure Clear (View : access Code_Analysis_Report'Class);
   --  Clear data from the view.

   function On_Double_Click (Object : access Gtk_Widget_Record'Class;
                             Event  : Gdk_Event;
                             Kernel : Kernel_Handle) return Boolean;
   --  Callback for the "2button_press" signal that show the File or Subprogram
   --  indicated by the selected Report of Analysis tree node

   procedure Setup_Local_Menu
     (View  : not null access Code_Analysis_Report'Class;
      Menu  : not null access Gtk.Menu.Gtk_Menu_Record'Class);
   --  Add custom entries to the given local menu.

   procedure Open_File_Editor_On_File
     (Kernel : Kernel_Handle;
      View   : Code_Analysis_Report_Access;
      Iter   : Gtk_Tree_Iter);
   --  Opens a file editor on the source file pointed out by Iter in Model

   procedure Open_File_Editor_On_Subprogram
     (Kernel : Kernel_Handle;
      View   : Code_Analysis_Report_Access;
      Iter   : Gtk_Tree_Iter);
   --  Opens a file editor on the source file containing the Subprogram
   --  pointed out by Iter in Model

   procedure Open_File_Editor
     (Kernel    : Kernel_Handle;
      View      : Code_Analysis_Report_Access;
      File_Node : Code_Analysis.File_Access;
      Quiet     : Boolean;
      Line      : Natural := 1;
      Column    : Natural := 1);
   --  Factorizes the code of Open_File_Editor_On_File and _On_Subprogram

   procedure Show_Full_Tree (Object : access Gtk_Widget_Record'Class);
   --  Fill again the Gtk_Tree_Store with the full tree

   procedure Show_Flat_List_Of_Files (Object : access Gtk_Widget_Record'Class);
   --  Fill the Gtk_Tree_Store with only on level of file

   procedure Show_Flat_List_Of_Subprograms
     (Object : access Gtk_Widget_Record'Class);
   --  Fill the Gtk_Tree_Store with only on level of subprograms

   procedure Set_Non_Analyzed_Visibility
     (View    : not null access Code_Analysis_Report'Class;
      Visible : Boolean);
   --  Show/hide the nodes that have not been analyzed, either because they
   --  don't contain executable code or because they have been explcitly
   --  excluded by the user.

end Code_Analysis_GUI;
