<?php
# Status module for rman using snmp
# --------------------------------------------------------------------------
# Copyright (C) 2002 Lawrence E. Baumle <larry.baumle@compaq.com>
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
WriteHeader("Active Sensor Status");

print "<h1>Active Sensor Status</h1>\n";
print "<hr>\n";

$dbh=ConnectToDb();

# Warning Level Variables
$sysdskwarn = 90;
$sysloadwarn = 2;

RunQuery($result,"SELECT sid, ip, updated, active, public_key FROM sensor WHERE active='Y'");
$row = mysql_fetch_array($result);

print "<table border=0 cellspacing=0 cellpadding=0 width='100%' BGCOLOR='#FFFFFF'>\n";

while ( $row ) {
	$sid = $row[sid];
	$sysip =  $row[ip];
	$public_key =  $row["public_key"];
	RunQuery($result2,"SELECT sid, hostname, interface FROM sensor WHERE sid=$sid");
	$line = mysql_fetch_array($result2);
	$sensorid = $line[hostname];
	$interface = $line[interface];

	$sysname = @snmpget($sysip, $public_key, 'system.sysName.0');
  	print "<tr><td><br><b><u>$sensorid</b></u></td></tr>\n";
	if (!$sysname) {
  		print "<tr><td><font color=#ff0000>Appears down. Not responding to snmp queries</font></td></tr>\n";
		}
	else {
	  	print "<tr><td width=20%>Sensor Name</td><td>$sysname</td></tr>\n";
  		print "<tr><td width=20%>Interface</td><td>$interface</td></tr>\n";
		$sysuptime = snmpget($sysip, $public_key , 'system.sysUpTime.0');
  		print "<tr><td width=20%>Uptime</td><td>$sysuptime</td></tr>\n";
		$syscpu1 = snmpget($sysip, $public_key , '.1.3.6.1.4.1.2021.10.1.3.1');
		$syscpu5 = snmpget($sysip, $public_key , '.1.3.6.1.4.1.2021.10.1.3.2');
		$syscpu15 = snmpget($sysip, $public_key , '.1.3.6.1.4.1.2021.10.1.3.3');
		if ( $syscpu1 > $sysloadwarn || $syscpu5 > $sysloadwarn || $syscpu15 > $sysloadwarn ){ $font = '<font color=#ff0000>';}
			else { $font = '';}
  		print "<tr><td width=20%>Load</td><td>$font $syscpu1,$syscpu5,$syscpu15</td></tr>\n";
		$sysmemory = round(snmpget($sysip, $public_key , '.1.3.6.1.4.1.2021.4.6.0') / 1024);
		$sysmemorytotal = round(snmpget($sysip, $public_key , '.1.3.6.1.4.1.2021.4.5.0') / 1024);

  		print "<tr><td width=20%>Free RAM/Total RAM</td><td>$sysmemory MB/$sysmemorytotal MB</td></tr>\n";

  		print "<tr><td width=20%><br>Disk Space Utilization</td></tr>\n";
		$counter=1;
		$sysdsk = @snmpget($sysip, $public_key , ".1.3.6.1.4.1.2021.9.1.2.$counter");
		while (!empty($sysdsk)){
			$sysdskused = snmpget($sysip, $public_key , ".1.3.6.1.4.1.2021.9.1.9.$counter");
			if ( $sysdskused > $sysdskwarn ){ $font = '<font color=#ff0000>';}
			else { $font = '';}
  			print "<tr><td width=20%>$font &nbsp;&nbsp;&nbsp;&nbsp;$sysdsk</td><td>$font $sysdskused %</td></tr>\n";
			$counter++;
			$sysdsk = @snmpget($sysip, $public_key , ".1.3.6.1.4.1.2021.9.1.2.$counter");
			}	

  		print "<tr><td width=20%><br>Processes</td></tr>\n";
		$counter=1;
		$sysproc = @snmpget($sysip, $public_key, ".1.3.6.1.4.1.2021.2.1.2.$counter");
		while (!empty($sysproc)){
			$sysprocstatus = snmpget($sysip, $public_key, ".1.3.6.1.4.1.2021.2.1.101.$counter");
			if (empty($sysprocstatus)){$sysprocstatus = "Process is running";}
  			print "<tr><td width=20%>&nbsp;&nbsp;&nbsp;&nbsp;$sysproc</td><td>$sysprocstatus</td></tr>\n";
			$counter++;
			$sysproc = @snmpget($sysip, $public_key, ".1.3.6.1.4.1.2021.2.1.2.$counter");
			}
		}
	$row = mysql_fetch_array($result);
	}
print "</table>";
mysql_close($dbh);

?>
    <HR>
  </BODY>
</HTML>

