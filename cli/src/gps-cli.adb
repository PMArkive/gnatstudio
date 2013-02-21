------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2001-2013, AdaCore                     --
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
--  Driver for command line version of GPS

with GPS.CLI_Kernels;
with GPS.Core_Kernels;
with GPS.Python_Core;

procedure GPS.CLI is
   Kernel : aliased GPS.CLI_Kernels.CLI_Kernel;
begin
   GPS.Core_Kernels.Initialize (Kernel'Access);
   GPS.Python_Core.Register_Python (Kernel'Access);

   --  Destroy all
   GPS.Core_Kernels.Destroy (Kernel'Access);
end GPS.CLI;
