# $Id: SguildClientCmdRcvd.tcl,v 1.49 2013/09/05 00:38:45 bamm Exp $

#
# ClientCmdRcvd: Called when client sends commands.
#
proc ClientCmdRcvd { socketID } {

    global clientList validSockets GLOBAL_QRY_LIST REPORT_QRY_LIST
                                                                                                            
    if { [eof $socketID] || [catch {gets $socketID data}] || [catch {llength $data} tmpLen] } {

        if { [info exists tmpLen] } {

            LogMessage "Error: Received poorly formatted message from $socketID: \n$data: \n$tmpLen"
            SendSocket $socketID [list ErrorMessage "Error: Your client sent improperly formatted data to sguild."]

        }

        # Socket closed
        catch {close $socketID}
        ClientExitClose $socketID
        LogMessage "Socket $socketID closed" 

    } else {

        # Don't display the user passwds
        if { [regexp ^ValidateUser $data] } {
         
            InfoMessage "Client Command Received: [lrange $data 0 1] ********"

        } elseif { [lindex $data 0] == "ChangePass" } { 

            InfoMessage "Client Command Received: [lrange $data 0 1] ******** ********"

        } else {

            InfoMessage "Client Command Received: $data"
        }

    if [catch {lindex $data 0} clientCmd] {

        LogMessage "Error: Received poorly formatted message from $socketID => $clientCmd"
        return

    }

    # Check to make the client validated itself
    if { $clientCmd != "ValidateUser" && \
         $clientCmd != "PING" && \
         $clientCmd != "VersionInfo" && \
         $clientCmd != "SendPcap" } {

        if { [lsearch -exact $validSockets $socketID] < 0 } {

            catch {SendSocket $socketID \
             [list InfoMessage "Client does not appear to be logged in. Please exit and log back in."]} tmpError

            return

        }

    }

    switch -exact $clientCmd {

      DeleteEventIDList   { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }

      EventHistoryRequest { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }

      GetCorrelatedEvents { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      GetIcmpData         { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      GetIPData           { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      GetPayloadData      { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      GetTcpData          { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      GetUdpData          { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      MonitorSensors      { $clientCmd $socketID [lindex $data 1] }

      QueryDB             { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      RuleRequest         { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] \
                            [lindex $data 4] [lindex $data 5] }

      SendSensorList      { $clientCmd $socketID }

      SendEscalatedEvents { $clientCmd $socketID }

      SendDBInfo          { $clientCmd $socketID }

      ValidateUser        { ValidateUser $socketID [lindex $data 1] [lindex $data 2] }

      PING                { puts $socketID "PONG" }

      UserMessage         { UserMsgRcvd $socketID [lindex $data 1] }

      SendGlobalQryList   { SendSocket $socketID [list GlobalQryList $GLOBAL_QRY_LIST] }

      SendReportQryList   { SendSocket $socketID [list ReportQryList $REPORT_QRY_LIST] }

      ReportRequest       { ReportBuilder $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }

      GetSancpFlagData    { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      XscriptRequest      { eval $clientCmd $socketID [lrange $data 1 end] }

      WiresharkRequest    { eval $clientCmd $socketID [lrange $data 1 end] }

      SendPcap            { $clientCmd $socketID [lindex $data 1] }

      AbortXscript        { $clientCmd $socketID [lindex $data 1] }

      GetOpenPorts        { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      SendClientSensorStatusInfo { $clientCmd $socketID }

      GetAssetData        { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      GetGenericDetail    { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      VersionInfo         { ClientVersionCheck $socketID [lindex $data 1] }

      QuickScript         { $clientCmd $socketID [lindex $data 1] }
 
      ChangePass          { $clientCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }

      AutoCatRequest      { $clientCmd $socketID [lrange $data 1 end] }

      SendAutoCatList     { $clientCmd $socketID }

      EnableAutoCatRule   { $clientCmd $socketID [lindex $data 1] }

      DisableAutoCatRule   { $clientCmd $socketID [lindex $data 1] }

      UserSelectedEvent   { $clientCmd $socketID [lindex $data 1] [lindex $data 2] }

      default { InfoMessage "Unrecognized command from $socketID: $data" }

    }

  }

}

proc ClientExitClose { socketID } {

  global clientList clientMonitorSockets validSockets socketInfo sensorUsers
  global userIDArray selectedEvent

  set userName [lindex $socketInfo($socketID) 2]

  LogClientAccess "[GetCurrentTimeStamp]: $socketID - $userName logged out"

  if { [info exists clientList] } {
    set clientList [ldelete $clientList $socketID]
  }
  if { [info exists clientMonitorSockets] } {
    foreach sensorName [array names clientMonitorSockets] {
      set clientMonitorSockets($sensorName) [ldelete $clientMonitorSockets($sensorName) $socketID]
    }
  }
  if { [info exists validSockets] } {
    set validSockets [ldelete $validSockets $socketID]
  }
  if { [array exists sensorUsers] } {
    foreach sensorName [array names sensorUsers] {
      set sensorUsers($sensorName) [ldelete $sensorUsers($sensorName) $userName]
    }
  }
  # Unselect selected event
  if { [array exists selectedEvent] && [info exists selectedEvent($socketID)] } {
    foreach client $clientList {
      SendSocket $client [list UserUnSelectedEvent $selectedEvent($socketID) $userIDArray($socketID)]
    }
    unset selectedEvent($socketID)
  }
  if { [info exists socketInfo($socketID)] } {
    set tmpUserName [lindex $socketInfo($socketID) 2]
    unset socketInfo($socketID)
    SendSystemInfoMsg sguild "User $tmpUserName has disconnected."
  }

}

proc UserMsgRcvd { socketID userMsg } {
  global socketInfo clientList userIDArray selectedEvent
                                                                                                            
  #set userMsg [lindex $userMsg 0]
                                                                                                            
  # Simple command stuff.
  # Who returns a list of connected users
  if { $userMsg == "who" } {
     SendSocket $socketID [list UserMessage sguild "== Connected Users =="]
     foreach client $clientList { 
       set uinfo "Username: [lindex $socketInfo($client) 2] -- User ID: $userIDArray($client) -- "
       if { [array exists selectedEvent] && [info exists selectedEvent($client)] } { 
         append uinfo "Selected Event: $selectedEvent($client)"
       } else {
         append uinfo "Selected Event: none"
       }
       SendSocket $socketID [list UserMessage sguild $uinfo]
     }
  } elseif { $userMsg == "autocats" } { 
    set c1 7
    set c2 80
    SendSocket $socketID [list UserMessage sguild "+-[string repeat - $c1]-+-[string repeat - $c2]-+"]
    foreach r [GetAutoCatList] {
      foreach i [list ID Erase Sensor SrcIP SrcPort DstIP DstPort Proto Sig Status Active UID Added Comment] v $r {
        if { $v == "" && ($i == "Erase" || $i == "Comment") } { set v none } elseif { $v == "" } { set v any }
        set msg [format "| %-*s | %-*s |" $c1 $i $c2 $v]
        SendSocket $socketID [list UserMessage sguild $msg]
      }
      SendSocket $socketID [list UserMessage sguild "+-[string repeat - $c1]-+-[string repeat - $c2]-+"]
    }
  } elseif { $userMsg == "healthcheck" } { 
    #SensorAgentsHealthCheck 1
    SendSocket $socketID [list UserMessage sguild "Command healthcheck depreciated."]
  } else {
    foreach client $clientList {
      SendSocket $client [list UserMessage [lindex $socketInfo($socketID) 2] $userMsg]
    }
  }
}

proc GetCorrelatedEvents { socketID eid winName } {
  global correlatedEventArray eventIDArray
  if { [info exists eventIDArray] } {
    SendSocket $socketID\
     [list InsertQueryResults $winName [eval FormatStdToQuery $eventIDArray($eid)]]
  }
                                                                                                            
  if { [info exists correlatedEventArray($eid)] } {
    foreach row $correlatedEventArray($eid) {
      SendSocket $socketID [list InsertQueryResults $winName [eval FormatStdToQuery $row]]
    }
  }
}

proc FormatStdToQuery { status priority class sensor time sid cid msg sip dip proto sp dp genID sigID rev refID1 refID2 } {
  return "[list $status $priority $sensor $time $sid $cid $msg $sip $dip $proto $sp $dp $genID $sigID $rev]"
}


proc SendDBInfo { socketID } {
  global tableNameList tableArray
  catch {SendSocket $socketID [list TableNameList $tableNameList]} tmpError
  foreach tableName $tableNameList {
    catch {SendSocket $socketID [list TableColumns $tableName $tableArray($tableName)]} tmpError
  }
}

#
# RuleRequest finds rule based on message. Should change this to
# use sig ids in the future.
#
proc RuleRequest { socketID event_id sensor genID sigID sigRev } {

    global RULESDIR
                                                                                                            
    set RULEFOUND 0
    set ruleDir $RULESDIR/$sensor

    set search_string "sid:\\s*${sigID}\\s*;"

    if { [file exists $ruleDir] } {

        foreach ruleFile [glob -nocomplain $ruleDir/*.rules] {

            InfoMessage "Checking $ruleFile..."
            set ruleFileID [open $ruleFile r]
            set line 0

            while { [gets $ruleFileID data] >= 0 } {

                incr  line
                if { [ regexp $search_string $data ] } {
                    set RULEFOUND 1
                    InfoMessage "Matching rule found in $ruleFile."
                    break
                }

            }

            close $ruleFileID
            if {$RULEFOUND} {break}

        }

    } else {
  
        set data "Could not find $ruleDir."

    }

    if {$RULEFOUND} {

        catch {SendSocket $socketID [list InsertRuleData $data]} tmpError
        catch {SendSocket $socketID [list InsertRuleData "$ruleFile: Line $line"]} tmpError

    } else {

        catch {SendSocket $socketID [list InsertRuleData "Unable to find matching rule in $ruleDir."]} tmpError

    }

}

proc EventHistoryRequest { socketID winName sid cid } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set query "SELECT history.sid, history.cid, user_info.username, history.timestamp, history.status, status.description, history.comment FROM history, user_info, status WHERE history.uid=user_info.uid AND history.status=status.status_id AND history.sid=$sid and history.cid=$cid"
  if [catch {mysqlsel $dbSocketID "$query" -list} selResults] {
    catch {SendSocket $socketID [list InfoMessage $selResults]} tmpError
  } else {
    foreach row $selResults {
      catch {SendSocket $socketID [list InsertHistoryResults $winName $row]} tmpError
    }
  }
  mysqlclose $dbSocketID
  catch {SendSocket $socketID [list InsertHistoryResults $winName done]} tmpError
}

proc GetSancpFlagData { socketID sensorID xid } {
  set query\
   "SELECT src_flags, dst_flags FROM sancp WHERE sancp.sid=$sensorID AND sancp.sancpid=$xid"
   set queryResults [FlatDBQuery $query]
   catch {SendSocket $socketID [list InsertSancpFlags $queryResults]}
}
proc GetIPData { socketID sid cid } {
  set query\
   "SELECT INET_NTOA(src_ip), INET_NTOA(dst_ip), ip_ver, ip_hlen, ip_tos, ip_len, ip_id,\
    ip_flags, ip_off, ip_ttl, ip_csum\
   FROM event\
   WHERE sid=$sid and cid=$cid"
                                                                                                            
  set queryResults [FlatDBQuery $query]
  catch {SendSocket $socketID [list InsertIPHdr $queryResults]} tmpError
}
proc GetTcpData { socketID sid cid } {
  set query\
   "SELECT tcp_seq, tcp_ack, tcp_off, tcp_res, tcp_flags, tcp_win, tcp_urp, tcp_csum\
   FROM tcphdr\
   WHERE sid=$sid and cid=$cid"
  set queryResults [FlatDBQuery $query]
  set portQuery [FlatDBQuery "SELECT src_port, dst_port FROM event WHERE sid=$sid AND cid=$cid"]
  catch {SendSocket $socketID [list InsertTcpHdr $queryResults $portQuery]} tmpError
}
proc GetIcmpData { socketID sid cid } {
  set query\
   "SELECT event.icmp_type, event.icmp_code, icmphdr.icmp_csum, icmphdr.icmp_id, icmphdr.icmp_seq\
   FROM event, icmphdr\
   WHERE event.sid=icmphdr.sid AND event.cid=icmphdr.cid AND event.sid=$sid AND event.cid=$cid"
                                                                                                            
  set queryResults [FlatDBQuery $query]
                                                                                                            
  set query\
   "SELECT data_payload FROM data WHERE sid=$sid and cid=$cid"
                                                                                                            
  set plqueryResults [FlatDBQuery $query]
                                                                                                            
  catch {SendSocket $socketID [list InsertIcmpHdr $queryResults $plqueryResults]} tmpError
}
proc GetPayloadData { socketID sid cid } {
  set query\
   "SELECT data_payload FROM data WHERE sid=$sid and cid=$cid"
                                                                                                            
  set queryResults [FlatDBQuery $query]
  catch {SendSocket $socketID [list InsertPayloadData $queryResults]} tmpError
}
proc GetUdpData { socketID sid cid } {
  set query\
   "SELECT udp_len, udp_csum FROM udphdr WHERE sid=$sid and cid=$cid"
                                                                                                            
  set queryResults [FlatDBQuery $query]
  set portQuery [FlatDBQuery "SELECT src_port, dst_port FROM event WHERE sid=$sid AND cid=$cid"]
  catch {SendSocket $socketID [list InsertUdpHdr $queryResults $portQuery]} tmpError
}

proc GetOpenPorts { socketID sid cid } {
    global DBNAME DBUSER DBPASS DBPORT DBHOST

    if {$DBPASS == ""} {
	set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
    } else {
	set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
    }

    set query\
	"SELECT unified_event_id FROM event WHERE sid=$sid and cid=$cid"
    set event_id [lindex [FlatDBQuery $query] 0]
    if { $event_id == "" } { 
	catch {SendSocket $socketID [list InsertOpenPortsData DONE]} tmpError
	return
    }
    set query\
	"SELECT INET_NTOA(event.dst_ip), data.data_payload from event, data WHERE event.sid=data.sid AND event.cid=data.cid AND event.unified_event_ref=$event_id"
    foreach row [mysqlsel $dbSocketID "$query" -list] {
    catch {SendSocket $socketID [list InsertOpenPortsData $row]} tmpError
    }
    mysqlclose $dbSocketID
    catch {SendSocket $socketID [list InsertOpenPortsData DONE]} tmpError
}
#
# MonitorSensors: Sends current events to client. Adds client to clientList
#                 In the future sensorList will contain a list of sensors, for
#                 now the client gets everything.
#
proc MonitorSensors { socketID ClientSensorList } {

    global clientList clientMonitorSockets socketInfo sensorUsers sensorList
    global snortStatsArray
   

    set userName [lindex $socketInfo($socketID) 2]

    if {[lsearch -exact $clientList $socketID] < 0} { 
	LogMessage "$socketID added to clientList"
	lappend clientList $socketID
    }
    # Find this socketID in other sensors and delete it 
    foreach sensor $sensorList {
	if [info exists clientMonitorSockets($sensor)] {
            if {[lsearch -exact $clientMonitorSockets($sensor) $socketID] >= 0} {
              set clientMonitorSockets($sensor) [ldelete $clientMonitorSockets($sensor) $socketID]
              # Delete the user name from sensorUsers if the socket use to monitor that sensor.
	      if [info exists sensorUsers($sensor)] {
                set sensorUsers($sensor) [ldelete $sensorUsers($sensor) $userName]
	      }
           }
	}
    }

    foreach sensorName $ClientSensorList {
	lappend clientMonitorSockets($sensorName) $socketID
	lappend sensorUsers($sensorName) $userName
    }
    SendSystemInfoMsg sguild "User [lindex $socketInfo($socketID) 2] is monitoring sensors: $ClientSensorList"
    SendCurrentEvents $socketID

    # Send the snort stats info here.
    if { [array exists snortStatsArray] && [array names snortStatsArray] != "" } {

        foreach sensor [array names snortStatsArray] {

            lappend tmpList [linsert $snortStatsArray($sensor) 1 $sensor]

        }

        catch { SendSocket $socketID [list NewSnortStats $tmpList] } tmpError

    }   

}
                                                                                                            
proc SendEscalatedEvents { socketID } {
  global escalateIDList escalateArray
  if [info exists escalateIDList] {
    foreach escalateID $escalateIDList {
      catch {SendSocket $socketID [list InsertEscalatedEvent $escalateArray($escalateID)]} tmpError
    }
  }
}

#
# SendCurrentEvents: Sends newly connected clients the current event list
#
proc SendCurrentEvents { socketID } {

    global eventIDArray eventIDList clientMonitorSockets eventIDCountArray
    global sidNetNameMap userIDArray selectedEvent
                                                                                                                       
    if { [info exists eventIDList] && [llength $eventIDList] > 0 } {

        foreach eventID $eventIDList {

            set sensorID [lindex [split $eventID .] 0]
            set netName $sidNetNameMap($sensorID)
            if { [info exists clientMonitorSockets($netName)] } {

                if { [lsearch -exact $clientMonitorSockets($netName) $socketID] >= 0} {
                    InfoMessage "Sending client $socketID: InsertEvent $eventIDArray($eventID) $eventIDCountArray($eventID)" 
                    catch {\
                     SendSocket $socketID [list InsertEvent "$eventIDArray($eventID) $eventIDCountArray($eventID)"] \
                    } tmpError

                }
            }

        }

    }

    # Update client on which events are currently selected
    foreach s [array names selectedEvent] {

        SendSocket $socketID [list UserSelectedEvent $selectedEvent($s) $userIDArray($s)] 

    }

}

proc UserSelectedEvent { socketID eventID userID } {

    global selectedEvent clientList

    # Unselect previously selected event
    if { [info exists selectedEvent($socketID)] } {

        foreach client $clientList {

            if { $client != $socketID } { 

                SendSocket $client [list UserUnSelectedEvent $selectedEvent($socketID) $userID] 

            }

        }

    }

    set selectedEvent($socketID) $eventID

    # Send newly selected event
    foreach client $clientList {

        if { $client != $socketID } { 

            SendSocket $client [list UserSelectedEvent $selectedEvent($socketID) $userID] 

        }

    }
   
}

