<?php
# --------------------------------------------------------------------------
# Copyright (C) 2002 Mark Vevers <mark@vevers.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# --------------------------------------------------------------------------

  include_once("rman_common.inc");
  session_start();
  session_destroy();

  WriteHeader("");

  $dbh=ConnectToDb();

  GetActive($active, $notactive);

  print "<table border=0 cellspacing=0 cellpadding=0 width='100%' BGCOLOR='#FFFFFF'>\n";
  print "<TR><TD>Active Rules: $active</TD></TR>\n";
  print "<TR><TD>Inactive Rules: $notactive</TD></TR>\n";
  print "</TABLE>\n";
  print "<HR>\n";
  
  print "<table border=0 cellspacing=0 cellpadding=0 width='100%' BGCOLOR='#FFFFFF'>\n";
  print "<TR><TD><A HREF='rman_sensor.php'>Sensor Maintenance</A></TD></TR>\n";
  print "<TR><TD><A HREF='rman_group.php'>Rule Group Maintenance</A></TD></TR>\n";
  print "<TR><TD><A HREF='rman_vars.php'>Variable Maintenance</A></TD></TR>\n";
  print "<TR><TD><A HREF='rman_preprocessors.php'>Preprocessor Maintenance</A></TD></TR>\n";
  print "<TR><TD><A HREF='rman_status.php'><br>Sensor Status</A></TD></TR>\n";
  print "</TABLE>\n";

  mysql_close($dbh);

?>
    <HR>
  </BODY>
</HTML>


<?php
?>
