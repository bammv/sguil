#
# QueryRequest is called thru various drop downs.
# It's job is to massage the data into the meat of 
# a WHERE statement, pass the info on to the QryBuilder
# and finally call DBQueryRequest or SsnQueryRequest.
#
proc QueryRequest { tableName queryType { incidentCat {NULL} } } {
  global currentSelectedPane
  set timestamp [lindex [GetCurrentTimeStamp "1 week ago"] 0]
  if { $tableName == "event" } {
    set whereTmp "WHERE $tableName.sid=sensor.sid AND $tableName.timestamp > '$timestamp' AND "
  } else {
    set whereTmp "WHERE $tableName.sid=sensor.sid AND $tableName.start_time > '$timestamp' AND "
  }
  if { $queryType == "srcip" } {
    set selectedIndex [$currentSelectedPane.srcIPFrame.list curselection]
    set srcIP [$currentSelectedPane.srcIPFrame.list get $selectedIndex]
    set whereTmp "$whereTmp $tableName.src_ip = INET_ATON('$srcIP')"
  } elseif { $queryType == "dstip" } {
    set selectedIndex [$currentSelectedPane.srcIPFrame.list curselection]
    set dstIP [$currentSelectedPane.dstIPFrame.list get $selectedIndex]
    set whereTmp "$whereTmp $tableName.dst_ip  = INET_ATON('$dstIP')"
  } elseif { $queryType == "empty" } {
    set whereTmp "$whereTmp <Insert Query Here>"
  } elseif { $queryType == "src2dst" } {
    set selectedIndex [$currentSelectedPane.srcIPFrame.list curselection]
    set srcIP [$currentSelectedPane.srcIPFrame.list get $selectedIndex]
    set dstIP [$currentSelectedPane.dstIPFrame.list get $selectedIndex]
    set whereTmp "$whereTmp $tableName.src_ip  = INET_ATON('$srcIP') AND $tableName.dst_ip = INET_ATON('$dstIP')"
  } elseif { $queryType == "category" } {
    set whereTmp "$whereTmp event.status = $incidentCat"
  } elseif { $queryType == "signature" } {
    set selectedIndex [$currentSelectedPane.srcIPFrame.list curselection]
    set eventMsg [$currentSelectedPane.msgFrame.list get $selectedIndex]
    set whereTmp "$whereTmp event.signature = '$eventMsg'"
  }
  set tmpWhereStatement [QryBuild $tableName $whereTmp]
  set whereStatement [lindex $tmpWhereStatement 1]
  set tableName [lindex $tmpWhereStatement 0]
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
        DBQueryRequest $whereStatement $winTitle
    } else {
       DBQueryRequest $whereStatement
    }
  } else {
    SsnQueryRequest $whereStatement
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
   sessions.src_pckts, sessions.src_bytes, sessions.dst_pckts, sessions.dst_bytes\
   FROM sessions, sensor $whereStatement"
  regsub -all {\n} $selectQuery {} selectQuery
  incr SSN_QUERY_NUMBER
  $eventTabs add -label "Ssn Query $SSN_QUERY_NUMBER"
  set currentTab [$eventTabs childsite end]
  set tabIndex [$eventTabs index end]
  set queryFrame [frame $currentTab.ssnquery_${SSN_QUERY_NUMBER}]
  $eventTabs select end
  # Here is where we build the session display lists.
  CreateSessionLists $queryFrame
  set whereText [text $currentTab.text -height 1 -background white]
  $whereText insert 0.0 $whereStatement
  bind $whereText <Return> {
    set whereStatement [%W get 0.0 end]
    SsnQueryRequest $whereStatement
    break
  }
  set buttonFrame [frame $currentTab.buttonFrame]
  set closeButton [button $buttonFrame.close -text "Close Tab" \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "DeleteTab $eventTabs $currentTab"]
  set exportButton [button $buttonFrame.export -text "Export Query Results" \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "ExportResults $queryFrame ssn"]
  pack $closeButton $exportButton -side left -fill x -expand true
  pack $whereText $buttonFrame -side bottom -fill x
  pack $queryFrame -side top
  $queryFrame configure -cursor watch
  if {$DEBUG} { puts "Sending Server: QueryDB $queryFrame $selectQuery" }
  SendToSguild "QueryDB $queryFrame $selectQuery"
}
#
# Build an event query tab and send the query to sguild.
#
proc DBQueryRequest { whereStatement {winTitle {none} } } {
  global eventTabs QUERY_NUMBER socketID DEBUG
  global CONNECTED
  if {!$CONNECTED} {ErrorMessage "Not connected to sguild. Query aborted."; return}
  set selectQuery "SELECT event.status, event.priority, sensor.hostname, event.timestamp,\
   event.sid, event.cid, event.signature,\
   INET_NTOA(event.src_ip), INET_NTOA(event.dst_ip), event.ip_proto,\
   event.src_port, event.dst_port FROM event, sensor, user_info $whereStatement"
  regsub -all {\n} $selectQuery {} selectQuery
  incr QUERY_NUMBER
  if { $winTitle == "none" } {
    $eventTabs add -label "Event Query $QUERY_NUMBER"
  } else {
    $eventTabs add -label "Event Query $winTitle"
  }
  set currentTab [$eventTabs childsite end]
  set tabIndex [$eventTabs index end]
  set queryFrame [frame $currentTab.query_$QUERY_NUMBER]
  $eventTabs select end
  CreateEventLists $queryFrame
  set whereText [text $currentTab.text -height 1 -background white]
  $whereText insert 0.0 $whereStatement
  bind $whereText <Return> {
    set whereStatement [%W get 0.0 end]
    DBQueryRequest $whereStatement
    break
  }
  set buttonFrame [frame $currentTab.buttonFrame]
  set closeButton [button $buttonFrame.close -text "Close Tab" \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "DeleteTab $eventTabs $currentTab"]
  set exportButton [button $buttonFrame.export -text "Export Query Results" \
	  -relief raised -borderwidth 2 -pady 0 \
	  -command "ExportResults $queryFrame event"]
  pack $closeButton $exportButton -side left -fill x -expand true -padx 5
  pack $whereText $buttonFrame -side bottom -fill x
  pack $queryFrame -side top
  $queryFrame configure -cursor watch
  if {$DEBUG} { puts "Sending Server: QueryDB $queryFrame $selectQuery" }
  SendToSguild "QueryDB $queryFrame $selectQuery"
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
