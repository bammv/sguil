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

include_once("rman_formclasses.inc");
###############################################################
# Snort Rule Option Definitions
# This may be extended later to say what an option can take
# For now it just says if it needs quotes or not
###############################################################
# Special Case Options
$r_opts['sid']="SPECIAL:";
$r_opts['rev']="SPECIAL:";
$r_opts['msg']="SPECIAL:";

# Known Options ....
$r_opts['content']="NEGTXT:";
$r_opts['flow']="NORM:";
$r_opts['reference']="NORM:";
$r_opts['classtype']="NORM:";
$r_opts['nocase']="NONE:";
$r_opts['logto']="TXT:";
$r_opts['ttl']="NORM:";
$r_opts['tos']="NORM:";
$r_opts['id']="NORM:";
$r_opts['ipoption']="NORM:";
$r_opts['fragbits']="NORM:";
$r_opts['dsize']="NORM:";
$r_opts['flags']="NORM:";
$r_opts['seq']="NORM:";
$r_opts['ack']="NORM:";
$r_opts['itype']="NORM:";
$r_opts['icode']="NORM:";
$r_opts['icmp_id']="NORM:";
$r_opts['icmp_seq']="NORM:";
$r_opts['content-list']="NEGTXT:";
$r_opts['offset']="NORM:";
$r_opts['depth']="NORM:";
$r_opts['session']="NORM:";
$r_opts['rpc']="NORM:";
$r_opts['resp']="NORM:";
$r_opts['react']="NORM:";
$r_opts['priority']="NORM:";
$r_opts['uricontent']="NEGTXT:";
$r_opts['tag']="NORM:";
$r_opts['ip_proto']="NORM:";
$r_opts['sameip']="NONE:";
$r_opts['stateless']="NONE:";
$r_opts['regex']="NORM:";

$r_actions['alert']="Alert";
$r_actions['log']="Log";
$r_actions['pass']="Pass";
$r_actions['activate']="Activate";
$r_actions['dynamic']="Dynamic";
$r_actions['drop']="Drop";

$r_protos['tcp']="tcp";
$r_protos['udp']="udp";
$r_protos['ip']="ip";
$r_protos['icmp']="icmp";

$r_dirs['->']="->";
$r_dirs['<>']="<>";
$r_dirs['<-']="<-";


class db_updateset
{
  var $table;
  var $updates;
  var $key;
  var $keyvalue;
  var $insert_id;

  function db_updateset($table, $key, $keyvalue) {
    $this->table = $table;
    $this->key = $key;
    $this->keyvalue = $keyvalue;
    $this->updates = array();
  }

  function db_updatecol($colname, $value) {
    $this->updates[$colname]=$value;
  }


  function db_commit() {
    global $debug;

    if ($this->keyvalue!="") {
      $query = "UPDATE ".$this->table." SET ";
      $updates_present==false;

      foreach ($this->updates AS $colname => $value) {
        if ($updates_present) {
           $query .= ",";
        }
     
        $value === NULL ? $value="NULL" : $value="'".mysql_escape_string($value)."'";
        $query .= $colname."=".$value;
        $updates_present=true;
      }

      if ($updates_present) {
        $query .= " WHERE ".$this->key."=";
        $query .= "'".mysql_escape_string($this->keyvalue)."'";
        if ($debug) print"<BR> $query\n";
        RunQuery($result,$query);
      }
    }
    else {
      $query = "INSERT INTO ".$this->table." ";
      $cols="";
      $values="";
      $firstone=true;
      foreach ($this->updates AS $colname => $value) {
        $colnames .= ($firstone ? "" : ",") . $colname;
        $value === NULL ? $value="NULL" : $value="'".mysql_escape_string($value)."'";
        $values .= ($firstone ? "" : ",") . $value;
        $firstone=false;
      }  
      $query .= "(".$colnames.") VALUES (".$values.")";
      if ($debug) print"<BR> $query\n";
      RunQuery($result,$query);
      $this->insert_id = mysql_insert_id();
    }
  }              
}

class Ipp
{
    var $ip;
    var $port;

    function Ipp()
    {
      $this->port=NULL;
    }
    function Set($ip, $port)
    {
      $this->ip=$ip;
      $this->port=$port;
    }
}


class Rule
{
    var $rid;
    var $name;
    var $active;
    var $rev;
    var $updated;
    var $created;
    var $action;
    var $proto;
    var $src;
    var $dir;
    var $dst;
    var $options;
    var $opts_modified;
    var $editable;

    function Rule($rid = NULL)
    {
      $this->src = new Ipp;
      $this->dst = new Ipp;
      $this->rid = $rid;
      $this->editable=false;
      $this->opts_modified=false;
      
      $this->Fetch();
    }

