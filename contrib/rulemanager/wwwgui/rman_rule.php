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
  include_once("rman_ruleclasses.inc");
   
  global $debug;

  session_start();

  WriteHeader("Rule Maintenance");

  $dbh=ConnectToDb();
  
  if ($debug) print_r($HTTP_POST_VARS); 
  if ($debug) print_r($HTTP_SESSION_VARS); 
  if ($HTTP_POST_VARS["options"]) {
    $opt_action=$HTTP_POST_VARS["options"];

    switch($opt_action) {
      case "Add New":
        Option_AddNew();
        break;

      case "Delete Selected":
        Option_Delete();
        break;

      default:
        print "<BR> Undefined Action - this has been logged - you do not need to contact the webmaster\n";
        session_destroy();
    }
  }
  else {
    if ($HTTP_POST_VARS["submit"]) {
      $submit=$HTTP_POST_VARS["submit"];
      switch($submit) {
        case "Update Active":
          Update_Rule();
          break;
  
        case "Copy Rule":
          Edit_Rule(true);
          break;

        case "Edit Rule":
          Edit_Rule();
          break;

        case "Save Rule":
          Save_Rule();
          break;
        
        default:
          print "<BR> Undefined Action - this has been logged - you do not need to contact the webmaster\n";
          session_destroy();
      }
    }
    else {
      if ($HTTP_GET_VARS['rid']) {
        show_rule($HTTP_GET_VARS['rid']);
      }
      else {
        # Show default page
        rule_maint();
      } 
    }
  }
  mysql_close($dbh);

?>
    <HR>
  </BODY>
</HTML>


<?php

function rule_maint() {
  
  GetActive($active,$notactive);
  RunQuery($result,"SELECT count(*) AS unassigned FROM rman_rules LEFT JOIN rman_rrgid ON rman_rules.rid=rman_rrgid.rid WHERE rman_rrgid.rid is NULL");
  $row=mysql_fetch_array($result, MYSQL_ASSOC);
  $unassigned=$row["unassigned"];
  
  print "<P><TABLE border=1><TR><TD>\n";
  print "<TABLE cellspacing=1 cellpadding=1 border=0>\n";

  print "<TR><TD><B>Total Rules</TD><TD ALIGN='LEFT'>".($active+$notactive)."</TD></TD></TR>\n";
  print "<TR><TD></TD><TD><LI>Active&nbsp;</TD><TD ALIGN='RIGHT'>".$active."</TD></TR>\n";
  print "<TR><TD></TD><TD><LI>Inactive&nbsp;</TD><TD ALIGN='RIGHT'>".$notactive."</TD></TR>\n";
  print "<TR><TD></TD><TD><LI><A href='rman_group.php?rgid=-1'>Unassigned to a group</A>&nbsp;</TD><TD ALIGN='RIGHT'>".$unassigned."</TD></TR>\n";
  print "</TABLE></TD></TR></TABLE></P>\n";

}

function show_rule($rid) {
  global $HTTP_SESSION_VARS;

  # Defang User Input
  $rid=mysql_escape_string($rid);
  if (!is_numeric($rid)) {
    PrintError("Invalid Input");
    return;
  }

  # Create & Fetch rule;
  $rule=new Rule($rid);
  
  if (session_is_registered("rule")) {
    session_unset("rule");
  } 
  else {
    session_register("rule");
  }

  $HTTP_SESSION_VARS["rule"]=$rule;
  Rule_PrintInfo($rid);

  $rule->PrintHTML();
}

function Rule_PrintInfo($rid) {
  print "<P><TABLE border=1><TR><TD><TABLE><TR><TD><B>Rule Group Membership</B></TD></TR>\n";
  RunQuery($result,"SELECT name,rman_rgroup.rgid AS rgid FROM rman_rgroup, rman_rrgid WHERE rman_rgroup.rgid=rman_rrgid.rgid AND rid='".$rid."'");
  if (mysql_num_rows($result)==0) {
    print "<TR><TD><LI><A HREF='rman_group.php?rgid=-1'>Unassigned</A></TD></TR></TABLE>\n";
  }
  else {
    while($row=mysql_fetch_array($result, MYSQL_ASSOC)) {
      print "<TR><TD><LI><A HREF='rman_group.php?rgid=".$row["rgid"]."'>".$row["name"]."</A></TD></TR>\n";
    }
  }
  print "</TABLE></TD><TR><TABLE></P>\n";

}

function Update_Rule()
{
  global $HTTP_POST_VARS, $HTTP_SESSION_VARS;

  $new_state=$HTTP_POST_VARS['rule_chkbx'];

  if (($new_state !="Y" && $new_state !="N") || !session_is_registered("rule")) {
    # Something Wrong
    session_destroy();
    print "<BR> Bad Data Received, session destroyed\n";
    return(0);
  }
    
  $rule=$HTTP_SESSION_VARS["rule"];

  if ($rule->active != $new_state) {
    $updates=Edit_Rule_ProcessDetail(&$rule);
    $updates->keyvalue=$rule->rid;
    $updates->db_commit();
    Rule_UpdateTimeStamps($rule->rid);
    session_unregister("rule_changes");
    $rule->Fetch();
    $HTTP_SESSION_VARS["rule"]=$rule;
  }
  Rule_PrintInfo($rule->rid);
  $rule->PrintHTML();
}

