------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2001-2014, AdaCore                     --
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

with Ada.Characters.Handling;   use Ada.Characters.Handling;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Hash;

with GNATCOLL.Projects;         use GNATCOLL.Projects;
with GNATCOLL.Symbols;          use GNATCOLL.Symbols;
with GNATCOLL.Traces;           use GNATCOLL.Traces;
with GNATCOLL.VFS;              use GNATCOLL.VFS;
with GNATCOLL.VFS.GtkAda;       use GNATCOLL.VFS.GtkAda;
with GNATCOLL.VFS_Utils;        use GNATCOLL.VFS_Utils;

with Glib;                      use Glib;
with Glib.Main;                 use Glib.Main;
with Glib.Object;               use Glib.Object;
with Glib.Values;               use Glib.Values;

with Gdk;                       use Gdk;
with Gdk.Dnd;                   use Gdk.Dnd;
with Gdk.Event;                 use Gdk.Event;
with Gdk.Rectangle;             use Gdk.Rectangle;
with Gdk.Window;                use Gdk.Window;

with Gtk.Dnd;                   use Gtk.Dnd;
with Gtk.Enums;                 use Gtk.Enums;
with Gtk.Arguments;             use Gtk.Arguments;
with Gtk.Box;                   use Gtk.Box;
with Gtk.Check_Button;          use Gtk.Check_Button;
with Gtk.Check_Menu_Item;       use Gtk.Check_Menu_Item;
with Gtk.Handlers;
with Gtk.Label;                 use Gtk.Label;
with Gtk.Toolbar;               use Gtk.Toolbar;
with Gtk.Tree_Model;            use Gtk.Tree_Model;
with Gtk.Tree_Model_Filter;     use Gtk.Tree_Model_Filter;
with Gtk.Tree_View;             use Gtk.Tree_View;
with Gtk.Tree_Store;            use Gtk.Tree_Store;
with Gtk.Tree_Selection;        use Gtk.Tree_Selection;
with Gtk.Menu;                  use Gtk.Menu;
with Gtk.Widget;                use Gtk.Widget;
with Gtk.Cell_Renderer_Text;    use Gtk.Cell_Renderer_Text;
with Gtk.Cell_Renderer_Pixbuf;  use Gtk.Cell_Renderer_Pixbuf;
with Gtk.Scrolled_Window;       use Gtk.Scrolled_Window;
with Gtk.Toggle_Button;
with Gtk.Tree_Sortable;         use Gtk.Tree_Sortable;
with Gtk.Tree_View_Column;      use Gtk.Tree_View_Column;
with Gtkada.MDI;                use Gtkada.MDI;
with Gtkada.Tree_View;          use Gtkada.Tree_View;
with Gtkada.Handlers;           use Gtkada.Handlers;

with Commands.Interactive;      use Commands, Commands.Interactive;
with Find_Utils;                use Find_Utils;
with Generic_Views;             use Generic_Views;
with Histories;                 use Histories;
with GPS.Kernel;                use GPS.Kernel;
with GPS.Kernel.Actions;        use GPS.Kernel.Actions;
with GPS.Kernel.Contexts;       use GPS.Kernel.Contexts;
with GPS.Kernel.Hooks;          use GPS.Kernel.Hooks;
with GPS.Kernel.Project;        use GPS.Kernel.Project;
with GPS.Kernel.MDI;            use GPS.Kernel.MDI;
with GPS.Kernel.Modules;        use GPS.Kernel.Modules;
with GPS.Kernel.Modules.UI;     use GPS.Kernel.Modules.UI;
with GPS.Kernel.Preferences;    use GPS.Kernel.Preferences;
with GPS.Kernel.Standard_Hooks; use GPS.Kernel.Standard_Hooks;
with GPS.Search;                use GPS.Search;
with GPS.Intl;                  use GPS.Intl;
with GUI_Utils;                 use GUI_Utils;
with Language;                  use Language;
with Language.Unknown;          use Language.Unknown;
with Language_Handlers;         use Language_Handlers;
with Language_Utils;            use Language_Utils;
with Projects;                  use Projects;
with Project_Explorers_Common;  use Project_Explorers_Common;
with Remote;                    use Remote;
with String_Hash;
with String_Utils;              use String_Utils;
with Tooltips;
with Vsearch;                   use Vsearch;

