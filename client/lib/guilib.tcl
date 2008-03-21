####################################################
# Sguil procs for general GUI purposes             #
# Note:  Selection and Multi-Selection procs       #
# have their own file (sellib.tcl)                 #
####################################################
# $Id: guilib.tcl,v 1.27 2008/03/21 16:13:41 bamm Exp $
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
	    Copyright (C) 2002-2008 Robert (Bamm) Visscher <bamm@satx.rr.com>\n\
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

    set tbl $winName.table
    set sb $winName.scrollbar

    tablelist::tablelist $tbl \
        -columns {15  "Column Name"  left
                  10  "Type"         left
                  10 "Length"        left} \
         -selectmode single \
         -movablecolumns 0 \
         -yscrollcommand [list $sb set] -width 40

    $tbl columnconfigure 0 -name cname -resizable 1 -stretchable 1 -sortmode dictionary
    $tbl columnconfigure 1 -name ctype -resizable 1 -stretchable 1 -sortmode dictionary
    $tbl columnconfigure 2 -name clength -resizable 1 -stretchable 1 -sortmode integer

    scrollbar $sb -orient vertical -width 10 -command [list $tbl yview]

    pack $tbl -side left -fill both -expand true
    pack $sb -side right -fill y
   
    foreach column $columnList {
        $tbl insert end $column
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
  global dataText dataHex dataSearchButton
  global prioritySfpDataFrame connectionsSfpDataFrame ipCountSfpDataFrame ipRangeSfpDataFrame protoCountSfpDataFrame protoRangeSfpDataFrame sfpOPDataText

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
  $dataHex delete 0.0 end
  $dataSearchButton configure -state disabled
  $prioritySfpDataFrame.text delete 0.0 end
  $connectionsSfpDataFrame.text delete 0.0 end
  $ipCountSfpDataFrame.text delete 0.0 end
  $ipRangeSfpDataFrame.text delete 0.0 end
  $protoCountSfpDataFrame.text delete 0.0 end
  $protoRangeSfpDataFrame.text delete 0.0 end
  $sfpOPDataText delete 0.0 end
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
proc InsertTcpHdr { data ports} {
  global r1TcpHdrFrame r0TcpHdrFrame urgTcpHdrFrame ackTcpHdrFrame
  global pshTcpHdrFrame rstTcpHdrFrame synTcpHdrFrame finTcpHdrFrame
  global windowTcpHdrFrame urpTcpHdrFrame tcpchksumTcpHdrFrame
  global sPortTcpHdrFrame dPortTcpHdrFrame seqTcpHdrFrame
  global acknoTcpHdrFrame tcpoffsetTcpHdrFrame resTcpHdrFrame

  $sPortTcpHdrFrame.text insert 0.0 [lindex $ports 0]
  $dPortTcpHdrFrame.text insert 0.0 [lindex $ports 1]
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
proc InsertUdpHdr { data ports } {
  global sPortUdpHdrFrame dPortUdpHdrFrame udplenUdpHdrFrame udpchksumUdpHdrFrame
  $sPortUdpHdrFrame.text insert 0.0 [lindex $ports 0]
  $dPortUdpHdrFrame.text insert 0.0 [lindex $ports 1]
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
    global protoIcmpDecodeFrame sipIcmpDecodeFrame sportIcmpDecodeFrame dipIcmpDecodeFrame dportIcmpDecodeFrame gipIcmpDecodeFrame
    
    set ICMPList [DecodeICMP [lindex $data 0] [lindex $data 1] $pldata]
    if { $ICMPList != "NA" } {
	$gipIcmpDecodeFrame.text insert 0.0 [lindex $ICMPList 0]
	$protoIcmpDecodeFrame.text insert 0.0 [lindex $ICMPList 1]
	$sipIcmpDecodeFrame.text insert 0.0 [lindex $ICMPList 2]
	$dipIcmpDecodeFrame.text insert 0.0 [lindex $ICMPList 3]
	$sportIcmpDecodeFrame.text insert 0.0 [lindex $ICMPList 4]
	$dportIcmpDecodeFrame.text insert 0.0 [lindex $ICMPList 5]
	
	pack $icmpDecodeFrame -after $icmpHdrFrame -fill x
    } else {
	pack forget $icmpDecodeFrame
    }	    
}

proc InsertGenericDetail { hexData } {

    global genericText

    $genericText  insert end [hex2string $hexData]
    Idle

}

proc InsertPadsBanner { data } {

    global bannerText bannerHex

    set banner [lindex $data 0]

    if { $banner == "" } {

        $bannerText insert 0.0 "None"
        $bannerHex insert 0.0 "None"

    } else {

        set dataLength [string length $banner]
        set asciiStr ""
        set counter 2

        for {set i 1} {$i < $dataLength} {incr i 2} {

            set currentByte [string range $banner [expr $i - 1] $i]
            append hexStr "$currentByte "
            set intValue [format "%i" 0x$currentByte]

            if { $intValue < 32 || $intValue > 126 } {
                # Non printable char
                set currentChar "."
            } else {
                set currentChar [format "%c" $intValue]
            }

            append asciiStr "$currentChar"

            if { $counter == 32 } {

                $bannerHex insert end "$hexStr\n"
                $bannerText insert end "$asciiStr\n"
                set hexStr ""
                set asciiStr ""
                set counter 2

            } elseif { $counter == 16 } {

                append hexStr " "
                append asciiStr " "
                incr counter 2

            } else {

                incr counter 2

            }

        }

        $bannerText insert end $asciiStr
        $bannerHex insert end $hexStr
        Idle

    }

}

proc InsertPayloadData { data } {
  global dataText dataHex dataSearchButton sfpDataFrame
  set payload [lindex $data 0]
  if {[lindex $data 0] == ""} { 
    $dataText insert 0.0 "None."
    $dataHex insert 0.0 "None."  
  } elseif { [string range $payload 0 15] == "5072696F72697479" } {
      set SFPList [DecodeSFPPayload $payload]
      $sfpDataFrame.prioritySpfDataFrame.text insert end [lindex $SFPList 0]
      $sfpDataFrame.connectionsSpfDataFrame.text insert end [lindex $SFPList 1]
      $sfpDataFrame.ipCountSpfDataFrame.text insert end [lindex $SFPList 2]
      $sfpDataFrame.ipRangeSpfDataFrame.text insert end [lindex $SFPList 3] 
      $sfpDataFrame.protoCountSpfDataFrame.text insert end [lindex $SFPList 4]
      $sfpDataFrame.protoRangeSpfDataFrame.text insert end [lindex $SFPList 5]
  } else {
    $dataSearchButton configure -state active
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
	$dataHex insert end "$hexStr\n"  
        $dataText insert end "$asciiStr\n"
        set hexStr ""
        set asciiStr ""
        set counter 2
      } else {
        incr counter 2
      }
    }
    $dataText insert end $asciiStr
    $dataHex insert end $hexStr
  }
  Idle
}

