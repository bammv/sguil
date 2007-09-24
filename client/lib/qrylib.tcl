# $Id: qrylib.tcl,v 1.38 2007/09/24 14:49:43 bamm Exp $ #
#
# QueryRequest is called thru various drop downs.
# It's job is to massage the data into the meat of 
# a WHERE statement, pass the info on to the QryBuilder
# and finally call DBQueryRequest or SsnQueryRequest.
#
proc QueryRequest { tableName queryType { incidentCat {NULL} } { build {"build"}}} {

    global CUR_SEL_PANE 

    # Example sancp UNION
    # (
    #
    #   SELECT sensor.hostname, sancp.sancpid, sancp.start_time as datetime, sancp.end_time, 
    #          INET_NTOA(sancp.src_ip), sancp.src_port, INET_NTOA(sancp.dst_ip), sancp.dst_port,
    #          sancp.ip_proto, sancp.src_pkts, sancp.src_bytes, sancp.dst_pkts, sancp.dst_bytes
    #   FROM sancp
    #   IGNORE INDEX (p_key) 
    #   INNER JOIN sensor ON sancp.sid=sensor.sid
    #   WHERE sancp.start_time > '2005-08-02' AND sancp.src_ip = INET_ATON('82.96.96.3')
    #
    # ) UNION (
    #
    #   SELECT sensor.hostname, sancp.sancpid, sancp.start_time as datetime, sancp.end_time,
    #          INET_NTOA(sancp.src_ip), sancp.src_port, INET_NTOA(sancp.dst_ip), sancp.dst_port,
    #          sancp.ip_proto, sancp.src_pkts, sancp.src_bytes, sancp.dst_pkts, sancp.dst_bytes
    #   FROM sancp
    #   IGNORE INDEX (p_key)
    #   INNER JOIN sensor ON sancp.sid=sensor.sid
    #   WHERE sancp.start_time > '2005-08-02' AND sancp.dst_ip = INET_ATON('82.96.96.3')
    #
    # ) 
    #
    # ORDER BY datetime
    # LIMIT 500;

    set eventtimestamp [lindex [GetCurrentTimeStamp "1 week ago"] 0]
    set ssntimestamp [lindex [GetCurrentTimeStamp "1 day ago"] 0]
    if { $queryType != "category" && $queryType != "empty" } { set selectedIndex [$CUR_SEL_PANE(name) curselection] }

    if { $tableName == "event" } {

	if { $incidentCat == "RT" } {
	    set globalWhere "WHERE event.status = 0 AND "
	} else {
	    set globalWhere "WHERE $tableName.timestamp > '$eventtimestamp' AND "
	}   

    } elseif { $tableName == "pads" } {

        if { $build == "build" } { 
            set globalWhere "WHERE $tableName.timestamp > $eventtimestamp AND " 
        } else { 
            set globalWhere "WHERE " 
        }

    } else {

	if { ( $queryType == "srcip" || $queryType == "dstip" || $queryType == "src2dst" ) && $incidentCat == "hour" } {

            if { $CUR_SEL_PANE(type) == "SANCP" } {
                set starttime [clock scan "30 min ago" -base [clock scan [$CUR_SEL_PANE(name) getcells $selectedIndex,starttime]]]
            } else {
                set starttime [clock scan "30 min ago" -base [clock scan [$CUR_SEL_PANE(name) getcells $selectedIndex,date]]]
            }

	    set endtime [expr $starttime + 3600]
	    set tminus [clock format $starttime -f "%Y-%m-%d %T"]
	    set tplus [clock format $endtime -f "%Y-%m-%d %T"]
	    set globalWhere "WHERE $tableName.start_time > '$tminus' AND $tableName.start_time < '$tplus' AND "

	} else {

	    set globalWhere "WHERE $tableName.start_time > '$ssntimestamp' AND "

	}  

    }

    if { $queryType == "srcip" } {

	set srcIP [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]

        if { $tableName == "pads" } {

            lappend whereTmp "$globalWhere $tableName.ip = INET_ATON('$srcIP')"

        } else {

	    lappend whereTmp "$globalWhere $tableName.src_ip = INET_ATON('$srcIP')"
            lappend whereTmp "$globalWhere $tableName.dst_ip = INET_ATON('$srcIP')"

        }

    } elseif { $queryType == "srcport" } {

	set srcport [$CUR_SEL_PANE(name) getcells $selectedIndex,srcport]
	lappend whereTmp "$globalWhere $tableName.src_port = '$srcport'"
        lappend whereTmp "$globalWhere $tableName.dst_port = '$srcport'"

    } elseif { $queryType == "dstport" } {

	set dstport [$CUR_SEL_PANE(name) getcells $selectedIndex,dstport]
	lappend whereTmp "$globalWhere $tableName.src_port = '$dstport'"
        lappend whereTmp "$globalWhere $tableName.dst_port = '$dstport'"

    } elseif { $queryType == "dstip" } {

	set dstIP [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]

        if { $tableName == "pads" } {

            lappend whereTmp "$globalWhere $tableName.ip = INET_ATON('$dstIP')"

        } else {

	    lappend whereTmp "$globalWhere $tableName.src_ip = INET_ATON('$dstIP')"
            lappend whereTmp "$globalWhere $tableName.dst_ip = INET_ATON('$dstIP')"

        }

    } elseif { $queryType == "empty" } {

	lappend whereTmp "$globalWhere <Insert Query Here>"

    } elseif { $queryType == "src2dst" } {

	set srcIP [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]
	set dstIP [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]
	lappend whereTmp "$globalWhere $tableName.src_ip  = INET_ATON('$srcIP') AND $tableName.dst_ip = INET_ATON('$dstIP')"

    } elseif { $queryType == "category" } {

	lappend whereTmp "$globalWhere event.status = $incidentCat"

    } elseif { $queryType == "signature" } {

	set eventMsg [$CUR_SEL_PANE(name) getcells $selectedIndex,event]
	lappend whereTmp "$globalWhere event.signature = '$eventMsg'"

    } elseif { $queryType == "pads" } {

	set dstIP [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]

    }

    # if it is a sancp query tack a order by start_time on it.  MERGE tables mess up the returned order.
    #if { $tableName == "sancp" } { set whereTmp "$whereTmp ORDER BY $tableName.start_time" }

    if { $build != "quick" } {

	set tmpWhereStatement [QryBuild $tableName $whereTmp]
	set whereStatement [lindex $tmpWhereStatement 1]
	set tableName [lindex $tmpWhereStatement 0]

    } else {

        set whereStatement $whereTmp

    }

    if { $whereStatement == "cancel" } { return }

    if { $tableName == "event" } {

	if { $queryType == "category" } {

	    switch -exact $incidentCat {
		11 { set winTitle "Cat I" }
		12 { set winTitle "Cat II" }
		13 { set winTitle "Cat III" }
		14 { set winTitle "Cat IV" }
		15 { set winTitle "Cat V" }
		16 { set winTitle "Cat VI" }
		17 { set winTitle "Cat VII" }
		default { set winTitle "none" }
	    }

	    DBQueryRequest $tableName $whereStatement $winTitle

	} else {
 
	    DBQueryRequest $tableName $whereStatement

	}

    } elseif { $tableName == "sessions" } {

	SsnQueryRequest $whereStatement

    } elseif { $tableName == "sancp" } {

	SancpQueryRequest $tableName $whereStatement

    } elseif { $tableName == "pads" } { 

        PadsQueryRequest $tableName $whereStatement

    }

}
#
# Build a ssn query tab and send the query to sguild.
#
proc SsnQueryRequest { whereStatement } {
  global eventTabs SSN_QUERY_NUMBER socketID DEBUG
  global CONNECTED
  if {!$CONNECTED} {ErrorMessage "Not connected to sguild. Query aborted"; return}
  set selectQuery "SELECT sensor.hostname, sessions.xid, sessions.start_time, sessions.end_time,\
   INET_NTOA(sessions.src_ip), sessions.src_port, INET_NTOA(sessions.dst_ip), sessions.dst_port,\
   sessions.ip_proto, sessions.src_pckts, sessions.src_bytes, sessions.dst_pckts, sessions.dst_bytes\
   FROM sessions INNER JOIN sensor ON sessions.sid=sensor.sid $whereStatement"
  regsub -all {\n} $selectQuery {} selectQuery
  incr SSN_QUERY_NUMBER
  $eventTabs add -label "Ssn Query $SSN_QUERY_NUMBER"
  set currentTab [$eventTabs childsite end]
  set tabIndex [$eventTabs index end]
  set queryFrame [frame $currentTab.ssnquery_${SSN_QUERY_NUMBER} -background black -borderwidth 1]
  $eventTabs select end
  # Here is where we build the session display lists.
  CreateSessionLists $queryFrame
  set buttonFrame [frame $currentTab.buttonFrame]
  set whereText [text $buttonFrame.text -height 1 -background white -wrap none]
  $whereText insert 0.0 $whereStatement
  bind $whereText <Return> {
    set whereStatement [%W get 0.0 end]
    SsnQueryRequest $whereStatement
    break
  }
  set closeButton [button $buttonFrame.close -text "Close" \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "DeleteTab $eventTabs $currentTab"]
  set exportButton [button $buttonFrame.export -text "Export" \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "ExportResults $queryFrame ssn"]
  set rsubmitButton [button $buttonFrame.rsubmit -text "Submit " \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "SsnQueryRequest \[$whereText get 0.0 end\] "]
  pack $closeButton $exportButton -side left
  pack $whereText -side left -fill x -expand true
  pack $rsubmitButton -side left
  pack $buttonFrame -side top -fill x
  pack $queryFrame -side bottom -fill both
  $queryFrame configure -cursor watch
  if {$DEBUG} { puts "Sending Server: QueryDB $queryFrame $selectQuery" }
  SendToSguild "QueryDB $queryFrame $selectQuery"
}
#
# Build an event query tab and send the query to sguild.
#
proc DBQueryRequest { selectedTable whereList {winTitle {none} } } {

    global eventTabs QUERY_NUMBER socketID DEBUG
    global CONNECTED SELECT_LIMIT

    if {!$CONNECTED} {ErrorMessage "Not connected to sguild. Query aborted."; return}
  
    set COLUMNS "event.status, event.priority, sensor.hostname, \
     event.timestamp as datetime, event.sid, event.cid, event.signature,\
     INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto,\
     event.src_port, event.dst_port, event.signature_gen, event.signature_id, \
     event.signature_rev"

    # Parse the WHERE's and determine what tables we need to SELECT from.

    # We'll always have 'event' and 'sensor'.
    set JOINS "INNER JOIN sensor ON event.sid=sensor.sid"

    foreach whereStatement $whereList {

        #  user_info
        if { [regexp {\s+user_info\.} $whereStatement] } {
            set JOINS "$JOINS INNER JOIN user_info ON user_info.uid=event.last_uid"
        }

         # tcphdr
        if { [regexp {\s+tcphdr\.} $whereStatement] } {
            set JOINS "$JOINS INNER JOIN tcphdr ON event.sid=tcphdr.sid AND event.cid=tcphdr.cid"
        }

        # udphdr
        if { [regexp {\s+udphdr\.} $whereStatement] } {
            set JOINS "$JOINS INNER JOIN udphdr ON event.sid=udphdr.sid AND event.cid=udphdr.cid"
        }

        # icmphdr
        if { [regexp {\s+icmphdr\.} $whereStatement] } {
            set JOINS "$JOINS INNER JOIN icmphdr ON event.sid=icmphdr.sid AND event.cid=icmphdr.cid"
        }

        # data
        if { [regexp {\s+data\.} $whereStatement] } {
            set JOINS "$JOINS INNER JOIN data ON event.sid=data.sid AND event.cid=data.cid"
        }

        lappend queries "SELECT $COLUMNS FROM event IGNORE INDEX (event_p_key, sid_time) $JOINS $whereStatement"

    }

    # Union queries have a llength > 0
    if { [llength $queries] > 1 } {
 
        set tmpQry [join $queries " ) UNION ( "]
        set fQuery "( $tmpQry ) ORDER BY datetime, src_port ASC LIMIT $SELECT_LIMIT"
    
    } else {

        set fQuery "[lindex $queries 0] ORDER BY datetime, src_port ASC LIMIT $SELECT_LIMIT"

    }

    regsub -all {\n} $fQuery {} selectQuery

    incr QUERY_NUMBER

    if { $winTitle == "none" } {
        $eventTabs add -label "Event Query $QUERY_NUMBER"
    } else {
        $eventTabs add -label "Event Query $winTitle"
    }

    set currentTab [$eventTabs childsite end]
    set tabIndex [$eventTabs index end]
    set queryFrame [frame $currentTab.query_$QUERY_NUMBER -background black -borderwidth 1]
    $eventTabs select end
    CreateEventLists $queryFrame 1 0
    set topFrame [frame $currentTab.topFrame]
    set whereText [scrolledtext $topFrame.text -textbackground white -visibleitems 30x3 -wrap word \
      -vscrollmode dynamic -hscrollmode none -sbwidth 10]
    $whereText insert 0.0 $selectQuery
    $whereText configure -state disabled
    set lbuttonsFrame [frame $topFrame.lbuttons]
    set closeButton [button $lbuttonsFrame.close -text "Close" \
	    -relief raised -borderwidth 2 -pady 0 \
	    -command "DeleteTab $eventTabs $currentTab"]
    set exportButton [button $lbuttonsFrame.export -text "Export " \
	    -relief raised -borderwidth 2 -pady 0 \
	    -command "ExportResults $queryFrame event"]
    pack $closeButton $exportButton -side top -fill x
    set rbuttonsFrame [frame $topFrame.rbuttons]
    set rsubmitButton [button $rbuttonsFrame.rsubmit -text "Submit " \
	    -relief raised -borderwidth 2 -pady 0 \
	    -command "[list DBQueryRequest $selectedTable $whereList]"]
    set editButton [button $rbuttonsFrame.edit -text "Edit " \
	    -relief raised -borderwidth 2 -pady 0 \
	    -command "[list EditQuery $selectedTable $whereList]"]
    pack $rsubmitButton $editButton -side top -fill x
    pack $lbuttonsFrame  -side left
    pack $whereText -side left -fill both -expand true
    pack $rbuttonsFrame  -side left
    pack $topFrame -side top -fill x
    pack $queryFrame -side bottom -fill both
    $queryFrame configure -cursor watch
    SendToSguild "QueryDB $queryFrame.tablelist $selectQuery"

}

