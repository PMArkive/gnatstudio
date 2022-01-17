------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                        Copyright (C) 2013-2022, AdaCore                  --
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

with Config;                  use Config;
with GNATCOLL.Arg_Lists;
with GNATCOLL.Scripts;
with GNATCOLL.Scripts.Python; use GNATCOLL.Scripts.Python;
with GNATCOLL.Utils;          use GNATCOLL.Utils;
with GNATCOLL.VFS;            use GNATCOLL.VFS;
with GNAT.OS_Lib;             use GNAT.OS_Lib;

package body GPS.Python_Core is

   ---------------------
   -- Register_Python --
   ---------------------

   procedure Register_Python
     (Kernel : access GPS.Core_Kernels.Core_Kernel_Record'Class)
   is
      Python_Home : String_Access := Getenv ("GPS_PYTHONHOME");
   begin
      if Python_Home.all = "" then
         declare
            Packaged_Python_Location : constant Virtual_File :=
               Create (+Executable_Location)
                  / (+"share") / (+"gnatstudio") / (+"python");
         begin
            Register_Python_Scripting
              (Kernel.Scripts,
               Module       => "GPS",
               Python_Home  => Packaged_Python_Location.Display_Full_Name);
         end;
      else
         Register_Python_Scripting
           (Kernel.Scripts,
            Module       => "GPS",
            Python_Home  => Python_Home.all);
      end if;

      Free (Python_Home);

      declare
         Gtk_Home : String_Access := Getenv ("GPS_GTKDLL");
         Script : constant GNATCOLL.Scripts.Scripting_Language :=
           Kernel.Scripts.Lookup_Scripting_Language (Python_Name);
         Errors : Boolean;
      begin
         --  Dynamically load the gtk DLLs on windows for python3.8+
         --  if the DLLs are not relatively located to PYTHONHOME.
         if Config.Host = Windows and then Gtk_Home.all /= "" then
            Script.Execute_Command
              (CL           => GNATCOLL.Arg_Lists.Create
                 ("import os; os.add_dll_directory('"
                  & Gtk_Home.all & "')"),
               Hide_Output  => True,
               Errors       => Errors);
         end if;
         Free (Gtk_Home);

         --  Register GPS module as GS to use both in transition period
         Script.Execute_Command
           (CL           => GNATCOLL.Arg_Lists.Create
              ("sys.modules['GS'] = GPS"),
            Hide_Output  => True,
            Errors       => Errors);
         pragma Assert (not Errors);

         --  Force the interpreter to load all files as utf8
         Script.Execute_Command
           (CL           => GNATCOLL.Arg_Lists.Create
              ("import _locale; _locale._getdefaultlocale" &
                 " = (lambda *args: ['en_US', 'utf8'])"),
            Hide_Output  => True,
            Errors       => Errors);
         pragma Assert (not Errors);
      end;
   end Register_Python;

end GPS.Python_Core;
