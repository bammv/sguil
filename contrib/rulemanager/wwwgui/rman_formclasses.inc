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

class html_formaction
{
  var $type;
  var $name;
  var $value;

  function html_formaction($value="default", $name="submit", $type="submit")
  {
    $this->type=$type;
    $this->name=$name;
    $this->value=$value;
  }

  function Print_HTML($indent=0)
  {
    print str_repeat(" ",$indent)."<input TYPE=\"$this->type\" NAME=\"$this->name\" VALUE=\"$this->value\">\n";
  }
}


class html_form
{
  var $name;
  var $method;
  var $action;

  var $actions;
  var $fields;

  function html_form($name="default",$method="post",$action="")
  {
    $this->name=$name;
    $this->method=$method;
    $this->action=$action;
    $this->actions=array();
    $this->exports=array();
  }

  function AddAction($value, $name, $type)
  {
    $this->actions[]=new html_formaction($value, $name, $type);
  }

  function AddActionChooser($act_options) 
  {
    $chooser=new html_RowElemSelect("action_choice",$act_options);
    $chooser->td=false;
    $this->actions[]=$chooser;
  }
  
  function AddActionEntry() {
    $entry=new html_RowElem("","","","action_entry");
    $entry->td=false;
    $this->actions[]=$entry;
  }

  function SetAction($action)
  {
    $this->action=$action;
  }

  function Print_HTMLhdr($indent=0)
  {
    print str_repeat(" ",$indent)."<form METHOD=\"$this->method\" NAME=\"$this->name\" ACTION=\"$this->action\">\n";
  }
  function ExportVar($var, $value)
  {
    $this->exports[$var]=$value;
  }
  function Print_HTMLexports($indent=0)
  {
    $idstr=str_repeat(" ",$indent);
    foreach ($this->exports as $name => $value) {
      print $idstr;
      ExportVar($name,$value);
    }
  }
}

class html_tablecol
{
  var $name;
  var $class;
  var $width=0;

  function Print_HTML($indent=0)
  {
    print str_repeat(" ",$indent);
    print "<TD";

    if ($this->class!="") {
      print " CLASS=\"$this->class\"";
    }
    if ($this->width!=0) {
      print " WIDTH=\"$this->width"."%\"";
    }
    print ">$this->name"."</TD>\n";
  }
}

class html_RowElem
{
  var $align;
  var $value;
  var $class;
  var $editname;
  var $editcols;
  var $td;
  var $maxlength;
  var $width;

  function Print_HTML($indent=0)
  {
    print str_repeat(" ",$indent);
    if ($this->td) {
      print "<TD ALIGN=$this->align";

      if ($this->width!="") print" WIDTH=\"$this->width\"";
      if ($this->class!="") print " CLASS=\"$this->class\"";
      print ">";
    }
    if ($this->editname=="") { 
      print $this->value;
    }
    else {
      print "<input type=text size=$this->editcols maxlength=$this->maxlength bgcolor=\"#2299bb\" name=\"$this->editname\" value=\"$this->value\" align=$this->align>";
    }
    $this->td ? print "</TD>\n" : print "\n";
  
  }

  function html_RowElem($value="",$align="left",$class="",$editname="", $editcols=20, $maxlength=255)
  {
    $this->align=$align;
    $this->value=$value;
    $this->class=$class;
    $this->editname=$editname;
    $this->editcols=$editcols;
    $this->td=true;
    $this->maxlength=$maxlength;
  }
}

class html_RowElemTickBox extends html_rowelem
{
  var $state;
  var $groupname;

  function html_RowElemTickBox($elemid=0,$groupname="",$state="N", $align="CENTER", $class="")
  {
    $this->state=$state;
    $this->value=$elemid;
    $this->groupname=$groupname;
    $this->class=$class;
    $this->align=$align;
  }
  function Print_HTML($indent=0)
  {
    $idstr=str_repeat(" ",$indent);
    print $idstr."<TD ALIGN=$this->align";
    if ($this->class!="") {
      print " CLASS=\"$this->class\"";
    }
    print ">";
    if ($this->value == -1) {
      $arrstring="";
    }
    else {
      $arrstring="[$this->value]";
    }
    print "<input TYPE=\"hidden\" NAME=\"$this->groupname".$arrstring."\" VALUE=\"N\">";
    print "<input TYPE=\"checkbox\" NAME=\"$this->groupname".$arrstring."\" VALUE=\"Y\"";
    if ($this->state=="Y") {
      print " CHECKED=1";
    }
    print "></TD>\n";
  }
}

class html_RowElemSelect extends html_rowelem
{
  var $sel_opts;
  var $default;

  function html_RowElemSelect($editname="select", $sel_opts=NULL,$align="CENTER", $class="", $default=false) {
    $this->editname=$editname;
    $this->sel_opts=$sel_opts;
    $this->class=$class;
    $this->align=$align;
    $this->default=$default;
    $this->td=true;
  }

