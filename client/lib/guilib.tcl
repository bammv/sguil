####################################################
# Sguil procs for general GUI purposes             #
# Note:  Selection and Multi-Selection procs       #
# have their own file (sellib.tcl)                 #
####################################################
# $Id: guilib.tcl,v 1.5 2004/07/20 20:02:08 shalligan Exp $
######################## GUI PROCS ##################################

proc LabelText { winFrame width labelText { height {1} } { bgColor {lightblue} } } {
  label $winFrame.label -text "$labelText" -foreground black -background $bgColor -anchor s -height $height
  text $winFrame.text  -width $width -background white -height 1
  pack $winFrame.label $winFrame.text -side top -anchor w -fill both -expand true
}


proc UpdateClock {} {
  global gmtClock
  $gmtClock configure -text "[GetCurrentTimeStamp] GMT"
  after 1000 UpdateClock
}
proc AboutBox {} {
    global VERSION
    set aboutWin .aboutWin
    if [winfo exists $aboutWin] {
	wm withdraw $aboutWin
	wm deiconify $aboutWin
	return
    }
    toplevel $aboutWin
    wm title $aboutWin "About Sguil"
    set welcomeFrame [frame $aboutWin.welcomeFrame -borderwidth 1 -background black]
    set welcomeLabel [label $welcomeFrame.welcomeLabel -background lightblue\
	    -foreground navy -text "\
	    Sguil Version: $VERSION\n\
	    \n\
	    Copyright (C) 2002-2003 Robert (Bamm) Visscher <bamm@satx.rr.com>\n\
	    \n\
	    This program is distributed under the terms of version 1.0 of the\n\
	    Q Public License.  See LICENSE.QPL for further details.\n\
	    \n\
	    This program is distributed in the hope that it will be useful,\n\
	    but WITHOUT ANY WARRANTY; without even the implied warranty of\n\
	    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\
	    "]
    pack $welcomeLabel -ipadx 5 -ipady 5
    pack $welcomeFrame -side top -padx 5 -pady 10
    set actionButtonFrame [frame $aboutWin.actionButtonFrame -background white]
    set okButton [button $actionButtonFrame.okButton -text "Ok"\
	    -command "destroy $aboutWin"]
    pack $okButton -side top
    pack $actionButtonFrame -side bottom
}

proc TableNameList { tmpList } {
  global tableList
  set tableList $tmpList
}
proc TableColumns { tableName tmpColumnList } {
  global tableColumnArray
  set tableColumnArray($tableName) $tmpColumnList
}
proc ShowDBTables {} {
  global tableList tableColumnArray currentTableList tableListFrame
  set tableWin .tableWin
  if [winfo exists $tableWin] {
    wm withdraw $tableWin
    wm deiconify $tableWin
    return
  }
  toplevel $tableWin
  wm title $tableWin "Table Descriptions"
  set tableSelMenu [optionmenu $tableWin.tableSelMenu\
    -labeltext "Table Name:" -command "DisplayTableColumns $tableWin.tableSelMenu"] 
  foreach tableName $tableList {
    $tableSelMenu insert end $tableName
    set tableListFrame($tableName) [frame $tableWin.${tableName}Frame\
     -background black -borderwidth 1]
    CreateTableListBox $tableListFrame($tableName) $tableColumnArray($tableName)
  }
  set currentTableList $tableName
  button $tableWin.close -text "Close" -command "destroy $tableWin"
  pack $tableSelMenu $tableListFrame($tableName) $tableWin.close -side top
  $tableSelMenu sort ascending
  $tableSelMenu select event
  $tableSelMenu configure -cyclicon true
  DisplayTableColumns $tableWin.tableSelMenu
}
proc DisplayTableColumns { winName } {
  global currentTableList tableListFrame
  set tableName [$winName get]
  pack forget $tableListFrame($currentTableList)
  pack $tableListFrame($tableName) -after $winName -fill both -expand true
  set currentTableList $tableName
}
proc CreateTableListBox { winName columnList } {
  set nameFrame [frame  $winName.nameFrame]
    set nameLabel [label $nameFrame.nameLabel -text "Column Name" -background black -foreground white]
    set nameList [listbox $nameFrame.nameList -width 15 -height 10\
     -yscrollcommand "$winName.scroll set" -exportselection false -borderwidth 0]
    pack $nameLabel -fill x -side top
    pack $nameList -side top -fill both -expand true
  set typeFrame [frame  $winName.typeFrame]
    set typeLabel [label $typeFrame.typeLabel -text "Type" -background black -foreground white]
    set typeList [listbox $typeFrame.typeList -width 10 -height 10\
     -yscrollcommand "$winName.scroll set" -exportselection false -borderwidth 0]
    pack $typeLabel -fill x -side top
    pack $typeList -side top -fill both -expand true
  set lengthFrame [frame $winName.lenghtFrame]
    set lengthLabel [label $lengthFrame.lengthLabel -text "Length" -background black -foreground white]
    set lengthList [listbox $lengthFrame.lengthList -width 10 -height 10\
     -yscrollcommand "$winName.scroll set" -exportselection false -borderwidth 0]
    pack $lengthLabel -fill x -side top
    pack $lengthList -side top -fill both -expand true
  scrollbar $winName.scroll -command "MultiScrollBar \"$nameList $typeList $lengthList\""\
   -width 10
  pack $nameFrame $typeFrame $lengthFrame -side left -expand true -fill both
  pack $winName.scroll -side right -fill y
   
  set BCOLOR white
  foreach column $columnList {
    $nameList insert end [lindex $column 0]
    $typeList insert end [lindex $column 1]
    $lengthList insert end [lindex $column 2]
    if { $BCOLOR == "white" } { set BCOLOR lightblue } else { set BCOLOR white }
    $nameList itemconfigure end -background $BCOLOR
    $typeList itemconfigure end -background $BCOLOR
    $lengthList itemconfigure end -background $BCOLOR
  }
}