    function Update()
    {
      if ($this->rid == NULL) {     # Use Store for new rules - Update only valid for pre-fetched rules;
        return(0);
      }

      # Check rule exists by checking returned rid.  Go home if not (see above comment)
      RunQuery($myrule, "SELECT rid FROM rman_rules WHERE rid = $this->rid");
      $rulechk=mysql_fetch_array($myrule, MYSQL_ASSOC);

      if ($rulechk["rid"] != $this->rid) {
        return(0);
      } 
      #  OK so now build the strings to update ....
    }

    function Fetch()
    { 
      if ($this->rid !== NULL) {
        RunQuery($myrule, "SELECT name,active,rev,action,proto,dir,s_ip,s_port,d_ip,d_port,options,DATE_FORMAT(rman_rules.created,'%d-%b-%Y %H:%i:%S') AS created,DATE_FORMAT(rman_rules.updated,'%d-%b-%Y %H:%i:%S') AS updated FROM rman_rules WHERE rid = $this->rid");
        $rule = mysql_fetch_array($myrule, MYSQL_ASSOC);
        $this->opts_modified=false;
        $this->options=array();
        $this->name=$rule["name"];
        $this->active=$rule["active"];
        $this->rev=$rule["rev"];
        $this->updated=$rule["updated"];
        $this->created=$rule["created"];
        $this->action=$rule["action"];
        $this->proto=$rule["proto"];
        $this->dir=$rule["dir"];
        $this->src->Set($rule["s_ip"],$rule["s_port"]);
        $this->dst->Set($rule["d_ip"],$rule["d_port"]);
        $options=$rule["options"];
        while(NextOption($options, $option)) {
          $this->options[]=$option;
        }
        mysql_free_result($myrule);
      }
    }

    function CreateNew() {
      global $debug;
      $new_rule = new db_updateset("rman_rules", "rid", ""); 
 
      $sipp = $this->src;
      $dipp = $this->dst;

      $this->rev = 1;

      $new_rule->db_updatecol("name", $this->name);
      $new_rule->db_updatecol("active", $this->active);
      $new_rule->db_updatecol("rev", $this->rev);
      $new_rule->db_updatecol("updated", NULL);
      $new_rule->db_updatecol("created", NULL);
      $new_rule->db_updatecol("action", $this->action);
      $new_rule->db_updatecol("proto", $this->proto);
      $new_rule->db_updatecol("dir", $this->dir);
      $new_rule->db_updatecol("s_ip", $sipp->ip);
      $new_rule->db_updatecol("s_port", $sipp->port);
      $new_rule->db_updatecol("d_ip", $dipp->ip);
      $new_rule->db_updatecol("d_port", $dipp->port);
  
      # Create new rule and get rid as we need this to build options
      $new_rule->db_commit();
      $this->rid=$new_rule->insert_id;
      
      # Create a new updates set with the options and commit it
      $new_rule_options = new db_updateset("rman_rules", "rid", $this->rid); 
      $new_rule_options->db_updatecol("options",$this->OptionsToString());
      if ($debug) print "<BR>".$this->OptionsToString();
      $new_rule_options->db_commit();
      $this->opts_modified=false;
    }
   
    function OptionsToString() {
      $options="";
      foreach ($this->options AS $option) {
        switch ($option->type) { 
          case "SPECIAL:":
            break;
          case "NORM:":
            $options .= $option->name.":".$option->value."; ";
            break;
          case "NONE:":
            $options .= $option->name."; ";
            break;
          case "NEGTXT:":
            $options .= $option->name.": ".($option->neg ? "!" : "")."\"".$option->value."\"; ";
            break;
          case "TXT:":
            $options .= $option->name.": \"".$option->value."\"; ";
            break;
          default:            # unhandled option type
        }
    
      }
      $options .= "msg:\"".$this->name."\"; rev:".$this->rev."; sid:".$this->rid.";";
      return($options);
    }
 
