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
  include_once("rman_formclasses.inc");

  $dbh=ConnectToDb();

  if ($HTTP_POST_VARS["submit"]) {
    $submit=$HTTP_POST_VARS["submit"];
    if ($submit=="Update Groups") {
        WriteHeader("Sensor Maintenance");
	UpdateSensorGroups($HTTP_POST_VARS["sid"],$HTTP_POST_VARS["sengrp_chkbx"]);
        mod_sensor($HTTP_POST_VARS["sid"]);
    }
    if ($submit=="Update Sensor Info") {
        WriteHeader("Sensor Maintenance");
	UpdateSensorInfo($HTTP_POST_VARS["sid"],$HTTP_POST_VARS["ip"],$HTTP_POST_VARS["string"]);
        mod_sensor($HTTP_POST_VARS["sid"]);
    }
    if ($submit=="Add Sensor") {
        WriteHeader("Sensor Maintenance - Activate Sensors");
        AddSensors();
    }
    if ($submit=="Activate") {
        WriteHeader("Sensor Maintenance - Activate Sensors");
        ActivateSensors($HTTP_POST_VARS["grpnew_sensor"]);
        AddSensors();
    }
  }
  else {
    if ($HTTP_GET_VARS['sid']) {
      WriteHeader("Sensor Maintenance");
      mod_sensor($HTTP_GET_VARS['sid']);
    }
    else {
      if ($HTTP_GET_VARS['senwgrp']) {
        $rgid=$HTTP_GET_VARS['senwgrp'];
	if (is_numeric($rgid)) {
	   $rgid=mysql_escape_string($rgid);
	   grp_showsensors($rgid);
	}
      }
      else {
        WriteHeader("Sensor Maintenance - Active Sensors");
        list_sensors();
      }
    } 
  }
  mysql_close($dbh);

?>
    <HR>
  </BODY>
</HTML>


<?php

function grp_showsensors($rgid) {
  WriteHeader("Sensor Maintenance - Sensor by Group");

  RunQuery($result,"SELECT name FROM rman_rgroup WHERE rgid='".$rgid."'");
  if (mysql_num_rows($result)==0) {
    PrintError("Invalid Group Supplied");
    return;
  }
  $row = mysql_fetch_object($result);
  $grpname = $row->name;

  print "<H2> Sensors with group: ".$grpname."</H2>\n";

  print "<P>Back to <A HREF='rman_group.php?rgid=".$rgid."'>Group Maintenance</A></P>\n";

  RunQuery($result,"SELECT sensor.sid AS sid, sensor.hostname AS host, sensor.interface AS intf FROM sensor, rman_senrgrp WHERE rman_senrgrp.rgid='".$rgid."' AND rman_senrgrp.sid=sensor.sid");

  
  

  $form=new html_tableform("senwgrp","post","rman_sensor.php");
  $form->outertable=true;
  $form->stripe=true;
  $form->width=60;

  $form->AddColumn(" ID ","plfieldhdr",10);
  $form->AddColumn(" Sensor Name ","plfieldhdr",80);

  while ($row = mysql_fetch_array($result, MYSQL_ASSOC)) {
    $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;" . $row["sid"],"CENTER"));
    $form->AddRowElem(new html_RowElem("<font><A HREF='rman_sensor.php?sid=" . $row["sid"] . "'>".$row["host"]." - " . $row["intf"] ."</font>&nbsp;","CENTER"));
    $form->EndRow();
  }
  $form->Print_HTML();
}

function ActivateSensors($sensors) {
  foreach($sensors as $sid => $active) {
    if ($active=='Y') {
      RunQuery($result,"INSERT INTO sensor (sid,updated,active) VALUES ('".mysql_escape_string($sid)."',NULL,'Y')");
    }
  }
}


#function AddSensors() {
#  RunQuery($result,"select sensor.sid AS sid, sensor.hostname AS host, sensor.interface AS intf FROM sensor WHERE sensor.sid is NULL");
#  print "<A HREF=\"rman_sensor.php\">Return to Sensor Maintenance</A>\n";
#  print "<H2> Add New Sensors</H2>\n";
#  $form=new html_tableform("NewSensors","post","rman_sensor.php");
#  $form->AddAction("Activate","submit","submit");
#  $form->outertable=true;
#  $form->stripe=true;
#  $form->width=60;

#  $form->AddColumn(" ID ","plfieldhdr",10);
#  $form->AddColumn(" Sensor Name ","plfieldhdr",80);
#  $form->AddColumn(" Active ","plfieldhdr",10);

#  while ($row = mysql_fetch_array($result, MYSQL_ASSOC)) {
#    $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;" . $row["sid"],"CENTER"));
#    $form->AddRowElem(new html_RowElem($row["host"]." - " . $row["intf"],"CENTER"));
#    $form->AddRowElem(new html_RowElemTickBox($row['sid'],"grpnew_sensor",'N'));
#    $form->EndRow();
#  }
#  $form->Print_HTML();
#}