  function AddOption($value, $text)
  {
    $this->sel_opts[$value]=$text;
  }

  function Print_HTML($indent=0) 
  {
    $idstr=str_repeat(" ",$indent);
    if ($this->td) {
      print $idstr."<TD ALIGN=$this->align";
      if ($this->class!="") {
        print " CLASS=\"$this->class\"";
      }
      print ">";
    }

    if ($this->sel_opts !== NULL) {
      print $idstr."  <select NAME=\"$this->editname\">\n";
        foreach ($this->sel_opts AS $value => $text) { 
          print $idstr."    <option VALUE=\"$value\" ";
          if ($value == $this->default) print "SELECTED ";
          print ">$text\n"; 
        }
      print $idstr."  </select>\n";
    }
    if ($this->td) print $idstr."</TD>\n";
  }
}

class html_tableform extends html_form
{
  var $outertable=false;
  var $stipe=true;
  var $border=0;
  var $cellspacing=0;
  var $cellpadding=0;
  var $height="";
  var $width="100";
  var $bgcolor="#FFFFFF";
  var $trclass="";
  var $columns;
  var $rows;
  var $rowptr=0;
  var $tabletitle;

  function html_tableform($name="default",$method="post",$action="")
  {
    $this->html_form($name, $method, $action);
    $columns=array();
    $rows=array(array());
    $tabletitle="";
  }

  function AddRowElem($rowelem)
  {
    $row=&$this->rows[$this->rowptr];
    $row[]=$rowelem;
  }

  function EndRow()
  {
    $this->rowptr++;
  }

  function AddColumn($name, $class="", $width=0)
  {
    $newcol = new html_tablecol;
    $newcol->name=$name;
    $newcol->class=$class;
    $newcol->width=$width;

    $this->columns[]=$newcol;
  }

  function Print_HTML_Actions($indent=0) {
    $idstr=str_repeat(" ",$indent);
    print $idstr."<TABLE width=\"$this->width%\"><TR><TD ALIGN=RIGHT>\n";

    foreach($this->actions AS $action) {
      $action->Print_HTML($indent+4);
    }
    
    print $idstr."</TD></TR></TABLE>\n";
  }

  function Print_HTML_Table($indent=0)
  {
    $idstr=str_repeat(" ",$indent);
    $numcols=count($this->columns);
    if ($this->outertable) {
      print $idstr."<TABLE CELLSPACING=0 CELLPADDING=2 BORDER=0 WIDTH=\"$this->width%\" BGCOLOR=\"#000000\">\n";
      $idstr=$idstr."  ";
      $indent+=2;
      print $idstr."<tr><td>\n";
    }
    
    if ($this->height != "") {
       print $idstr."<DIV class='scroller' style='max-height: ".$this->height."'>\n";
    }
    print $idstr."<TABLE CELLSPACING=$this->cellspacing CELLPADDING=$this->cellpadding BORDER=$this->border width=\"";
    if ($this->outertable) {
      print "100";
    }
    else {
      print $this->width;
    }
    print "%\" BGCOLOR=\"$this->bgcolor\">\n";
    if ($this->tabletitle !="") {
      print $idstr."  <TR><TD CLASS='tabletitle' COLSPAN=$numcols >$this->tabletitle</TD></TR>\n";
    }

    print $idstr."  <TR";
    if ($this->trclass!="") {
      print " CLASS=\"$this->trclass\"";
    }
    print ">\n";
    
    if (count($this->columns)) {    
      foreach($this->columns AS $col) {
        $col->Print_HTML($indent+4);
      }
      print "  </TR>\n";
    }
    $odd=0;
    if ($this->rowptr > 0) {
      foreach($this->rows AS $row) {
         print $idstr."  <TR";
         if ($this->stripe) {
           print " BGCOLOR=\"".ColourOddEven($odd)."\"";
         }
         if ($this->trclass!="") {
           print " CLASS=\"$this->trclass\"";
         }
         print ">\n";
         foreach($row AS $rowelem) {
           $rowelem->Print_HTML($indent+4);
         }
         print $idstr."  </TR>\n";
      }
    }
    print $idstr."</TABLE>\n";
    if ($this->height != "") print $idstr."</DIV>\n"; 
    if ($this->outertable) {
       print $idstr."</TD></TR></TABLE>\n";
    }
  }

  function Print_HTML($indent=0)
  {
    $idstr=str_repeat(" ",$indent);
    $this->Print_HTMLhdr($indent);
    $this->Print_HTML_Actions($indent);    
    $this->Print_HTML_Table($indent);    
    $this->Print_HTMLexports($indent);
    print $idstr."</FORM>\n";
  }  
}

function GetPostVar($varname, &$var) {
  global $HTTP_POST_VARS;

  if (isset($HTTP_POST_VARS[$varname])) {
    $retvar=SanitizeUserInput($HTTP_POST_VARS[$varname]);
    if ($var==$retvar) return(false);
    $var=$retvar;
    return(true);       
  }
  return(false);
}


?>