proc PadsQueryRequest { table where } {

    global eventTabs PADS_QUERY_NUMBER DEBUG CONNECTED SELECT_LIMIT

    if {!$CONNECTED} {ErrorMessage "Not connected to sguild. Query aborted"; return}

    set COLUMNS "pads.hostname, pads.sid, pads.asset_id, pads.timestamp as datetime, \
     INET_NTOA(pads.ip), pads.ip_proto, pads.service, pads.port, pads.application"

    set tmpQuery "SELECT $COLUMNS FROM pads [lindex $where 0]"
    regsub -all {\n} $tmpQuery {} selectQuery

    incr PADS_QUERY_NUMBER
    $eventTabs add -label "Asset Query $PADS_QUERY_NUMBER"
    set currentTab [$eventTabs childsite end]
    set tabIndex [$eventTabs index end]
    set queryFrame [frame $currentTab.padsquery_${PADS_QUERY_NUMBER} -background black -borderwidth 1]
    $eventTabs select end

    # Build the display list
    CreatePadsLists $queryFrame

    # Create the rest of the frame
    set topFrame [frame $currentTab.topFrame]
    set whereText [scrolledtext $topFrame.text -textbackground white -visibleitems 30x3 -wrap word \
      -vscrollmode dynamic -hscrollmode none -sbwidth 10]
    $whereText insert 0.0 $selectQuery
    $whereText configure -state disabled
    set lbuttonsFrame [frame $topFrame.lbuttons]
    set closeButton [button $lbuttonsFrame.close -text "Close" \
            -relief raised -borderwidth 2 -pady 0 \
            -command "DeleteTab $eventTabs $currentTab"]
    set exportButton [button $lbuttonsFrame.export -text "Export " \
            -relief raised -borderwidth 2 -pady 0 \
            -command "ExportResults $queryFrame pads"]
    pack $closeButton $exportButton -side top -fill x
    set rbuttonsFrame [frame $topFrame.rbuttons]
    set rsubmitButton [button $rbuttonsFrame.rsubmit -text "Submit " \
            -relief raised -borderwidth 2 -pady 0 \
            -command "[list PadsQueryRequest $table $where]"]
    set editButton [button $rbuttonsFrame.edit -text "Edit " \
            -relief raised -borderwidth 2 -pady 0 \
            -command "[list EditQuery $table $where]"]
    pack $rsubmitButton $editButton -side top -fill x
    pack $lbuttonsFrame  -side left
    pack $whereText -side left -fill both -expand true
    pack $rbuttonsFrame  -side left
    pack $topFrame -side top -fill x
    pack $queryFrame -side bottom -fill both

    $queryFrame configure -cursor watch
    if {$DEBUG} { puts "Sending Server: QueryDB $queryFrame $selectQuery" }

    SendToSguild "QueryDB $queryFrame.tablelist $selectQuery"

}

