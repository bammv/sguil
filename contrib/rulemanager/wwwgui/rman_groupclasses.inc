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

class rgroup_member {
  var $state;
  var $name;
  var $rev;
  var $created;
  var $updated;
  var $active;

  function rgroup_member($state="exists", $name="", $rev="", $created="", $updated="", $active="Y") {
    $this->state=$state;
    $this->name=$name;
    $this->rev=$rev;
    $this->updated=$updated;
    $this->created=$created;
    $this->active=$active;
  }
}


class rgroup {

  var $rgid;
  var $name;
  var $members;
  var $description;


  function rgroup($rgid=0) {

    $this->rgid=$rgid;
    $this->members=array();

    if ($this->rgid != 0) $this->Fetch();
  }
  
  function Fetch() {
    # -1 signifies rules with no group
    if ($this->rgid != -1) { 
      RunQuery($g_result,"SELECT name,description FROM rman_rgroup WHERE rgid=".$this->rgid);   
      RunQuery($m_result,"SELECT rman_rules.rid,rman_rules.rev, DATE_FORMAT(rman_rules.created,'%d-%b-%Y %H:%i:%S') AS created, DATE_FORMAT(rman_rules.updated,'%d-%b-%Y %H:%i:%S') AS updated, rman_rules.name, rman_rules.active FROM rman_rules, rman_rrgid WHERE rman_rrgid.rgid=" . $this->rgid . " AND rman_rules.rid=rman_rrgid.rid ORDER BY rman_rules.name");
      $group_row=mysql_fetch_array($g_result, MYSQL_ASSOC);
      $this->name=$group_row["name"];
      $this->description=$group_row["description"];
    }
    else {
      RunQuery($m_result,"SELECT rman_rules.rid, rman_rules.rev, DATE_FORMAT(rman_rules.created,'%d-%b-%Y %H:%i:%S') AS created, DATE_FORMAT(rman_rules.updated,'%d-%b-%Y %H:%i:%S') AS updated, rman_rules.name, rman_rules.active FROM rman_rules LEFT JOIN rman_rrgid ON rman_rules.rid=rman_rrgid.rid WHERE rman_rrgid.rid is NULL ORDER BY rman_rules.name");
      $this->name="Unassigned";
      $this->description="Rules not assigned to a group";
    }
  
    while($m=mysql_fetch_array($m_result, MYSQL_ASSOC)) {
      $this->members[$m["rid"]]=new rgroup_member("exists",$m["name"],$m["rev"],$m["created"],$m["updated"],$m["active"]);
    }
  }  
 
#  function Delete($rid) {
#    if (isset($this->members[$rid])) {
#      if($this->members[$rid]=="add") {
#        unset($this->members[$rid]);
#      }
#      else {
#        $this->members[$rid]="delete";
#      }
#    }
#  }    
#
#  function Add($rid) {
#    if (isset($this->members[$rid])) {
#       if ($this->members[$rid]!="add") {
#         $this->members[$rid]="exists";
#       }
#    }
#    else {
#       $this->members[$rid]="add";
#    }
#  }
#
#  function Put() {
#    modified=false;
#
#    foreach($this->members AS $rid => $state) {
#      switch ($state) {
#        case "add":
#          RunQuery($result,"INSERT INTO rman_rrgid rid,rgid VALUES(".$rid.",".$this->rgid.")");
#          $this->members[$rid]="exists";
#          modified=true;
#          break;
#
#        case "delete":
#          RunQuery($result,"DELETE FROM rman_rrgid WHERE rid=".$rid." AND rgid=".$this-rgid);
#          unset($this->members[$rid]");
#          modified=true;
#        default:
#      }
#    }
#    if ($modified) this->UpdateTimeStamps();
#  }
#  
#  function UpdateTimeStamps() {
#    RunQuery($result,"UPDATE rman_rgroup SET updated=NULL WHERE rgid=".$this->rgid);
#    RunQuery($s_result,"SELECT sid FROM rman_senrgrp WHERE rgid=".$this->rgid);
#
#    while($row = mysql_fetch_array($s_result, MYSQL_ASSOC)) {
#      RunQuery($result,"UPDATE rman_sensor SET updated=NULL WHERE sid=".$row["sid"]);
#    }
#  }
}