#
# UnSelectPacketOptions:  Used when ESC is hit or on a multiple selection to turn off packet details, etc
#
proc UnSelectPacketOptions { } {

    global displayPacketButton displayRuleButton 
    global padsDisplayButton displayPSButton

    $displayPacketButton deselect
    ClearPacketData

    $displayRuleButton deselect
    ClearRuleText

    ClearPSLists
    $displayPSButton deselect

    ClearPadsData
    $padsDisplayButton deselect
  
}

#
# ScrollHome: If ScrollHome var is set, move the scrollbar to the bottom of the list
#
proc ScrollHome { paneName } {

  global SCROLL_HOME

  if {$SCROLL_HOME($paneName)} { $paneName see end }

}

proc BindSelectionToAllDataBoxes { boxName } {

    foreach buttonEvent { "MouseWheel" "Button-5" } {
        bind $boxName <$buttonEvent> { WheelDataScroll %D %W "5"; break }
    }

    foreach buttonEvent { "Button-4" } {
        bind $boxName <$buttonEvent> { WheelDataScroll %D %W "4"; break }
    }

}

#
# WheelDataScroll: Scroll all of the packet data text boxes together on a mousey-wheely-scrolly
#
proc WheelDataScroll { delta winName source } {

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
    foreach childWin [winfo children [winfo parent $winName]] {
        if { [winfo name $childWin] != "scroll" } {

            $childWin yview scroll $move units
        }
    }
}


