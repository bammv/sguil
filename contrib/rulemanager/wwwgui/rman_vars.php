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

  global $debug;
  session_start();

  $handled=false;

  $dbh=ConnectToDb();
  $debug=0;

  if ($debug) {
     print "<P>\n";
     print_r($HTTP_GET_VARS);
     print "<BR>\n";
     print_r($HTTP_POST_VARS);
     print "<BR>\n";
     print_r($HTTP_SESSION_VARS);
     print "</P>\n";
  }

  if (isset($HTTP_POST_VARS['showvid_submit']) && !$handled) {
    $svsubmit=SanitizeUserInput($HTTP_POST_VARS['showvid_submit'],"plaintext");
    if ($debug) print "<BR>$svsubmit\n";
    
    $vid=SanitizeUserInput($HTTP_GET_VARS['vid'],"int",11,&$modified);
    
    switch ($svsubmit) {
      case "AddNewfor":
        if (!$modified) $sid=SanitizeUserInput($HTTP_POST_VARS['action_choice'],"int",11,&$modified);
	if (!$modified) { 
	  vars_sv_addnew($vid,$sid);
        }
	else {
	  PrintError("Invalid Submission Received for Add New");
	}
	break;

      case "DeleteSelected":
	if (!$modified) vars_sv_delete($vid,$HTTP_POST_VARS['showvid_select']);
	break;

      case "Update":
        if (!$modified) vars_updatedefaults($vid,$HTTP_POST_VARS['defvalue'],$HTTP_POST_VARS['defcomment']);
        break;
       
      case "Delete":
        if (!$modified) vars_deletevar($vid);
        # this vid just bit the dust so we can't display it - return to show_main
	unset($HTTP_GET_VARS['vid']);
	break;
      
      case "UpdateSensors":
        if (!$modified) vars_updatesenvars($vid,$HTTP_POST_VARS['vid_val'],$HTTP_POST_VARS['vid_com']);
        break;
	
      default:
      PrintError("Invalid Submission Received");
    }
      
  }

  if (isset($HTTP_GET_VARS['vid']) && !$handled) {
     $vid=SanitizeUserInput($HTTP_GET_VARS['vid'],"int",11,&$modified);
     if ((!$modified) && $vid!=0) {
       vars_showvid($vid);
       $handled=true;
     }
     else {
       PrintError("Invalid User Input Detected");
     }
  }
  
  if (isset($HTTP_POST_VARS['create_submit']) && !$handled) {
    $createsubmit=SanitizeUserInput($HTTP_POST_VARS['create_submit'],"plaintext");
    switch ($createsubmit) {
      case "Create":
        $handled=vars_createnew($HTTP_POST_VARS['name'],$HTTP_POST_VARS['value'],$HTTP_POST_VARS['comment']);
        break;
    
      case "Cancel":
        break;
      default:
      PrintError("Invalid Submission Received");
    }
  }

  if (isset($HTTP_POST_VARS['main_submit']) && !$handled) {
    $mainsubmit=SanitizeUserInput($HTTP_POST_VARS['main_submit'],"plaintext");
    switch ($mainsubmit) {
      case "CreateNew":
        vars_showcreatenew();
	$handled=true;
      break;
      case "DeleteSelected":
        if (isset($HTTP_POST_VARS['vars_select'])) vars_maindelselect($HTTP_POST_VARS['vars_select']);
        break; 
      default:
      PrintError("Invalid Submission Received");
    }
  }
  
  if (!$handled) {
     vars_showmain();
  }

  mysql_close($dbh);
?>
    <HR>
  </BODY>
</HTML>


<?php

function vars_deletevar($vid) {
  if ($vid>=100) {
    RunQuery($result,"DELETE FROM rman_vars WHERE vid='".$vid."'");
    RunQuery($result,"DELETE FROM rman_varvals WHERE vid='".$vid."'");
    UpdateAllActiveSensors();
  }
}

function vars_updatedefaults($vid,$value,$comment) {
  vars_sv_sessinit($vid,$sensors,$defaults,$senvars,&$restored);
  
  $modified=!$restored;
  if (!$modified) $value=SanitizeUserInput($value,"snort_ip",255,&$modified);
  if (!$modified) $comment=SanitizeUserInput($comment,"description",255,&$modified);
  if (!$modified) {
    if (($value != $defaults->value) || ($comment != $defaults->comment)) {
      vars_update($vid,0,$value,$comment);
      
      # Now Get List of  Sensors which use default and update timestampes
      RunQuery($senslist,"SELECT sensor.sid FROM sensor LEFT JOIN rman_varvals ON (sensor.sid=rman_varvals.sid AND vid='".$vid."') WHERE rman_varvals.sid IS NULL");
      UpdateSensorTimeStamps($senslist);
      
      if (session_is_registered("s_vid")) session_unregister("s_vid");
    }
  }
  if ($modified) {
     printerror("Invalid User Input Detected $value - $comment");
  }
}

