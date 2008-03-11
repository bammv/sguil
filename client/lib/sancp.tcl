# $Id: sancp.tcl,v 1.13 2008/03/11 14:44:26 bamm Exp $ 
#
# Build a sancp query tab and send the query to sguild.
#
proc SancpQueryRequest { selectedTable whereList } {

    global eventTabs SANCP_QUERY_NUMBER DEBUG CONNECTED SELECT_LIMIT

    if {!$CONNECTED} {ErrorMessage "Not connected to sguild. Query aborted"; return}

    set COLUMNS "sensor.hostname, sancp.sid, sancp.sancpid, sancp.start_time as datetime,\
     sancp.end_time, INET_NTOA(sancp.src_ip), sancp.src_port, INET_NTOA(sancp.dst_ip),\
     sancp.dst_port, sancp.ip_proto, sancp.src_pkts, sancp.src_bytes, sancp.dst_pkts,\
     sancp.dst_bytes"

    foreach whereStatement $whereList {

        lappend queries "SELECT $COLUMNS FROM sancp IGNORE INDEX (p_key) \
                         INNER JOIN sensor ON sancp.sid=sensor.sid $whereStatement" 

    }

    # Build UNION if required
    if { [llength $queries] > 1 } {

        set tmpQry [join $queries " ) UNION ( "]
        set fQuery "( $tmpQry ) ORDER BY datetime, src_port ASC LIMIT $SELECT_LIMIT"

    } else {

        set fQuery "[lindex $queries 0] ORDER BY datetime, src_port ASC LIMIT $SELECT_LIMIT"

    }

    regsub -all {\n} $fQuery {} selectQuery

    incr SANCP_QUERY_NUMBER
    $eventTabs add -label "Sancp Query $SANCP_QUERY_NUMBER"
    set currentTab [$eventTabs childsite end]
    set tabIndex [$eventTabs index end]
    set queryFrame [frame $currentTab.sancpquery_${SANCP_QUERY_NUMBER} -background black -borderwidth 1]
    $eventTabs select end

    # Here is where we build the session display lists.
    CreateSessionLists $queryFrame

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
            -command "ExportResults $queryFrame sancp"]
    pack $closeButton $exportButton -side top -fill x
    set rbuttonsFrame [frame $topFrame.rbuttons]
    set rsubmitButton [button $rbuttonsFrame.rsubmit -text "Submit " \
            -relief raised -borderwidth 2 -pady 0 \
            -command "[list SancpQueryRequest $selectedTable $whereList]"]
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
    if {$DEBUG} { puts "Sending Server: QueryDB $queryFrame $selectQuery" }

    SendToSguild "QueryDB $queryFrame.tablelist $selectQuery"

}

proc GetSancpData {} {

    global CONNECTED ACTIVE_EVENT CUR_SEL_PANE SANCPINFO

    ClearSancpFlags

    # Shouldn't be called in w/o a sancp query being selected
    # but we double check.
    if {$CUR_SEL_PANE(type) == "SANCP" && $ACTIVE_EVENT && $SANCPINFO} {

        # Make sure we are still connected to sguild.
        if {!$CONNECTED} {

            ErrorMessage "Not connected to sguild. Cannot make a request for packet data."
            return

        }

        # Pretty hour glass says no clicky-clicky
        Working
        update

        set selectedIndex [$CUR_SEL_PANE(name) curselection]
        set cnxInfo [split [$CUR_SEL_PANE(name) getcells $selectedIndex,alertID] .]
	set sensorID [lindex $cnxInfo 0]
        set cnxID [lindex $cnxInfo 1]

        SendToSguild "GetSancpFlagData $sensorID $cnxID"

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
proc InsertSancpFlags { flagsList } {

    global r2SrcSancpFrame r1SrcSancpFrame urgSrcSancpFrame ackSrcSancpFrame
    global pshSrcSancpFrame rstSrcSancpFrame synSrcSancpFrame finSrcSancpFrame 
    global r2dstSancpFrame r1dstSancpFrame urgdstSancpFrame ackdstSancpFrame
    global pshdstSancpFrame rstdstSancpFrame syndstSancpFrame findstSancpFrame 
  
    set frameName SrcSancpFrame.text
    set srcFlags [lindex $flagsList 0]
    set dstFlags [lindex $flagsList 1]
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