proc InfoMessage { message } {
    
    global DEBUG

    if {$DEBUG} { puts $message }
    tk_messageBox -type ok -icon info -message "$message"

}
proc ErrorMessage { message } {

    tk_messageBox -type ok -icon warning -message "$message"

}
proc SearchData {} {
    global dataSearchText dataTextFrame dataSearchType dataSearchCase
    set searchWidget [$dataSearchType get]
    $searchWidget tag delete highlight
    set searchtext [$dataSearchText get]
    if {$searchtext == "" || $searchtext == "\n"} {
	return
    }
    regsub -all {\n} $searchtext {} searchtext
    set searchRegexp ""
    for {set i 0} { $i < [string length $searchtext] } { incr i } {
	set searchRegexp "${searchRegexp}[string range $searchtext $i $i]\\n*"
    }
    set stop 1
    set nextchar 0
    set textinds {}
    while {$stop == 1} {
	set inds {}
	if { $dataSearchCase == 0 } {
	    set stop [regexp -start $nextchar  -indices -- $searchRegexp [$searchWidget get 0.0 end-1c] inds]
	} else {
	    set stop [regexp -nocase -start $nextchar  -indices -- $searchRegexp [$searchWidget get 0.0 end-1c] inds]
	}
	set nextchar [expr [lindex $inds 1] +1]
	if {$stop == 1 } {
	    foreach index $inds {
		lappend textinds [$searchWidget index "1.0 +$index chars"]
	    }
	}
    }    
    set i 0
    # puts $textinds
    if { [llength $textinds] == 0 } { 
	InfoMessage "Search string $searchtext not found."
	return 
    }

    while {$i < [llength $textinds] } {
	$searchWidget tag add highlight [lindex $textinds $i] "[lindex $textinds [expr $i + 1]] + 1 chars"
    set i [expr $i + 2] 
    }
    
    $searchWidget tag configure highlight -background yellow
    $searchWidget see [lindex $textinds 0]
}
proc ShowHideSearch { } {
    global dataSearchFrame packetFrame dataFrame
   
    if {[winfo ismapped $dataSearchFrame] == 0 } {
	pack forget $dataFrame
	pack $dataSearchFrame -side bottom -anchor s -fill x -expand false
	pack $dataFrame -fill both -expand true -side top
    } else {
	pack forget $dataSearchFrame
    }
}

# Pub Domain Wheel Scroll Code
proc WheelEvent { x y delta } {

    # Find out what's the widget we're on
    set act 0
    set widget [winfo containing $x $y]

    if {$widget != ""} {
        # Make sure we've got a vertical scrollbar for this widget
        if {[catch "$widget cget -yscrollcommand" cmd]} return

        if {$cmd != ""} {
            # Find out the scrollbar widget we're using
            set scroller [lindex $cmd 0]

            # Make sure we act
            set act 1
        }
    }

    if {$act == 1} {
        # Now we know we have to process the wheel mouse event
        set xy [$widget yview]
        set factor [expr [lindex $xy 1]-[lindex $xy 0]]

        # Make sure we activate the scrollbar's command
        set cmd "[$scroller cget -command] scroll [expr -int($delta/(120*$factor))] units"
        eval $cmd
    }

}