package body Project_Explorers is

   Me : constant Trace_Handle := Create ("Project_Explorers");

   type Explorer_Module_Record is new Module_ID_Record with null record;
   Explorer_Module_ID : Module_ID := null;
   --  Id for the explorer module

   Show_Absolute_Paths : constant History_Key :=
                           "explorer-show-absolute-paths";
   Show_Flat_View      : constant History_Key :=
                           "explorer-show-flat-view";
   Show_Hidden_Dirs    : constant History_Key :=
     "explorer-show-hidden-directories";
   Show_Empty_Dirs     : constant History_Key :=
     "explorer-show-empty-directories";

   Toggle_Absolute_Path_Name : constant String :=
     "Explorer toggle absolute paths";
   Toggle_Absolute_Path_Tip : constant String :=
     "Toggle the display of absolute paths or just base names in the"
     & " project explorer";

   Projects_Before_Directories : constant Boolean := False;
   --  <preference> True if the projects should be displayed, when sorted,
   --  before the directories in the project view.

   -------------
   --  Filter --
   -------------

   type Filter_Type is (Show_Direct, Show_Indirect, Hide);
   --  The status of the filter for each node:
   --  - show_direct is used when the node itself matches the filter.
   --  - show_indirect is used when a child of the node must be displayed, but
   --    the node itself does not match the filter.
   --  - hide is used when the node should be hidden

   package Filter_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Virtual_File,
      Hash            => GNATCOLL.VFS.Full_Name_Hash,
      Element_Type    => Filter_Type,
      Equivalent_Keys => "=");
   use Filter_Maps;

   type Explorer_Filter is record
      Pattern  : GPS.Search.Search_Pattern_Access;
      --  The pattern on which we filter.

      Cache    : Filter_Maps.Map;
      --  A cache of the filter. We do not manipulate the gtk model directlyy,
      --  because it does not contain everything in general (the contents of
      --  nodes is added dynamically).
   end record;

   procedure Set_Pattern
     (Self    : in out Explorer_Filter;
      Kernel  : not null access Kernel_Handle_Record'Class;
      Pattern : Search_Pattern_Access);
   --  Change the pattern and update the cache

   function Is_Visible
     (Self : Explorer_Filter; File : Virtual_File) return Filter_Type;
   --  Whether the given file should be visible

   ---------------------------------
   -- The project explorer widget --
   ---------------------------------

   type Project_Explorer_Record is new Generic_Views.View_Record with record
      Tree      : Gtkada.Tree_View.Tree_View;

      Filter    : Explorer_Filter;

      Expand_Id : Gtk.Handlers.Handler_Id;
      --  The signal for the expansion of nodes in the project view

      Expanding : Boolean := False;
   end record;
   overriding procedure Create_Menu
     (View    : not null access Project_Explorer_Record;
      Menu    : not null access Gtk.Menu.Gtk_Menu_Record'Class);
   overriding procedure Create_Toolbar
     (View    : not null access Project_Explorer_Record;
      Toolbar : not null access Gtk.Toolbar.Gtk_Toolbar_Record'Class);
   overriding procedure Filter_Changed
     (Self    : not null access Project_Explorer_Record;
      Pattern : in out GPS.Search.Search_Pattern_Access);

   function Initialize
     (Explorer : access Project_Explorer_Record'Class)
      return Gtk.Widget.Gtk_Widget;
   --  Create a new explorer, and return the focus widget.

   package Explorer_Views is new Generic_Views.Simple_Views
     (Module_Name        => Explorer_Module_Name,
      View_Name          => "Project",
      Formal_View_Record => Project_Explorer_Record,
      Formal_MDI_Child   => MDI_Explorer_Child_Record,
      Reuse_If_Exist     => True,
      Local_Toolbar      => True,
      Local_Config       => True,
      Areas              => Gtkada.MDI.Sides_Only,
      Position           => Position_Left,
      Initialize         => Initialize);
   use Explorer_Views;
   subtype Project_Explorer is Explorer_Views.View_Access;

   package Set_Visible_Funcs is new Set_Visible_Func_User_Data
     (User_Data_Type => Project_Explorer);

   function Is_Visible
     (Child_Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter        : Gtk.Tree_Model.Gtk_Tree_Iter;
      Self        : Project_Explorer) return Boolean;
   --  Filter out some lines in the project view, based on the filter in the
   --  toolbar.

   -----------------------
   -- Local subprograms --
   -----------------------

   type Toggle_Absolute_Path_Command is
      new Interactive_Command with null record;
   overriding function Execute
     (Self    : access Toggle_Absolute_Path_Command;
      Context : Commands.Interactive.Interactive_Command_Context)
      return Commands.Command_Return_Type;

   function Hash (Key : Filesystem_String) return Ada.Containers.Hash_Type;
   pragma Inline (Hash);

   package Filename_Node_Hash is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => Filesystem_String,
      Element_Type    => Gtk_Tree_Iter,
      Hash            => Hash,
      Equivalent_Keys => "=");
   use Filename_Node_Hash;

   package File_Node_Hash is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => Virtual_File,
      Element_Type    => Gtk_Tree_Iter,
      Hash            => GNATCOLL.VFS.Full_Name_Hash,
      Equivalent_Keys => "=");
   use File_Node_Hash;

   type Directory_Info is record
      Directory : Virtual_File;
      Kind      : Node_Types;
   end record;
   function "<" (D1, D2 : Directory_Info) return Boolean;
   package Files_List is new Ada.Containers.Doubly_Linked_Lists (Virtual_File);
   package Dirs_Files_Hash is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type        => Directory_Info,
      Element_Type    => Files_List.List,
      "="             => Files_List."=");
   use Files_List, Dirs_Files_Hash;

   overriding procedure Default_Context_Factory
     (Module  : access Explorer_Module_Record;
      Context : in out Selection_Context;
      Child   : Glib.Object.GObject);
   --  See inherited documentation

   ---------------
   -- Searching --
   ---------------

   type Search_Status is new Integer;
   --  Values stored in the String_Status hash table:
   --    - n: the entry or one of its children matches. n is the number of
   --         children that potentially matches (ie that have an entry set to
   --         n or -1
   --    - 0: the node doesn't match and neither do its children.
   --    - -1: the entry hasn't been examined yet

   Search_Match : constant Search_Status := 1;
   No_Match     : constant Search_Status := 0;
   Unknown      : constant Search_Status := -1;

   package Project_Sets is
     new Ada.Containers.Indefinite_Hashed_Sets
       (Virtual_File, GNATCOLL.VFS.Full_Name_Hash, "=");

   Projects : Project_Sets.Set;
   --  Cache for project passed through search
   --  ??? Should not be a global variable

   procedure Nop (X : in out Search_Status) is null;
   --  Do nothing, required for instantiation of string_boolean_hash

   package String_Status_Hash is new String_Hash
     (Data_Type => Search_Status,
      Free_Data => Nop,
      Null_Ptr  => No_Match);
   use String_Status_Hash;
   use String_Status_Hash.String_Hash_Table;

   type Explorer_Search_Context is new Root_Search_Context with record
      Current             : Gtk_Tree_Iter := Null_Iter;
      Include_Entities    : Boolean;
      Include_Projects    : Boolean;
      Include_Directories : Boolean;
      Include_Files       : Boolean;

      Matches             : String_Status_Hash.String_Hash_Table.Instance;
      --  The search is performed on the internal Ada structures first, and for
      --  each matching project, directory or file, an entry is made in this
      --  table (set to true). This then speeds up the traversing of the tree
      --  to find the matching entities.
      --  Key is
      --    Base_Name for File and Project
      --    Display_Full_Name for directories
   end record;
   type Explorer_Search_Context_Access is access all Explorer_Search_Context;

   overriding function Context_Look_In
     (Self : Explorer_Search_Context) return String;
   overriding procedure Free (Context : in out Explorer_Search_Context);
   --  Free the memory allocated for Context

   type Explorer_Search_Extra_Record is new Gtk_Box_Record with record
      Include_Entities    : Gtk_Check_Button;
      Include_Projects    : Gtk_Check_Button;
      Include_Directories : Gtk_Check_Button;
      Include_Files       : Gtk_Check_Button;
   end record;
   type Explorer_Search_Extra is access all Explorer_Search_Extra_Record'Class;

   function Explorer_Search_Factory
     (Kernel            : access GPS.Kernel.Kernel_Handle_Record'Class;
      All_Occurences    : Boolean;
      Extra_Information : Gtk.Widget.Gtk_Widget)
      return Root_Search_Context_Access;
   --  Create a new search context for the explorer

   function Explorer_Search_Factory
     (Kernel           : access GPS.Kernel.Kernel_Handle_Record'Class;
      Include_Projects : Boolean;
      Include_Files    : Boolean)
      return Root_Search_Context_Access;
   --  Create a new search context for the explorer. Only one occurence is
   --  searched, and only in Projects or Files, depending on the parameters.

   overriding procedure Search
     (Context         : access Explorer_Search_Context;
      Kernel          : access GPS.Kernel.Kernel_Handle_Record'Class;
      Search_Backward : Boolean;
      Give_Focus      : Boolean;
      Found           : out Boolean;
      Continue        : out Boolean);
   --  Search the next occurrence in the explorer

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class);
   --  Called when the preferences have changed

   function Sort_Func
     (Model : Gtk_Tree_Model;
      A     : Gtk.Tree_Model.Gtk_Tree_Iter;
      B     : Gtk.Tree_Model.Gtk_Tree_Iter) return Gint;
   --  Used to sort nodes in the explorer

   function Compute_Project_Node_Type
      (Explorer : not null access Project_Explorer_Record'Class;
       Project  : Project_Type) return Node_Types;
   --  The node type to use for a project

   --------------
   -- Tooltips --
   --------------

   type Explorer_Tooltips is new Tooltips.Tooltips with record
      Explorer : Project_Explorer;
   end record;
   type Explorer_Tooltips_Access is access all Explorer_Tooltips'Class;
   overriding function Create_Contents
     (Tooltip  : not null access Explorer_Tooltips;
      Widget   : not null access Gtk.Widget.Gtk_Widget_Record'Class;
      X, Y     : Glib.Gint) return Gtk.Widget.Gtk_Widget;
   --  See inherited documentatoin

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Set_Column_Types (Tree : Gtk_Tree_View);
   --  Sets the types of columns to be displayed in the tree_view

   ---------------------
   -- Expanding nodes --
   ---------------------

   function Directory_Node_Text
     (Show_Abs_Paths : Boolean;
      Project        : Project_Type;
      Dir            : Virtual_File) return String;
   --  Return the text to use for a directory node

   procedure Expand_Row_Cb
     (Explorer    : access Gtk.Widget.Gtk_Widget_Record'Class;
      Filter_Iter : Gtk_Tree_Iter;
      Filter_Path : Gtk_Tree_Path);
   --  Called every time a node is expanded. It is responsible for
   --  automatically adding the children of the current node if they are not
   --  there already.

   procedure Collapse_Row_Cb
     (Explorer    : access Gtk.Widget.Gtk_Widget_Record'Class;
      Filter_Iter : Gtk_Tree_Iter;
      Filter_Path : Gtk_Tree_Path);
   --  Called every time a node is collapsed

   procedure Refresh_Project_Node
     (Self      : not null access Project_Explorer_Record'Class;
      Node      : Gtk_Tree_Iter;
      Flat_View : Boolean);
   --  Insert the children nodes for the project (directories, imported
   --  projects,...)
   --  Node is associated with Project. Both can be null when in flat view
   --  mode.

   function Button_Press
     (Explorer : access GObject_Record'Class;
      Event    : Gdk_Event_Button) return Boolean;
   --  Called every time a row is clicked
   --  ??? It is actually called twice in that case: a first time when the
   --  mouse button is pressed and a second time when it is released.

   function Key_Press
     (Explorer : access Gtk_Widget_Record'Class;
      Event    : Gdk_Event) return Boolean;
   --  Calledback on a key press

   procedure Tree_Select_Row_Cb
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class; Args : GValues);
   --  Called every time a new row is selected

   --------------------
   -- Updating nodes --
   --------------------

   procedure Update_Absolute_Paths
     (Explorer : access Gtk_Widget_Record'Class);
   --  Update the text for all directory nodes in the tree, mostly after the
   --  "show absolute path" setting has changed.

   procedure Update_View (Explorer : access Gtk_Widget_Record'Class);
   --  Clear the view and recreate from scratch.

   ----------------------------
   -- Retrieving information --
   ----------------------------

   procedure Refresh
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Refresh the contents of the tree after the project view has changed.
   --  This procedure tries to keep as many things as possible in the current
   --  state (expanded nodes,...)

   type Refresh_Hook_Record is new Function_No_Args with record
      Explorer : Project_Explorer;
   end record;
   type Refresh_Hook is access all Refresh_Hook_Record'Class;
   overriding procedure Execute
     (Hook   : Refresh_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class);
   --  Called when the project view has changed

   type Project_Changed_Hook_Record is new Function_No_Args with record
      Explorer : Project_Explorer;
   end record;
   type Project_Hook is access all Project_Changed_Hook_Record'Class;
   overriding procedure Execute
     (Hook   : Project_Changed_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class);
   --  Called when the project as changed, as opposed to the project view.
   --  This means we need to start up with a completely new tree, no need to
   --  try to keep the current one.

   procedure Jump_To_Node
     (Explorer    : Project_Explorer;
      Target_Node : Gtk_Tree_Iter);
   --  Select Target_Node, and make sure it is visible on the screen

   procedure Explorer_Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu);
   --  Return the context to use for the contextual menu.
   --  It is also used to return the context for
   --  GPS.Kernel.Get_Current_Context, and thus can be called with a null
   --  event or a null menu.

   procedure Child_Selected
     (Explorer : access Gtk_Widget_Record'Class; Args : GValues);
   --  Called every time a new child is selected in the MDI. This makes sure
   --  that the selected node in the explorer doesn't reflect false information

   --------------
   -- Commands --
   --------------

   type Locate_File_In_Explorer_Command
     is new Interactive_Command with null record;
   overriding function Execute
     (Command : access Locate_File_In_Explorer_Command;
      Context : Interactive_Command_Context) return Command_Return_Type;

   type Locate_Project_In_Explorer_Command
     is new Interactive_Command with null record;
   overriding function Execute
     (Command : access Locate_Project_In_Explorer_Command;
      Context : Interactive_Command_Context) return Command_Return_Type;

   -------------
   -- Filters --
   -------------

   type Project_View_Filter_Record is new Action_Filter_Record
      with null record;
   type Project_Node_Filter_Record is new Action_Filter_Record
      with null record;
   type Directory_Node_Filter_Record is new Action_Filter_Record
      with null record;
   type File_Node_Filter_Record is new Action_Filter_Record
      with null record;
   type Entity_Node_Filter_Record is new Action_Filter_Record
      with null record;
   overriding function Filter_Matches_Primitive
     (Context : access Project_View_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean;
   overriding function Filter_Matches_Primitive
     (Context : access Project_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean;
   overriding function Filter_Matches_Primitive
     (Context : access Directory_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean;
   overriding function Filter_Matches_Primitive
     (Context : access File_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean;
   overriding function Filter_Matches_Primitive
     (Context : access Entity_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean;

   -------------------------------
   -- Compute_Project_Node_Type --
   -------------------------------

   function Compute_Project_Node_Type
      (Explorer : not null access Project_Explorer_Record'Class;
       Project  : Project_Type) return Node_Types
   is
   begin
      if Project.Modified then
         return Modified_Project_Node;
      elsif Project = Explorer.Kernel.Registry.Tree.Root_Project then
         return Root_Project_Node;
      elsif Extending_Project (Project) /= No_Project then
         return Extends_Project_Node;
      else
         return Project_Node;
      end if;
   end Compute_Project_Node_Type;

   ---------
   -- "<" --
   ---------

   function "<" (D1, D2 : Directory_Info) return Boolean is
   begin
      return D1.Directory < D2.Directory;
   end "<";

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   overriding function Filter_Matches_Primitive
     (Context : access Project_View_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean
   is
      pragma Unreferenced (Context);
   begin
      return Module_ID (Get_Creator (Ctxt)) = Explorer_Module_ID;
   end Filter_Matches_Primitive;

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   overriding function Filter_Matches_Primitive
     (Context : access Project_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean
   is
      pragma Unreferenced (Context);
   begin
      return Module_ID (Get_Creator (Ctxt)) = Explorer_Module_ID
        and then Has_Project_Information (Ctxt)
        and then not Has_Directory_Information (Ctxt);
   end Filter_Matches_Primitive;

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   overriding function Filter_Matches_Primitive
     (Context : access Directory_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean
   is
      pragma Unreferenced (Context);
   begin
      return Module_ID (Get_Creator (Ctxt)) = Explorer_Module_ID
        and then Has_Directory_Information (Ctxt)
        and then not Has_File_Information (Ctxt);
   end Filter_Matches_Primitive;

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   overriding function Filter_Matches_Primitive
     (Context : access File_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean
   is
      pragma Unreferenced (Context);
   begin
      return Module_ID (Get_Creator (Ctxt)) = Explorer_Module_ID
        and then Has_File_Information (Ctxt)
        and then not Has_Entity_Name_Information (Ctxt);
   end Filter_Matches_Primitive;

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   overriding function Filter_Matches_Primitive
     (Context : access Entity_Node_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean
   is
      pragma Unreferenced (Context);
   begin
      return Module_ID (Get_Creator (Ctxt)) = Explorer_Module_ID
        and then Has_Entity_Name_Information (Ctxt);
   end Filter_Matches_Primitive;

   ----------------------
   -- Set_Column_Types --
   ----------------------

   procedure Set_Column_Types (Tree : Gtk_Tree_View) is
      Col         : Gtk_Tree_View_Column;
      Text_Rend   : Gtk_Cell_Renderer_Text;
      Pixbuf_Rend : Gtk_Cell_Renderer_Pixbuf;
      Dummy       : Gint;
      pragma Unreferenced (Dummy);

   begin
      Gtk_New (Text_Rend);
      Gtk_New (Pixbuf_Rend);

      Set_Rules_Hint (Tree, False);

      Gtk_New (Col);
      Pack_Start (Col, Pixbuf_Rend, False);
      Pack_Start (Col, Text_Rend, True);
      Add_Attribute (Col, Pixbuf_Rend, "pixbuf", Icon_Column);
      Add_Attribute (Col, Text_Rend, "markup", Display_Name_Column);
      Dummy := Append_Column (Tree, Col);
   end Set_Column_Types;

   ------------------
   -- Button_Press --
   ------------------

   function Button_Press
     (Explorer : access GObject_Record'Class;
      Event    : Gdk_Event_Button) return Boolean
   is
      T : constant Project_Explorer := Project_Explorer (Explorer);
   begin
      --  If expanding/collapsing, don't handle  button clicks
      if T.Expanding then
         T.Expanding := False;
         return False;
      else
         return On_Button_Press
           (T.Kernel,
            MDI_Explorer_Child
              (Explorer_Views.Child_From_View (T)),
            T.Tree, T.Tree.Model, Event, Add_Dummy => False);
      end if;
   exception
      when E : others =>
         Trace (Me, E);
         return False;
   end Button_Press;

   ---------------
   -- Key_Press --
   ---------------

   function Key_Press
     (Explorer : access Gtk_Widget_Record'Class;
      Event    : Gdk_Event) return Boolean
   is
      T : constant Project_Explorer := Project_Explorer (Explorer);
   begin
      return On_Key_Press (T.Kernel, T.Tree, Event);
   exception
      when E : others =>
         Trace (Me, E);
         return False;
   end Key_Press;

   ------------------------
   -- Tree_Select_Row_Cb --
   ------------------------

   procedure Tree_Select_Row_Cb
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class; Args : GValues)
   is
      pragma Unreferenced (Args);
      T : constant Project_Explorer := Project_Explorer (Explorer);
   begin
      Context_Changed (T.Kernel);
   exception
      when E : others =>
         Trace (Me, E);
   end Tree_Select_Row_Cb;

   ----------------
   -- Initialize --
   ----------------

   function Initialize
     (Explorer : access Project_Explorer_Record'Class)
      return Gtk.Widget.Gtk_Widget
   is
      H1       : Refresh_Hook;
      H2       : Project_Hook;
      Tooltip  : Explorer_Tooltips_Access;
      Scrolled : Gtk_Scrolled_Window;
   begin
      Initialize_Vbox (Explorer, Homogeneous => False);

      Gtk_New (Scrolled);
      Scrolled.Set_Policy (Policy_Automatic, Policy_Automatic);
      Explorer.Pack_Start (Scrolled, Expand => True, Fill => True);

      Init_Graphics (Gtk_Widget (Explorer));
      Gtk_New (Explorer.Tree, Columns_Types, Filtered => True);
      Set_Headers_Visible (Explorer.Tree, False);
      Set_Column_Types (Gtk_Tree_View (Explorer.Tree));

      Set_Visible_Funcs.Set_Visible_Func
         (Explorer.Tree.Filter, Is_Visible'Access, Data => Explorer);

      Set_Name (Explorer.Tree, "Project Explorer Tree");  --  For testsuite

      Scrolled.Add (Explorer.Tree);

      Register_Contextual_Menu
        (Kernel          => Explorer.Kernel,
         Event_On_Widget => Explorer.Tree,
         Object          => Explorer,
         ID              => Explorer_Module_ID,
         Context_Func    => Explorer_Context_Factory'Access);

      --  The contents of the nodes is computed on demand. We need to be aware
      --  when the user has changed the visibility status of a node.

      Explorer.Expand_Id := Widget_Callback.Object_Connect
        (Explorer.Tree,
         Signal_Row_Expanded,
         Widget_Callback.To_Marshaller (Expand_Row_Cb'Access),
         Explorer);
      Widget_Callback.Object_Connect
        (Explorer.Tree,
         Signal_Row_Collapsed,
         Widget_Callback.To_Marshaller (Collapse_Row_Cb'Access),
         Explorer);

      Explorer.Tree.On_Button_Release_Event (Button_Press'Access, Explorer);
      Explorer.Tree.On_Button_Press_Event (Button_Press'Access, Explorer);

      Gtkada.Handlers.Return_Callback.Object_Connect
        (Explorer.Tree,
         Signal_Key_Press_Event,
         Gtkada.Handlers.Return_Callback.To_Marshaller (Key_Press'Access),
         Slot_Object => Explorer,
         After       => False);

      Widget_Callback.Object_Connect
        (Get_Selection (Explorer.Tree), Signal_Changed,
         Tree_Select_Row_Cb'Access, Explorer, After => True);

      --  Automatic update of the tree when the project changes
      H1 := new Refresh_Hook_Record'
        (Function_No_Args with Explorer => Project_Explorer (Explorer));
      Add_Hook
        (Explorer.Kernel, Project_View_Changed_Hook, H1,
         Name => "explorer.project_view_changed", Watch => GObject (Explorer));

      H2 := new Project_Changed_Hook_Record'
        (Function_No_Args with Explorer => Project_Explorer (Explorer));
      Add_Hook
        (Explorer.Kernel, Project_Changed_Hook, H2,
         Name => "explorer.project_changed", Watch => GObject (Explorer));

      --  The explorer (project view) is automatically refreshed when the
      --  project view is changed.

      Widget_Callback.Object_Connect
        (Get_MDI (Explorer.Kernel), Signal_Child_Selected,
         Child_Selected'Access, Explorer, After => True);

      Gtk.Dnd.Dest_Set
        (Explorer.Tree, Dest_Default_All, Target_Table_Url, Action_Any);
      Kernel_Callback.Connect
        (Explorer.Tree, Signal_Drag_Data_Received,
         Drag_Data_Received'Access, Explorer.Kernel);

      --  Sorting is now alphabetic: directories come first, then files. Use
      --  a custom sort function

      Set_Sort_Func
        (+Explorer.Tree.Model,
         Display_Name_Column,
         Sort_Func      => Sort_Func'Access);
      Set_Sort_Column_Id
        (+Explorer.Tree.Model, Display_Name_Column, Sort_Ascending);

      --  Initialize tooltips

      Tooltip := new Explorer_Tooltips;
      Tooltip.Explorer := Project_Explorer (Explorer);
      Tooltip.Set_Tooltip (Explorer.Tree);

      Refresh (Explorer);

      Add_Hook (Explorer.Kernel, Preference_Changed_Hook,
                Wrapper (Preferences_Changed'Access),
                Name => "project_Explorer.preferences_changed",
                Watch => GObject (Explorer));
      Preferences_Changed (Explorer.Kernel, null);

      return Gtk.Widget.Gtk_Widget (Explorer.Tree);
   end Initialize;

   ---------------
   -- Sort_Func --
   ---------------

   function Sort_Func
     (Model : Gtk_Tree_Model;
      A     : Gtk.Tree_Model.Gtk_Tree_Iter;
      B     : Gtk.Tree_Model.Gtk_Tree_Iter) return Gint
   is
      A_Before_B : Gint := -1;
      B_Before_A : Gint := 1;
      M          : constant Gtk_Tree_Store := -Model;
      A_Type     : constant Node_Types :=
                     Get_Node_Type (M, A);
      B_Type     : constant Node_Types :=
                     Get_Node_Type (M, B);
      Order      : Gtk_Sort_Type;
      Column     : Gint;

      function Alphabetical return Gint;
      --  Compare the two nodes alphabetically
      --  ??? Should take into account the sorting order

      ------------------
      -- Alphabetical --
      ------------------

      function Alphabetical return Gint is
         A_Name : constant String := To_Lower (Get_String (Model, A, Column));
         B_Name : constant String := To_Lower (Get_String (Model, B, Column));
      begin
         if A_Name < B_Name then
            return A_Before_B;
         elsif A_Name = B_Name then
            case A_Type is   --  same as B_Type
               when Project_Node_Types
                  | Directory_Node | Obj_Directory_Node
                  | Exec_Directory_Node | File_Node =>

                  if Get_File (Model, A, File_Column) <
                    Get_File (Model, B, File_Column)
                  then
                     return A_Before_B;
                  else
                     return B_Before_A;
                  end if;

               when others =>
                  return A_Before_B;
            end case;
         else
            return B_Before_A;
         end if;
      end Alphabetical;

   begin
      Get_Sort_Column_Id (M, Column, Order);
      if Order = Sort_Descending then
         A_Before_B := 1;
         B_Before_A := -1;
      end if;

      --  Subprojects first

      case A_Type is
         when Project_Node_Types =>
            case B_Type is
               when Project_Node_Types =>
                  return Alphabetical;

               when others =>
                  if Projects_Before_Directories then
                     return A_Before_B;
                  else
                     return B_Before_A;
                  end if;
            end case;

         when Directory_Node =>
            case B_Type is
               when Project_Node_Types =>
                  if Projects_Before_Directories then
                     return B_Before_A;
                  else
                     return A_Before_B;
                  end if;

               when Directory_Node =>
                  return Alphabetical;

               when others =>
                  return A_Before_B;
            end case;

         when Obj_Directory_Node =>
            case B_Type is
               when Project_Node_Types =>
                  if Projects_Before_Directories then
                     return B_Before_A;
                  else
                     return A_Before_B;
                  end if;

               when Directory_Node =>
                  return B_Before_A;

               when Obj_Directory_Node =>
                  return Alphabetical;

               when others =>
                  return B_Before_A;
            end case;

         when Exec_Directory_Node =>
            case B_Type is
               when Project_Node_Types =>
                  if Projects_Before_Directories then
                     return B_Before_A;
                  else
                     return A_Before_B;
                  end if;

               when Directory_Node | Obj_Directory_Node =>
                  return B_Before_A;

               when Exec_Directory_Node =>
                  return Alphabetical;

               when others =>
                  return B_Before_A;
            end case;

         when others =>
            if B_Type = A_Type then
               return Alphabetical;
            else
               return B_Before_A;
            end if;
      end case;
   end Sort_Func;

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class)
   is
      Explorer : constant Project_Explorer :=
        Explorer_Views.Retrieve_View (Kernel);
   begin
      if Explorer /= null then
         Set_Font_And_Colors
           (Explorer.Tree, Fixed_Font => True, Pref => Get_Pref (Data));
      end if;
   end Preferences_Changed;

   --------------------
   -- Child_Selected --
   --------------------

   procedure Child_Selected
     (Explorer : access Gtk_Widget_Record'Class; Args : GValues)
   is
      E     : constant Project_Explorer := Project_Explorer (Explorer);
      Child : constant MDI_Child := MDI_Child (To_Object (Args, 1));
      Model : Gtk_Tree_Model;
      Node  : Gtk_Tree_Iter;
      Iter  : Gtk_Tree_Iter;
   begin
      Get_Selected (Get_Selection (E.Tree), Model, Node);

      if Node = Null_Iter then
         return;
      end if;

      E.Tree.Convert_To_Store_Iter (Store_Iter => Iter, Filter_Iter => Node);

      if Child = null
        or else (Get_Title (Child) = " ")
        or else (Get_Title (Child) =
                   Display_Full_Name (Get_File_From_Node (E.Tree.Model, Iter)))
      then
         return;
      end if;

      if not (Get_Widget (Child).all in Project_Explorer_Record'Class) then
         Unselect_All (Get_Selection (E.Tree));
      end if;
   end Child_Selected;

   --------------------
   -- Create_Toolbar --
   --------------------

   overriding procedure Create_Toolbar
     (View    : not null access Project_Explorer_Record;
      Toolbar : not null access Gtk.Toolbar.Gtk_Toolbar_Record'Class)
   is
   begin
      View.Build_Filter
        (Toolbar     => Toolbar,
         Hist_Prefix => "project_view",
         Tooltip     => -"Filter the contents of the project view",
         Placeholder => -"filter",
         Options     =>
           Has_Regexp or Has_Negate or Has_Whole_Word or Has_Fuzzy);
   end Create_Toolbar;

   -----------------
   -- Create_Menu --
   -----------------

   overriding procedure Create_Menu
     (View    : not null access Project_Explorer_Record;
      Menu    : not null access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      Check : Gtk_Check_Menu_Item;
   begin
      Gtk_New (Check, -"Show absolute paths");
      Associate (Get_History (View.Kernel).all, Show_Absolute_Paths, Check);
      Widget_Callback.Object_Connect
        (Check, Gtk.Check_Menu_Item.Signal_Toggled,
         Update_Absolute_Paths'Access, View);
      Menu.Add (Check);

      Gtk_New (Check, -"Show flat view");
      Associate (Get_History (View.Kernel).all, Show_Flat_View, Check);
      Widget_Callback.Object_Connect
        (Check, Gtk.Check_Menu_Item.Signal_Toggled,
         Update_View'Access, View);
      Menu.Add (Check);

      Gtk_New (Check, -"Show hidden directories");
      Associate (Get_History (View.Kernel).all, Show_Hidden_Dirs, Check);
      Widget_Callback.Object_Connect
        (Check, Gtk.Check_Menu_Item.Signal_Toggled, Update_View'Access, View);
      Menu.Add (Check);

      Gtk_New (Check, -"Show empty directories");
      Associate (Get_History (View.Kernel).all, Show_Empty_Dirs, Check);
      Widget_Callback.Object_Connect
        (Check, Gtk.Check_Menu_Item.Signal_Toggled, Update_View'Access, View);
      Menu.Add (Check);
   end Create_Menu;

   ----------------
   -- Is_Visible --
   ----------------

   function Is_Visible
     (Child_Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter        : Gtk.Tree_Model.Gtk_Tree_Iter;
      Self        : Project_Explorer) return Boolean
   is
      File   : Virtual_File;
   begin
      case Get_Node_Type (-Child_Model, Iter) is
         when Project_Node_Types | Directory_Node_Types | File_Node =>
            File := Get_File_From_Node (-Child_Model, Iter);
            return Is_Visible (Self.Filter, File) /= Hide;

         when Category_Node | Entity_Node | Dummy_Node =>
            return True;
      end case;
   end Is_Visible;

   ----------------
   -- Is_Visible --
   ----------------

   function Is_Visible
     (Self : Explorer_Filter; File : Virtual_File) return Filter_Type
   is
      C : Filter_Maps.Cursor;
   begin
      if Self.Pattern = null then
         return Show_Direct;
      end if;

      C := Self.Cache.Find (File);
      if Has_Element (C) then
         return Element (C);
      end if;
      return Hide;
   end Is_Visible;

   -----------------
   -- Set_Pattern --
   -----------------

   procedure Set_Pattern
     (Self    : in out Explorer_Filter;
      Kernel  : not null access Kernel_Handle_Record'Class;
      Pattern : Search_Pattern_Access)
   is
      Show_Abs_Paths : constant Boolean :=
        Get_History (Get_History (Kernel).all, Show_Absolute_Paths);
      Flat_View : constant Boolean :=
        Get_History (Get_History (Kernel).all, Show_Flat_View);

      procedure Mark_Project_And_Parents_Visible (P : Project_Type);
      --  mark the given project node and all its parents as visible

      procedure Mark_Project_And_Parents_Visible (P : Project_Type) is
         It : Project_Iterator;
         C  : Filter_Maps.Cursor;
      begin
         C := Self.Cache.Find (P.Project_Path);
         if Has_Element (C) and then Element (C) /= Hide then
            --  Already marked, nothing more to do
            return;
         end if;

         Self.Cache.Include (P.Project_Path, Show_Indirect);

         if not Flat_View then
            It := P.Find_All_Projects_Importing
              (Include_Self => False, Direct_Only => False);
            while Current (It) /= No_Project loop
               Mark_Project_And_Parents_Visible (Current (It));
               Next (It);
            end loop;
         end if;
      end Mark_Project_And_Parents_Visible;

      PIter : Project_Iterator;
      P     : Project_Type;
      Files : File_Array_Access;
      Found : Boolean;
      Prj_Filter : Filter_Type;
   begin
      GPS.Search.Free (Self.Pattern);
      Self.Pattern := Pattern;

      Self.Cache.Clear;

      if Pattern = null then
         --  No filter applied, make all visible
         return;
      end if;

      PIter := Get_Project (Kernel).Start
        (Direct_Only      => False,
         Include_Extended => True);
      while Current (PIter) /= No_Project loop
         P := Current (PIter);

         if Self.Pattern.Start (P.Name) /= GPS.Search.No_Match then
            Prj_Filter := Show_Direct;
            Mark_Project_And_Parents_Visible (P);
            Self.Cache.Include (P.Project_Path, Show_Direct);
         else
            Prj_Filter := Hide;
         end if;

         Files := P.Source_Files (Recursive => False);
         for F in Files'Range loop
            Found :=
              (Show_Abs_Paths and then Self.Pattern.Start
                 (Files (F).Display_Full_Name) /= GPS.Search.No_Match)
              or else
              (not Show_Abs_Paths and then Self.Pattern.Start
                 (Files (F).Display_Base_Name) /= GPS.Search.No_Match);

            if Found then
               if Prj_Filter = Hide then
                  Prj_Filter := Show_Indirect;
                  Mark_Project_And_Parents_Visible (P);
               end if;

               Self.Cache.Include (Create (Files (F).Dir_Name), Show_Indirect);
               Self.Cache.Include (Files (F), Show_Direct);
            end if;
         end loop;
         Unchecked_Free (Files);

         Next (PIter);
      end loop;
   end Set_Pattern;

   --------------------
   -- Filter_Changed --
   --------------------

   overriding procedure Filter_Changed
     (Self    : not null access Project_Explorer_Record;
      Pattern : in out GPS.Search.Search_Pattern_Access) is
   begin
      Set_Pattern (Self.Filter, Self.Kernel, Pattern);
      Self.Tree.Filter.Refilter;
   end Filter_Changed;

   ------------------------------
   -- Explorer_Context_Factory --
   ------------------------------

   procedure Explorer_Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu)
   is
      pragma Unreferenced (Event_Widget, Object, Menu);

      --  "Object" is also the explorer, but this way we make sure the current
      --  context is that of the explorer (since it will have the MDI focus)
      T         : constant Project_Explorer :=
        Explorer_Views.Get_Or_Create_View (Kernel, Focus => True);
      Filter_Iter      : constant Gtk_Tree_Iter :=
                    Find_Iter_For_Event (T.Tree, Event);
      Iter        : Gtk_Tree_Iter;
      Filter_Path : Gtk_Tree_Path;
   begin
      if Filter_Iter = Null_Iter then
         return;
      end if;

      Filter_Path := Get_Path (T.Tree.Get_Model, Filter_Iter);
      if not Path_Is_Selected (Get_Selection (T.Tree), Filter_Path) then
         Set_Cursor (T.Tree, Filter_Path, null, False);
      end if;
      Path_Free (Filter_Path);

      T.Tree.Convert_To_Store_Iter
        (Store_Iter => Iter, Filter_Iter => Filter_Iter);
      Project_Explorers_Common.Context_Factory
        (Context, Kernel_Handle (Kernel), T.Tree.Model, Iter);
   end Explorer_Context_Factory;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Hook   : Project_Changed_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class)
   is
      pragma Unreferenced (Kernel);
   begin
      --  Destroy all the items in the tree.
      --  The next call to refresh via the "project_view_changed" signal will
      --  completely restore the tree.

      Clear (Hook.Explorer.Tree.Model);
   end Execute;

   -------------
   -- Execute --
   -------------

   overriding function Execute
     (Self    : access Toggle_Absolute_Path_Command;
      Context : Commands.Interactive.Interactive_Command_Context)
      return Commands.Command_Return_Type
   is
      pragma Unreferenced (Self);
      K : constant Kernel_Handle := Get_Kernel (Context.Context);
      H : constant Histories.History := Get_History (K);
      V : constant Project_Explorer := Explorer_Views.Retrieve_View (K);
   begin
      Set_History
        (H.all, Show_Absolute_Paths,
         not Get_History (H.all, Show_Absolute_Paths));
      Update_Absolute_Paths (V);
      return Commands.Success;
   end Execute;

   ---------------------------
   -- Update_Absolute_Paths --
   ---------------------------

   procedure Update_Absolute_Paths
     (Explorer : access Gtk_Widget_Record'Class)
   is
      Exp : constant Project_Explorer := Project_Explorer (Explorer);
      Show_Abs_Paths : constant Boolean :=
         Get_History (Get_History (Exp.Kernel).all, Show_Absolute_Paths);

      procedure Process_Node (Iter : Gtk_Tree_Iter; Project : Project_Type);
      --  Recursively process node

      ------------------
      -- Process_Node --
      ------------------

      procedure Process_Node (Iter : Gtk_Tree_Iter; Project : Project_Type) is
         It   : Gtk_Tree_Iter := Children (Exp.Tree.Model, Iter);
         Prj  : Project_Type := Project;
      begin
         case Get_Node_Type (Exp.Tree.Model, Iter) is
            when Project_Node_Types =>
               Prj := Get_Project_From_Node
                 (Exp.Tree.Model, Exp.Kernel, Iter, False);

            when Directory_Node_Types
               | File_Node | Category_Node | Entity_Node | Dummy_Node =>
               null;
         end case;

         while It /= Null_Iter loop
            case Get_Node_Type (Exp.Tree.Model, It) is
               when Project_Node_Types =>
                  Process_Node (It, No_Project);

               when Directory_Node_Types =>
                  Set (Exp.Tree.Model, It, Display_Name_Column,
                       Directory_Node_Text
                          (Show_Abs_Paths, Prj,
                           Get_File (Exp.Tree.Model, It, File_Column)));

               when others =>
                  null;
            end case;

            Next (Exp.Tree.Model, It);
         end loop;
      end Process_Node;

      Iter : Gtk_Tree_Iter := Get_Iter_First (Exp.Tree.Model);
      Sort : constant Gint := Freeze_Sort (Exp.Tree.Model);
   begin
      while Iter /= Null_Iter loop
         Process_Node (Iter, Get_Project (Exp.Kernel));
         Next (Exp.Tree.Model, Iter);
      end loop;

      Thaw_Sort (Exp.Tree.Model, Sort);
   end Update_Absolute_Paths;

   -----------------
   -- Update_View --
   -----------------

   procedure Update_View
     (Explorer : access Gtk_Widget_Record'Class)
   is
      Tree : constant Project_Explorer := Project_Explorer (Explorer);
   begin
      Tree.Tree.Model.Clear;
      Refresh (Explorer);
   end Update_View;

   ---------------------
   -- Create_Contents --
   ---------------------

   overriding function Create_Contents
     (Tooltip  : not null access Explorer_Tooltips;
      Widget   : not null access Gtk.Widget.Gtk_Widget_Record'Class;
      X, Y     : Glib.Gint) return Gtk.Widget.Gtk_Widget
   is
      pragma Unreferenced (Widget);

      Path       : Gtk_Tree_Path;
      Column     : Gtk_Tree_View_Column;
      Cell_X,
      Cell_Y     : Gint;
      Row_Found  : Boolean := False;
      Par, Iter  : Gtk_Tree_Iter;
      Node_Type  : Node_Types;
      File       : Virtual_File;
      Area       : Gdk_Rectangle;
      Label      : Gtk_Label;
   begin
      Get_Path_At_Pos
        (Tooltip.Explorer.Tree, X, Y, Path,
         Column, Cell_X, Cell_Y, Row_Found);

      if not Row_Found then
         return null;

      else
         --  Now check that the cursor is over a text

         Iter := Get_Iter (Tooltip.Explorer.Tree.Model, Path);
         if Iter = Null_Iter then
            return null;
         end if;
      end if;

      Get_Cell_Area (Tooltip.Explorer.Tree, Path, Column, Area);
      Path_Free (Path);

      Tooltip.Set_Tip_Area (Area);

      Node_Type := Get_Node_Type (Tooltip.Explorer.Tree.Model, Iter);

      case Node_Type is
         when Project_Node_Types =>
            --  Project or extended project full pathname
            File := Get_File (Tooltip.Explorer.Tree.Model, Iter, File_Column);
            Gtk_New (Label, File.Display_Full_Name);

         when Directory_Node_Types =>
            --  Directroy full pathname and project name
            --  Get parent node which is the project name
            Par := Parent (Tooltip.Explorer.Tree.Model, Iter);

            File := Get_File (Tooltip.Explorer.Tree.Model, Iter, File_Column);
            Gtk_New
              (Label, File.Display_Full_Name
               & ASCII.LF &
               (-"in project ") &
               Get_String
                 (Tooltip.Explorer.Tree.Model, Par, Display_Name_Column));

         when File_Node =>
            --  Base filename and Project name
            --  Get grand-parent node which is the project node
            Par := Parent
              (Tooltip.Explorer.Tree.Model,
               Parent (Tooltip.Explorer.Tree.Model, Iter));
            Gtk_New
              (Label, Get_String
                 (Tooltip.Explorer.Tree.Model, Iter,
                  Display_Name_Column)
               & ASCII.LF &
               (-"in project ") &
               Get_String
                 (Tooltip.Explorer.Tree.Model, Par, Display_Name_Column));

         when Entity_Node =>
            --  Entity (parameters) declared at Filename:line
            --  Get grand-parent node which is the filename node
            Par := Parent
              (Tooltip.Explorer.Tree.Model,
               Parent (Tooltip.Explorer.Tree.Model, Iter));

            Gtk_New (Label);
            Label.Set_Markup
              (Get_String
                 (Tooltip.Explorer.Tree.Model, Iter, Display_Name_Column)
               & ASCII.LF &
               (-"declared at ") &
               Get_String (Tooltip.Explorer.Tree.Model, Par,
                 Display_Name_Column)
               & ':' &
               Image (Integer
                 (Get_Int (Tooltip.Explorer.Tree.Model, Iter, Line_Column))));

         when others =>
            null;
      end case;

      return Gtk_Widget (Label);
   end Create_Contents;

   -------------------
   -- Expand_Row_Cb --
   -------------------

   procedure Expand_Row_Cb
     (Explorer    : access Gtk.Widget.Gtk_Widget_Record'Class;
      Filter_Iter : Gtk_Tree_Iter;
      Filter_Path : Gtk_Tree_Path)
   is
      T         : constant Project_Explorer := Project_Explorer (Explorer);
      Iter      : Gtk_Tree_Iter;
      Success   : Boolean;
      Dummy     : G_Source_Id;
      Sort_Col  : Gint;
      N_Type    : Node_Types;
      pragma Unreferenced (Success, Dummy);
   begin
      if T.Expanding or else Filter_Iter = Null_Iter then
         return;
      end if;

      T.Expanding := True;
      T.Tree.Convert_To_Store_Iter
        (Store_Iter => Iter, Filter_Iter => Filter_Iter);
      N_Type := Get_Node_Type (T.Tree.Model, Iter);
      Set_Node_Type (T.Tree.Model, Iter, N_Type, Expanded => True);

      Sort_Col := Freeze_Sort (T.Tree.Model);

      case N_Type is
         when Project_Node_Types =>
            Refresh_Project_Node
              (T, Iter,
               Flat_View =>
                  Get_History (Get_History (T.Kernel).all, Show_Flat_View));
            Success := Expand_Row (T.Tree, Filter_Path, False);

         when File_Node =>
            Append_File_Info
              (T.Kernel, T.Tree.Model, Iter,
               Get_File_From_Node (T.Tree.Model, Iter), Sorted => False);
            Success := Expand_Row (T.Tree, Filter_Path, False);

         when Directory_Node_Types | Category_Node | Entity_Node
            | Dummy_Node =>
            null;   --  nothing to do
      end case;

      Thaw_Sort (T.Tree.Model, Sort_Col);
      T.Expanding := False;

   exception
      when E : others =>
         Trace (Me, E);
         Thaw_Sort (T.Tree.Model, Sort_Col);
         T.Expanding := False;
   end Expand_Row_Cb;

   ---------------------
   -- Collapse_Row_Cb --
   ---------------------

   procedure Collapse_Row_Cb
     (Explorer    : access Gtk.Widget.Gtk_Widget_Record'Class;
      Filter_Iter : Gtk_Tree_Iter;
      Filter_Path : Gtk_Tree_Path)
   is
      pragma Unreferenced (Filter_Path);
      E : constant Project_Explorer := Project_Explorer (Explorer);
      Iter : Gtk_Tree_Iter;
   begin
      E.Tree.Convert_To_Store_Iter
         (Store_Iter => Iter, Filter_Iter => Filter_Iter);
      Set_Node_Type   --  update the icon
        (E.Tree.Model,
         Iter,
         Get_Node_Type (E.Tree.Model, Iter),
         Expanded => False);
   end Collapse_Row_Cb;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Hook   : Refresh_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class)
   is
      pragma Unreferenced (Kernel);
   begin
      Refresh (Hook.Explorer);
   end Execute;

   -------------------------
   -- Directory_Node_Text --
   -------------------------

   function Directory_Node_Text
     (Show_Abs_Paths : Boolean;
      Project        : Project_Type;
      Dir            : Virtual_File) return String
   is
   begin
      if Show_Abs_Paths then
         return Dir.Display_Full_Name;
      else
         declare
            Rel : constant String :=
               +Relative_Path (Dir, Project.Project_Path.Dir);
         begin
            if Rel = "" then
               return "";
            elsif Rel (Rel'Last) = '/' or else Rel (Rel'Last) = '\' then
               return Rel (Rel'First .. Rel'Last - 1);
            else
               return Rel;
            end if;
         end;
      end if;
   end Directory_Node_Text;

   -------------
   -- Refresh --
   -------------

   procedure Refresh (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class) is
      T     : constant Project_Explorer := Project_Explorer (Explorer);
      Path_Start, Path_End : Gtk_Tree_Path;
      Success : Boolean;
      Id      : Gint;

   begin
      if Get_Project (T.Kernel) = No_Project then
         T.Tree.Model.Clear;
         return;
      end if;

      T.Tree.Filter.Ref;

      --  Store current settings (visible part, sort order,...)
      Id := Freeze_Sort (T.Tree.Model);
      T.Tree.Get_Visible_Range (Path_Start, Path_End, Success);

      --  Insert the nodes
      Refresh_Project_Node
        (Self      => T,
         Node      => Null_Iter,
         Flat_View =>
          Get_History (Get_History (T.Kernel).all, Show_Flat_View));

      --  Restore initial settings

      if Success then
         T.Tree.Scroll_To_Cell
           (Path      => Path_Start,
            Column    => null,
            Use_Align => True,
            Row_Align => 0.0,
            Col_Align => 0.0);
         Path_Free (Path_Start);
         Path_Free (Path_End);
      end if;

      Thaw_Sort (T.Tree.Model, Id);
      T.Tree.Filter.Unref;
   end Refresh;

   --------------------------
   -- Refresh_Project_Node --
   --------------------------

   procedure Refresh_Project_Node
     (Self      : not null access Project_Explorer_Record'Class;
      Node      : Gtk_Tree_Iter;
      Flat_View : Boolean)
   is
      function Create_Or_Reuse_Node
        (Self   : not null access Project_Explorer_Record'Class;
         Parent : Gtk_Tree_Iter;
         Kind   : Node_Types;
         Name   : String;
         File   : Virtual_File;
         Add_Dummy : Boolean := False) return Gtk_Tree_Iter;
      --  Check if Parent already has a child with the correct kind and name,
      --  and returns it. If not, creates a new node, where Name is set for the
      --  Display_Name_Column.
      --  If Add_Dummy is true and a new node is created, a dummy child is
      --  added to it so that the user can expand the node.

      function Create_Or_Reuse_Project
        (P : Project_Type; Add_Dummy : Boolean := False) return Gtk_Tree_Iter;
      function Create_Or_Reuse_Directory
        (Dir : Directory_Info) return Gtk_Tree_Iter;
      procedure Create_Or_Reuse_File
        (Dir : Gtk_Tree_Iter; File : Virtual_File);
      --  Create a new project node, or reuse one if it exists

      function Is_Hidden (Dir : Virtual_File) return Boolean;
      --  Return true if Dir contains an hidden directory (a directory starting
      --  with a dot).

      Show_Abs_Paths : constant Boolean :=
        Get_History (Get_History (Self.Kernel).all, Show_Absolute_Paths);

      Child   : Gtk_Tree_Iter;
      Files   : File_Array_Access;
      Project : Project_Type;
      Dirs    : Dirs_Files_Hash.Map;

      ---------------
      -- Is_Hidden --
      ---------------

      function Is_Hidden (Dir : Virtual_File) return Boolean is
         Root : constant Virtual_File := Get_Root (Dir);
         D    : Virtual_File := Dir;
      begin
         while D /= GNATCOLL.VFS.No_File
           and then D /= Root
         loop
            if Is_Hidden (Self.Kernel, D.Base_Dir_Name) then
               return True;
            end if;

            D := D.Get_Parent;
         end loop;

         return False;
      end Is_Hidden;

      --------------------------
      -- Create_Or_Reuse_Node --
      --------------------------

      function Create_Or_Reuse_Node
        (Self   : not null access Project_Explorer_Record'Class;
         Parent : Gtk_Tree_Iter;
         Kind   : Node_Types;
         Name   : String;
         File   : Virtual_File;
         Add_Dummy : Boolean := False) return Gtk_Tree_Iter
      is
         Iter : Gtk_Tree_Iter := Null_Iter;
      begin
         if Parent = Null_Iter then
            Iter := Self.Tree.Model.Get_Iter_First;
         else
            Iter := Self.Tree.Model.Children (Parent);
         end if;

         while Iter /= Null_Iter loop
            if Get_Node_Type (Self.Tree.Model, Iter) = Kind
              and then Get_File (Self.Tree.Model, Iter, File_Column) = File
            then
               return Iter;
            end if;
            Self.Tree.Model.Next (Iter);
         end loop;

         Self.Tree.Model.Append (Iter => Iter, Parent => Parent);
         Self.Tree.Model.Set (Iter, Display_Name_Column, Name);
         Set_File (Self.Tree.Model, Iter, File_Column, File);
         Set_Node_Type (Self.Tree.Model, Iter, Kind, False);

         if Add_Dummy then
            Append_Dummy_Iter (Self.Tree.Model, Iter);
         end if;

         return Iter;
      end Create_Or_Reuse_Node;

      -----------------------------
      -- Create_Or_Reuse_Project --
      -----------------------------

      function Create_Or_Reuse_Project
        (P : Project_Type; Add_Dummy : Boolean := False) return Gtk_Tree_Iter
      is
         T : constant Node_Types := Compute_Project_Node_Type (Self, P);
      begin
         if Flat_View and then P = Get_Project (Self.Kernel) then
            Child := Create_Or_Reuse_Node
              (Self   => Self,
               Parent => Node,
               Kind   => T,
               File   => P.Project_Path,
               Name   => P.Name & " (root project)",
               Add_Dummy => Add_Dummy);
         elsif P.Extending_Project /= No_Project then
            Child := Create_Or_Reuse_Node
              (Self   => Self,
               Parent => Node,
               Kind   => T,
               File   => P.Project_Path,
               Name   => P.Name & " (extended)",
               Add_Dummy => Add_Dummy);
         else
            Child := Create_Or_Reuse_Node
              (Self   => Self,
               Parent => Node,
               Kind   => T,
               File   => P.Project_Path,
               Name   => P.Name,
               Add_Dummy => Add_Dummy);
         end if;

         Set_File (Self.Tree.Model, Child, File_Column, P.Project_Path);
         return Child;
      end Create_Or_Reuse_Project;

      -------------------------------
      -- Create_Or_Reuse_Directory --
      -------------------------------

      function Create_Or_Reuse_Directory
        (Dir : Directory_Info) return Gtk_Tree_Iter is
      begin
         return Create_Or_Reuse_Node
           (Self   => Self,
            Parent => Node,
            Kind   => Dir.Kind,
            File   => Dir.Directory,
            Name   =>
              Directory_Node_Text (Show_Abs_Paths, Project, Dir.Directory));
      end Create_Or_Reuse_Directory;

      --------------------------
      -- Create_Or_Reuse_File --
      --------------------------

      procedure Create_Or_Reuse_File
        (Dir : Gtk_Tree_Iter; File : Virtual_File)
      is
         Child : Gtk_Tree_Iter;
         Lang : Language_Access;
      begin
         Child := Create_Or_Reuse_Node
           (Self   => Self,
            Parent => Dir,
            Kind   => File_Node,
            File   => File,
            Name   => File.Display_Base_Name);

         Lang := Get_Language_From_File
           (Get_Language_Handler (Self.Kernel), File);
         if Lang /= Unknown_Lang then
            Append_Dummy_Iter (Self.Tree.Model, Child);
         end if;
      end Create_Or_Reuse_File;

      Filter  : Filter_Type;
      Path    : Gtk_Tree_Path;
      Success : Boolean;
      pragma Unreferenced (Success);

   begin
      if Node = Null_Iter then
         if Flat_View then
            declare
               Iter : Project_Iterator := Get_Project (Self.Kernel).Start
                 (Direct_Only => False,
                  Include_Extended => True);
            begin
               while Current (Iter) /= No_Project loop
                  Filter := Is_Visible
                    (Self.Filter, Current (Iter).Project_Path);

                  if Filter = Show_Direct then
                     Child := Create_Or_Reuse_Project (Current (Iter));
                     Refresh_Project_Node (Self, Child, Flat_View);
                  end if;

                  Next (Iter);
               end loop;
            end;
         else
            --  Create and expand the node for the root project
            Child := Create_Or_Reuse_Project
              (Get_Project (Self.Kernel), Add_Dummy => True);

            --  This only works if the tree is still associated with the model
            Path := Gtk_Tree_Path_New_First;
            Success := Expand_Row (Self.Tree, Path, False);
            Path_Free (Path);
         end if;
         return;
      end if;

      Project := Get_Project_From_Node
        (Self.Tree.Model, Self.Kernel, Node, Importing => False);
      Remove_Dummy_Iter (Self.Tree.Model, Node);

      --  Insert non-expanded nodes for imported projects

      if not Flat_View then
         declare
            Iter : Project_Iterator := Project.Start
              (Direct_Only => True, Include_Extended => True);
         begin
            while Current (Iter) /= No_Project loop
               if Current (Iter) /= Project then
                  Filter := Is_Visible
                    (Self.Filter, Current (Iter).Project_Path);

                  if Filter /= Hide then
                     Child := Create_Or_Reuse_Project
                       (Current (Iter), Add_Dummy => True);
                  end if;
               end if;

               Next (Iter);
            end loop;
         end;
      end if;

      --  Prepare list of directories

      for Dir of Project.Source_Dirs loop
         Dirs.Include ((Dir, Directory_Node), Files_List.Empty_List);
      end loop;

      Dirs.Include
        ((Project.Object_Dir, Obj_Directory_Node), Files_List.Empty_List);

      if Project.Executables_Directory /= Project.Object_Dir then
         Dirs.Include
           ((Project.Executables_Directory, Exec_Directory_Node),
            Files_List.Empty_List);
      end if;

      --  Prepare list of files

      Files := Project.Source_Files (Recursive => False);
      for F in Files'Range loop
         Dirs ((Files (F).Dir, Directory_Node)).Append (Files (F));
      end loop;
      Unchecked_Free (Files);

      --  Now insert directories and files

      declare
         Dir : Dirs_Files_Hash.Cursor := Dirs.First;
         Show_Hidden : constant Boolean :=
           Get_History (Get_History (Self.Kernel).all, Show_Hidden_Dirs);
      begin
         while Has_Element (Dir) loop
            if Show_Hidden or else not Is_Hidden (Key (Dir).Directory) then
               Child := Create_Or_Reuse_Directory (Key (Dir));

               for F of Dirs (Dir) loop
                  --  ??? This is O(n^2), since every time we insert a row
                  --  it will be searched next time.
                  Create_Or_Reuse_File (Child, F);
               end loop;
            end if;

            Next (Dir);
         end loop;
      end;
   end Refresh_Project_Node;

   -----------------------------
   -- Default_Context_Factory --
   -----------------------------

   overriding procedure Default_Context_Factory
     (Module  : access Explorer_Module_Record;
      Context : in out Selection_Context;
      Child   : Glib.Object.GObject) is
   begin
      Explorer_Context_Factory
        (Context, Get_Kernel (Module.all),
         Gtk_Widget (Child), Child, null, null);
   end Default_Context_Factory;

   ----------
   -- Free --
   ----------

   overriding procedure Free (Context : in out Explorer_Search_Context) is
   begin
      Reset (Context.Matches);
   end Free;

   -----------------------------
   -- Explorer_Search_Factory --
   -----------------------------

   function Explorer_Search_Factory
     (Kernel            : access GPS.Kernel.Kernel_Handle_Record'Class;
      All_Occurences    : Boolean;
      Extra_Information : Gtk.Widget.Gtk_Widget)
      return Root_Search_Context_Access
   is
      pragma Unreferenced (Kernel, All_Occurences);
      Context : Explorer_Search_Context_Access;

   begin
      Assert (Me, Extra_Information /= null,
              "No extra information widget specified");

      Context := new Explorer_Search_Context;

      Context.Include_Projects := Get_Active
        (Explorer_Search_Extra (Extra_Information).Include_Projects);
      Context.Include_Directories := Get_Active
        (Explorer_Search_Extra (Extra_Information).Include_Directories);
      Context.Include_Files := Get_Active
        (Explorer_Search_Extra (Extra_Information).Include_Files);
      Context.Include_Entities := Get_Active
        (Explorer_Search_Extra (Extra_Information).Include_Entities);

      --  If we have no context, nothing to do
      if not (Context.Include_Projects
              or else Context.Include_Directories
              or else Context.Include_Files
              or else Context.Include_Entities)
      then
         Free (Root_Search_Context_Access (Context));
         return null;
      end if;

      Reset (Context.Matches);
      return Root_Search_Context_Access (Context);
   end Explorer_Search_Factory;

   -----------------------------
   -- Explorer_Search_Factory --
   -----------------------------

   function Explorer_Search_Factory
     (Kernel           : access GPS.Kernel.Kernel_Handle_Record'Class;
      Include_Projects : Boolean;
      Include_Files    : Boolean)
      return Root_Search_Context_Access
   is
      pragma Unreferenced (Kernel);
      Context : Explorer_Search_Context_Access;

   begin
      Context := new Explorer_Search_Context;

      Context.Include_Projects    := Include_Projects;
      Context.Include_Directories := False;
      Context.Include_Files       := Include_Files;
      Context.Include_Entities    := False;

      Reset (Context.Matches);
      return Root_Search_Context_Access (Context);
   end Explorer_Search_Factory;

   ------------
   -- Search --
   ------------

   overriding procedure Search
     (Context         : access Explorer_Search_Context;
      Kernel          : access GPS.Kernel.Kernel_Handle_Record'Class;
      Search_Backward : Boolean;
      Give_Focus      : Boolean;
      Found           : out Boolean;
      Continue        : out Boolean)
   is
      pragma Unreferenced (Search_Backward, Give_Focus, Continue);

      C        : constant Explorer_Search_Context_Access :=
                   Explorer_Search_Context_Access (Context);
      Explorer : constant Project_Explorer :=
        Explorer_Views.Get_Or_Create_View (Kernel, Focus => True);

      Full_Name_For_Dirs : constant Boolean := Get_History
        (Get_History (Explorer.Kernel).all, Show_Absolute_Paths);
      --  Use full name of directory in search

      function Directory_Name (Dir : Virtual_File) return String;
      --  Return directory name for search.
      --  It returns Base_Name or Full_Name depending on Full_Name_For_Dirs

      procedure Initialize_Parser;
      --  Compute all the matching files and mark them in the htable

      function Next return Gtk_Tree_Iter;
      --  Return the next matching node

      procedure Next_Or_Child
        (Name           : String;
         Key            : String;
         Start          : Gtk_Tree_Iter;
         Check_Match    : Boolean;
         Check_Projects : Boolean;
         Result         : out Gtk_Tree_Iter;
         Finish         : out Boolean);
      pragma Inline (Next_Or_Child);
      --  Move to the next node, starting from a project or directory node by
      --  name Name and key Key.
      --  Key may differ from Name for directories, where Key is Full_Name,
      --  but Name could be Base_Name.
      --  If Check_Match is false, then this subprogram doesn't test if the
      --  node's Name matches context.
      --  If Check_Projects is true, then this subprogram maintain set of
      --  projects and process children nodes only for first occurrence of the
      --  project.

      procedure Next_File_Node
        (Start  : Gtk_Tree_Iter;
         Result : out Gtk_Tree_Iter;
         Finish : out Boolean);
      pragma Inline (Next_File_Node);
      --  Move to the next node, starting from a file node

      function Check_Entities (File : Virtual_File) return Boolean;
      pragma Inline (Check_Entities);
      --  Check if File contains any entity matching C.
      --  Return True if there is a match.

      procedure Mark_File_And_Projects
        (File           : Virtual_File;
         Project_Marked : Boolean;
         Project        : Project_Type;
         Mark_File      : Search_Status;
         Increment      : Search_Status);
      pragma Inline (Mark_File_And_Projects);
      --  Mark the file Full_Name/Base as matching, as well as the project it
      --  belongs to and all its importing projects.
      --  Increment is added to the reference count for all directories and
      --  importing projects (should be 1 if the file is added, -1 if the file
      --  is removed)

      --------------------
      -- Directory_Name --
      --------------------

      function Directory_Name (Dir : Virtual_File) return String is
      begin
         if Full_Name_For_Dirs then
            return Dir.Display_Full_Name;
         else
            return +Dir.Base_Dir_Name;
         end if;
      end Directory_Name;

      -------------------
      -- Next_Or_Child --
      -------------------

      procedure Next_Or_Child
        (Name           : String;
         Key            : String;
         Start          : Gtk_Tree_Iter;
         Check_Match    : Boolean;
         Check_Projects : Boolean;
         Result         : out Gtk_Tree_Iter;
         Finish         : out Boolean) is
      begin
         Finish := False;

         if Check_Match
           and then Start /= C.Current
           and then not GPS.Search.Failed (Match (C, Name))
         then
            Result := Start;
            Finish := True;

         elsif Get (C.Matches, Key) /= No_Match then
            if Check_Projects then
               declare
                  Project_Name : constant Virtual_File :=
                    Get_File (Explorer.Tree.Model, Start, File_Column);
               begin
                  if Projects.Contains (Project_Name) then
                     Result := Start;
                     Explorer.Tree.Model.Next (Result);

                  else
                     Projects.Insert (Project_Name);
                     Result := Children (Explorer.Tree.Model, Start);
                  end if;
               end;

            else
               Result := Children (Explorer.Tree.Model, Start);
            end if;

         else
            Result := Start;
            Next (Explorer.Tree.Model, Result);
         end if;
      end Next_Or_Child;

      --------------------
      -- Next_File_Node --
      --------------------

      procedure Next_File_Node
        (Start  : Gtk_Tree_Iter;
         Result : out Gtk_Tree_Iter;
         Finish : out Boolean)
      is
         N      : aliased constant Filesystem_String :=
                    Get_Base_Name (Explorer.Tree.Model, Start);
         Status : Search_Status;
      begin
         Status := Get (C.Matches, +N);
         if C.Include_Entities then
            --  The file was already parsed, and we know it matched
            if Status >= Search_Match then
               Result := Children (Explorer.Tree.Model, Start);
               Finish := False;
               return;

            --  The file was never parsed
            elsif Status = Unknown then
               if Check_Entities
                 (Create_From_Dir
                    (Get_Directory_From_Node (Explorer.Tree.Model, Start), N))
               then
                  Set (C.Matches, +N, Search_Match);
                  Result := Children (Explorer.Tree.Model, Start);
                  Finish := False;
                  return;
               else
                  --  Decrease the count for importing directories and
                  --  projects, so that if no file belonging to them is
                  --  referenced any more, we simply don't parse them

                  Mark_File_And_Projects
                    (File => Create_From_Dir
                       (Get_Directory_From_Node (Explorer.Tree.Model, Start),
                        N),
                     Project_Marked => False,
                     Project        => Get_Project_From_Node
                       (Explorer.Tree.Model, Explorer.Kernel, Start, False),
                     Mark_File      => No_Match,
                     Increment      => -1);
               end if;
            end if;

         elsif Status /= No_Match then
            --  Do not return the initial node
            if Context.Include_Files and then C.Current /= Start then
               Result := Start;
               Finish := True;
               return;
            end if;
         end if;

         --  The file doesn't match

         Result := Start;
         Next (Explorer.Tree.Model, Result);
         Finish := False;
      end Next_File_Node;

      ----------
      -- Next --
      ----------

      function Next return Gtk_Tree_Iter is
         Start_Node : Gtk_Tree_Iter := C.Current;
         Tmp        : Gtk_Tree_Iter;
         Finish     : Boolean;

         function First_Word (Str : String) return String;
         --  Return the first word in Str. This is required since the model
         --  of the explorer stores the arguments of the subprograms as well,
         --  and no match would be found otherwise

         ----------------
         -- First_Word --
         ----------------

         function First_Word (Str : String) return String is
         begin
            for J in Str'Range loop
               if Str (J) = ' ' then
                  return Str (Str'First .. J - 1);
               end if;
            end loop;
            return Str;
         end First_Word;

      begin
         while Start_Node /= Null_Iter loop
            begin
               case Get_Node_Type (Explorer.Tree.Model, Start_Node) is
                  when Project_Node_Types =>
                     declare
                        Name : constant String :=
                          Get_Project_From_Node
                            (Explorer.Tree.Model, Kernel, Start_Node, False)
                            .Name;
                     begin
                        Next_Or_Child
                          (Name           => Name,
                           Key            => Name,
                           Start          => Start_Node,
                           Check_Match    => Context.Include_Projects,
                           Check_Projects => True,
                           Result         => Tmp,
                           Finish         => Finish);

                        if Finish then
                           return Tmp;
                        end if;
                     end;

                  when Directory_Node =>
                     declare
                        Dir : constant Virtual_File := Get_Directory_From_Node
                          (Explorer.Tree.Model, Start_Node);
                     begin
                        Next_Or_Child
                          (Name           => Directory_Name (Dir),
                           Key            => Display_Full_Name (Dir),
                           Start          => Start_Node,
                           Check_Match    => Context.Include_Directories,
                           Check_Projects => False,
                           Result         => Tmp,
                           Finish         => Finish);

                        if Finish and then Context.Include_Directories then
                           return Tmp;
                        end if;
                     end;

                  when Obj_Directory_Node | Exec_Directory_Node =>
                     Tmp := Start_Node;
                     Next (Explorer.Tree.Model, Tmp);

                  when File_Node =>
                     Next_File_Node (Start_Node, Tmp, Finish);
                     if Finish and then Context.Include_Files then
                        return Tmp;
                     end if;

                  when Category_Node =>
                     Tmp := Children (Explorer.Tree.Model, Start_Node);

                  when Entity_Node =>
                     if C.Current /= Start_Node
                       and then Get
                         (C.Matches,
                          First_Word
                            (+Get_Base_Name (Explorer.Tree.Model, Start_Node)))
                          /= No_Match
                     then
                        return Start_Node;
                     else
                        Tmp := Start_Node;
                        Next (Explorer.Tree.Model, Tmp);
                     end if;

                  when Dummy_Node =>
                     null;
               end case;

               while Tmp = Null_Iter loop
                  Start_Node := Parent (Explorer.Tree.Model, Start_Node);
                  exit when Start_Node = Null_Iter;

                  Tmp := Start_Node;
                  Next (Explorer.Tree.Model, Tmp);
               end loop;

               Start_Node := Tmp;
            end;
         end loop;
         return Null_Iter;
      end Next;

      --------------------
      -- Check_Entities --
      --------------------

      function Check_Entities (File : Virtual_File) return Boolean is
         Languages  : constant Language_Handler :=
                        Get_Language_Handler (Kernel);
         Constructs : Construct_List;
         Status     : Boolean := False;

      begin
         Parse_File_Constructs
           (Get_Language_From_File (Languages, File), File, Constructs);

         Constructs.Current := Constructs.First;

         while Constructs.Current /= null loop
            if Filter_Category (Constructs.Current.Category) /= Cat_Unknown
              and then Constructs.Current.Name /= No_Symbol
              and then not GPS.Search.Failed
                (Match (C, Get (Constructs.Current.Name).all))
            then
               Status := True;

               if Get (C.Matches, Get (Constructs.Current.Name).all) /=
                 Search_Match
               then
                  Set (C.Matches, Get (Constructs.Current.Name).all,
                       Search_Match);
               end if;
            end if;

            Constructs.Current := Constructs.Current.Next;
         end loop;

         Free (Constructs);
         return Status;
      end Check_Entities;

      ----------------------------
      -- Mark_File_And_Projects --
      ----------------------------

      procedure Mark_File_And_Projects
        (File           : Virtual_File;
         Project_Marked : Boolean;
         Project        : Project_Type;
         Mark_File      : Search_Status;
         Increment      : Search_Status)
      is
         Parent : constant Virtual_File := Dir (File);
         Dir    : constant String := Display_Full_Name (Parent);
         Iter   : Project_Iterator;

      begin
         if File.Is_Directory then
            --  Use full name of directories to keep them unique
            Set (C.Matches, Display_Full_Name (File), Mark_File);
            --  Don't mark parent directory, because project view doesn't
            --  place directories inside directory
         else
            Set (C.Matches, +Base_Name (File), Mark_File);

            --  Mark the number of entries in the directory, so that if a file
            --  doesn't match we can decrease it later, and finally no longer
            --  examine the directory
            if Get (C.Matches, Dir) /= No_Match then
               Set (C.Matches, Dir, Get (C.Matches, Dir) + Increment);
            elsif Increment > 0 then
               Set (C.Matches, Dir, 1);
            end if;
         end if;

         if not Project_Marked then
            --  Mark the current project and all its importing projects as
            --  matching.

            declare
               N : constant String := Project.Name;
            begin
               Set (C.Matches, N, Get (C.Matches, N) + Increment);
            end;

            Iter := Find_All_Projects_Importing
              (Project      => Project);

            while Current (Iter) /= No_Project loop
               declare
                  N : constant String := Current (Iter).Name;
               begin
                  Set (C.Matches, N, Get (C.Matches, N) + Increment);
               end;

               Next (Iter);
            end loop;
         end if;
      end Mark_File_And_Projects;

      -----------------------
      -- Initialize_Parser --
      -----------------------

      procedure Initialize_Parser is
         Iter : Project_Iterator := Start
           (Get_Project (Kernel), Recursive => True);
         Project_Marked : Boolean := False;
      begin
         Projects.Clear;

         while Current (Iter) /= No_Project loop
            Project_Marked := False;

            if not GPS.Search.Failed (Match (C, Current (Iter).Name)) then
               Mark_File_And_Projects
                 (File           => Project_Path (Current (Iter)),
                  Project_Marked => Project_Marked,
                  Project        => Current (Iter),
                  Mark_File      => Unknown,
                  Increment      => 1);
            end if;

            if Context.Include_Directories then
               declare
                  Sources : constant File_Array := Current (Iter).Source_Dirs;
               begin
                  for S in Sources'Range loop
                     declare
                        Name : constant String := Directory_Name (Sources (S));
                     begin
                        if not GPS.Search.Failed (Match (C, Name)) then
                           Mark_File_And_Projects
                             (File           => Sources (S),
                              Project_Marked => Project_Marked,
                              Project        => Current (Iter),
                              Mark_File      => Search_Match,
                              Increment      => 1);
                           Project_Marked  := True;
                        end if;
                     end;
                  end loop;
               end;
            end if;

            declare
               Sources : File_Array_Access := Current (Iter).Source_Files;
            begin
               for S in Sources'Range loop
                  declare
                     Base : constant String := Display_Base_Name (Sources (S));
                  begin
                     if not GPS.Search.Failed (Match (C, Base)) then
                        Mark_File_And_Projects
                          (File           => Sources (S),
                           Project_Marked => Project_Marked,
                           Project        => Current (Iter),
                           Mark_File      => Search_Match,
                           Increment      => 1);
                        Project_Marked  := True;
                     end if;

                     if not Project_Marked and then C.Include_Entities then
                        Mark_File_And_Projects
                          (File           => Sources (S),
                           Project_Marked => Project_Marked,
                           Project        => Current (Iter),
                           Mark_File      => Unknown,
                           Increment      => 1);
                        --  Do not change Project_Marked, since we want the
                        --  total count for directories and projects to be the
                        --  total number of files in them.
                        --  ??? Could be more efficient
                     end if;
                  end;
               end loop;

               GNATCOLL.VFS.Unchecked_Free (Sources);
            end;

            Next (Iter);
         end loop;
      end Initialize_Parser;

   begin
      --  We need to freeze and block the handlers to speed up the display of
      --  the node on the screen.
      Gtk.Handlers.Handler_Block (Explorer.Tree, Explorer.Expand_Id);

      if C.Current = Null_Iter then
         Initialize_Parser;
         C.Current := Get_Iter_First (Explorer.Tree.Model);
      end if;

      C.Current := Next;

      if C.Current /= Null_Iter then
         Jump_To_Node (Explorer, C.Current);
      end if;

      Gtk.Handlers.Handler_Unblock (Explorer.Tree, Explorer.Expand_Id);

      Found := C.Current /= Null_Iter;
   end Search;

   --------------------
   --  Jump_To_Node  --
   --------------------

   procedure Jump_To_Node
     (Explorer    : Project_Explorer;
      Target_Node : Gtk_Tree_Iter)
   is
      Path   : Gtk_Tree_Path;
      Parent : Gtk_Tree_Path;
      Expand : Boolean;

      procedure Expand_Recursive (The_Path : Gtk_Tree_Path);
      --  Expand Path and all parents of Path that are not expanded

      ----------------------
      -- Expand_Recursive --
      ----------------------

      procedure Expand_Recursive (The_Path : Gtk_Tree_Path) is
         Parent : constant Gtk_Tree_Path := Copy (The_Path);
         Dummy  : Boolean;
         pragma Warnings (Off, Dummy);
      begin
         Dummy := Up (Parent);

         if Dummy then
            if not Row_Expanded (Explorer.Tree, Parent) then
               Expand_Recursive (Parent);
            end if;
         end if;

         Path_Free (Parent);
         Dummy := Expand_Row (Explorer.Tree, The_Path, False);
      end Expand_Recursive;

   begin
      Grab_Focus (Explorer.Tree);

      Path := Get_Path (Explorer.Tree.Model, Target_Node);
      Parent := Copy (Path);
      Expand := Up (Parent);

      if Expand then
         Expand_Recursive (Parent);
      end if;

      Path_Free (Parent);
      Set_Cursor (Explorer.Tree, Path, null, False);

      Scroll_To_Cell (Explorer.Tree, Path, null, True, 0.1, 0.1);

      Path_Free (Path);
   end Jump_To_Node;

   -------------
   -- Execute --
   -------------

   overriding function Execute
     (Command : access Locate_File_In_Explorer_Command;
      Context : Interactive_Command_Context) return Command_Return_Type
   is
      pragma Unreferenced (Command);
      Kernel   : constant Kernel_Handle := Get_Kernel (Context.Context);
      C        : Root_Search_Context_Access;
      Found    : Boolean;
      Continue : Boolean;
   begin
      C := Explorer_Search_Factory
        (Kernel,
         Include_Projects => False,
         Include_Files    => True);
      --  ??? Should we work directly with a Virtual_File, so that we
      --  are sure to match the right file, not necessarily a file with
      --  the same base name in an extending project...

      C.Set_Pattern
        (Pattern =>
           "^" & (+Base_Name (File_Information (Context.Context))) & "$",
         Case_Sensitive => Is_Case_Sensitive (Get_Nickname (Build_Server)),
         Whole_Word     => True,
         Kind           => GPS.Search.Regexp);

      Search
        (C, Kernel,
         Search_Backward => False,
         Give_Focus      => True,
         Found           => Found,
         Continue        => Continue);

      if not Found then
         Insert (Kernel,
                 -"File not found in the explorer: "
                 & Display_Base_Name (File_Information (Context.Context)),
                 Mode => GPS.Kernel.Error);
      end if;

      Free (C);
      return Commands.Success;
   end Execute;

   -------------
   -- Execute --
   -------------

   overriding function Execute
     (Command : access Locate_Project_In_Explorer_Command;
      Context : Interactive_Command_Context) return Command_Return_Type
   is
      pragma Unreferenced (Command);
      Kernel   : constant Kernel_Handle := Get_Kernel (Context.Context);
      C        : Root_Search_Context_Access;
      Found    : Boolean;
      Continue : Boolean;
   begin
      C := Explorer_Search_Factory
        (Kernel,
         Include_Projects => True,
         Include_Files    => False);

      C.Set_Pattern
        (Pattern => Project_Information (Context.Context).Name,
         Case_Sensitive => Is_Case_Sensitive (Get_Nickname (Build_Server)),
         Whole_Word     => True,
         Kind           => GPS.Search.Full_Text);

      Search
        (C, Kernel,
         Search_Backward => False,
         Give_Focus      => True,
         Found           => Found,
         Continue        => Continue);

      if not Found then
         Insert (Kernel,
                 -"Project not found in the explorer: "
                 & Project_Information (Context.Context).Name);
      end if;

      Free (C);
      return Commands.Success;
   end Execute;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Extra   : Explorer_Search_Extra;
      Box     : Gtk_Box;

      Project_View_Filter   : constant Action_Filter :=
                                new Project_View_Filter_Record;
      Project_Node_Filter   : constant Action_Filter :=
                                new Project_Node_Filter_Record;
      Directory_Node_Filter : constant Action_Filter :=
                                new Directory_Node_Filter_Record;
      File_Node_Filter      : constant Action_Filter :=
                                new File_Node_Filter_Record;
      Entity_Node_Filter    : constant Action_Filter :=
                                new Entity_Node_Filter_Record;
      Command               : Interactive_Command_Access;

   begin
      Explorer_Module_ID := new Explorer_Module_Record;
      Explorer_Views.Register_Module
        (Kernel => Kernel,
         ID     => Explorer_Module_ID);

      Create_New_Boolean_Key_If_Necessary
        (Get_History (Kernel).all, Show_Empty_Dirs, True);
      Create_New_Boolean_Key_If_Necessary
        (Get_History (Kernel).all, Show_Absolute_Paths, False);
      Create_New_Boolean_Key_If_Necessary
        (Get_History (Kernel).all, Show_Flat_View, False);
      Create_New_Boolean_Key_If_Necessary
        (Get_History (Kernel).all, Show_Hidden_Dirs, False);

      Register_Action
        (Kernel, "Locate file in explorer",
         new Locate_File_In_Explorer_Command,
         "Locate current file in project explorer",
         Lookup_Filter (Kernel, "File"), -"Project Explorer");

      Command := new Locate_File_In_Explorer_Command;
      Register_Contextual_Menu
        (Kernel, "Locate file in explorer",
         Action => Command,
         Filter => Lookup_Filter (Kernel, "In project")
                     and not Create (Module => Explorer_Module_Name),
         Label  => "Locate in Project View: %f");

      Command := new Locate_Project_In_Explorer_Command;
      Register_Contextual_Menu
        (Kernel, "Locate project in explorer",
         Action => Command,
         Filter => Lookup_Filter (Kernel, "Project only")
                     and not Create (Module => Explorer_Module_Name),
         Label  => "Locate in Project View: %p");

      Register_Action
        (Kernel, Toggle_Absolute_Path_Name,
         new Toggle_Absolute_Path_Command, Toggle_Absolute_Path_Tip,
         null, -"Project Explorer");

      Extra := new Explorer_Search_Extra_Record;
      Gtk.Box.Initialize_Vbox (Extra);

      Gtk_New_Vbox (Box, Homogeneous => False);
      Pack_Start (Extra, Box);

      Gtk_New (Extra.Include_Projects, -"Projects");
      Pack_Start (Box, Extra.Include_Projects);
      Set_Active (Extra.Include_Projects, True);
      Kernel_Callback.Connect
        (Extra.Include_Projects, Gtk.Toggle_Button.Signal_Toggled,
         Reset_Search'Access, Kernel_Handle (Kernel));

      Gtk_New (Extra.Include_Directories, -"Directories");
      Pack_Start (Box, Extra.Include_Directories);
      Set_Active (Extra.Include_Directories, True);
      Kernel_Callback.Connect
        (Extra.Include_Directories, Gtk.Toggle_Button.Signal_Toggled,
         Reset_Search'Access, Kernel_Handle (Kernel));

      Gtk_New (Extra.Include_Files, -"Files");
      Pack_Start (Box, Extra.Include_Files);
      Set_Active (Extra.Include_Files, True);
      Kernel_Callback.Connect
        (Extra.Include_Files, Gtk.Toggle_Button.Signal_Toggled,
         Reset_Search'Access, Kernel_Handle (Kernel));

      Gtk_New (Extra.Include_Entities, -"Entities (might be slow)");
      Pack_Start (Box, Extra.Include_Entities);
      Set_Active (Extra.Include_Entities, False);
      Kernel_Callback.Connect
        (Extra.Include_Entities, Gtk.Toggle_Button.Signal_Toggled,
         Reset_Search'Access, Kernel_Handle (Kernel));

      Register_Filter
        (Kernel,
         Filter => Project_View_Filter,
         Name   => "Explorer_View");
      Register_Filter
        (Kernel,
         Filter => Project_Node_Filter,
         Name   => "Explorer_Project_Node");
      Register_Filter
        (Kernel,
         Filter => Directory_Node_Filter,
         Name   => "Explorer_Directory_Node");
      Register_Filter
        (Kernel,
         Filter => File_Node_Filter,
         Name   => "Explorer_File_Node");
      Register_Filter
        (Kernel,
         Filter => Entity_Node_Filter,
         Name   => "Explorer_Entity_Node");

      Register_Search_Function
        (Kernel            => Kernel,
         Label             => -"Project View",
         Factory           => Explorer_Search_Factory'Access,
         Extra_Information => Extra,
         Id                => Explorer_Module_ID,
         Mask              => All_Options and not Supports_Replace
         and not Search_Backward and not All_Occurrences);
   end Register_Module;

   ----------
   -- Hash --
   ----------

   function Hash (Key : Filesystem_String) return Ada.Containers.Hash_Type is
   begin
      return Ada.Strings.Hash (+Key);
   end Hash;

   ---------------------
   -- Context_Look_In --
   ---------------------

   overriding function Context_Look_In
     (Self : Explorer_Search_Context) return String
   is
      pragma Unreferenced (Self);
   begin
      return -"project explorer";
   end Context_Look_In;

end Project_Explorers;