function Edit_Rule($new=false)
{
  global $HTTP_SESSION_VARS;
  if (session_must_be_registered("rule")) {

    $rule=$HTTP_SESSION_VARS["rule"];   # OK Session good - retrieve rule
    if ($new) $rule->rid=-1;
    $rule->editable=true;
    $HTTP_SESSION_VARS["rule"]=$rule;   # Save rule for next saving later
    $rule->PrintHTML();
  }
}

function Save_Rule()
{
  global $HTTP_SESSION_VARS;
  if (session_must_be_registered("rule")) {

    $rule=$HTTP_SESSION_VARS["rule"];   # OK Session good - retrieve rule

    $changes=Edit_Rule_ProcessDetail(&$rule);
    if ($rule->rid==-1) {
      $rule->CreateNew();
    }
    else {
      if(($changes->updates != array()) || $rule->opts_modified) {
        $changes->db_updatecol("rev",++$rule->rev);
        $changes->db_updatecol("options",$rule->OptionsToString());
        $changes->db_commit();
        Rule_UpdateTimeStamps($rule->rid);
      }
    }

    session_unregister("rule_changes");

    $rule->editable=false;
    $rule->Fetch();
    $HTTP_SESSION_VARS["rule"]=$rule;   # Save rule for next saving later
    Rule_PrintInfo($rule->rid);
    $rule->PrintHTML();
  }
}

function Edit_Rule_ProcessDetail($rule) {

  global $HTTP_POST_VARS, $HTTP_SESSION_VARS;
  $sipp = &$rule->src;
  $dipp = &$rule->dst;

  if (session_is_registered("rule_changes")) {
    $changes=$HTTP_SESSION_VARS["rule_changes"];
  }
  else {
    $changes=new db_updateset("rman_rules", "rid", ($rule->rid == -1 ? "" : $rule->rid));
    session_register("rule_changes");
  } 
  
  if (GetPostVar("rule_chkbx", &$rule->active)) $changes->db_updatecol("active", $rule->active);

  if (GetPostVar("det_rname", &$rule->name)) $changes->db_updatecol("name", $rule->name);

  if (GetPostVar("det_action", &$rule->action)) $changes->db_updatecol("action", $rule->action);
  if (GetPostVar("det_proto", &$rule->proto)) $changes->db_updatecol("proto", $rule->proto);
  if (GetPostVar("det_srcip", &$sipp->ip)) $changes->db_updatecol("s_ip", $sipp->ip);
  if (GetPostVar("det_srcprt", &$sipp->port)) $changes->db_updatecol("s_port", $sipp->port);
  if (GetPostVar("det_dir", &$rule->dir)) $changes->db_updatecol("dir", $rule->dir);
  if (GetPostVar("det_dstip", &$dipp->ip)) $changes->db_updatecol("d_ip", $dipp->ip);
  if (GetPostVar("det_dstprt", &$dipp->port)) $changes->db_updatecol("d_port", $dipp->port);

  $HTTP_SESSION_VARS["rule_changes"]=$changes;

  return($changes);
}

function Option_AddNew()
{
  global $HTTP_SESSION_VARS;
  global $HTTP_POST_VARS;
  global $r_opts;

  if (session_must_be_registered("rule")) {
    $opt_name=SanitizeUserInput($HTTP_POST_VARS["new_opt"]);
    $rule=$HTTP_SESSION_VARS["rule"];
    if ($opt_name != "None" && isset($r_opts[$opt_name])) { 
      $option=new Option();
      $option->SetName($opt_name);
      $option->value=snortescape(stripslashes($HTTP_POST_VARS["new_opt_value"]));
      $rule->options[]=$option;
      $rule->opts_modified=true;
    }
    else {
      PrintError("You must select a valid option type");
    }
    Edit_Rule_ProcessDetail(&$rule);
    $HTTP_SESSION_VARS["rule"]=$rule;
    $rule->PrintHTML();
  }
}

function Option_Delete()
{
  global $HTTP_SESSION_VARS;
  global $HTTP_POST_VARS;

  if (session_must_be_registered("rule")) {
    $rule=$HTTP_SESSION_VARS["rule"];
    $ruleopts=&$rule->options;

    $opt_del=$HTTP_POST_VARS["option_delete"];
 
    foreach($opt_del as $optnum => $delete) {
      if ($delete=="Y") {
        unset($ruleopts[$optnum]);
        $rule->opts_modified=true;
      }
    }
    Edit_Rule_ProcessDetail(&$rule);
    $HTTP_SESSION_VARS["rule"]=$rule;
    $rule->PrintHTML();
  }
}
?>
