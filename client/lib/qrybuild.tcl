# $Id: qrybuild.tcl,v 1.43 2007/03/17 02:43:37 bamm Exp $ #
proc QryBuild { tableSelected whereTmp } {

    global RETURN_FLAG SELECTEDTABLE SELECT_LIMIT
    global  tableColumnArray tableList funcList whereBoxList

    set RETURN_FLAG 0
    set SELECTEDTABLE $tableSelected
    
    if {$SELECTEDTABLE == "empty"} {
	set SELECTEDTABLE "event"
    }
    if {$whereTmp == "empty"} {
	set whereTmp "WHERE"
    }
    
    # Grab the current pointer locations
    set xy [winfo pointerxy .]
    # Create the window
    set qryBldWin .qryBldWin
    if { [winfo exists $qryBldWin] } {
	wm withdraw $qryBldWin
	wm deiconify $qryBldWin
	return
    }
    
    toplevel $qryBldWin
    wm title $qryBldWin "Query Builder"
    set height [winfo height .]
    set width [winfo width .]
    set y [expr ( ( $height / 2 ) - 250)]
    if { $y < 0 } { set y 0 }
    set x [expr ( ( $width / 2 ) - 350)]
    if { $x < 0 } { set x 0 }
    wm geometry $qryBldWin +$x+$y
    
    # Create some arrays for the lists
    # funclist are lists of {LABEL FUNCTION} pairs.  In most cases they will be the same.
    set mlst [list Tables Functions]
    set funcList(main) [list Common Strings Comparison Logical DateTime DateMacros]
    set funcList(mainevent) [list Categories]
    set funcList(mainsancp) [list FlagMacros]
    set funcList(Common) [list {INET_ATON() INET_ATON()} {LIMIT LIMIT} {LIKE LIKE} {AND AND} {OR OR} {NOT NOT}]
    set funcList(Strings) [list {LIKE LIKE} {REGEXP REGEXP} {RLIKE RLIKE}]
    set funcList(Logical) [list {AND AND} {OR OR} {NOT NOT} {LIKE LIKE}]
    set funcList(Comparison) [list {= =} {!= !=} {< <} {> >} {<=> <=>}]
    set funcList(DateTime) [list {TO_DAYS() TO_DAYS()} {UNIX_TIMESTAMP() UNIX_TIMESTAMP} {UTC_TIMESTAMP() UTC_TIMESTAMP}]
    set funcList(DateMacros) [list [list TODAYUTC '[lindex [GetCurrentTimeStamp] 0]'] \
	    [list LASTWEEK '[lindex [GetCurrentTimeStamp "1 week ago"] 0]'] \
	    [list YESTERDAY '[lindex [GetCurrentTimeStamp "1 day ago"] 0]']]
    set funcList(Categories) [list {CATI event.status=11} {CATII event.status=12} {CATIII event.status=13} \
	    {CATIV event.status=14} {CATV event.status=15} {CATVI event.status=16} {CATVII event.status=17} \
	    {NA event.status=1} {RealTime event.status=0} {Escalated event.status=2}]
    foreach tableName $tableList {
	set funcList($tableName) $tableColumnArray($tableName)
    }
    
    # Main Frame
    set mainFrame [frame $qryBldWin.mFrame -background #dcdcdc -borderwidth 1]

    # Query Type Box 
    set qryFrame [frame $mainFrame.qFrame]
      set qryTypeBox [radiobox $qryFrame.qTypeBox -orient horizontal -labeltext "Select Query Type" -labelpos n -foreground darkblue]
        $qryTypeBox add event -text "Events" -selectcolor red -foreground black
        #$qryTypeBox add sessions -text "Sessions" -selectcolor red -foreground black
        $qryTypeBox add sancp -text "Sancp" -selectcolor red -foreground black  
        $qryTypeBox add pads -text "PADS" -selectcolor red -foreground black  
 
        $qryTypeBox select $SELECTEDTABLE
        $qryTypeBox configure -command {typeChange}
      #pack the children of the queryFrame
      pack $qryTypeBox -side left -expand false
    # Edit Frame
    set editFrame [frame $mainFrame.eFrame -background black -borderwidth 1]
      
    set whereFrame [frame $editFrame.whereFrame]
    set cnt 0
    foreach where $whereTmp {
        set f ${whereFrame}.frame${cnt}
        set b ${f}.ub
        if [info exists editBox] {
            $b configure -text "Delete" -command "DeleteWhereBox $f $editBox"
        }

        set editBox [AddWhereBox $whereFrame $cnt]
        lappend whereBoxList $editBox
        incr cnt

        $editBox insert end $where
        $editBox mark set insert "end -11 c"

    }

    set maxRowsText [entryfield $whereFrame.maxRows -labeltext "LIMIT" -labelpos w -width 5 \
                     -textvariable SELECT_LIMIT]
    pack $maxRowsText -side bottom -expand no


      
      # Button box on left of edit box 
      set mainBB1 [buttonbox $editFrame.mbb1 -padx 0 -pady 0 -orient vertical]
      foreach logical $funcList(Logical) {
	      $mainBB1 add [lindex $logical 0] -text [lindex $logical 0] -padx 0 -pady 0 -command "ScrolledTextInsert [lindex $logical 1]"
      }
      # One last button for the left side that acts differently
      $mainBB1 add ipAddress -text "IP Address" -padx 0 -pady 0 -command "IPAddress2SQL builder"
      
      # button box to right of main edit box
      set mainBB2 [buttonbox $editFrame.mbb2 -padx 0 -pady 0 -orient vertical]
      foreach comparison $funcList(Comparison) {
          $mainBB2 add [lindex $comparison 0] -text [lindex $comparison 0] -padx 0 -pady 0 -command "ScrolledTextInsert [lindex $comparison 1]"
      }
      
      # packing children of edit frame
      pack $mainBB1 -side left -fill y
      pack $whereFrame -side left -fill both -expand true
      pack $mainBB2 -side left -fill y

    # Select Frame
    set selectFrame [frame $mainFrame.sFrame -background black -borderwidth 1]
      set catList [scrolledlistbox $selectFrame.cList -labeltext Categories \
	      -selectioncommand "updateItemList $selectFrame" -sbwidth 10\
	      -labelpos n -vscrollmode static -hscrollmode dynamic \
	      -visibleitems 20x10 -foreground darkblue -textbackground lightblue]
      set metaList [scrolledlistbox $selectFrame.mList -labeltext Meta -sbwidth 10\
	      -selectioncommand "updateCatList $selectFrame" \
	      -hscrollmode dynamic \
	      -labelpos n -vscrollmode static \
	      -visibleitems 20x10 -foreground darkblue -textbackground lightblue]
      set itemList [scrolledlistbox $selectFrame.iList -hscrollmode dynamic -sbwidth 10\
	     -dblclickcommand "addToEditBox $selectFrame" \
	     -scrollmargin 5 -labeltext "Items" \
	     -labelpos n -vscrollmode static -hscrollmode static\
	     -visibleitems 20x10 -foreground darkblue -textbackground lightblue]
      set flagFrame [frame $selectFrame.fFrame]
        set srcdstBox [radiobox $flagFrame.sdBox]
          $srcdstBox add src -text "Source"
          $srcdstBox add dst -text "Dest"
          $srcdstBox select src
        set flagBox [checkbox $flagFrame.fBox]
        set flags [list FIN SYN RST PSH ACK URG R1 R2]
        foreach f $flags {
	    $flagBox add $f -text [string totitle $f]
	}
	set logicBox [radiobox $flagFrame.lBox]
	  $logicBox add only -text "ONLY selected flags" 
	  $logicBox add and -text "AT LEAST selected flags"
	  $logicBox add not -text "NOT selected flags"
	  $logicBox select only
	set insertButton [button $flagFrame.iButton -command "addToEditBoxFlags $flagFrame" -text "Insert"]
	
	# packing children of flag Frame
	pack $srcdstBox $flagBox $logicBox $insertButton -side top -fill both -expand true
      
      # packing children of select frame
      pack $metaList $catList $itemList -side left -fill both -expand true
      iwidgets::Labeledwidget::alignlabels $metaList $catList $itemList
    
    # Button box for Submit/Cancel
    set buttonFrame [frame $mainFrame.bFrame]
      set submitButton [button $buttonFrame.submitButton -text "Submit" -command "set RETURN_FLAG 1"]
      set cancelButton [button $buttonFrame.cancelButton -text "Cancel" -command "set RETURN_FLAG 0"]
      pack $submitButton $cancelButton -side left -expand true 
    # pack the qryFrame to the top no fill no expand	
    pack $qryFrame -side top  -expand true
    
    # pack the main edit frame to the top fill and expand
    pack $editFrame -side top -fill both -expand yes

    # pack the select frame and submit/cancel box to the top fill and expand
    pack  $selectFrame $buttonFrame -side top -fill both -expand true -pady 1
    eval $metaList insert 0 $mlst

    #pack the main frame
    pack $mainFrame -side top -pady 1 -expand true -fill both
update

    tkwait variable RETURN_FLAG
    set returnWhere [list cancel [list cancel]]
    if {$RETURN_FLAG} {
        foreach box $whereBoxList {
            # No \n for you!
            regsub -all {\n} [$box get 0.0 end] {} tmpWhere
            lappend whereList $tmpWhere
        }
	set returnWhere "[list $SELECTEDTABLE $whereList]"
    } else {
	set returnWhere [list cancel [list cancel]]
    }
    destroy $qryBldWin

    set whereBoxList ""

    return $returnWhere  

}

proc AddWhereBox { frame cnt } {

    incr cnt
    set f $frame.frame$cnt
    set st $f.st
    set ub $f.ub

    frame $f 
    scrolledtext $st -textbackground white -vscrollmode dynamic \
		-sbwidth 10 -hscrollmode none -wrap word -visibleitems 60x3 -textfont ourFixedFont \
		-labeltext "Edit Where Clause $cnt"
    button $ub -text "Add Union" -command "AddUnion $frame $f $st $ub $cnt"

    pack $st -side top -expand true -fill both
    pack $ub -side bottom -expand false
    pack $f -side top -expand true -fill both

    return $st

}

proc DeleteWhereBox { oldFrame oldSt } {

    global whereBoxList
   
    set whereBoxList [ldelete $whereBoxList $oldSt]
    destroy $oldFrame 

}

proc AddUnion { frame oldFrame oldSt oldUb cnt } {

    global whereBoxList

    # Change the button on the calling where box.
    $oldUb configure -text "Delete" -command "DeleteWhereBox $oldFrame $oldSt"
    
    # Create new where box
    set st [AddWhereBox $frame $cnt]
    lappend whereBoxList $st

    # Copy data from old into new
    set whereTmp [$oldSt get 0.0 end]
    $st insert end $whereTmp
    $st  mark set insert "end -11 c"

}

proc IsWhereBox { win } {

    global whereBoxList

    set FOCUS 0
    foreach whereBox $whereBoxList {

        if { $win == [$whereBox component text] } {

            set FOCUS 1
            break

        }
        
    }

    return $FOCUS

}

proc ScrolledTextInsert { data } {

    global whereBoxList

    set currentWin [focus]

    if { [IsWhereBox $currentWin] } { 

        $currentWin insert insert "$data "

    } else {

        tk_messageBox -type ok -parent .qryBldWin \
          -message "Cannot insert \"$data\" into SQL. None of the text boxes have focus."

    }

}

proc updateCatList { selectFrame } {
    global funcList metaSelection SELECTEDTABLE
     
    $selectFrame.cList delete 0 end
    #$selectFrame.cList delete entry 0 end
    $selectFrame.iList delete 0 end
    
    set sel [$selectFrame.mList getcurselection]
    set metaSelection $sel
#    puts $tableSelected
    if {$sel == "Tables"} { 
	if { $SELECTEDTABLE == "event" } {
	    set localTableList [list event data icmphdr tcphdr udphdr sensor]
	} elseif { $SELECTEDTABLE == "sessions" } {
	    set localTableList [list sessions sensor]
	} elseif { $SELECTEDTABLE == "sancp" } {
	    set localTableList [list sancp sensor]
	} elseif { $SELECTEDTABLE == "pads" } {
            set localTableList [list pads sensor] } {
        }
	eval $selectFrame.cList insert 0 $localTableList
    } else {
	eval $selectFrame.cList insert 0 $funcList(main)
	if { $SELECTEDTABLE == "event" } {
	    eval $selectFrame.cList insert end $funcList(mainevent)
	}
	if { $SELECTEDTABLE == "sancp" } {
	    eval $selectFrame.cList insert end $funcList(mainsancp)
	}
    }
}
    
proc updateItemList { selectFrame} {
    global funcList catSelection metaSelection
    
    $selectFrame.iList delete 0 end
    #$selectFrame.iList delete entry 0 end
    
    eval set sel [$selectFrame.cList getcurselection]
    set catSelection $sel
    if {$metaSelection == "Tables"} {
	pack forget $selectFrame.fFrame
        pack $selectFrame.iList
	eval $selectFrame.iList insert 0 $funcList($sel)
    } elseif { $sel != "FlagMacros" } {
	pack forget $selectFrame.fFrame
	pack $selectFrame.iList
	foreach i $funcList($sel) {
	    eval $selectFrame.iList insert end [lindex $i 0]
	}
    } else {
	pack forget $selectFrame.iList
	pack $selectFrame.fFrame
    }
}

proc addToEditBox { selectFrame } {

    global catSelection metaSelection funcList
    
    
    set currentWin [focus]
    if { ![IsWhereBox $currentWin] } {
        tk_messageBox -type ok -parent .qryBldWin \
          -message "Click in the text box you want to insert data into first."
        return
    }
    #if Meta is set to table, prepend tablename. to the item
    if {$metaSelection == "Tables"} {
	set addText [lindex [$selectFrame.iList getcurselection] 0]
	set addText "$catSelection.$addText"
    } else {
	set addText [lindex [lindex $funcList($catSelection) [$selectFrame.iList curselection]]  1]
    }
    
    $currentWin insert insert "$addText "
}

proc addToEditBoxFlags { flagFrame } {
    
    set currentWin [focus]
    if { ![IsWhereBox $currentWin] } {
        tk_messageBox -type ok -parent .qryBldWin \
          -message "Click in the text box you want to insert data into first."
        return
    }
    # add up the flags selected to get the decimal representation
    set flaglist [$flagFrame.fBox get]
    # puts $flaglist
    set decimalFlag 0
# puts [lsearch -exact $flaglist "FIN"]
    if {[lsearch -exact $flaglist "FIN"] > -1} { set decimalFlag [expr $decimalFlag + 1] }
    if {[lsearch -exact $flaglist "SYN"] > -1} { set decimalFlag [expr $decimalFlag + 2] }
    if {[lsearch -exact $flaglist "RST"] > -1} { set decimalFlag [expr $decimalFlag + 4] }
    if {[lsearch -exact $flaglist "PSH"] > -1} { set decimalFlag [expr $decimalFlag + 8] }
    if {[lsearch -exact $flaglist "ACK"] > -1} { set decimalFlag [expr $decimalFlag + 16] }
    if {[lsearch -exact $flaglist "URG"] > -1} { set decimalFlag [expr $decimalFlag + 32] }
    if {[lsearch -exact $flaglist "R1"] > -1} { set decimalFlag [expr $decimalFlag + 64] }
    if {[lsearch -exact $flaglist "R2"] > -1} { set decimalFlag [expr $decimalFlag + 128] }
    # puts $decimalFlag
    
    set target [$flagFrame.sdBox get]
    set target "${target}_flags"
   
    # logic time (dusts off the old bitmath)
    set logic [$flagFrame.lBox get]
    if { $logic == "and" } {
	set insert "sancp.${target} & ${decimalFlag} = ${decimalFlag}"
    } elseif { $logic == "not" } {
	set insert "sancp.${target} & ${decimalFlag} = 0"
    } else { 
	set insert "sancp.${target} = ${decimalFlag}"
    }
    
    $currentWin insert insert $insert
}	

proc typeChange {} {
    global SELECTEDTABLE whereBoxList

    set mainFrame .qryBldWin.mFrame
    foreach box $whereBoxList {
        $box delete 0.0 end
    }

    set tableType [$mainFrame.qFrame.qTypeBox get]
    
    if { $tableType == "event" } {
	set SELECTEDTABLE "event"
    } elseif { $tableType == "sessions" } {
	set SELECTEDTABLE "sessions"
    } elseif { $tableType == "sancp" } {
	set SELECTEDTABLE "sancp"
    } elseif { $tableType == "pads" } {
	set SELECTEDTABLE "pads"
    }
    
    
    # return $tableSelected
}

#
#  InvokeQryBuild:  Call this proc if you need QueryBuilder to run stand-alone.
#     Calls DBQryRequest or SSNQryRequest after QryBuild is done
proc InvokeQryBuild { tableSelected whereTmpList } {
    
    global SELECTEDTABLE

    set tmpWhereStatement [QryBuild $tableSelected $whereTmpList]
    set tableName [lindex $tmpWhereStatement 0]
    if { $tableName == "cancel" } { return }
    set whereStatement [lindex $tmpWhereStatement 1]
    if { $tableName == "event" } {
	DBQueryRequest $SELECTEDTABLE $whereStatement
    } elseif { $tableName == "sessions" } {
	SsnQueryRequest $SELECTEDTABLE $whereStatement
    } else {
	SancpQueryRequest $SELECTEDTABLE $whereStatement
    }
}

#
#  IPAddress2SQL:  Pops up a box to type in an IP address/subnet (in CIDR) and spits
#                 out SQL to find that range.
#                 args:
#                 caller: Where this proc was called from.  Options: builder, menu
#                 parameter: If called from the builder, this is the path to the builders editBox
#                            If called from elsewhere, it is unused.
#
proc IPAddress2SQL { caller {parameter {NULL}} } {

    global SELECTEDTABLE RETURN_FLAG_IP whereBoxList

    # If we came in thru the query builder then we check to see
    # which WHERE is active.
    if { $caller == "builder" } {

        set currentWin [focus]
        if { ![IsWhereBox $currentWin] } {
            tk_messageBox -type ok -parent .qryBldWin \
              -message "Click in the text box you want to insert data into first."
            return
        }

    }

    # Create the window
    set ipAddressWin .ipAddressWin
    if { [winfo exists $ipAddressWin] } {
	wm withdraw $ipAddressWin
	wm deiconify $ipAddressWin
	return
    }
    
    set xy [winfo pointerxy .]
    toplevel $ipAddressWin
    wm title $ipAddressWin "IP Address Builder"
    wm geometry $ipAddressWin +[lindex $xy 0]+[lindex $xy 1]
    # Main Frame
    set mainFrame [frame $ipAddressWin.mFrame -background #dcdcdc -borderwidth 1]
    set ipBox [entryfield $mainFrame.ipBox -textbackground white -textfont ourFixedFont \
		-labeltext "Enter IP Address/Net" -command "set RETURN_FLAG_IP 1"]
    set srcdstBox [radiobox $mainFrame.srcdstToggle -orient horizontal]
    $srcdstBox add src -text "Src" 
    $srcdstBox add dst -text "Dst"
    $srcdstBox add src2dst -text "Src To Dst"
    $srcdstBox select 0
    if { $caller != "builder" } {
	set tableBox [radiobox $mainFrame.tableBox -orient horizontal]
	$tableBox add event -text "Event"
	#$tableBox add sessions -text "Sessions"
	$tableBox add sancp -text "Sancp"
	$tableBox select 0
    }
    set buttonFrame [frame $mainFrame.bFrame]
    set submitButton [button $buttonFrame.submitButton -text "Submit" -command "set RETURN_FLAG_IP 1"]
    if { $caller != "builder" } {
	set buildButton [button $buttonFrame.buildButton -text "Build" -command "set RETURN_FLAG_IP 2"]
    }
    set cancelButton [button $buttonFrame.cancelButton -text "Cancel" -command "set RETURN_FLAG_IP 0"]
    if { $caller != "builder" } {
	pack $buildButton -side left
    }
    pack $submitButton $cancelButton -side left

    pack $ipBox $srcdstBox -side top -expand false
    if { $caller != "builder" } {
	pack $tableBox -side top -expand false
    }
    pack $buttonFrame -side top -expand false
    pack $mainFrame
    focus $ipBox
    tkwait variable RETURN_FLAG_IP
    if { $RETURN_FLAG_IP == 0 } {
	destroy $ipAddressWin
	return
    }
    
    # Check that the content is in valid format and store it in varibles
    set fullip [$ipBox get]
    set iplist [ValidateIPAddress $fullip]

    if { $iplist==0 } { 
	ErrorMessage "Error.  Invalid IP Address"
	    destroy $ipAddressWin
	    IPAddress2SQL $caller
    }
    
    if { $caller != "builder" } {
	set SELECTEDTABLE [$tableBox get]
    }
    set qryType [$srcdstBox get]

    if { [lindex $iplist 1] == 32 } {

        # Query a single IP
        if { $qryType == "src" || $qryType == "dst" } {
            set inserttext "${SELECTEDTABLE}.${qryType}_ip = INET_ATON('[lindex $iplist 0]')"
        } else {
            set inserttext "${SELECTEDTABLE}.src_ip = INET_ATON('[lindex $iplist 0]') AND ${SELECTEDTABLE}.dst_ip = INET_ATON('[lindex $iplist 0]')"
        }

    } else { 

        set networknumber [lindex $iplist 2]
        set bcastaddress [lindex $iplist 3]
        # find the decimal values for the ip network and broadcast addresses
        set decNetwork [InetAtoN $networknumber]
        set decBcast [InetAtoN $bcastaddress]
    
        # build the ip part of the query.  It will look the same no matter what table we are working with. 
        if { $qryType == "src" } {
	    set inserttext "${SELECTEDTABLE}.src_ip BETWEEN ${decNetwork} AND ${decBcast} "
        } elseif { $qryType  == "dst" } {
	    set inserttext "${SELECTEDTABLE}.dst_ip BETWEEN ${decNetwork} AND ${decBcast} "
        } else {
	    set inserttext "(${SELECTEDTABLE}.dst_ip BETWEEN ${decNetwork} AND ${decBcast} \
		    OR ${SELECTEDTABLE}.src_ip BETWEEN ${decNetwork} AND ${decBcast}) "
        }
    
        # do something depending on who called us

    }
    if { $caller == "builder" } {
	$currentWin insert insert $inserttext
	destroy $ipAddressWin 
	return
    } elseif { $caller == "menu" } {

	if { $SELECTEDTABLE == "event" } {
	    set timestamp [lindex [GetCurrentTimeStamp "1 week ago"] 0]
	    set tmpWhere "WHERE ${SELECTEDTABLE}.timestamp > '$timestamp' AND $inserttext"
	} else {
	    set timestamp [lindex [GetCurrentTimeStamp "1 day ago"] 0]
	    set tmpWhere "WHERE ${SELECTEDTABLE}.start_time > '${timestamp}' AND  $inserttext"
	}
	# Are we going to the builder or submitting the query
	if { $RETURN_FLAG_IP == 2 } {
	    destroy $ipAddressWin
	    InvokeQryBuild $SELECTEDTABLE [list $tmpWhere]
	} else {
	    destroy $ipAddressWin
	    if { $SELECTEDTABLE == "event" } {
		DBQueryRequest $SELECTEDTABLE [list $tmpWhere]
	    } elseif { $SELECTEDTABLE == "sessions" } {
		SsnQueryRequest $SELECTEDTABLE $tmpWhere
	    } elseif { $SELECTEDTABLE == "sancp" } {
		SancpQueryRequest $SELECTEDTABLE [list $tmpWhere]
	    }
	} 
    }
    return
}