function vars_updatesenvars($vid,$values,$comments) {
  vars_sv_sessinit($vid,$sensors,$defaults,$senvars,&$restored);
  if (count($values) && $restored) {
    $updated=false;
    foreach($values AS $sid => $value) {
      $sid=SanitizeUserInput($sid,"int",11,&$modified); 
      if (($sid!=0) && !$modified) {
        $value=SanitizeUserInput($value,"snort_ip",255,&$modified);
        if (!$modified) $comment=SanitizeUserInput($comments[$sid],"description",255,&$modified);
	if ((($senvars[$sid]->value!=$value) || ($senvars[$sid]->comment!=$comment)) && !$modified)  {
          vars_update($vid,$sid,$value,$comment);
	  UpdateSensorTime_Sid($sid);
	  $updated=true;
	}
      }
      if ($modified) printerror ("Failed update for".$sensors[$sid].". Invalid User Input Detected");
    }
    if ($updated) {
      if (session_is_registered("s_vid")) session_unregister("s_vid");
    }
  }

  if (!$restored) printerror("Unable to restore session - can't update variables");
}


function vars_update($vid,$sid,$value,$comment) {
  RunQuery($result,"UPDATE rman_varvals SET value='".mysql_escape_string($value)."', comment='".mysql_escape_string($comment)."' WHERE vid='".$vid."' AND sid='".$sid."'");
}

function vars_sv_delete($vid,$selected) {

  $deleted=false;
  
  vars_sv_sessinit($vid,$sensors,$defaults,$senvars,&$restored);
  
  if ($restored) {
    foreach($selected as $sid => $select) {
      $sid=SanitizeUserInput($sid,"int",11,&$modified);
      if (!$modified && $sid!=0 && $select=='Y') {
         RunQuery($result,"DELETE FROM rman_varvals WHERE sid='".$sid."' AND vid='".$vid."'");
         $deleted=true;
	 UpdateSensorTime_Sid($sid);
      }
    }
  }
  if ($deleted || !$restored) session_unregister("s_vid");
}

function vars_sv_addnew($vid,$sid) {
  if ($sid==0) {
    PrintError("Please Select A Sensor!");
    return;
  }

  vars_sv_sessinit($vid,$sensors,$defaults,$senvars,&$restored);

  if ($restored) {
    if (!isset($senvars[$sid])) {
      # OK - there shouldn't be a variable present according to the session
      # but we had better check just in case someone else is tinkering!

      RunQuery($result,"SELECT value FROM rman_varvals WHERE sid='".$sid."' AND vid='".$vid."'");
      if (mysql_num_rows($result)==0) {
         RunQuery($result,"INSERT INTO rman_varvals (vid,sid,value,comment) VALUES ('".$vid."','".$sid."','".$defaults->value."','".$defaults->comment."')");
      }
      else {
        PrintError("Somebody else added the variable for this sensor while you weren't looking!");
      }
      session_unregister("s_vid");      # Unregister s_vid to force var refresh to pick up new one!
    }
    else {
      PrintError("Sensor already has variable defined - can't add new!");
    }
  }
  else {
    PrintError("Session Error - Clearing Session");
    session_unregister("s_vid");
  }
}

function vars_sv_sessinit(&$vid,&$sv_sensors,&$sv_defdata,&$sv_senvars,$ses_restored=false) {
  global $HTTP_SESSION_VARS;
  $ses_restored=false;
  if (session_is_registered("s_vid")) {
    $s_vid=$HTTP_SESSION_VARS["s_vid"];
    if ($s_vid == $vid) {
      $sv_sensors=$HTTP_SESSION_VARS["sv_sensors"];
      $sv_defdata=$HTTP_SESSION_VARS["sv_defdata"];
      $sv_senvars=$HTTP_SESSION_VARS["sv_senvars"];
      $ses_restored=true;
    }
  }

  if (!$ses_restored) {
    if (!session_is_registered("s_vid")) session_register("s_vid");
    if (!session_is_registered("sv_sensors")) session_register("sv_sensors");
    if (!session_is_registered("sv_defdata")) session_register("sv_defdata");
    if (!session_is_registered("sv_senvars")) session_register("sv_senvars");
    
    $HTTP_SESSION_VARS["s_vid"]=$vid;

    # Get Default value and check variable exists
    RunQuery($result,"SELECT vname,value,comment,updated FROM rman_vars,rman_varvals WHERE rman_vars.vid=rman_varvals.vid AND sid=0 AND rman_vars.vid='".$vid."'");
    if (mysql_num_rows($result)==0) {
      PrintError("Invalid variable identifier given");
      session_unset("s_vid");
      $vid=0;
      return;
    }
    $sv_defdata = mysql_fetch_object($result);
    $HTTP_SESSION_VARS["sv_defdata"]=$sv_defdata;
    
    # Populate sv_sensors
    RunQuery($allsensres,"SELECT sensor.sid, hostname, interface FROM sensor");
    $sv_sensors=array();
    while ($row = mysql_fetch_object($allsensres)) {
      $sv_sensors[$row->sid]=$row->hostname." - ".$row->interface;
    }
    $HTTP_SESSION_VARS["sv_sensors"]=$sv_sensors;

    # Get sensor specific vars into array
    $sv_senvars=array();
    RunQuery($senres,"SELECT sid, value, comment, updated FROM rman_vars, rman_varvals WHERE rman_vars.vid=rman_varvals.vid AND sid != 0 AND rman_vars.vid='".$vid."' ORDER BY sid");
    while ($senvar = mysql_fetch_object($senres)) {
      $sv_senvars[$senvar->sid]=$senvar;
    }
    $HTTP_SESSION_VARS["sv_senvars"]=$sv_senvars;
  }
}