    function CreateMainForm() {
      global $r_actions;

      $form=new html_tableform("RuleDetail","post","rman_rule.php");

      if ($this->rid < 1000000 && $this->rid!=-1) {
        $form->AddAction("Copy Rule","submit","submit");
        $form->AddAction("Update Active","submit","submit");
      }
      else {
        if ($this->rid == -1) {                    # Check whether uncommited - if so only print save
          $form->AddAction("Save Rule","submit","submit");
        } 
        else {
          if(!$this->editable) {
            $form->AddAction("Edit Rule","submit","submit");
            $form->AddAction("Copy Rule","submit","submit");
            $form->AddAction("Update Active","submit","submit");
          }
          else {
            $form->AddAction("Save Rule","submit","submit");
          }
        }
      }
      $form->tabletitle="Rule Summary";
      $form->stripe=true;

      $form->AddColumn(" ID ","plfieldhdr",9);
      $form->AddColumn(" Name ","plfieldhdrleft",49);
      $form->AddColumn(" Rev ","plfieldhdr",3);
      $form->AddColumn(" Created ","plfieldhdr",17);
      $form->AddColumn(" Updated ","plfieldhdr",17);
      $form->AddColumn(" Active ","plfieldhdr",5);

      if ($this->rid != -1) {
        $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;".$this->rid,"CENTER"));
      }
      else {
        $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;Unknown","CENTER"));
      }
      $form->AddRowElem(new html_RowElem($this->name,"LEFT", "",$this->editable ? "det_rname" : "",50));
      $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;".$this->rev,"CENTER"));
      $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;".$this->created,"CENTER"));
      $form->AddRowElem(new html_RowElem("&nbsp;&nbsp;".$this->updated,"CENTER"));
      $form->AddRowElem(new html_RowElemTickBox(-1,"rule_chkbx",$this->active));
      $form->EndRow();
      $form->ExportVar("rid",$this->rid);
      return($form);
    }


    function CreateTableDetail() {
      global $r_actions;
      global $r_protos;
      global $r_dirs;

      $detail=new html_tableform();
      $detail->tabletitle="Detail";
      $detail->stripe=true;

      $detail->AddColumn(" Action ","plfieldhdr",10);
      $detail->AddColumn(" Proto ","plfieldhdr",7);
      $detail->AddColumn(" Source ","plfieldhdrleft",20);
      $detail->AddColumn(" Src Port ","plfieldhdr",10);
      $detail->AddColumn(" Dir ","plfieldhdr",5);
      $detail->AddColumn(" Destination ","plfieldhdrleft",20);
      $detail->AddColumn(" Dst Port ","plfieldhdr",10);
      if (!$this->editable) {
        $detail->AddRowElem(new html_RowElem("&nbsp;&nbsp;".$r_actions[$this->action],"CENTER"));
        $detail->AddRowElem(new html_RowElem("&nbsp;&nbsp;".$this->proto,"CENTER"));
        $ipp = $this->src;
        $detail->AddRowElem(new html_RowElem($ipp->ip,"LEFT","rulesrcdst"));
        $detail->AddRowElem(new html_RowElem($ipp->port,"CENTER","rulesrcdst"));
        $detail->AddRowElem(new html_RowElem($this->dir,"CENTER"));
        $ipp = $this->dst;
        $detail->AddRowElem(new html_RowElem($ipp->ip,"LEFT","rulesrcdst"));
        $detail->AddRowElem(new html_RowElem($ipp->port,"CENTER","rulesrcdst"));
      }
      else {
        $detail->AddRowElem(new html_RowElemSelect("det_action",$r_actions,"CENTER","",$this->action));
        $detail->AddRowElem(new html_RowElemSelect("det_proto",$r_protos,"CENTER","",$this->proto));
        $ipp = $this->src;
        $detail->AddRowElem(new html_RowElem($ipp->ip,"LEFT","rulesrcdst","det_srcip"));
        $detail->AddRowElem(new html_RowElem($ipp->port,"CENTER","rulesrcdst","det_srcprt",10));
        $detail->AddRowElem(new html_RowElemSelect("det_dir",$r_dirs,"CENTER","",$this->dir));
        $ipp = $this->dst;
        $detail->AddRowElem(new html_RowElem($ipp->ip,"LEFT","rulesrcdst","det_dstip"));
        $detail->AddRowElem(new html_RowElem($ipp->port,"CENTER","rulesrcdst","det_dstprt",10));
      }
      $detail->EndRow();
      return($detail);
    }

    function CreateTableOptions() {
      global $r_opts;   
 
      $options=new html_tableform();
      $options->tabletitle="Options";
      $options->stripe=true;

      $options->AddColumn("Name","plfieldhdrleft",20);
      $options->AddColumn("Value","plfieldhdrleft",75);
      if ($this->editable) {
         $options->AddColumn("Select","plfieldhdrleft",5);
         $options->AddAction("Delete Selected","options","submit");
      }
   
      foreach ($this->options as $idx => $option) {
        switch ($option->type) {
          case "SPECIAL:":
            break;
          default:
            $options->AddRowElem(new html_RowElem($option->name,"LEFT"));
            $options->AddRowElem(new html_RowElem($option->value."&nbsp;","LEFT"));
            if ($this->editable) $options->AddRowElem(new html_RowElemTickBox($idx,"option_delete","N"));
            $options->EndRow();
        }
      }
      if ($this->editable) {
        $options->AddAction("Add New","options","submit");
        $new_opt=new html_RowElemSelect("new_opt", array("none" => "None"),"LEFT","editable");
        foreach ($r_opts as $option => $opttype) {
          switch ($opttype) {
            case "SPECIAL:":
              break;
            default:
               $new_opt->AddOption($option, $option);
          }
        }
        $new_opt_value=new html_RowElem("-","LEFT","editable","new_opt_value");
        $new_opt_value->editcols="70%";
        $options->AddRowElem($new_opt);
        $options->AddRowElem($new_opt_value);
        $options->AddRowElem(new html_RowElem("&nbsp;","LEFT","editable"));
        $options->EndRow();
      }
      return($options);
    }
 