proc DisplayIncidentCats {} {
  set categoryTl [toplevel .categoryTl]
  wm title .categoryTl "Incident Categories"
  wm geometry .categoryTl +[winfo pointerx .]+[winfo pointery .]
  set categoryText [scrolledtext $categoryTl.categoryText -vscrollmode dynamic -hscrollmode dynamic\
   -wrap word -visibleitems 60x8 -labelpos n -labeltext "Incident Category Definitions"]
  set categoryButton [button $categoryTl.close -text "Ok" -command "destroy $categoryTl"]
  pack $categoryText -side top -fill both -expand true
  pack $categoryButton -side bottom
  $categoryText component text insert end "Category I\tUnauthorized Root/Admin Access\n"
  $categoryText component text insert end "Category II\tUnauthorized User Access\n"
  $categoryText component text insert end "Category III\tAttempted Unauthorized Access\n"
  $categoryText component text insert end "Category IV\tSuccessful Denial of Service Attack\n"
  $categoryText component text insert end "Category V\tPoor Security Practice or Policy Violation\n"
  $categoryText component text insert end "Category VI\tReconnaissance/Probes/Scans\n"
  $categoryText component text insert end "Category VII\tVirus Infection\n"
}
proc LaunchXscriptMenu { winName yRoot} {
  global ACTIVE_EVENT eventIDMenut MULTI_SELECT
  if {!$ACTIVE_EVENT || $MULTI_SELECT == 1} { return }
  set selectedIndex { $winName curselection }
  if { $selectedIndex == "" } { set ACTIVE_EVENT 0; return }
  tk_popup $eventIDMenut [winfo rootx $winName] [expr $yRoot + 6]
}
proc LaunchIPQueryMenu { winName yRoot } {
  global ACTIVE_EVENT ipQueryMenu MULTI_SELECT
  if {!$ACTIVE_EVENT || $MULTI_SELECT == 1} { return }
  set selectedIndex { $winName curselection }
  if { $selectedIndex == "" } { set ACTIVE_EVENT 0; return }
  tk_popup $ipQueryMenu [winfo rootx $winName] [expr $yRoot + 6]
}
proc LaunchPortQueryMenu { winName yRoot } {
  global ACTIVE_EVENT portQueryMenu MULTI_SELECT
  if {!$ACTIVE_EVENT || $MULTI_SELECT == 1} { return }
  set selectedIndex { $winName curselection }
  if { $selectedIndex == "" } { set ACTIVE_EVENT 0; return }
  tk_popup $portQueryMenu [winfo rootx $winName] [expr $yRoot + 6]
}
proc LaunchSigQueryMenu { winName yRoot } {
  global ACTIVE_EVENT sigQueryMenu MULTI_SELECT
    if {!$ACTIVE_EVENT || $MULTI_SELECT == 1} { return }
  set selectedIndex { $winName curselection }
  if { $selectedIndex == "" } { set ACTIVE_EVENT 0; return }
  tk_popup $sigQueryMenu [winfo rootx $winName] [expr $yRoot + 6]
}
proc LaunchCorrelateMenu { winName yRoot } {
  global ACTIVE_EVENT correlateMenu MULTI_SELECT
  if {!$ACTIVE_EVENT || $MULTI_SELECT == 1} { return }
  set selectedIndex { $winName curselection }
  if { $selectedIndex == "" } { set ACTIVE_EVENT 0; return }
  tk_popup $correlateMenu [winfo rootx $winName] [expr $yRoot +6]
}
proc LaunchStatusMenu { winName yRoot } {
  global ACTIVE_EVENT statusMenu
  if {!$ACTIVE_EVENT} { return }
  set selectedIndex { $winName curselection }
  if { $selectedIndex == "" } { set ACTIVE_EVENT 0; return }
  tk_popup $statusMenu [winfo rootx $winName] [expr $yRoot +6]
}
proc ClearPacketData {} {
  global srcIPHdrFrame dstIPHdrFrame verIPHdrFrame hdrLenIPHdrFrame
  global tosIPHdrFrame lenIPHdrFrame idIPHdrFrame flagsIPHdrFrame
  global offsetIPHdrFrame ttlIPHdrFrame chksumIPHdrFrame
  global r1TcpHdrFrame r0TcpHdrFrame urgTcpHdrFrame ackTcpHdrFrame
  global pshTcpHdrFrame rstTcpHdrFrame synTcpHdrFrame finTcpHdrFrame
  global windowTcpHdrFrame urpTcpHdrFrame tcpchksumTcpHdrFrame
  global sPortTcpHdrFrame dPortTcpHdrFrame seqTcpHdrFrame
  global acknoTcpHdrFrame tcpoffsetTcpHdrFrame resTcpHdrFrame
  global sPortUdpHdrFrame dPortUdpHdrFrame udplenUdpHdrFrame udpchksumUdpHdrFrame
  global typeIcmpHdrFrame codeIcmpHdrFrame chksumIcmpHdrFrame
  global idIcmpHdrFrame seqIcmpHdrFrame sipIcmpDecodeFrame
  global dipIcmpDecodeFrame sportIcmpDecodeFrame dportIcmpDecodeFrame protoIcmpDecodeFrame gipIcmpDecodeFrame
  global dataText

  $srcIPHdrFrame.text delete 0.0 end
  $dstIPHdrFrame.text delete 0.0 end
  $verIPHdrFrame.text delete 0.0 end
  $hdrLenIPHdrFrame.text delete 0.0 end
  $tosIPHdrFrame.text delete 0.0 end
  $lenIPHdrFrame.text delete 0.0 end
  $idIPHdrFrame.text delete 0.0 end
  $flagsIPHdrFrame.text delete 0.0 end
  $offsetIPHdrFrame.text delete 0.0 end
  $ttlIPHdrFrame.text delete 0.0 end
  $chksumIPHdrFrame.text delete 0.0 end

  $r1TcpHdrFrame.text delete 0.0 end
  $r0TcpHdrFrame.text delete 0.0 end
  $urgTcpHdrFrame.text delete 0.0 end
  $ackTcpHdrFrame.text delete 0.0 end
  $pshTcpHdrFrame.text delete 0.0 end
  $rstTcpHdrFrame.text delete 0.0 end
  $synTcpHdrFrame.text delete 0.0 end
  $finTcpHdrFrame.text delete 0.0 end
  $windowTcpHdrFrame.text delete 0.0 end
  $urpTcpHdrFrame.text delete 0.0 end
  $tcpchksumTcpHdrFrame.text delete 0.0 end
  $sPortTcpHdrFrame.text delete 0.0 end
  $dPortTcpHdrFrame.text delete 0.0 end
  $seqTcpHdrFrame.text delete 0.0 end
  $acknoTcpHdrFrame.text delete 0.0 end
  $tcpoffsetTcpHdrFrame.text delete 0.0 end
  $resTcpHdrFrame.text delete 0.0 end

  $sPortUdpHdrFrame.text delete 0.0 end
  $dPortUdpHdrFrame.text delete 0.0 end
  $udplenUdpHdrFrame.text delete 0.0 end
  $udpchksumUdpHdrFrame.text delete 0.0 end

  $typeIcmpHdrFrame.text delete 0.0 end
  $codeIcmpHdrFrame.text delete 0.0 end
  $chksumIcmpHdrFrame.text delete 0.0 end
  $idIcmpHdrFrame.text delete 0.0 end
  $seqIcmpHdrFrame.text delete 0.0 end
  $sipIcmpDecodeFrame.text delete 0.0 end
  $dipIcmpDecodeFrame.text delete 0.0 end
  $gipIcmpDecodeFrame.text delete 0.0 end
  $sportIcmpDecodeFrame.text delete 0.0 end
  $dportIcmpDecodeFrame.text delete 0.0 end
  $protoIcmpDecodeFrame.text delete 0.0 end
  $dataText delete 0.0 end
}
proc InsertIPHdr { data } {
  global srcIPHdrFrame dstIPHdrFrame verIPHdrFrame hdrLenIPHdrFrame
  global tosIPHdrFrame lenIPHdrFrame idIPHdrFrame flagsIPHdrFrame
  global offsetIPHdrFrame ttlIPHdrFrame chksumIPHdrFrame
  
  $srcIPHdrFrame.text insert 0.0 [lindex $data 0]
  $dstIPHdrFrame.text insert 0.0 [lindex $data 1]
  $verIPHdrFrame.text insert 0.0 [lindex $data 2]
  $hdrLenIPHdrFrame.text insert 0.0 [lindex $data 3]
  $tosIPHdrFrame.text insert 0.0 [lindex $data 4]
  $lenIPHdrFrame.text insert 0.0 [lindex $data 5]
  $idIPHdrFrame.text insert 0.0 [lindex $data 6]
  $flagsIPHdrFrame.text insert 0.0 [lindex $data 7]
  $offsetIPHdrFrame.text insert 0.0 [lindex $data 8]
  $ttlIPHdrFrame.text insert 0.0 [lindex $data 9]
  $chksumIPHdrFrame.text insert 0.0 [lindex $data 10]
}
proc InsertTcpHdr { data } {
  global r1TcpHdrFrame r0TcpHdrFrame urgTcpHdrFrame ackTcpHdrFrame
  global pshTcpHdrFrame rstTcpHdrFrame synTcpHdrFrame finTcpHdrFrame
  global windowTcpHdrFrame urpTcpHdrFrame tcpchksumTcpHdrFrame
  global sPortTcpHdrFrame dPortTcpHdrFrame seqTcpHdrFrame
  global acknoTcpHdrFrame tcpoffsetTcpHdrFrame resTcpHdrFrame

  $sPortTcpHdrFrame.text insert 0.0 [lindex $data 8]
  $dPortTcpHdrFrame.text insert 0.0 [lindex $data 9]
  $seqTcpHdrFrame.text insert 0.0 [lindex $data 0]
  $acknoTcpHdrFrame.text insert 0.0 [lindex $data 1]
  $tcpoffsetTcpHdrFrame.text insert 0.0 [lindex $data 2]
  $resTcpHdrFrame.text insert 0.0 [lindex $data 3]
  # TCP Flags
  set ipFlags [lindex $data 4]
  set r1Flag "."
  set r0Flag "."
  set urgFlag "."
  set ackFlag "."
  set pshFlag "."
  set rstFlag "."
  set synFlag "."
  set finFlag "."
  if { $ipFlags != "" } {
    if { 128 & $ipFlags } {
      set r1Flag "X"
      set ipFlags [expr $ipFlags - 128]
    }
    if { 64 & $ipFlags } {
      set r0Flag "X"
      set ipFlags [expr $ipFlags - 64]
    }
    if { 32 & $ipFlags } {
      set urgFlag "X"
      set ipFlags [expr $ipFlags - 32]
    }
    if { 16 & $ipFlags } {
      set ackFlag "X"
      set ipFlags [expr $ipFlags - 16]
    }
    if { 8 & $ipFlags } {
      set pshFlag "X"
      set ipFlags [expr $ipFlags - 8]
    }
    if { 4 & $ipFlags } {
      set rstFlag "X"
      set ipFlags [expr $ipFlags - 4]
    }
    if { 2 & $ipFlags } {
      set synFlag "X"
      set ipFlags [expr $ipFlags - 2]
    }
    if { 1 & $ipFlags } {
      set finFlag "X"
    }
  }
  $r1TcpHdrFrame.text insert 0.0 $r1Flag
  $r0TcpHdrFrame.text insert 0.0 $r0Flag
  $urgTcpHdrFrame.text insert 0.0 $urgFlag
  $ackTcpHdrFrame.text insert 0.0 $ackFlag
  $pshTcpHdrFrame.text insert 0.0 $pshFlag
  $rstTcpHdrFrame.text insert 0.0 $rstFlag
  $synTcpHdrFrame.text insert 0.0 $synFlag
  $finTcpHdrFrame.text insert 0.0 $finFlag

  $windowTcpHdrFrame.text insert 0.0 [lindex $data 5]
  $urpTcpHdrFrame.text insert 0.0 [lindex $data 6]
  $tcpchksumTcpHdrFrame.text insert 0.0 [lindex $data 7]
  
}
proc InsertUdpHdr { data } {
  global sPortUdpHdrFrame dPortUdpHdrFrame udplenUdpHdrFrame udpchksumUdpHdrFrame
  $sPortUdpHdrFrame.text insert 0.0 [lindex $data 2]
  $dPortUdpHdrFrame.text insert 0.0 [lindex $data 3]
  $udplenUdpHdrFrame.text insert 0.0 [lindex $data 0]
  $udpchksumUdpHdrFrame.text insert 0.0 [lindex $data 1]
}
proc InsertIcmpHdr { data pldata } {
  global typeIcmpHdrFrame codeIcmpHdrFrame chksumIcmpHdrFrame
  global idIcmpHdrFrame seqIcmpHdrFrame
  global icmpDecodeFrame icmpHdrFrame
  $typeIcmpHdrFrame.text insert 0.0 [lindex $data 0]
  $codeIcmpHdrFrame.text insert 0.0 [lindex $data 1]
  $chksumIcmpHdrFrame.text insert 0.0 [lindex $data 2]
  $idIcmpHdrFrame.text insert 0.0 [lindex $data 3]
  $seqIcmpHdrFrame.text insert 0.0 [lindex $data 4]
  
  # If the ICMP packet is a dest unreachable, redirect or a time exceeded,
  # check to see if it is network, host, port unreachable or admin prohibited or filtered
  # then show some other stuff

  if {[lindex $data 0] == "3" || [lindex $data 0] == "11" || [lindex $data 0] == "5"} {
	if {[lindex $data 1] == "0" || [lindex $data 1] == "4" || [lindex $data 1] == "9" || [lindex $data 1] == "13" || [lindex $data 1] == "1" || [lindex $data 1] == "3" || [lindex $data 1] == "2" } {
	    global protoIcmpDecodeFrame sipIcmpDecodeFrame sportIcmpDecodeFrame dipIcmpDecodeFrame dportIcmpDecodeFrame gipIcmpDecodeFrame
	    
	    #  There may be 32-bits of NULL padding at the start of the payload
	    # or a 32-bit gateway address on a redirect
	    set offset 0
	    # puts [string range $pldata 0 7]
	    if {[string range $pldata 0 7] == "00000000" || [lindex $data 0] == "5"} {
		set offset 8
		if {[lindex $data 0] == "5"} {
		    set giphex1 [string range $pldata 0 1]
		    set giphex2 [string range $pldata 2 3]
		    set giphex3 [string range $pldata 4 5]
		    set giphex4 [string range $pldata 6 7]
		    $gipIcmpDecodeFrame.text insert 0.0 [format "%i" 0x$giphex1].[format "%i" 0x$giphex2].[format "%i" 0x$giphex3].[format "%i" 0x$giphex4]
		}
	    }
	    # puts [string range $pldata [expr $offset+24] [expr $offset+25]]
	    
	    # Build the protocol
	    set protohex [string range $pldata [expr $offset+18] [expr $offset+19]]
	    $protoIcmpDecodeFrame.text insert 0.0 [format "%i" 0x$protohex]

	    # Build the src address
	    set srchex1 [string range $pldata [expr $offset+24] [expr $offset+25]]
	    set srchex2 [string range $pldata [expr $offset+26] [expr $offset+27]]
	    set srchex3 [string range $pldata [expr $offset+28] [expr $offset+29]]
	    set srchex4 [string range $pldata [expr $offset+30] [expr $offset+31]]
	    $sipIcmpDecodeFrame.text insert 0.0 [format "%i" 0x$srchex1].[format "%i" 0x$srchex2].[format "%i" 0x$srchex3].[format "%i" 0x$srchex4]
	    
	    # Build the dst address
	    set dsthex1 [string range $pldata [expr $offset+32] [expr $offset+33]]
	    set dsthex2 [string range $pldata [expr $offset+34] [expr $offset+35]]
	    set dsthex3 [string range $pldata [expr $offset+36] [expr $offset+37]]
	    set dsthex4 [string range $pldata [expr $offset+38] [expr $offset+39]]
	    $dipIcmpDecodeFrame.text insert 0.0 [format "%i" 0x$dsthex1].[format "%i" 0x$dsthex2].[format "%i" 0x$dsthex3].[format "%i" 0x$dsthex4]
	    
	    # Find and build the src port
	    set hdroffset [expr [string index $pldata [expr ($offset+1)]] * 8 + $offset]
	    puts "header offset = $hdroffset"
	    puts "header lenght = [string index $pldata [expr ($offset+1)]]"
	    puts "offset = $offset"
	    puts "looking for length at [expr ($offset+1)]"
	    puts "pldata is $pldata"
	    set sporthex [string range $pldata $hdroffset [expr $hdroffset+3]]
	    $sportIcmpDecodeFrame.text insert 0.0 [format "%i" 0x$sporthex]
	    
	    # Dest Port
	    set dporthex [string range $pldata [expr $hdroffset+4] [expr $hdroffset+7]]
	    $dportIcmpDecodeFrame.text insert 0.0 [format "%i" 0x$dporthex]
	    
	    pack $icmpDecodeFrame -after $icmpHdrFrame -fill x
	} else {
            pack forget $icmpDecodeFrame
        }
    } else {
        pack forget $icmpDecodeFrame
    }
	    
}
proc InsertPayloadData { data } {
  global dataText
  if {[lindex $data 0] == ""} { 
    $dataText insert 0.0 "None."
  } else {
    set payload [lindex $data 0]
    set dataLength [string length $payload]
    set asciiStr ""
    set counter 2
    for {set i 1} {$i < $dataLength} {incr i 2} {
      set currentByte [string range $payload [expr $i - 1] $i]
      lappend hexStr $currentByte
      set intValue [format "%i" 0x$currentByte]
      if { $intValue < 32 || $intValue > 126 } {
        # Non printable char
        set currentChar "."
      } else {
        set currentChar [format "%c" $intValue]
      }
      set asciiStr "$asciiStr$currentChar"
      if { $counter == 32 } {
        $dataText insert end "$hexStr $asciiStr\n"
        set hexStr ""
        set asciiStr ""
        set counter 2
      } else {
        incr counter 2
      }
    }
    $dataText insert end "[format "%-47s %s\n" $hexStr $asciiStr]"
  }
  Idle
}