function vars_showvid($vid) {
  # vid has been sanitized to be a postive integer  only before entry to 
  # this procedure.  Further checking it not required.
  
  WriteHeader("Variable Maintenace - Variable Definition");

  # Initialize the session
  vars_sv_sessinit(&$vid,&$sensors,&$defdata,&$senvars);
  
  # $vid=0 if invalid $vid passed
  if ($vid==0) return;

  print "<H2>Variable: ".$defdata->vname."</H2>\n";
  print "<A HREF='rman_vars.php'>Return to Variable Maintenance</A>\n";

  $defaults = new html_tableform("var_view","post","rman_vars.php?vid=".$vid);

  # Add delete option if no sensors have their own copy of this var
  if (count($senvars)==0 && $vid>=100) $defaults->AddAction("Delete","showvid_submit","submit");
  $defaults->AddAction("Update","showvid_submit","submit");
  $defaults->width=55;
 
  
  $rowelem=new html_RowElem("Value&nbsp;","LEFT","");
  $rowelem->width="25%";
  $defaults->AddRowElem($rowelem);
  $defaults->AddRowElem(new html_RowElem($defdata->value,"LEFT","","defvalue",60,255));
  $defaults->EndRow();
  
  $defaults->AddRowElem(new html_RowElem("Comment&nbsp;","LEFT",""));
  $defaults->AddRowElem(new html_RowElem($defdata->comment,"LEFT","","defcomment",60,255));
  $defaults->EndRow();
  
  $var_sens = new html_tableform();
  $var_sens->outertable=true;
  $var_sens->stripe=true;
  $var_sens->width=80;

  $var_sens->AddAction("Add New for","showvid_submit","submit");
  $sensors[0]="{Select Sensor}";
  $var_sens->AddActionChooser($sensors); 
  $var_sens->AddAction("Delete Selected","showvid_submit","submit");
  $var_sens->AddAction("Update Sensors","showvid_submit","submit");

  $var_sens->AddColumn(" Sensor ","plfieldhdrleft",25);
  $var_sens->AddColumn(" Value ","plfieldhdrleft",35);
  $var_sens->AddColumn(" Comment ","plfieldhdrleft",35);
  $var_sens->AddColumn(" Select ","plfieldhdr",5);
  
  if (count($senvars)) {
    foreach ($senvars as $senvar) {
      $var_sens->AddRowElem(new html_RowElem($sensors[$senvar->sid],"LEFT",""));
      $var_sens->AddRowElem(new html_RowElem($senvar->value,"LEFT","","vid_val[".$senvar->sid."]",40,255));
      $var_sens->AddRowElem(new html_RowElem($senvar->comment,"LEFT","","vid_com[".$senvar->sid."]",40,255));
      $var_sens->AddRowElem(new html_RowElemTickBox($senvar->sid,"showvid_select",'N'));
      $var_sens->EndRow();
    }
  }

  $defaults->Print_HTMLhdr();
  print "<P><H2>Defaults</H2>\n";
  $defaults->Print_HTML_Actions();
  $defaults->Print_HTML_Table();
  $defaults->Print_HTMLexports();
  print "</P><BR>\n";

  print "<P><H2>Per Sensor Variations</H2>\n";
  $var_sens->Print_HTML_Actions();
  $var_sens->Print_HTML_Table();
  print "</P>\n";
  
  print "</FORM>\n";
  
}