proc EditQuery { tableName whereList } {

    set tmpWhereStatement [QryBuild $tableName $whereList]
    set whereList [lindex $tmpWhereStatement 1]
    set tableName [lindex $tmpWhereStatement 0]

    if { $whereList  == "cancel" } { return }

    if { $tableName == "event" } {

        DBQueryRequest $tableName $whereList 

    } elseif { $tableName == "sessions" } {

	SsnQueryRequest $tableName $whereList 

    } elseif { $tableName == "sancp" } {

	SancpQueryRequest $tableName $whereList 

    }

}

# Depreciated
proc GetStdQuery {} {
  set data [StdQuery]
  set  [lindex $data 0]
  if { $query == "abort" } { return }
  set whereStatement [EditWhere $query]
  if { $whereStatement == "cancel" } { return }
  if { [lindex $data 1] == "sessions" } {
    SsnQueryRequest $whereStatement
  } else {
    DBQueryRequest $whereStatement
  }
}
# Depreciated
proc EditWhere { whereTmp } {
  global RETURN_FLAG
  set RETURN_FLAG 0
  set editWhere .editWhere
  if { [winfo exists $editWhere] } {
    wm withdraw $editWhere
    wm deiconify $editWhere
    return
  }
  toplevel $editWhere
  wm geometry $editWhere +[expr [winfo pointerx .] - 200]+[expr [winfo pointery .]- 30 ]
  wm title $editWhere "Query Template"
  set textBox [scrolledtext $editWhere.textBox -textbackground white -vscrollmode dynamic\
   -hscrollmode none -wrap word -visibleitems 80x5 -labeltext "Edit WHERE Statement"]
  set buttonBox [buttonbox $editWhere.buttonBox]
    $buttonBox add ok -text "Ok" -command "set RETURN_FLAG 1"
    $buttonBox add showTables -text "Show DB Tables" -command ShowDBTables
    $buttonBox add cancel -text "Cancel" -command "set RETURN_FLAG 0"
  pack $textBox $buttonBox -side top -fill both -expand true
  set whereTmp "$whereTmp LIMIT 500"
  $textBox insert end "$whereTmp"
  tkwait variable RETURN_FLAG
  if {$RETURN_FLAG} {
    set whereStatement [$textBox get 0.0 end]
    regsub -all {\n} $whereStatement {} whereStatement
  } else {
    set whereStatement "cancel"
  }
  destroy $editWhere
  return $whereStatement
}
