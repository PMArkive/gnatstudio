with Gtk.Window; use Gtk.Window;
with Gtk.Box; use Gtk.Box;
with Gtk.Frame; use Gtk.Frame;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.Check_Button; use Gtk.Check_Button;
with Gtk.Alignment; use Gtk.Alignment;
with Gtk.Table; use Gtk.Table;
with Gtk.Label; use Gtk.Label;
with Gtk.Combo; use Gtk.Combo;
with Gtk.GEntry; use Gtk.GEntry;
with Gtk.Radio_Button; use Gtk.Radio_Button;
with Gtk.Scrolled_Window; use Gtk.Scrolled_Window;
with Gtk.Text; use Gtk.Text;
with Gtk.Separator; use Gtk.Separator;
with Gtk.Hbutton_Box; use Gtk.Hbutton_Box;
with Gtk.Button; use Gtk.Button;
with Gtk.Object; use Gtk.Object;
package New_Variable_Editor_Pkg is

   type New_Variable_Editor_Record is new Gtk_Window_Record with record
      Vbox37 : Gtk_Vbox;
      Name_Frame : Gtk_Frame;
      Variable_Name : Gtk_Entry;
      Frame33 : Gtk_Frame;
      Vbox38 : Gtk_Vbox;
      Get_Environment : Gtk_Check_Button;
      Alignment7 : Gtk_Alignment;
      Environment_Table : Gtk_Table;
      Label56 : Gtk_Label;
      Default_Env_Variable : Gtk_Combo;
      Combo_Entry8 : Gtk_Entry;
      List_Env_Variables : Gtk_Combo;
      Combo_Entry7 : Gtk_Entry;
      Label55 : Gtk_Label;
      Env_Must_Be_Defined : Gtk_Check_Button;
      Frame34 : Gtk_Frame;
      Vbox39 : Gtk_Vbox;
      Typed_Variable : Gtk_Radio_Button;
      Alignment4 : Gtk_Alignment;
      Enumeration_Scrolled : Gtk_Scrolled_Window;
      Enumeration_Value : Gtk_Text;
      Untyped_List_Variable : Gtk_Radio_Button;
      Alignment5 : Gtk_Alignment;
      List_Scrolled : Gtk_Scrolled_Window;
      List_Value : Gtk_Text;
      Untyped_Single_Variable : Gtk_Radio_Button;
      Alignment6 : Gtk_Alignment;
      Single_Value : Gtk_Text;
      Hseparator4 : Gtk_Hseparator;
      Hbuttonbox3 : Gtk_Hbutton_Box;
      Add_Button : Gtk_Button;
      Cancel_Button : Gtk_Button;
   end record;
   type New_Variable_Editor_Access is access all New_Variable_Editor_Record'Class;

   procedure Gtk_New (New_Variable_Editor : out New_Variable_Editor_Access);
   procedure Initialize (New_Variable_Editor : access New_Variable_Editor_Record'Class);

end New_Variable_Editor_Pkg;