function vars_createnew($name, $value, $comment) {
  $name=SanitizeUserInput($name,"plaintext",30,&$modname);
  $value=SanitizeUserInput($value,"snort_ip",255,&$modval);
  $comment=SanitizeUserInput($comment,"description",255,&$modcomment);

  # OK - if vars were modified return the page with edited vars on and ask user to confirm
  if ($modname || $modval || $modcomment) {
    vars_showcreatenew($name,$value,$comment,"Invalid User Input Removed - Click 'Create' to confirm creation");
    return(true);
  }
  
  # We have clean vars so check to see if name already exists
  RunQuery($result,"SELECT vid FROM rman_vars WHERE vname='".$name."'");
  if (mysql_num_rows($result)!=0) {
    vars_showcreatenew($name,$value,$comment,"Variable Already Exists");
    return(true);
  }
  
  # Ok, it doesn't - lets create it ......
  RunQuery($result,"INSERT INTO rman_vars (vname) VALUES ('".$name."')");
  $vid=mysql_insert_id();
  RunQuery($result,"INSERT INTO rman_varvals (vid,sid,value,comment) VALUES ('".$vid."', 0, '".mysql_escape_string($value)."','".mysql_escape_string($comment)."')");
  # Now update sensors ....
  UpdateAllActiveSensors();
  return(false);
}


function vars_showcreatenew($name="",$value="Default Value",$comment="Default Comment",$errmess="") {
  WriteHeader("Variable Maintenace - Create New");

  if ($errmess != "") PrintError($errmess);
  
  print "<P><H2>Create New Variable\n";
  $newvar = new html_tableform("var_createnew","post","rman_vars.php");
  $newvar->AddAction("Create","create_submit","submit");
  $newvar->AddAction("Cancel","create_submit","submit");
  $newvar->width=55;
  
  $rowelem=new html_RowElem("Name&nbsp;","LEFT","");
  $rowelem->width="25%";
  $newvar->AddRowElem($rowelem);
  $newvar->AddRowElem(new html_RowElem($name,"LEFT","","name",30,30));
  $newvar->EndRow();
  
  $newvar->AddRowElem(new html_RowElem("Value&nbsp;","LEFT",""));
  $newvar->AddRowElem(new html_RowElem($value,"LEFT","","value",30,255));
  $newvar->EndRow();

  $newvar->AddRowElem(new html_RowElem("Comment&nbsp;","LEFT",""));
  $newvar->AddRowElem(new html_RowElem($comment,"LEFT","","comment",60,255));
  $newvar->EndRow();
	      
  $newvar->Print_HTML();
  print "</P>\n";
}

function vars_maindelselect($selected) {
  foreach($selected AS $vid => $select) {
    if ($select=='Y') {
      $vid=SanitizeUserInput($vid,"int",11,&$modified);
    
      if (!$modified) {
        RunQuery($senres,"SELECT vname FROM rman_vars, rman_varvals WHERE rman_vars.vid=rman_varvals.vid AND sid != 0 AND rman_vars.vid='".$vid."' ORDER BY sid");
	if (mysql_num_rows($senres)==0) {
	  vars_deletevar($vid);
	}
	else {
	  $ivn = mysql_fetch_object($senres);
	  printerror("Unable to delete variable: ".$ivn->vname." - Per Sensor Variations Still Exist!");
	}
      }
    }
  }
}

function vars_showmain() {
  WriteHeader("Variable Maintenace");

  print "<P><H2>Default Variables</H2></P>\n";

  print "<BR> N.B. You can not delete the base variables used by the official Snort ruleset\n"; 
  $vars = new html_tableform("var_summary","post","rman_vars.php");
  $vars->outertable=true;
  $vars->stripe=true;
  $vars->AddAction("Create New","main_submit","submit"); 
  $vars->AddAction("Delete Selected","main_submit","submit"); 
 
  $vars->AddColumn("Variable Name","plfieldhdrleft",15);
  $vars->AddColumn("Default Value","plfieldhdrleft",40);
  $vars->AddColumn("Comment","plfieldhdrleft",40);
  $vars->AddColumn("Select","plfieldhdr",5);

  RunQuery($result,"SELECT rman_vars.vid, vname,value,comment FROM rman_vars NATURAL JOIN rman_varvals WHERE sid=0 ORDER BY rman_vars.vid"); 
 
  While ($row = mysql_fetch_object($result)) {
    $vars->AddRowElem(new html_RowElem("&nbsp;<font><A HREF='rman_vars.php?vid=" . $row->vid . "'>".$row->vname."</font>&nbsp;","LEFT"));
    $val=substr($row->value,0,45).((strlen($row->value) > 45) ? " ..." : "");
    $vars->AddRowElem(new html_RowElem("&nbsp;" . $val,"LEFT")); 
    $vars->AddRowElem(new html_RowElem("&nbsp;" . $row->comment,"LEFT")); 
    if ($row->vid >= 100) {
      $vars->AddRowElem(new html_RowElemTickBox($row->vid,"vars_select",'N'));
    }
    else {
        $vars->AddRowElem(new html_RowElem("&nbsp;N/A","CENTER")); 
    }	
    $vars->EndRow();
  }
  $vars->Print_HTML();
}
?>