function list_sensors() {

  RunQuery($result,"SELECT sensor.sid AS sid, sensor.hostname AS host, sensor.interface AS intf, sensor.active AS active FROM sensor");

  $form=new html_tableform("SensorForm","post","rman_sensor.php");
  $form->AddAction("Add Sensor","submit","submit");
  #$form->AddAction("Update","submit","submit");
  $form->outertable=true;
  $form->stripe=true;
  $form->width=60;

  $form->AddColumn(" ID ","plfieldhdr",10);
  $form->AddColumn(" Sensor Name ","plfieldhdr",80);
 # $form->AddColumn(" Active ","plfieldhdr",10);

  while ($row = mysql_fetch_array($result, MYSQL_ASSOC)) {
    $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;" . $row["sid"],"CENTER"));
    $form->AddRowElem(new html_RowElem("<font><A HREF='rman_sensor.php?sid=" . $row["sid"] . "'>".$row["host"]." - " . $row["intf"] ."</font>&nbsp;","CENTER"));
#    $form->AddRowElem(new html_RowElemTickBox($row['rid'],"grprule_chkbox[".$row["host"]."]",$row['active']));
    $form->EndRow();
  }
  $form->ExportVar("sid",$sid);
  $form->Print_HTML();
}

function mod_sensor($sid) {
  $sid=sanitizeUserInput($sid,"int",11);
  $sensname=GetSensorName($sid);
  $sensip=GetSensorIP($sid);
  $sensstring=GetSensorPublicKey($sid);
  RunQuery($resgrp,"SELECT rgid,name,description FROM rman_rgroup ORDER BY name");
  GetSensorGroups($sid,$sgrps);

  print "<form METHOD='post' NAME='SensorGroupForm' ACTION='rman_sensor.php'>\n";
  print "<div align='LEFT'>";
  print "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=800 BGCOLOR='#FFFFFF' >\n";
  print "<TR><TD width='200'><B>Sensor Name:</B></TD><TD>$sensname</TD></TR>\n";
  print "<TR><TD width='200'><B>Sensor IP:</B></TD><TD><input TYPE='test' SIZE='15' NAME='ip' Value=$sensip></TD></TR>\n";
  print "<TR><TD width='200'><B>SNMP Community String:</B></TD><TD><input TYPE='test' SIZE='25' NAME='string' Value=$sensstring></TD></TR>\n";
  print "<TR><TD></TD><TD ALIGN='RIGHT'><input TYPE='submit' NAME='submit' VALUE='Update Sensor Info'><input TYPE='submit' NAME='submit' VALUE='Update Groups'></TD></TR>\n";
  print "</TABLE>\n";
  print "</div>\n";

  print "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=800 BGCOLOR='#FFFFFF' >\n";
  print "<TR>\n";
  print "<TD CLASS='plfieldhdrleft' WIDTH='35%'> Group Name </TD>\n";
  print "<TD CLASS='plfieldhdrleft' WIDTH='50%'> Description </TD>\n";
  print "<TD CLASS='plfieldhdr'> Active </TD>\n";
  print "</TR>\n";
  $odd=0;
  while ($row = mysql_fetch_array($resgrp, MYSQL_ASSOC)) {
    $odd = $odd ^ 1;
    if ($odd) {
        print "<TR BGCOLOR='#DDDDDD'>\n";
    }
    else {
        print "<TR BGCOLOR='#FFFFFF'>\n";
    }
    print "\t<TD ALIGN=LEFT><font>&nbsp;<A HREF='rman_group.php?rgid=" . $row["rgid"] . "'>".$row["name"]; 
    print "&nbsp;</TD>\n";
    print "\t<TD ALIGN=LEFT>&nbsp;&nbsp;" . $row["description"] . "</TD>\n";
    print "\t<TD ALIGN=CENTER>&nbsp;\n";
    print "<input TYPE='hidden' NAME='sengrp_chkbx[" . $row["rgid"] . "]' VALUE='N'>";
    print "<input TYPE='checkbox' NAME='sengrp_chkbx[" . $row["rgid"] . "]' VALUE='Y'";
    if ($sgrps[$row["rgid"]]=="Y") {
      print " CHECKED=1 >";
    }
    else {
      print " >";
    }
    print "</TR>\n";
  }
  print "</TABLE>\n";
  ExportVar("sid",$sid);
  print "</form>\n";

}

function UpdateSensorGroups($sid,$chkboxes) {
  GetSensorGroups($sid, $sgrps);
  $changed=false;
  foreach($chkboxes as $rgid => $active) {
    if ($sgrps[$rgid] != $active) {
      $changed=true;
      if ($active=='Y') {
         RunQuery($result,"INSERT INTO rman_senrgrp (sid,rgid) VALUES (".$sid.",".$rgid.")");
      }
      else {
         RunQuery($result,"DELETE FROM rman_senrgrp WHERE sid=".$sid." AND rgid=".$rgid);
      }
    }
  }
  if ($changed) UpdateSensorTime_Sid($sid);
}

function UpdateSensorInfo($sid,$ip,$string) {
	RunQuery($result,"UPDATE sensor SET ip='$ip',public_key='$string' WHERE sid=".$sid);
	}

?>
