# $Id: SguildSensorAgentComms.tcl,v 1.33 2011/05/29 15:41:16 bamm Exp $ #

# Get the sid and cid for the agent. Create it if it doesn't exist. 
# Send the agent [AgentSid {type} {sid}]
proc RegisterAgent { socketID type sensorName netName } {

    global agentSocketArray agentSensorNameArray
    global validSensorSockets agentStatusList sidNetNameMap
    global pcapSocket sancpSocket padsSocket sancpSocket snortSocket
    global agentSocketInfo

    # Add agent to a list of valid sockets
    lappend validSensorSockets $socketID

    # Log the agent type
    LogAgentAccess "[GetCurrentTimeStamp]: ($socketID) $sensorName $netName $type"

    # Data cnx stop here
    if { $type == "data" } { return }

    set sensorID [GetSensorID $sensorName $type $netName]
    set maxCid [GetMaxCid $sensorID]

    # Send agent id to the agent
    SendSensorAgent $socketID [list AgentInfo $sensorName $type $netName $sensorID $maxCid]

    # Sid NetName Map
    set sidNetNameMap($sensorID) $netName

    # SensorName to SocketID mapping
    set agentSensorNameArray($socketID) $sensorName

    # Update various array info
    switch -exact $type {

        pads { set padsSocket($netName) $socketID }
        pcap { set pcapSocket($netName) $socketID }
        sancp { set sancpSocket($netName) $socketID }
        snort { set snortSocket($netName) $socketID }
        data { set dataSocket($netName) $socketID }
        default { set foo bar }

    }


    set agentSocketInfo($socketID) [list $sensorID $sensorName $netName $type]

    # Update status array
    if { [info exists agentStatusList($sensorID)] } {

        set agentStatusList($sensorID) [lreplace $agentStatusList($sensorID) 4 4 1 ]

    } else {

        set agentStatusList($sensorID) [list $netName $sensorName $type N/A 1]

    }

    SendAllSensorStatusInfo

}


proc SendSensorAgent { socketID msg } {

    global agentSocketArray agentSensorNameArray
    
    set RFLAG 1
    if { [catch { puts $socketID $msg } sendError] } {

        catch { close $socketID } tmpError
        CleanUpDisconnectedAgent $socketID
        set RFLAG 0

    } else {

        flush $socketID
        InfoMessage "Sent $socketID: $msg"

    }

    return $RFLAG
}

proc AgentLastCidReq { socketID req_socketID sid } {

    set maxCid [GetMaxCid $sid]

    SendSensorAgent $socketID [list LastCidResults $req_socketID $maxCid]

}

