-----------------------------------------------------------------------
--                   GVD - The GNU Visual Debugger                   --
--                                                                   --
--                      Copyright (C) 2000-2001                      --
--                              ACT-Europe                           --
--                                                                   --
-- GVD is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Gtk; use Gtk;
with Gdk.Types;       use Gdk.Types;
with Gdk.Types.Keysyms; use Gdk.Types.Keysyms;
with Gtk.Widget;      use Gtk.Widget;
with Gtk.Enums;       use Gtk.Enums;
with Gtk.Accel_Group; use Gtk.Accel_Group;
with Gtk.Pixmap;      use Gtk.Pixmap;
with Gtkada.Handlers; use Gtkada.Handlers;
with Callbacks_Odd; use Callbacks_Odd;
with Odd_Intl; use Odd_Intl;
with Main_Debug_Window_Pkg.Callbacks; use Main_Debug_Window_Pkg.Callbacks;
with GVD.Pixmaps; use GVD.Pixmaps;
with GVD.Types;   use GVD.Types;
with GVD.Dialogs; use GVD.Dialogs;
with GVD.Process; use GVD.Process;
with GVD.Memory_View; use GVD.Memory_View;

package body Main_Debug_Window_Pkg is

procedure Gtk_New (Main_Debug_Window : out Main_Debug_Window_Access) is
begin
   Main_Debug_Window := new Main_Debug_Window_Record;
   Main_Debug_Window_Pkg.Initialize (Main_Debug_Window);
end Gtk_New;

