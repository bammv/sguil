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

# Control Contstants for print classes
define("_PRINT", 0);
define("_EDIT", 1);

$debug=0;
$dbuser="dbuser";
$dbpass="dbpass";
$dbserver="dbhost";
$dbname="sguildb";

##################################################################################################
function SanitizeUserInput($input,$type="nothing",$maxlen=255, $modified=false) {
  # Limit string size immediately
  $inlen=strlen($input);
  $input=substr($input,0,$maxlen);
  $input=stripslashes($input);
  $inlen=strlen($input);
  $modified=false;

  switch ($type) {
    case "plaintext":
      $input=CleanString($input);
      break;
    case "description":
      $input=CleanString($input,"([0-9a-zA-Z]|-|[(). #,_:])");
      break;
    case "int":
      $input=CleanString($input,"([0-9])");
      break;
    case "s_int":
      $input=CleanString($input,"([0-9]|-)");
      break;
    case "snort_ip":
      $input=CleanString($input,"([0-9a-zA-Z]|\[|\]|[.,/!&|]|\$)");
      break;
    case "nothing": 
    default:
  }
  if (strlen($input) != $inlen) $modified=true;
  return($input);
}

function CleanString($string, $allowregex="([0-9a-zA-Z]|-|[_:])") {
  $chars = preg_split('//', $string, -1, PREG_SPLIT_NO_EMPTY);
  $chars = preg_grep($allowregex,$chars);
  return(join("",$chars));
}

function snortescape($string) {
  global $debug;
  $nchar=strlen($string);
  $pos=0;
  $escaped=false;
  $outstring="";

  while ($pos < $nchar) {
    $char=substr($string,$pos,1);
    switch ($char) {
      case "\\":
        if ($escaped) {
          $escaped=false;
        } 
        else {
          $escaped=true;
	}
	$outstring .= $char;
	break;
      case "\"":
      case ";":
      case ":":
        if ($escaped) {
          $outstring .= $char;
	  $escaped=false;
	}
	else {
	  $outstring .= "\\" . $char;
	}
	break;
      default:
        $outstring .= $char;
        $escaped=false;
    }
    $pos++;
  }
  if ($debug) print "<BR> String $string, Outstring $outstring\n";
  return($outstring);
}

function PrintError($message) {
  print "<P><B><BR>*** ERROR ***</B> $message</P>\n";
}

function session_must_be_registered($varname) {
  if (!session_is_registered($varname)) {
    session_destroy();
    print "<BR> Data Received, session destroyed\n";
    return(false);
  }
  return(true);
}

function GetActive(&$active, &$notactive) {

  RunQuery($result,"select active,COUNT(*) AS num FROM rman_rules GROUP BY active");
  $notactive=0;
  $active=0;
  while($summary=mysql_fetch_array($result, MYSQL_ASSOC)) {
    if ($summary['active']=="Y") {
       $active=$summary['num'];
    }
    else {
       $notactive=$summary['num'];
    }

  }
}

function ConnectToDb() {
 global $dbuser,$dbpass,$dbserver,$dbname;
 $dbh = @mysql_connect($dbserver, $dbuser, $dbpass);
  if (!$dbh) {
    echo "Unable to connect to Database Server!<BR>";
    exit();
  }

  $rtdb = @mysql_select_db($dbname, $dbh);
  if (!$rtdb) {
    echo "Unable to connect to Database!<BR>";
    exit();
  }
  return $dbh;
}

function RunQuery(&$res, $query) {
  $res = mysql_query($query);
  if (!$res) {
    echo ("Error performing query: " . mysql_error() . "<BR>");
    exit();
  }
}

#------------------------------------------------------------------------
# Time Stamp Management Code 
# These routines get called to update the sensor timestamps to provoke a
# new download of the ruleset

function UpdateAllActiveSensors() {
  RunQuery($sensorlist,"SELECT sid FROM sensor WHERE active='Y'");
  UpdateSensorTimeStamps($sensorlist);
}

function Group_UpdateTimeStamps($rgid) {
  RunQuery($sensorlist,"SELECT sid FROM rman_senrgrp WHERE rgid='".$rgid."'");
  UpdateSensorTimeStamps($sensorlist);
}

function Rule_UpdateTimeStamps($rid) {
  RunQuery($sensorlist,"SELECT sid FROM rman_senrgrp, rman_rrgid WHERE rman_senrgrp.rgid=rman_rrgid.rgid AND rid = '".$rid."'");
  UpdateSensorTimeStamps($sensorlist);
}

function UpdateSensorTimeStamps($sensorlist) {
  while ($row = mysql_fetch_array($sensorlist, MYSQL_ASSOC)) {
    RunQuery($result,"UPDATE sensor SET updated = NULL WHERE sid = '".$row["sid"]."'");
  }
}

function UpdateSensorTime_Sid($sid) {
  RunQuery($result,"UPDATE sensor SET updated = NULL WHERE sid = '".$sid."'");
}

#---------------------------------------------------------------------------
#
function GetSensorName($sid) {
  RunQuery($result,"SELECT hostname,interface FROM sensor WHERE sid=".$sid);
  $row = mysql_fetch_array($result, MYSQL_ASSOC);
  return $row["hostname"] . " - " . $row["interface"];
} 

function GetSensorGroups($sid, &$sgrps) {
  # Get Current Group Id's
  RunQuery($grpids, "SELECT rgid FROM rman_rgroup");
  
  # Get Group Id's to which sensor belongs; 
  RunQuery($activgrps, "SELECT rgid FROM rman_senrgrp WHERE sid=".$sid);

  while ($row=mysql_fetch_array($grpids, MYSQL_NUM)) {
    $sgrps[$row[0]]="N";
  }
  
  while ($row=mysql_fetch_array($activgrps, MYSQL_NUM)) {
    $sgrps[$row[0]]="Y";
  }
}

function ExportVar($name,$value) {
  echo "<INPUT TYPE=\"hidden\" NAME=\"$name\" VALUE=\"$value\">\n";
}

function WriteHeader($header,$begin="",$homeref="") {

  if ($homeref=="") {
    $homeref="<A HREF=\"rman_index.php\">Home</A>";
  }
  if ($begin=="") {
    $begin="RMAN";
  }
  if ($header=="") {
    $header="Rule MANagement for Snort";
    $begin="&nbsp;";
    $homeref="&nbsp;";
  } 

  print "<HTML>\n  <HEAD>\n    <TITLE>Snort Rule MANager</TITLE>\n";
  echo "<link rel=\"stylesheet\" type=\"text/css\" href=\"rman.css\">\n";
  print "</HEAD>\n<BODY>\n";
  

  echo "<table width=\"100%\" border=0 cellspacing=0 cellpadding=5>\n";
  print "  <tr><td width=\"1%\" class=\"mainheader\">$begin</td><td class=\"mainheadertitle\">\n";
  print "  $header</td><td width='5%' class=\"mainheader\">$homeref</TD></tr>\n</table>\n";

  print "<p>\n";
}
function ColourOddEven(&$odd) {
    $odd = $odd ^ 1;
    if ($odd) {
        $colour="#DDDDDD";
    }
    else {
        $colour="#FFFFFF";
    }
  return $colour;
}


function GetSensorIP($sid) {
   RunQuery($result,"SELECT ip FROM sensor WHERE sid=$sid");
   $row=mysql_fetch_object($result);
   return($row->ip);
}


function GetSensorPublicKey($sid) {
   RunQuery($result,"SELECT public_key FROM sensor WHERE sid=$sid");
   $row=mysql_fetch_object($result);
   return($row->public_key);
}	 


?>