proc BYEventRcvd { socketID req_socketID status sid cid sensorName u_event_id          \
                   u_event_ref u_ref_time sig_gen sig_id sig_rev  msg timestamp        \
                   priority class_type dec_sip str_sip dec_dip str_dip                 \
                   ip_proto ip_ver ip_hlen ip_tos ip_len ip_id ip_flags ip_off ip_ttl  \
                   ip_csum icmp_type icmp_code icmp_csum icmp_id icmp_seq src_port     \
                   dst_port tcp_seq tcp_ack tcp_off tcp_res tcp_flags tcp_win tcp_csum \
                   tcp_urp udp_len udp_csum data_payload } {

    global LAST_EVENT_ID agentStatusList

    # Check for a potential dupe. Can happen if we get busy and the confirmation
    # doesn't make it back to BY quick enough.
    set eventID "${sid}.${cid}"

    #puts "DEBUG #### Got event: $eventID"
    #if { [array exists LAST_EVENT_ID] && [info exists LAST_EVENT_ID($sensorName)] } {
    #    puts "DEBUG #### Last event from $sensorName: $LAST_EVENT_ID($sensorName)"
    #} else {
    #    puts "DEBUG #### First event from $sensorName"
    #}
      

    if { [array exists LAST_EVENT_ID] \
      && [info exists LAST_EVENT_ID($sensorName)] \
      && $LAST_EVENT_ID($sensorName) == $eventID } {

        InfoMessage "Non-fatal Error: received a duplicate alert from $sensorName. : $eventID"

        # Send by/op_sguil confirmation
        # Still undecided how best to hand this.
        #SendSensorAgent $socketID [list Confirm $req_socketID $cid]

        return

    }

    # Table Prefix
    set tmpDate [clock format [clock scan $timestamp -gmt true] -gmt true -format "%Y%m%d"]
    set tablePrefix "${sensorName}_${tmpDate}"
    
    # Insert Event Hdr
    if [catch { InsertEventHdr $tablePrefix $sid $cid $u_event_id $u_event_ref $u_ref_time \
                $msg $sig_gen $sig_id $sig_rev $timestamp $priority $class_type \
                $status $dec_sip $dec_dip $ip_proto $ip_ver $ip_hlen $ip_tos \
                $ip_len $ip_id $ip_flags $ip_off $ip_ttl $ip_csum $icmp_type \
                $icmp_code $src_port $dst_port } tmpError] {

        # DEBUG Foo
        LogMessage "ERROR: While inserting event info: $tmpError"

        SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
        return

    } 

    # Insert ICMP, TCP, or UDP hdrs
    switch -exact -- $ip_proto {

        17  {    if [catch { InsertUDPHdr $tablePrefix $sid $cid $udp_len $udp_csum } tmpError] {
                     SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]

                     # DEBUG Foo
                     LogMessage "ERROR: While inserting UDP header: $tmpError"
                     #exit

                     return
                 }
         }
        
         6  {    if [catch { InsertTCPHdr $tablePrefix $sid $cid $tcp_seq $tcp_ack $tcp_off $tcp_res \
                             $tcp_flags $tcp_win $tcp_csum $tcp_urp } tmpError] {
                     SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]

                     # DEBUG Foo
                     LogMessage "ERROR: While inserting TCP header: $tmpError"
                     #exit

                     return
                 }
         }

         1  {    
                 
                     if [catch { InsertICMPHdr $tablePrefix $sid $cid $icmp_csum $icmp_id $icmp_seq } \
                         tmpError] {
                         SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
  
                         # DEBUG Foo
                         LogMessage "ERROR: While inserting ICMP header: $tmpError"
                         #exit

                         return
                     }
        
         }
    }

    # Insert Payload
    if { $data_payload != "" } { 
        if [catch { InsertDataPayload $tablePrefix $sid $cid $data_payload } tmpError] {
            SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
  
            # DEBUG Foo
            LogMessage "ERROR: While inserting data payload: $tmpError"
            #exit

            return
        }
    }

    # Send RT Event
    # RTEvent|st|priority|class_type|hostname|timestamp|sid|cid|msg|srcip|dstip|ipproto|srcport|dstport|sig_id|rev|u_event_id|u_event_ref
    EventRcvd \
     [list 0 $priority $class_type $sensorName $timestamp $sid $cid $msg $str_sip \
      $str_dip $ip_proto $src_port $dst_port $sig_gen $sig_id $sig_rev $u_event_id $u_event_ref]

    # Send by/op_sguil confirmation
    SendSensorAgent $socketID [list Confirm $req_socketID $cid] 

    # Update last event
    set LAST_EVENT_ID($sensorName) $eventID

    # Update last event rcvd time
    if [info exists agentStatusList($sid)] {

        set agentStatusList($sid) [lreplace $agentStatusList($sid) 3 3 $timestamp]

    }

}

proc UpdateLastPcapTime { socketID timestamp } {

    global agentStatusList agentSocketInfo

    set sid [lindex $agentSocketInfo($socketID) 0]

    # Update last pcap written time
    if [info exists agentStatusList($sid)] {

        set agentStatusList($sid) [lreplace $agentStatusList($sid) 3 3 $timestamp]

    }

}

proc BarnyardConnect { socketID dateTime } {

    global agentSensorNameArray

    if [info exists agentSensorNameArray($socketID)] {

        set sensorName $agentSensorNameArray($socketID)

    }

}

proc BarnyardDisConnect { socketID dateTime } {

    global agentSensorNameArray

    if [info exists agentSensorNameArray($socketID)] {

        set sensorName $agentSensorNameArray($socketID)

    }

}

proc SnortStatsRcvd { socketID statsList } {

    global agentSensorNameArray snortStatsArray clientList

    if [info exists agentSensorNameArray($socketID)] {

        set sensorName $agentSensorNameArray($socketID)
        set snortStatsArray($sensorName) $statsList

    }

    if { [info exists clientList] && [llength $clientList] > 0 } {

        foreach clientSocket $clientList {

            if [catch {SendSocket $clientSocket [list UpdateSnortStats [linsert $statsList 1 $sensorName]]} tmpError] { 
                 puts "\n\n $tmpError \n\n"
            }

        }

    }


}

proc GetPadsID { socketID sensorName } {

    # Unique sid for each sensor/type. 2 == PADS
    set padsID [GetSensorID $sensorName 2]

    if { $padsID == "" } {

        LogMessage "New PADS sensor. Adding sensor $sensorName to the DB."
        # We have a new sensor

        set tmpQuery "INSERT INTO sensor (hostname, sensor_type) VALUES ('$sensorName', '2')"

        if [catch {SafeMysqlExec $tmpQuery} tmpError] {
            # Insert failed
            ErrorMessage "ERROR from mysqld: $tmpError :\nQuery => $tmpQuery"
            ErrorMessage "ERROR: Unable to add new sensors."
            return
        }

        set padsID [GetSensorID $sensorName 2]

    }

    SendSensorAgent $socketID [list PadsID $padsID]

}