    function PrintHTML($action = _PRINT)
    {
      $form = $this->CreateMainForm();
      $detail=$this->CreateTableDetail();
      $options=$this->CreateTableOptions();

      $form->Print_HTMLhdr();
      $form->Print_HTML_Actions();
      $form->Print_HTML_Table();
      $form->Print_HTMLexports();

      print"<p>\n";
      print "  <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH='70%' BGCOLOR='#FFFFFF'>\n";
      print "  <TR><TD width=3%>&nbsp;</TD><TD width=\"70%\">\n";
      $detail->Print_HTML_Table(2);
      print"</TD></TR><TR><TD>&nbsp;</TD></TR><TR><TD width=3%></TD><TD width=\"70%\">\n";
      $options->Print_HTML_Table(2);
      if ($this->editable) {
        $options->Print_HTML_Actions();
      }

      print "  </TD></TR></TABLE>\n";
      print"</P>\n";
      print"</FORM>\n";
    }
}

class Option
{
    var $name;
    var $type;
    var $value;
    var $neg;

    function Option()
    {
       $this->name="";
       $this->type="NONE:";
       $this->neg=false;
    }
    function Negate()
    {
       $this->neg=true;
    }
    function SetName($name)
    {
      global $r_opts;
      $this->name=$name;
      $this->type=$r_opts[$name];
    }
}

#Function NextOption processes a snort option string char by char
#Returns number of characters processed and an updated copy of the
#string with those characters removed.
#***RANT*** Why can't they use easily tokenisable option strings
#***RANT*** Instead of having to look at it char by char?


function NextOption(&$options, &$option) {

  global $r_opts;
  
  # Check we have something to scan else return 0 
  $nchar=strlen(&$options);
  if ($nchar==0) {
    return(0);
  }
  # Loose White Space
  $pos=0;
  while(substr($options,$pos,1)==" ") {
    $pos++;
  } 
  $options=substr($options,$pos); 

  $nchar=strlen(&$options);
 
  $option = new Option;

  # Set pre-loop conditions
  $finished=false;
  $escaped=false;
  $inquotes=0;
  $negated=false;
  $foundcolon=false;
  $quoted=false;
  $pos=0;

  while (($pos < $nchar) && $finished==false) {
    $char=substr($options,$pos,1);

    switch ($char) {
      case "\\":                                         # next char escaped
        if (!$escaped) {
          $escaped=true;
        }
        else {
          $escaped=false;
        }
        break;

      case ":":
        if (!$foundcolon) {
          $option->SetName(substr($options,0,$pos));
          if ($option->type=="TXT:" OR $option->type=="NEGTXT:" OR $option->name=="msg") {
            $quoted=true;
          }
          $foundcolon=true;  
          $start=$pos+1; # This may get reassigned
          $begin=$start; # Keep a record for good measure
          break;
        }
        $escaped=false;
	
      case "!":
        if ($quoted && !$inquotes) {                     # negate quoted string (eg content: ! "fred");
          $option->Negate();
        }
	$escaped=false;
        break;

      case "\"":
        if (!$escaped && $quoted && $foundcolon) {                      # Start / end of string?
          if ($inquotes==false) {			 # Start of string	
            $inquotes=true;
            $start=$pos+1;
          }
          else {                                         # End of string
            $inquotes=false;
            $optlen=$pos-$start;
          }
          break;
        }

      case ";" :
        if (!$escaped) {                                 # Note the snort config says ; must be escaped if used in a string
          $finished=true;
          break;
        }
	$escaped=false;

      default:
        $escaped=false;
    }
  $pos++;
  }
  
  # Check for missing ;  Snort Config says it must have one even for the last option
  if (!$finished) {
    return(0);
  }
  if ($foundcolon) {
    if ($quoted) {
      $option->value=substr($options,$start,$optlen);
    }
    else {
      $option->value=substr($options,$begin,$pos-$begin-1);
    }
  }
  else {
    $option->SetName(substr($options,0,$pos-1));
  }
  # Return remainder of string and number of characters processed
  $options=substr($options,$pos);
  return($pos);
}

?>
