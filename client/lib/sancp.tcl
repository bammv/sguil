# $Id: sancp.tcl,v 1.3 2005/01/20 20:02:29 shalligan Exp $ 
#
# Build a sancp query tab and send the query to sguild.
#
proc SancpQueryRequest { whereStatement } {
  global eventTabs SANCP_QUERY_NUMBER socketID DEBUG
  global CONNECTED
  if {!$CONNECTED} {ErrorMessage "Not connected to sguild. Query aborted"; return}
  set selectQuery "SELECT sensor.hostname, sancp.sancpid, sancp.start_time, sancp.end_time,\
   INET_NTOA(sancp.src_ip), sancp.src_port, INET_NTOA(sancp.dst_ip), sancp.dst_port,\
   sancp.ip_proto, sancp.src_pkts, sancp.src_bytes, sancp.dst_pkts, sancp.dst_bytes\
   FROM sancp INNER JOIN sensor ON sancp.sid=sensor.sid $whereStatement"
  regsub -all {\n} $selectQuery {} selectQuery
  incr SANCP_QUERY_NUMBER
  $eventTabs add -label "Sancp Query $SANCP_QUERY_NUMBER"
  set currentTab [$eventTabs childsite end]
  set tabIndex [$eventTabs index end]
  set queryFrame [frame $currentTab.sancpquery_${SANCP_QUERY_NUMBER} -background black -borderwidth 1]
  $eventTabs select end
  # Here is where we build the session display lists.
  CreateSessionLists sancp $queryFrame
  set buttonFrame [frame $currentTab.buttonFrame]
  set whereText [text $buttonFrame.text -height 1 -background white -wrap none]
  $whereText insert 0.0 $whereStatement
  bind $whereText <Return> {
    set whereStatement [%W get 0.0 end]
    SancpQueryRequest $whereStatement
    break
  }
  set closeButton [button $buttonFrame.close -text "Close" \
          -relief raised -borderwidth 2 -pady 0 \
          -command "DeleteTab $eventTabs $currentTab"]
  set exportButton [button $buttonFrame.export -text "Export" \
          -relief raised -borderwidth 2 -pady 0 \
          -command "ExportResults $queryFrame sancp"]
  set rsubmitButton [button $buttonFrame.rsubmit -text "Submit " \
          -relief raised -borderwidth 2 -pady 0 \
          -command "SancpQueryRequest \[$whereText get 0.0 end\] "]
  pack $closeButton $exportButton -side left
  pack $whereText -side left -fill x -expand true
  pack $rsubmitButton -side left
  pack $buttonFrame -side top -fill x
  pack $queryFrame -side bottom -fill both
  $queryFrame configure -cursor watch
  if {$DEBUG} { puts "Sending Server: QueryDB $queryFrame $selectQuery" }
  SendToSguild "QueryDB $queryFrame $selectQuery"
}

proc GetSancpData {} {
  global CONNECTED ACTIVE_EVENT SANCP_QUERY CUR_SEL_PANE SANCPINFO

  ClearSancpFlags
  # Shouldn't be called in w/o a sancp query being selected
  # but we double check.
  if {$SANCP_QUERY && $ACTIVE_EVENT && $SANCPINFO} {
     # Make sure we are still connected to sguild.
     if {!$CONNECTED} {
      ErrorMessage "Not connected to sguild. Cannot make a request for packet data."
      return
    }
    # Pretty hour glass says no clicky-clicky
    Working
    update
    set selectedIndex [$CUR_SEL_PANE(name).sensorFrame.list curselection]
    set sensorName [$CUR_SEL_PANE(name).sensorFrame.list get $selectedIndex]
    set cnxID [$CUR_SEL_PANE(name).xidFrame.list get $selectedIndex]
    #
    # We don't have the sid in the session data (stoopid). So we'll
    # count on sguild to do the JOIN and get the correct one. We may
    # need to change this later if it seems slow.
    # 
    # We send off the request and press on. Since this should be quick
    # we leave the hour glass on until we get a 'Done.' from sguild.
    # we put the lotion in the basket.
    SendToSguild "GetSancpFlagData $sensorName $cnxID"
  }
}
proc ClearSancpFlags {} {
  global r2SrcSancpFrame r1SrcSancpFrame urgSrcSancpFrame ackSrcSancpFrame
  global pshSrcSancpFrame rstSrcSancpFrame synSrcSancpFrame finSrcSancpFrame 
  global r2dstSancpFrame r1dstSancpFrame urgdstSancpFrame ackdstSancpFrame
  global pshdstSancpFrame rstdstSancpFrame syndstSancpFrame findstSancpFrame 

  foreach frameName [list SrcSancpFrame.text dstSancpFrame.text] {
    eval \$r2$frameName delete 0.0 end
    eval \$r1$frameName delete 0.0 end
    eval \$urg$frameName delete 0.0 end
    eval \$ack$frameName delete 0.0 end
    eval \$psh$frameName delete 0.0 end
    eval \$rst$frameName delete 0.0 end
    eval \$syn$frameName delete 0.0 end
    eval \$fin$frameName delete 0.0 end
  }
}
proc InsertSancpFlags { srcFlags dstFlags } {
  global r2SrcSancpFrame r1SrcSancpFrame urgSrcSancpFrame ackSrcSancpFrame
  global pshSrcSancpFrame rstSrcSancpFrame synSrcSancpFrame finSrcSancpFrame 
  global r2dstSancpFrame r1dstSancpFrame urgdstSancpFrame ackdstSancpFrame
  global pshdstSancpFrame rstdstSancpFrame syndstSancpFrame findstSancpFrame 
  
  set frameName SrcSancpFrame.text
  foreach flags [list $srcFlags $dstFlags] {
    set r1Flag "."
    set r0Flag "."
    set urgFlag "."
    set ackFlag "."
    set pshFlag "."
    set rstFlag "."
    set synFlag "."
    set finFlag "."
    # Bitwise AND hell
    if { $flags & 1 } { set finFlag X }
    if { $flags & 2 } { set synFlag X }
    if { $flags & 4 } { set rstFlag X }
    if { $flags & 8 } { set pshFlag X }
    if { $flags & 16 } { set ackFlag X }
    if { $flags & 32 } { set urgFlag X }
    if { $flags & 64 } { set r0Flag X }
    if { $flags & 128 } { set r1Flag X }

    eval \$r2$frameName insert 0.0 $r1Flag
    eval \$r1$frameName insert 0.0 $r0Flag
    eval \$urg$frameName insert 0.0 $urgFlag
    eval \$ack$frameName insert 0.0 $ackFlag
    eval \$psh$frameName insert 0.0 $pshFlag
    eval \$rst$frameName insert 0.0 $rstFlag
    eval \$syn$frameName insert 0.0 $synFlag
    eval \$fin$frameName insert 0.0 $finFlag

    set frameName dstSancpFrame.text
  }
  

  # Now you can clicky-clicky
  Idle
}