#
# UnSelectPacketOptions:  Used when ESC is hit or on a multiple selection to turn off packet details, etc
#
proc UnSelectPacketOptions { } {
  global displayPacketButton displayRuleButton referenceButton icatButton displayPSButton
  $displayPacketButton deselect
  ClearPacketData
  $displayRuleButton deselect
  ClearRuleText
  $referenceButton configure -state disabled
  $icatButton configure -state disabled
  ClearPSLists
  $displayPSButton deselect
}
#
# ScrollHome: If ScrollHome var is set, move the scrollbar to the bottom of the list
#
proc ScrollHome { paneName } {
  global SCROLL_HOME
  if {$SCROLL_HOME($paneName)} {
    foreach childWin [winfo children $paneName] {
      if { [winfo name $childWin] != "scroll" } {
        $childWin.list see end
      }
    }
  }
}

#
# BindSelectionToAllLists: Grabs button-1 events and make sure that a list is
#                          selected across all lists.
#
proc BindSelectionToAllLists { listName } {
    foreach buttonEvent { "Shift-Button-1" } {
	bind $listName <$buttonEvent> { ShiftSelect %W [%W nearest %y]; break }
    }
    foreach buttonEvent { "Control-Button-1" } {
	bind $listName <$buttonEvent> { CtrlSelect %W [%W nearest %y]; break }
    }
    foreach buttonEvent { "Button-1" } {
        bind $listName <$buttonEvent> { SingleSelect %W [%W nearest %y]; break }
    }
    foreach buttonEvent { "B1-Motion" "Control-B1-Motion" } {
	bind $listName <$buttonEvent> { MotionSelect %W [%W nearest %y]; break }
    }
    foreach buttonEvent { "ButtonRelease-1" } {
	bind $listName <$buttonEvent> { ReSetMotion }
    }
    foreach buttonEvent { "MouseWheel" "Button-5" } {
	bind $listName <$buttonEvent> { WheelScroll %D %W "5"; break }
    }
    foreach buttonEvent { "Button-4" } {
	bind $linstName <$buttonEvent> { WheelScroll %D %W "4"; break }
    }
}    
proc BindSelectionToAllPSLists { listName } {
    
    foreach buttonEvent { "MouseWheel" "Button-5" } {
	bind $listName <$buttonEvent> { WheelScroll %D %W "5"; break }
    }
    foreach buttonEvent { "Button-4" } {
	bind $linstName <$buttonEvent> { WheelScroll %D %W "4"; break }
    }
}
#
# WheelScroll: Scroll all of the lists together on a mousey-wheely-scrolly
#
proc WheelScroll { delta winName source } {
    global SCROLL_HOME
    if { $source == 4 || $source == 5 } {
	set parentWin [winfo parent [winfo parent $winName]]
    } else {
	set parentWin $winName
    }
    set SCROLL_HOME($parentWin) 0
    # first we have to support Windows and X
    # Windows will trigger on MouseWheel events and delta will be high (at least more than 10)
    # if it is a negative number, then we are looking a a MouseWheel event
    # XWindows (in most cases generate Button-4 or -5 events and delta will be 4 or 5
    # Some strange mice in some X systems in some WM's don't fill in delta
    # so instead, we grab which button event happened and use it for delta
    if { $delta == "??" } {
	set delta $source
    }
    # X-Windows wheel motion
    if { $delta == 4 || $delta == 5 } {
	if { $delta == 4 } { set move -3 }
	if { $delta == 5 } { set move 3 }
    } else {
	# MouseWheel Motion (usually Windows generated)
	if { $delta > 0 } { set move -3 }
	if { $delta < 0 } { set move 3}
	if { $delta == 0 } { break } 
    }
    foreach childWin [winfo children $parentWin] {
	if { [winfo name $childWin] != "scroll" } {
	    $childWin.list yview scroll $move units
	}
    }
    # check scrollbar position, if at the bottom, toggle SCROLL_HOME
    set scrollbarPosition [lindex [$parentWin.scroll get] 1]
    if {$scrollbarPosition == 1.0} {set SCROLL_HOME($parentWin) 1}
}
proc InfoMessage { message } {
    puts $message
    tk_messageBox -type ok -icon info -message "$message"
}
proc ErrorMessage { message } {
    puts $message
    tk_messageBox -type ok -icon warning -message "$message"
}
