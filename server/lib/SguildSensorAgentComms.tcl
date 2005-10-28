# $Id: SguildSensorAgentComms.tcl,v 1.17 2005/10/28 15:24:25 bamm Exp $ #

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

    if { $maxCid == "{}" } {
        # New sensor
        set maxCid 0
    }

    SendSensorAgent $socketID [list LastCidResults $req_socketID $maxCid]

}

proc BYEventRcvd { socketID req_socketID status sid cid sensorName u_event_id \
                   u_event_ref u_ref_time  sig_gen sig_id sig_rev  msg timestamp \
                   priority class_type dec_sip str_sip dec_dip str_dip \
                   ip_proto ip_ver ip_hlen ip_tos ip_len ip_id ip_flags ip_off ip_ttl \
                   ip_csum icmp_type icmp_code icmp_csum icmp_id icmp_seq src_port \
                   dst_port tcp_seq tcp_ack tcp_off tcp_res tcp_flags tcp_win tcp_csum \
                   tcp_urp udp_len udp_csum data_payload } {

    global LAST_EVENT_ID sensorStatusArray

    # Check for a potential dupe. Can happen if we get busy and the confirmation
    # doesn't make it back to BY quick enough.
    set eventID "${sid}.${cid}"

    if { [array exists LAST_EVENT_ID] \
      && [info exists LAST_EVENT_ID($sensorName)] \
      && $LAST_EVENT_ID($sensorName) == $eventID } {

        InfoMessage "Non-fatal Error: recieved a duplicate alert from $sensorName. : $eventID"

        # Send by/op_sguil confirmation
        SendSensorAgent $socketID [list Confirm $req_socketID $cid]

        return

    }

    # Table Prefix
    set tmpDate [clock format [clock scan $timestamp] -gmt true -format "%Y%m%d"]
    set tablePrefix "${sensorName}_${tmpDate}"
    
    # Insert Event Hdr
    if [catch { InsertEventHdr $tablePrefix $sid $cid $u_event_id $u_event_ref $u_ref_time \
                $msg $sig_gen $sig_id $sig_rev $timestamp $priority $class_type \
                $status $dec_sip $dec_dip $ip_proto $ip_ver $ip_hlen $ip_tos \
                $ip_len $ip_id $ip_flags $ip_off $ip_ttl $ip_csum $icmp_type \
                $icmp_code $src_port $dst_port } tmpError] {

        # DEBUG Foo
        puts "ERROR: While inserting event info: $tmpError"

        SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
        return

    } 

    # Insert ICMP, TCP, or UDP hdrs
    switch -exact -- $ip_proto {

        17  {    if [catch { InsertUDPHdr $tablePrefix $sid $cid $udp_len $udp_csum } tmpError] {
                     SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]

                     # DEBUG Foo
                     puts "ERROR: While inserting UDP header: $tmpError"
                     #exit

                     return
                 }
         }
        
         6  {    if [catch { InsertTCPHdr $tablePrefix $sid $cid $tcp_seq $tcp_ack $tcp_off $tcp_res \
                             $tcp_flags $tcp_win $tcp_csum $tcp_urp } tmpError] {
                     SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]

                     # DEBUG Foo
                     puts "ERROR: While inserting TCP header: $tmpError"
                     #exit

                     return
                 }
         }

         1  {    
                 
                     if [catch { InsertICMPHdr $tablePrefix $sid $cid $icmp_csum $icmp_id $icmp_seq } \
                         tmpError] {
                         SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
  
                         # DEBUG Foo
                         puts "ERROR: While inserting ICMP header: $tmpError"
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
            puts "ERROR: While inserting data payload: $tmpError"
            #exit

            return
        }
    }

    # Send RT Event
    # RTEvent|st|priority|class_type|hostname|timestamp|sid|cid|msg|srcip|dstip|ipproto|srcport|dstport|sig_id|rev|u_event_id|u_event_ref
    EventRcvd \
     [list 0 $priority $class_type $sensorName $timestamp $sid $cid $msg $str_sip \
      $str_dip $ip_proto $src_port $dst_port $sig_id $sig_rev $u_event_id $u_event_ref]

    # Send by/op_sguil confirmation
    SendSensorAgent $socketID [list Confirm $req_socketID $cid] 

    # Update last event
    set LAST_EVENT_ID($sensorName) $eventID

    # Update last event rcvd time
    if [info exists sensorStatusArray($sensorName)] {

        set sensorStatusArray($sensorName) [lreplace $sensorStatusArray($sensorName) 1 1 $timestamp]

    }

}

proc ConfirmSancpFile { sensorName fileName } {

    global agentSocketArray agentSensorNameArray

    if { [array exists agentSocketArray] && [info exists agentSocketArray($sensorName)]} {
    
        SendSensorAgent $agentSocketArray($sensorName) [list ConfirmSancpFile $fileName]
    
    } else { 
    
        after 5000 ConfirmSancpFile $sensorName $fileName
    
    }

}

proc ConfirmSsnFile { sensorName fileName } {

    global agentSocketArray agentSensorNameArray

    if { [array exists agentSocketArray] && [info exists agentSocketArray($sensorName)]} {
    
        SendSensorAgent $agentSocketArray($sensorName) [list ConfirmSsnFile $fileName]
    
    } else { 
    
        after 5000 ConfirmSsnFile $sensorName $fileName
    
    }

}

proc ConfirmPortscanFile { sensorName fileName } {

    global agentSocketArray agentSensorNameArray

    if { [array exists agentSocketArray] && [info exists agentSocketArray($sensorName)]} {
    
        SendSensorAgent $agentSocketArray($sensorName) [list ConfirmPortscanFile $fileName]
    
    } else { 
    
        after 5000 ConfirmPortscanFile $sensorName $fileName
    
    }

}

proc BarnyardConnect { socketID dateTime } {

    global sensorStatusArray agentSensorNameArray

    if [info exists agentSensorNameArray($socketID)] {

        set sensorName $agentSensorNameArray($socketID)

        if [info exists sensorStatusArray($sensorName)] {

            set sensorStatusArray($sensorName) [lreplace $sensorStatusArray($sensorName) 3 3 $dateTime]

        }

    }

    SendAllSensorStatusInfo

}

proc BarnyardDisConnect { socketID dateTime } {

    global sensorStatusArray agentSensorNameArray

    if [info exists agentSensorNameArray($socketID)] {

        set sensorName $agentSensorNameArray($socketID)

        if [info exists sensorStatusArray($sensorName)] {

            set sensorStatusArray($sensorName) [lreplace $sensorStatusArray($sensorName) 3 3 0]

        }

    }

    SendAllSensorStatusInfo

}
