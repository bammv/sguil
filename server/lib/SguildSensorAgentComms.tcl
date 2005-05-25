proc SendSensorAgent { socketID msg } {
    
    set RFLAG 1
    if { [catch { puts $socketID $msg } sendError] } {
        catch { close $socketID } tmpError
        CleanUpDisconnectedAgent $socketID
        set RFLAG 0
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


    # Insert Event Hdr
    if [catch { InsertEventHdr $sid $cid $u_event_id $u_event_ref $u_ref_time \
                $msg $sig_gen $sig_id $sig_rev $timestamp $priority $class_type \
                $status $dec_sip $dec_dip $ip_proto $ip_ver $ip_hlen $ip_tos \
                $ip_len $ip_id $ip_flags $ip_off $ip_ttl $ip_csum $icmp_type \
                $icmp_code $src_port $dst_port } tmpError] {

        SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
        return

    } 

    # Insert ICMP, TCP, or UDP hdrs
    switch -exact -- $ip_proto {

        17  {    if [catch { InsertUDPHdr $sid $cid $udp_len $udp_csum } tmpError] {
                     SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
                     return
                 }
         }
        
         6  {    if [catch { InsertTCPHdr $sid $cid $tcp_seq $tcp_ack $tcp_off $tcp_res \
                             $tcp_flags $tcp_win $tcp_csum $tcp_urp } tmpError] {
                     SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
                     return
                 }
         }

         1  {    
                 
                     if [catch { InsertICMPHdr $sid $cid $icmp_csum $icmp_id $icmp_seq } \
                         tmpError] {
                         SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
                         return
                     }
        
         }
    }

    # Insert Payload
    if { $data_payload != "" } { 
        if [catch { InsertDataPayload $sid $cid $data_payload } tmpError] {
            SendSensorAgent $socketID [list Failed $req_socketID $cid $tmpError]
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

}