procedure Initialize (Main_Debug_Window : access Main_Debug_Window_Record'Class) is
   pragma Suppress (All_Checks);
   The_Accel_Group : Gtk_Accel_Group;

begin
   Gtk.Window.Initialize (Main_Debug_Window, Window_Toplevel);
   Set_Title (Main_Debug_Window, -"The GNU Visual Debugger");
   Set_Policy (Main_Debug_Window, False, True, False);
   Set_Position (Main_Debug_Window, Win_Pos_None);
   Set_Modal (Main_Debug_Window, False);
   Set_Default_Size (Main_Debug_Window, 700, 700);
   Return_Callback.Connect
     (Main_Debug_Window, "delete_event", On_Main_Debug_Window_Delete_Event'Access);

   Gtk_New_Vbox (Main_Debug_Window.Vbox1, False, 0);
   Add (Main_Debug_Window, Main_Debug_Window.Vbox1);

   Gtk_New (Main_Debug_Window.Menubar1);
   Set_Shadow_Type (Main_Debug_Window.Menubar1, Shadow_Out);
   Pack_Start (Main_Debug_Window.Vbox1, Main_Debug_Window.Menubar1, False, False, 0);

   Gtk_New (Main_Debug_Window.File1, -"File");
   Set_Right_Justify (Main_Debug_Window.File1, False);
   Add (Main_Debug_Window.Menubar1, Main_Debug_Window.File1);

   Gtk_New (Main_Debug_Window.File1_Menu);
   Set_Submenu (Main_Debug_Window.File1, Main_Debug_Window.File1_Menu);

   Gtk_New (Main_Debug_Window.Open_Program1, -"Open Program...");
   Set_Right_Justify (Main_Debug_Window.Open_Program1, False);
   Set_Sensitive (Main_Debug_Window.Open_Program1, False);
   Gtk_New (The_Accel_Group);
   Add_Accel_Group (Main_Debug_Window, The_Accel_Group);
   Add_Accelerator (Main_Debug_Window.Open_Program1, "activate",
     The_Accel_Group, GDK_F3, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Open_Program1, "activate",
      Widget_Callback.To_Marshaller (On_Open_Program1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Open_Program1);

   Gtk_New (Main_Debug_Window.Open_Debugger1, -"New Debugger...");
   Set_Right_Justify (Main_Debug_Window.Open_Debugger1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Open_Debugger1, "activate",
      Widget_Callback.To_Marshaller (On_Open_Debugger1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Open_Debugger1);

   Gtk_New (Main_Debug_Window.Open_Recent1, -"Open Recent");
   Set_Right_Justify (Main_Debug_Window.Open_Recent1, False);
   Set_Sensitive (Main_Debug_Window.Open_Recent1, False);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Open_Recent1);

   Gtk_New (Main_Debug_Window.Open_Core_Dump1, -"Open Core Dump...");
   Set_Right_Justify (Main_Debug_Window.Open_Core_Dump1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Open_Core_Dump1, "activate",
      Widget_Callback.To_Marshaller (On_Open_Core_Dump1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Open_Core_Dump1);

   Gtk_New (Main_Debug_Window.Separator0);
   Set_Right_Justify (Main_Debug_Window.Separator0, False);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Separator0);

   Gtk_New (Main_Debug_Window.Edit_Source1, -"Edit Current Source");
   Set_Right_Justify (Main_Debug_Window.Edit_Source1, False);
   Add_Accelerator (Main_Debug_Window.Edit_Source1, "activate",
     The_Accel_Group, GDK_e, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Edit_Source1, "activate",
      Widget_Callback.To_Marshaller (On_Edit_Source1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Edit_Source1);

   Gtk_New (Main_Debug_Window.Open_Source1, -"Open Source...");
   Set_Right_Justify (Main_Debug_Window.Open_Source1, False);
   Set_Sensitive (Main_Debug_Window.Open_Source1, True);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Open_Source1, "activate",
      Widget_Callback.To_Marshaller (On_Open_Source1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Open_Source1);

   Gtk_New (Main_Debug_Window.Separator1);
   Set_Right_Justify (Main_Debug_Window.Separator1, False);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Separator1);

   Gtk_New (Main_Debug_Window.Open_Session1, -"Open Session...");
   Set_Right_Justify (Main_Debug_Window.Open_Session1, False);
   Add_Accelerator (Main_Debug_Window.Open_Session1, "activate",
     The_Accel_Group, GDK_N, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Open_Session1, "activate",
      Widget_Callback.To_Marshaller (On_Open_Session1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Open_Session1);

   Gtk_New (Main_Debug_Window.Save_Session_As1, -"Save Session As...");
   Set_Right_Justify (Main_Debug_Window.Save_Session_As1, False);
   Add_Accelerator (Main_Debug_Window.Save_Session_As1, "activate",
     The_Accel_Group, GDK_S, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Save_Session_As1, "activate",
      Widget_Callback.To_Marshaller (On_Save_Session_As1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Save_Session_As1);

   Gtk_New (Main_Debug_Window.Separator2);
   Set_Right_Justify (Main_Debug_Window.Separator2, False);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Separator2);

   Gtk_New (Main_Debug_Window.Attach_To_Process1, -"Attach To Process...");
   Set_Right_Justify (Main_Debug_Window.Attach_To_Process1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Attach_To_Process1, "activate",
      Widget_Callback.To_Marshaller (On_Attach_To_Process1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Attach_To_Process1);

   Gtk_New (Main_Debug_Window.Detach_Process1, -"Detach Process");
   Set_Right_Justify (Main_Debug_Window.Detach_Process1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Detach_Process1, "activate",
      Widget_Callback.To_Marshaller (On_Detach_Process1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Detach_Process1);

   Gtk_New (Main_Debug_Window.Separator3);
   Set_Right_Justify (Main_Debug_Window.Separator3, False);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Separator3);

   Gtk_New (Main_Debug_Window.Change_Directory1, -"Change Directory...");
   Set_Right_Justify (Main_Debug_Window.Change_Directory1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Change_Directory1, "activate",
      Widget_Callback.To_Marshaller (On_Change_Directory1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Change_Directory1);

   Gtk_New (Main_Debug_Window.Separator4);
   Set_Right_Justify (Main_Debug_Window.Separator4, False);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Separator4);

   Gtk_New (Main_Debug_Window.Close1, -"Close");
   Set_Right_Justify (Main_Debug_Window.Close1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Close1, "activate",
      Widget_Callback.To_Marshaller (On_Close1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Close1);

   Gtk_New (Main_Debug_Window.Exit1, -"Exit");
   Set_Right_Justify (Main_Debug_Window.Exit1, False);
   Add_Accelerator (Main_Debug_Window.Exit1, "activate",
     The_Accel_Group, GDK_Q, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Exit1, "activate",
      Widget_Callback.To_Marshaller (On_Exit1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.File1_Menu, Main_Debug_Window.Exit1);

   Gtk_New (Main_Debug_Window.Edit2, -"Edit");
   Set_Right_Justify (Main_Debug_Window.Edit2, False);
   Add (Main_Debug_Window.Menubar1, Main_Debug_Window.Edit2);

   Gtk_New (Main_Debug_Window.Edit2_Menu);
   Set_Submenu (Main_Debug_Window.Edit2, Main_Debug_Window.Edit2_Menu);

   Gtk_New (Main_Debug_Window.Undo1, -"Undo");
   Set_Right_Justify (Main_Debug_Window.Undo1, False);
   Set_Sensitive (Main_Debug_Window.Undo1, False);
   Add_Accelerator (Main_Debug_Window.Undo1, "activate",
     The_Accel_Group, GDK_z, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Undo1, "activate",
      Widget_Callback.To_Marshaller (On_Undo1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Undo1);

   Gtk_New (Main_Debug_Window.Redo1, -"Redo");
   Set_Right_Justify (Main_Debug_Window.Redo1, False);
   Set_Sensitive (Main_Debug_Window.Redo1, False);
   Add_Accelerator (Main_Debug_Window.Redo1, "activate",
     The_Accel_Group, GDK_y, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Redo1, "activate",
      Widget_Callback.To_Marshaller (On_Redo1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Redo1);

   Gtk_New (Main_Debug_Window.Separator5);
   Set_Right_Justify (Main_Debug_Window.Separator5, False);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Separator5);

   Gtk_New (Main_Debug_Window.Cut1, -"Cut");
   Set_Right_Justify (Main_Debug_Window.Cut1, False);
   Set_Sensitive (Main_Debug_Window.Cut1, False);
   Add_Accelerator (Main_Debug_Window.Cut1, "activate",
     The_Accel_Group, GDK_Delete, Gdk.Types.Shift_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Cut1, "activate",
      Widget_Callback.To_Marshaller (On_Cut1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Cut1);

   Gtk_New (Main_Debug_Window.Copy1, -"Copy");
   Set_Right_Justify (Main_Debug_Window.Copy1, False);
   Set_Sensitive (Main_Debug_Window.Copy1, False);
   Add_Accelerator (Main_Debug_Window.Copy1, "activate",
     The_Accel_Group, GDK_Insert, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Copy1, "activate",
      Widget_Callback.To_Marshaller (On_Copy1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Copy1);

   Gtk_New (Main_Debug_Window.Paste1, -"Paste");
   Set_Right_Justify (Main_Debug_Window.Paste1, False);
   Set_Sensitive (Main_Debug_Window.Paste1, False);
   Add_Accelerator (Main_Debug_Window.Paste1, "activate",
     The_Accel_Group, GDK_Insert, Gdk.Types.Shift_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Paste1, "activate",
      Widget_Callback.To_Marshaller (On_Paste1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Paste1);

   Gtk_New (Main_Debug_Window.Select_All1, -"Select All");
   Set_Right_Justify (Main_Debug_Window.Select_All1, False);
   Set_Sensitive (Main_Debug_Window.Select_All1, False);
   Add_Accelerator (Main_Debug_Window.Select_All1, "activate",
     The_Accel_Group, GDK_A, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Select_All1, "activate",
      Widget_Callback.To_Marshaller (On_Select_All1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Select_All1);

   Gtk_New (Main_Debug_Window.Separator6);
   Set_Right_Justify (Main_Debug_Window.Separator6, False);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Separator6);

   Gtk_New (Main_Debug_Window.Search1, -"Search...");
   Set_Right_Justify (Main_Debug_Window.Search1, False);
   Set_Sensitive (Main_Debug_Window.Search1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Search1, "activate",
      Widget_Callback.To_Marshaller (On_Search1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Search1);

   Gtk_New (Main_Debug_Window.Separator7);
   Set_Right_Justify (Main_Debug_Window.Separator7, False);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Separator7);

   Gtk_New (Main_Debug_Window.Preferences1, -"Preferences...");
   Set_Right_Justify (Main_Debug_Window.Preferences1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Preferences1, "activate",
      Widget_Callback.To_Marshaller (On_Preferences1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Preferences1);

   Gtk_New (Main_Debug_Window.Gdb_Settings1, -"GDB Settings...");
   Set_Right_Justify (Main_Debug_Window.Gdb_Settings1, False);
   Set_Sensitive (Main_Debug_Window.Gdb_Settings1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Gdb_Settings1, "activate",
      Widget_Callback.To_Marshaller (On_Gdb_Settings1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Edit2_Menu, Main_Debug_Window.Gdb_Settings1);

   Gtk_New (Main_Debug_Window.Program1, -"Program");
   Set_Right_Justify (Main_Debug_Window.Program1, False);
   Add (Main_Debug_Window.Menubar1, Main_Debug_Window.Program1);

   Gtk_New (Main_Debug_Window.Program1_Menu);
   Set_Submenu (Main_Debug_Window.Program1, Main_Debug_Window.Program1_Menu);

   Gtk_New (Main_Debug_Window.Run1, -"Run/Start...");
   Set_Right_Justify (Main_Debug_Window.Run1, False);
   Add_Accelerator (Main_Debug_Window.Run1, "activate",
     The_Accel_Group, GDK_F2, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Run1, "activate",
      Widget_Callback.To_Marshaller (On_Run1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Run1);

   Gtk_New (Main_Debug_Window.Separator10);
   Set_Right_Justify (Main_Debug_Window.Separator10, False);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Separator10);

   Gtk_New (Main_Debug_Window.Step1, -"Step");
   Set_Right_Justify (Main_Debug_Window.Step1, False);
   Add_Accelerator (Main_Debug_Window.Step1, "activate",
     The_Accel_Group, GDK_F5, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Step1, "activate",
      Widget_Callback.To_Marshaller (On_Step1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Step1);

   Gtk_New (Main_Debug_Window.Step_Instruction1, -"Step Instruction");
   Set_Right_Justify (Main_Debug_Window.Step_Instruction1, False);
   Add_Accelerator (Main_Debug_Window.Step_Instruction1, "activate",
     The_Accel_Group, GDK_F5, Gdk.Types.Shift_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Step_Instruction1, "activate",
      Widget_Callback.To_Marshaller (On_Step_Instruction1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Step_Instruction1);

   Gtk_New (Main_Debug_Window.Next1, -"Next");
   Set_Right_Justify (Main_Debug_Window.Next1, False);
   Add_Accelerator (Main_Debug_Window.Next1, "activate",
     The_Accel_Group, GDK_F6, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Next1, "activate",
      Widget_Callback.To_Marshaller (On_Next1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Next1);

   Gtk_New (Main_Debug_Window.Next_Instruction1, -"Next Instruction");
   Set_Right_Justify (Main_Debug_Window.Next_Instruction1, False);
   Add_Accelerator (Main_Debug_Window.Next_Instruction1, "activate",
     The_Accel_Group, GDK_F6, Gdk.Types.Shift_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Next_Instruction1, "activate",
      Widget_Callback.To_Marshaller (On_Next_Instruction1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Next_Instruction1);

   Gtk_New (Main_Debug_Window.Finish1, -"Finish");
   Set_Right_Justify (Main_Debug_Window.Finish1, False);
   Add_Accelerator (Main_Debug_Window.Finish1, "activate",
     The_Accel_Group, GDK_F7, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Finish1, "activate",
      Widget_Callback.To_Marshaller (On_Finish1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Finish1);

   Gtk_New (Main_Debug_Window.Separator12);
   Set_Right_Justify (Main_Debug_Window.Separator12, False);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Separator12);

   Gtk_New (Main_Debug_Window.Continue1, -"Continue");
   Set_Right_Justify (Main_Debug_Window.Continue1, False);
   Add_Accelerator (Main_Debug_Window.Continue1, "activate",
     The_Accel_Group, GDK_F8, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Continue1, "activate",
      Widget_Callback.To_Marshaller (On_Continue1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Continue1);

   Gtk_New (Main_Debug_Window.Continue_Without_Signal1, -"Continue without Signal");
   Set_Right_Justify (Main_Debug_Window.Continue_Without_Signal1, False);
   Set_Sensitive (Main_Debug_Window.Continue_Without_Signal1, False);
   Add_Accelerator (Main_Debug_Window.Continue_Without_Signal1, "activate",
     The_Accel_Group, GDK_F8, Gdk.Types.Shift_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Continue_Without_Signal1, "activate",
      Widget_Callback.To_Marshaller (On_Continue_Without_Signal1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Continue_Without_Signal1);

   Gtk_New (Main_Debug_Window.Separator13);
   Set_Right_Justify (Main_Debug_Window.Separator13, False);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Separator13);

   Gtk_New (Main_Debug_Window.Kill1, -"Kill");
   Set_Right_Justify (Main_Debug_Window.Kill1, False);
   Set_Sensitive (Main_Debug_Window.Kill1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Kill1, "activate",
      Widget_Callback.To_Marshaller (On_Kill1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Kill1);

   Gtk_New (Main_Debug_Window.Interrupt1, -"Interrupt");
   Set_Right_Justify (Main_Debug_Window.Interrupt1, False);
   Add_Accelerator (Main_Debug_Window.Interrupt1, "activate",
     The_Accel_Group, GDK_Escape, 0, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Interrupt1, "activate",
      Widget_Callback.To_Marshaller (On_Interrupt1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Interrupt1);

   Gtk_New (Main_Debug_Window.Abort1, -"Abort");
   Set_Right_Justify (Main_Debug_Window.Abort1, False);
   Set_Sensitive (Main_Debug_Window.Abort1, False);
   Add_Accelerator (Main_Debug_Window.Abort1, "activate",
     The_Accel_Group, GDK_backslash, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Abort1, "activate",
      Widget_Callback.To_Marshaller (On_Abort1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Program1_Menu, Main_Debug_Window.Abort1);

   Gtk_New (Main_Debug_Window.Command1, -"Command");
   Set_Right_Justify (Main_Debug_Window.Command1, False);
   Add (Main_Debug_Window.Menubar1, Main_Debug_Window.Command1);

   Gtk_New (Main_Debug_Window.Command1_Menu);
   Set_Submenu (Main_Debug_Window.Command1, Main_Debug_Window.Command1_Menu);

   Gtk_New (Main_Debug_Window.Command_History1, -"Command History...");
   Set_Right_Justify (Main_Debug_Window.Command_History1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Command_History1, "activate",
      Widget_Callback.To_Marshaller (On_Command_History1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Command1_Menu, Main_Debug_Window.Command_History1);

   Gtk_New (Main_Debug_Window.Clear_Window1, -"Clear Window");
   Set_Right_Justify (Main_Debug_Window.Clear_Window1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Clear_Window1, "activate",
      Widget_Callback.To_Marshaller (On_Clear_Window1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Command1_Menu, Main_Debug_Window.Clear_Window1);

   Gtk_New (Main_Debug_Window.Separator14);
   Set_Right_Justify (Main_Debug_Window.Separator14, False);
   Add (Main_Debug_Window.Command1_Menu, Main_Debug_Window.Separator14);

   Gtk_New (Main_Debug_Window.Define_Command1, -"Define Command...");
   Set_Right_Justify (Main_Debug_Window.Define_Command1, False);
   Set_Sensitive (Main_Debug_Window.Define_Command1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Define_Command1, "activate",
      Widget_Callback.To_Marshaller (On_Define_Command1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Command1_Menu, Main_Debug_Window.Define_Command1);

   Gtk_New (Main_Debug_Window.Edit_Buttons1, -"Edit Buttons...");
   Set_Right_Justify (Main_Debug_Window.Edit_Buttons1, False);
   Set_Sensitive (Main_Debug_Window.Edit_Buttons1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Edit_Buttons1, "activate",
      Widget_Callback.To_Marshaller (On_Edit_Buttons1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Command1_Menu, Main_Debug_Window.Edit_Buttons1);

   Gtk_New (Main_Debug_Window.Data1, -"Data");
   Set_Right_Justify (Main_Debug_Window.Data1, False);
   Add (Main_Debug_Window.Menubar1, Main_Debug_Window.Data1);

   Gtk_New (Main_Debug_Window.Data1_Menu);
   Set_Submenu (Main_Debug_Window.Data1, Main_Debug_Window.Data1_Menu);

   Gtk_New (Main_Debug_Window.Call_Stack, -"Call Stack");
   Set_Active (Main_Debug_Window.Call_Stack, True);
   Set_Always_Show_Toggle (Main_Debug_Window.Call_Stack, True);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Call_Stack, "activate",
      Widget_Callback.To_Marshaller (On_Call_Stack_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Call_Stack);

   Gtk_New (Main_Debug_Window.Threads1, -"Threads...");
   Set_Right_Justify (Main_Debug_Window.Threads1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Threads1, "activate",
      Widget_Callback.To_Marshaller (On_Threads1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Threads1);

   Gtk_New (Main_Debug_Window.Processes1, -"Processes...");
   Set_Right_Justify (Main_Debug_Window.Processes1, False);
   Set_Sensitive (Main_Debug_Window.Processes1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Processes1, "activate",
      Widget_Callback.To_Marshaller (On_Processes1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Processes1);

   Gtk_New (Main_Debug_Window.Signals1, -"Signals...");
   Set_Right_Justify (Main_Debug_Window.Signals1, False);
   Set_Sensitive (Main_Debug_Window.Signals1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Signals1, "activate",
      Widget_Callback.To_Marshaller (On_Signals1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Signals1);

   Gtk_New (Main_Debug_Window.Separator17);
   Set_Right_Justify (Main_Debug_Window.Separator17, False);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Separator17);

   Gtk_New (Main_Debug_Window.Edit_Breakpoints1, -"Edit Breakpoints...");
   Set_Right_Justify (Main_Debug_Window.Edit_Breakpoints1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Edit_Breakpoints1, "activate",
      Widget_Callback.To_Marshaller (On_Edit_Breakpoints1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Edit_Breakpoints1);

   Gtk_New (Main_Debug_Window.Edit_Displays1, -"Edit Displays...");
   Set_Right_Justify (Main_Debug_Window.Edit_Displays1, False);
   Set_Sensitive (Main_Debug_Window.Edit_Displays1, False);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.Edit_Displays1, "activate",
      Menu_Item_Callback.To_Marshaller (On_Edit_Displays1_Activate'Access));
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Edit_Displays1);

   Gtk_New (Main_Debug_Window.Examine_Memory1, -"Examine Memory...");
   Set_Right_Justify (Main_Debug_Window.Examine_Memory1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Examine_Memory1, "activate",
      Widget_Callback.To_Marshaller (On_Examine_Memory1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Examine_Memory1);

   Gtk_New (Main_Debug_Window.Separator24);
   Set_Right_Justify (Main_Debug_Window.Separator24, False);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Separator24);

   Gtk_New (Main_Debug_Window.Display_Local_Variables1, -"Display Local Variables");
   Set_Right_Justify (Main_Debug_Window.Display_Local_Variables1, False);
   Add_Accelerator (Main_Debug_Window.Display_Local_Variables1, "activate",
     The_Accel_Group, GDK_L, Gdk.Types.Mod1_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Display_Local_Variables1, "activate",
      Widget_Callback.To_Marshaller (On_Display_Local_Variables1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Display_Local_Variables1);

   Gtk_New (Main_Debug_Window.Display_Arguments1, -"Display Arguments");
   Set_Right_Justify (Main_Debug_Window.Display_Arguments1, False);
   Add_Accelerator (Main_Debug_Window.Display_Arguments1, "activate",
     The_Accel_Group, GDK_U, Gdk.Types.Mod1_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Display_Arguments1, "activate",
      Widget_Callback.To_Marshaller (On_Display_Arguments1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Display_Arguments1);

   Gtk_New (Main_Debug_Window.Display_Registers1, -"Display Registers");
   Set_Right_Justify (Main_Debug_Window.Display_Registers1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Display_Registers1, "activate",
      Widget_Callback.To_Marshaller (On_Display_Registers1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Display_Registers1);

   Gtk_New (Main_Debug_Window.Display_Expression1, -"Display Any Expression...");
   Set_Right_Justify (Main_Debug_Window.Display_Expression1, False);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Display_Expression1, "activate",
      Widget_Callback.To_Marshaller (On_Display_Expression1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Display_Expression1);

   Gtk_New (Main_Debug_Window.More_Status_Display1, -"More Status Display...");
   Set_Right_Justify (Main_Debug_Window.More_Status_Display1, False);
   Set_Sensitive (Main_Debug_Window.More_Status_Display1, False);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.More_Status_Display1, "activate",
      Menu_Item_Callback.To_Marshaller (On_More_Status_Display1_Activate'Access));
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.More_Status_Display1);

   Gtk_New (Main_Debug_Window.Separator27);
   Set_Right_Justify (Main_Debug_Window.Separator27, False);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Separator27);

   Gtk_New (Main_Debug_Window.Refresh1, -"Refresh");
   Set_Right_Justify (Main_Debug_Window.Refresh1, False);
   Add_Accelerator (Main_Debug_Window.Refresh1, "activate",
     The_Accel_Group, GDK_L, Gdk.Types.Control_Mask, Accel_Visible);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Refresh1, "activate",
      Widget_Callback.To_Marshaller (On_Refresh1_Activate'Access), Main_Debug_Window);
   Add (Main_Debug_Window.Data1_Menu, Main_Debug_Window.Refresh1);

   Gtk_New (Main_Debug_Window.Help1, -"Help");
   Set_Right_Justify (Main_Debug_Window.Help1, True);
   Add (Main_Debug_Window.Menubar1, Main_Debug_Window.Help1);

   Gtk_New (Main_Debug_Window.Help1_Menu);
   Set_Submenu (Main_Debug_Window.Help1, Main_Debug_Window.Help1_Menu);

   Gtk_New (Main_Debug_Window.Overview1, -"Overview...");
   Set_Right_Justify (Main_Debug_Window.Overview1, False);
   Set_Sensitive (Main_Debug_Window.Overview1, False);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.Overview1, "activate",
      Menu_Item_Callback.To_Marshaller (On_Overview1_Activate'Access));
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.Overview1);

   Gtk_New (Main_Debug_Window.On_Item1, -"On Item...");
   Set_Right_Justify (Main_Debug_Window.On_Item1, False);
   Set_Sensitive (Main_Debug_Window.On_Item1, False);
   Add_Accelerator (Main_Debug_Window.On_Item1, "activate",
     The_Accel_Group, GDK_F1, Gdk.Types.Shift_Mask, Accel_Visible);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.On_Item1, "activate",
      Menu_Item_Callback.To_Marshaller (On_On_Item1_Activate'Access));
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.On_Item1);

   Gtk_New (Main_Debug_Window.Separator29);
   Set_Right_Justify (Main_Debug_Window.Separator29, False);
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.Separator29);

   Gtk_New (Main_Debug_Window.What_Now_1, -"What Now ... ?");
   Set_Right_Justify (Main_Debug_Window.What_Now_1, False);
   Set_Sensitive (Main_Debug_Window.What_Now_1, False);
   Add_Accelerator (Main_Debug_Window.What_Now_1, "activate",
     The_Accel_Group, GDK_F1, Gdk.Types.Control_Mask, Accel_Visible);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.What_Now_1, "activate",
      Menu_Item_Callback.To_Marshaller (On_What_Now_1_Activate'Access));
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.What_Now_1);

   Gtk_New (Main_Debug_Window.Tip_Of_The_Day1, -"Tip Of The Day...");
   Set_Right_Justify (Main_Debug_Window.Tip_Of_The_Day1, False);
   Set_Sensitive (Main_Debug_Window.Tip_Of_The_Day1, False);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.Tip_Of_The_Day1, "activate",
      Menu_Item_Callback.To_Marshaller (On_Tip_Of_The_Day1_Activate'Access));
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.Tip_Of_The_Day1);

   Gtk_New (Main_Debug_Window.Separator30);
   Set_Right_Justify (Main_Debug_Window.Separator30, False);
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.Separator30);

   Gtk_New (Main_Debug_Window.About_Odd1, -"About GVD...");
   Set_Right_Justify (Main_Debug_Window.About_Odd1, False);
   Menu_Item_Callback.Connect
     (Main_Debug_Window.About_Odd1, "activate",
      Menu_Item_Callback.To_Marshaller (On_About_Odd1_Activate'Access));
   Add (Main_Debug_Window.Help1_Menu, Main_Debug_Window.About_Odd1);

   Gtk_New (Main_Debug_Window.Toolbar2, Orientation_Horizontal, Toolbar_Icons);
   Set_Space_Size (Main_Debug_Window.Toolbar2, 5);
   Set_Space_Style (Main_Debug_Window.Toolbar2, Toolbar_Space_Empty);
   Set_Tooltips (Main_Debug_Window.Toolbar2, True);
   Set_Button_Relief (Main_Debug_Window.Toolbar2, Relief_Normal);
   Main_Debug_Window.Button49 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Start the debugged program",
      Icon => Gtk_Widget (Create_Pixmap (run_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button49, "clicked", On_Run1_Toolbar_Activate'Access, Main_Debug_Window);
   Main_Debug_Window.Button50 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Start the debugged program, stopping at the beginning of the main procedure",
      Icon => Gtk_Widget (Create_Pixmap (start_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button50, "clicked", On_Start1_Activate'Access, Main_Debug_Window);
   Main_Debug_Window.Button52 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Step program until it reaches a different source line",
      Icon => Gtk_Widget (Create_Pixmap (step_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button52, "clicked", Widget_Callback.To_Marshaller (On_Step1_Activate'Access), Main_Debug_Window);
   Main_Debug_Window.Button53 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Step one instruction exactly",
      Icon => Gtk_Widget (Create_Pixmap (stepi_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button53, "clicked", Widget_Callback.To_Marshaller (On_Step_Instruction1_Activate'Access), Main_Debug_Window);
   Main_Debug_Window.Button54 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Step program, proceeding through subroutine calls",
      Icon => Gtk_Widget (Create_Pixmap (next_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button54, "clicked", Widget_Callback.To_Marshaller (On_Next1_Activate'Access), Main_Debug_Window);
   Main_Debug_Window.Button55 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Step one instruction, but proceed through subroutine calls",
      Icon => Gtk_Widget (Create_Pixmap (nexti_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button55, "clicked", Widget_Callback.To_Marshaller (On_Next_Instruction1_Activate'Access), Main_Debug_Window);
   Main_Debug_Window.Button58 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Execute until selected stack frame returns",
      Icon => Gtk_Widget (Create_Pixmap (finish_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button58, "clicked", Widget_Callback.To_Marshaller (On_Finish1_Activate'Access), Main_Debug_Window);
   Main_Debug_Window.Button60 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Continue program being debugged, after signal or breakpoint",
      Icon => Gtk_Widget (Create_Pixmap (cont_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button60, "clicked", Widget_Callback.To_Marshaller (On_Continue1_Activate'Access), Main_Debug_Window);
   Main_Debug_Window.Button57 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Select and print stack frame that called this one",
      Icon => Gtk_Widget (Create_Pixmap (up_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button57, "clicked", On_Up1_Activate'Access, Main_Debug_Window);
   Main_Debug_Window.Button51 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Select and print stack frame called by this one",
      Icon => Gtk_Widget (Create_Pixmap (down_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button51, "clicked", On_Down1_Activate'Access, Main_Debug_Window);
   Main_Debug_Window.Button61 := Append_Element
     (Toolbar => Main_Debug_Window.Toolbar2,
      The_Type => Toolbar_Child_Button,
      Text => -"",
      Tooltip_Text => -"Interrupt debugged program",
      Icon => Gtk_Widget (Create_Pixmap (interrupt_xpm, Main_Debug_Window)));
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Button61, "clicked", Widget_Callback.To_Marshaller (On_Interrupt1_Activate'Access), Main_Debug_Window);
   Pack_Start (Main_Debug_Window.Vbox1,
     Get_Handle_Box (Main_Debug_Window.Toolbar2), False, False, 0);

   Gtk_New (Main_Debug_Window.Frame7);
   Set_Shadow_Type (Main_Debug_Window.Frame7, Shadow_Etched_In);
   Pack_Start (Main_Debug_Window.Vbox1, Main_Debug_Window.Frame7, True, True, 0);

   Gtk_New (Main_Debug_Window.Process_Notebook);
   Set_Scrollable (Main_Debug_Window.Process_Notebook, True);
   Set_Show_Border (Main_Debug_Window.Process_Notebook, True);
   Set_Show_Tabs (Main_Debug_Window.Process_Notebook, False);
   Set_Tab_Hborder (Main_Debug_Window.Process_Notebook, 2);
   Set_Tab_Vborder (Main_Debug_Window.Process_Notebook, 2);
   Set_Tab_Pos (Main_Debug_Window.Process_Notebook, Pos_Top);
   Widget_Callback.Object_Connect
     (Main_Debug_Window.Process_Notebook, "switch_page", On_Process_Notebook_Switch_Page'Access, Main_Debug_Window);
   Add (Main_Debug_Window.Frame7, Main_Debug_Window.Process_Notebook);

   Gtk_New (Main_Debug_Window.Statusbar1);
   Pack_Start (Main_Debug_Window.Vbox1, Main_Debug_Window.Statusbar1, False, False, 0);

   Gtk_New (Main_Debug_Window.Task_Dialog, Gtk_Window (Main_Debug_Window));
   Gtk_New (Main_Debug_Window.History_Dialog, Gtk_Window (Main_Debug_Window));
   Gtk_New (Main_Debug_Window.Memory_View, Gtk_Widget (Main_Debug_Window));
   Lock (The_Accel_Group);
   Lock (Gtk.Accel_Group.Get_Default);
end Initialize;

   -----------------------------
   -- Update_External_Dialogs --
   -----------------------------

   procedure Update_External_Dialogs
     (Window : access Main_Debug_Window_Record'Class;
      Debugger : Gtk.Widget.Gtk_Widget := null)
   is
      Tab : Debugger_Process_Tab := Debugger_Process_Tab (Debugger);
   begin
      if Debugger = null then
         Tab := Get_Current_Process (Window);
      end if;

      if Tab /= null then
         Update_Call_Stack (Tab);
         Update (Window.Task_Dialog, Tab);
         Update (Window.History_Dialog, Tab);
      end if;
   end Update_External_Dialogs;

   ----------------
   -- Find_Match --
   ----------------

   procedure Find_Match
     (H   : in out History_List;
      Num : in Natural;
      D   : in Direction)
   is
      Data    : GNAT.OS_Lib.String_Access;
      Current : History_Data;
   begin
      begin
         Data := Get_Current (H).Command;
      exception
         when No_Such_Item =>
            Data := null;
      end;

      loop
         if D = Backward then
            Move_To_Previous (H);
         else
            Move_To_Next (H);
         end if;
         Current := Get_Current (H);
         exit when Current.Debugger_Num = Num
           and then Current.Mode /= Hidden
           and then (Data = null
                     or else Current.Command.all /= Data.all);
      end loop;
   end Find_Match;

end Main_Debug_Window_Pkg;
