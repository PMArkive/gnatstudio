------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                        Copyright (C) 2022, AdaCore                       --
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

with Ada.Strings.UTF_Encoding;

with GNATCOLL.Traces;       use GNATCOLL.Traces;
with GNATCOLL.VFS_Utils;

with VSS.Strings.Conversions;

with Toolchains_Old;

with DAP.Breakpoints;
with DAP.Breakpoint_Maps;

with DAP.Requests.Breakpoints;
with DAP.Requests.ConfigurationDone;

package body DAP.Requests.Launch is

   Me : constant Trace_Handle := Create ("DAP.Requests.Launch", On);

   procedure Initialize
     (Self    : in out Launch_DAP_Request;
      Project : GNATCOLL.Projects.Project_Type;
      File    : GNATCOLL.VFS.Virtual_File;
      Args    : Ada.Strings.Unbounded.Unbounded_String)
   is
      use Ada.Strings.Unbounded;
      use GNATCOLL.VFS;

      type Extension_Array is array (Positive range <>) of
        Filesystem_String (1 .. 4);
      Extensions : constant Extension_Array := (".exe", ".out", ".vxe");
      Tmp        : Virtual_File;

      A            : Unbounded_String := Args;
      End_Of_Exec  : Natural;
      Exec         : Virtual_File;
      Blank_Pos    : Integer;

      --------------
      -- Get_Args --
      --------------

      function Get_Args return String;
      function Get_Args return String is
      begin
         if Length (A) = 0 then
            return "";
         else
            return " " & To_String (A);
         end if;
      end Get_Args;

   begin
      if File /= GNATCOLL.VFS.No_File then
         Self.Parameters.arguments.program := VSS.Strings.Conversions.
           To_Virtual_String
             (Ada.Strings.UTF_Encoding.UTF_8_String'
                (+File.Full_Name & Get_Args));

      elsif A /= "" then
         Blank_Pos := Index (A, " ");

         if Blank_Pos = 0 then
            End_Of_Exec := Length (A);
         else
            End_Of_Exec := Blank_Pos - 1;
            A := Unbounded_Slice
              (A, Blank_Pos + 1, Length (A));
         end if;

         declare
            Exec_Name : constant Filesystem_String :=
              +Slice (A, 1, End_Of_Exec);

         begin
            --  First check whether Exec_Name is an absolute path
            Exec := Create (Full_Filename => Exec_Name);

            if not Exec.Is_Absolute_Path then
               --  If the Exec name is not an absolute path, check
               --  whether it corresponds to a file found from the
               --  current directory.

               Exec := Create
                 (Full_Filename =>
                    GNATCOLL.VFS_Utils.Normalize_Pathname
                      (Exec_Name, GNATCOLL.VFS_Utils.Get_Current_Dir));

               if not Exec.Is_Regular_File then
                  --  If the Exec is not an absolute path and it is not
                  --  found from the current directory, try to locate it
                  --  on path.

                  Exec := Toolchains_Old.Locate_Compiler_Executable
                    (Exec_Name);

                  if Exec = No_File then
                     Exec := Create_From_Base (Exec_Name);
                  end if;
               end if;
            end if;
         end;
         --  Check for a missing extension in module, and add it if needed
         --  Extensions currently checked in order: .exe, .out, .vxe

         if Exec = GNATCOLL.VFS.No_File then
            null;

         elsif Exec.Is_Regular_File then
            Self.Parameters.arguments.program := VSS.Strings.Conversions.
              To_Virtual_String
                (Ada.Strings.UTF_Encoding.UTF_8_String'
                   (+Exec.Full_Name & Get_Args));

         else
            for J in Extensions'Range loop
               Tmp := Create
                 (Full_Filename => Exec.Full_Name.all & Extensions (J));

               if Tmp.Is_Regular_File then
                  Exec := Tmp;
                  exit;
               end if;
            end loop;

            if Exec.Is_Regular_File then
               Self.Parameters.arguments.program := VSS.Strings.Conversions.
                 To_Virtual_String
                   (Ada.Strings.UTF_Encoding.UTF_8_String'
                      (+Exec.Full_Name & Get_Args));
            end if;
         end if;
      end if;
   end Initialize;

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self   : Launch_DAP_Request;
      Stream : not null access LSP.JSON_Streams.JSON_Stream'Class) is
   begin
      DAP.Tools.LaunchRequest'Write (Stream, Self.Parameters);
   end Write;

   -----------------------
   -- On_Result_Message --
   -----------------------

   overriding procedure On_Result_Message
     (Self        : in out Launch_DAP_Request;
      Stream      : not null access LSP.JSON_Streams.JSON_Stream'Class;
      New_Request : in out DAP_Request_Access)
   is
      Response : DAP.Tools.LaunchResponse;
   begin
      DAP.Tools.LaunchResponse'Read (Stream, Response);
      Launch_DAP_Request'Class
        (Self).On_Result_Message (Response, New_Request);
   end On_Result_Message;

   -----------------------
   -- On_Result_Message --
   -----------------------

   procedure On_Result_Message
     (Self        : in out Launch_DAP_Request;
      Result      : DAP.Tools.LaunchResponse;
      New_Request : in out DAP_Request_Access) is
   begin
      declare
         Map : constant DAP.Breakpoint_Maps.Breakpoint_Map :=
           DAP.Breakpoints.Get_Persistent_Breakpoints;
      begin
         if not Map.Is_Empty then
            declare
               Breakpoint : constant DAP.Requests.Breakpoints.
                 Breakpoint_DAP_Request_Access :=
                   new DAP.Requests.Breakpoints.Breakpoint_DAP_Request
                     (Self.Kernel);
            begin
               DAP.Requests.Breakpoints.Initialize (Breakpoint.all, Map);
               New_Request := DAP_Request_Access (Breakpoint);
            end;

         else
            declare
               Done : constant DAP.Requests.ConfigurationDone.
                 ConfigurationDone_DAP_Request_Access :=
                   new DAP.Requests.ConfigurationDone.
                     ConfigurationDone_DAP_Request (Self.Kernel);
            begin
               New_Request := DAP_Request_Access (Done);
            end;
         end if;
      end;
   end On_Result_Message;

   -----------------
   -- On_Rejected --
   -----------------

   overriding procedure On_Rejected (Self : in out Launch_DAP_Request) is
   begin
      Trace (Me, "Rejected");
   end On_Rejected;

   ----------------------
   -- On_Error_Message --
   ----------------------

   overriding procedure On_Error_Message
     (Self    : in out Launch_DAP_Request;
      Message : VSS.Strings.Virtual_String) is
   begin
      Self.Kernel.Get_Messages_Window.Insert_Error
        ("[Debug] " &
           VSS.Strings.Conversions.To_UTF_8_String (Message));

      Trace (Me, VSS.Strings.Conversions.To_UTF_8_String (Message));
   end On_Error_Message;

   -------------
   -- Set_Seq --
   -------------

   overriding procedure Set_Seq
     (Self : in out Launch_DAP_Request;
      Id   : LSP.Types.LSP_Number) is
   begin
      Self.Parameters.seq := Id;
   end Set_Seq;

end DAP.Requests.Launch;
