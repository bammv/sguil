# $Id: qrybuild.tcl,v 1.23 2004/10/18 21:46:05 shalligan Exp $ #
proc QryBuild {tableSelected whereTmp } {
    global RETURN_FLAG SELECTEDTABLE
    global  tableColumnArray tableList funcList
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
	wm deiconify $qryBldWIn
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
    set funcList(Logical) [list {AND AND} {OR OR} {NOT NOT} {BETWEEN() BETWEEN()} {LIKE LIKE}]
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

    
    set qryTypeBox [radiobox $mainFrame.qTypeBox -orient horizontal -labeltext "Select Query Type" -labelpos n -foreground darkblue]
      $qryTypeBox add event -text "Events" -selectcolor red -foreground black
      $qryTypeBox add sessions -text "Sessions" -selectcolor red -foreground black
      $qryTypeBox add sancp -text "Sancp" -selectcolor red -foreground black  
 
      $qryTypeBox select $SELECTEDTABLE
      $qryTypeBox configure -command {typeChange}

    set editFrame [frame $mainFrame.eFrame -background black -borderwidth 1]
      set editBox [scrolledtext $editFrame.eBox -textbackground white -vscrollmode dynamic \
		-sbwidth 10 -hscrollmode none -wrap word -visibleitems 60x10 -textfont ourFixedFont \
		-labeltext "Edit Where Clause"]
      
      if { ![string match -nocase *limit* $whereTmp] } { set whereTmp "$whereTmp  LIMIT 500" }
      $editBox insert end $whereTmp
      $editBox mark set insert "end -11 c"
      set bb [buttonbox $mainFrame.bb]
      $bb add Submit -text "Submit" -command "set RETURN_FLAG 1"
      $bb add Cancel -text "Cancel" -command "set RETURN_FLAG 0"
      #pack $bb -side top -fill x -expand true

    set mainBB1 [buttonbox $editFrame.mbb1 -padx 0 -pady 0 -orient vertical]
      foreach logical $funcList(Logical) {
	  set command "$editBox insert insert \"[lindex $logical 1] \""
	  $mainBB1 add [lindex $logical 0] -text [lindex $logical 0] -padx 0 -pady 0 -command "$command"
      }
    set mainBB2 [buttonbox $editFrame.mbb2 -padx 0 -pady 0 -orient vertical]
      foreach comparison $funcList(Comparison) {
	  set command "$editBox insert insert \"[lindex $comparison 1] \""
	  $mainBB2 add [lindex $comparison 0] -text [lindex $comparison 0] -padx 0 -pady 0 -command "$command"
      }
      pack $mainBB1 -side left -fill y
      pack $editBox -side left -fill both -expand true
      pack $mainBB2 -side left -fill y

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
	     -dblclickcommand "addToEditBox $editBox $selectFrame" \
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
	set insertButton [button $flagFrame.iButton -command "addToEditBoxFlags $editBox $flagFrame" -text "Insert"]
	pack $srcdstBox $flagBox $logicBox $insertButton -side top -fill both -expand true
      pack $metaList $catList $itemList -side left -fill both -expand true
      iwidgets::Labeledwidget::alignlabels $metaList $catList $itemList
    pack $qryTypeBox -side top -fill none -expand false
    pack $editFrame -side top -fill both -expand yes
    #pack  $mainBB1 $mainBB2 -side top -fill none -expand false
    pack  $selectFrame $bb -side top -fill both -expand true -pady 1
    eval $metaList insert 0 $mlst
    pack $mainFrame -side top -pady 1 -expand true -fill both
update


    tkwait variable RETURN_FLAG
    set returnWhere [list cancel cancel]
    if {$RETURN_FLAG} {
        # No \n for you!
        regsub -all {\n} [$editBox get 0.0 end] {} returnWhere
	set returnWhere "[list $SELECTEDTABLE $returnWhere]"
    } else {
	set returnWhere [list cancel cancel]
    }
    destroy $qryBldWin
    return $returnWhere  
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
	} else {
	    set localTableList [list sancp sensor]
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

proc addToEditBox { editBox selectFrame } {
    global catSelection metaSelection funcList
    
    
    #if Meta is set to table, prepend tablename. to the item
    if {$metaSelection == "Tables"} {
	set addText [lindex [$selectFrame.iList getcurselection] 0]
	set addText "$catSelection.$addText"
    } else {
	set addText [lindex [lindex $funcList($catSelection) [$selectFrame.iList curselection]]  1]
    }
    
    $editBox insert insert "$addText "
}

proc addToEditBoxFlags {editBox flagFrame} {
    
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
    
    $editBox insert insert $insert
}	

proc typeChange {} {
    global SELECTEDTABLE
    set mainFrame .qryBldWin.mFrame
    $mainFrame.eFrame.eBox delete 0.0 end
    $mainFrame.sFrame.iList delete 0 end
    $mainFrame.sFrame.cList delete 0 end
    
    if {[$mainFrame.qTypeBox get] == "event" } {
	$mainFrame.eFrame.eBox insert end "WHERE  LIMIT 500"
	set SELECTEDTABLE "event"
    } elseif {[$mainFrame.qTypeBox get] == "sessions" } {
	set SELECTEDTABLE "sessions"
	$mainFrame.eFrame.eBox insert end "WHERE  LIMIT 500"
    } else {
	set SELECTEDTABLE "sancp"
	$mainFrame.eFrame.eBox insert end "WHERE LIMIT 500"
    }
    
    $mainFrame.eFrame.eBox mark set insert "end -11 c"
    # return $tableSelected
}

#
#  InvokeQryBuild:  Call this proc if you need QueryBuilder to run stand-alone.
#     Calls DBQryRequest or SSNQryRequest after QryBuild is done
proc InvokeQryBuild { tableSelected whereTmp } {
    
    set tmpWhereStatement [QryBuild $tableSelected $whereTmp]
    set whereStatement [lindex $tmpWhereStatement 1]
    set tableName [lindex $tmpWhereStatement 0]
    if { $whereStatement == "cancel" } { return }
    if { $tableName == "event" } {
	DBQueryRequest $whereStatement
    } elseif { $tableName == "sessions" } {
	SsnQueryRequest $whereStatement
    } else {
	SancpQueryRequest $whereStatement
    }
}

