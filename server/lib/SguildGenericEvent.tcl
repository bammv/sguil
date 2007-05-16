# $Id: SguildGenericEvent.tcl,v 1.2 2007/05/16 19:06:41 bamm Exp $

# GenericEvent status priority class hostname timestamp sensorID alertID hexMessage  \
#               inet_sip inet_dip ip_proto src_port dst_port generatorID sigID       \
#               revision hexDetail
proc GenericEvent { agentSocketID eventList } {

    global agentStatusList

    # Make sure we have the right number of 
    if { [llength $eventList] != 18 } { 

        set errorMsg "ERROR: Invalid length ([llength $eventList]): $eventList"
        # DEBUG Foo
        LogMessage $errorMsg

        SendSensorAgent $agentSocketID [list Failed $errorMsg]
        return

    }

    set status [lindex $eventList 0]
    set priority [lindex $eventList 1]
    set class [lindex $eventList 2]
    set hostname [lindex $eventList 3]
    set timestamp [lindex $eventList 4]
    set sensorID [lindex $eventList 5]
    set alertID [lindex $eventList 6]
    set refID [lindex $eventList 7]
    set msg [hex2string [lindex $eventList 8]]
    set inet_sip [lindex $eventList 9]
    set dec_sip [InetAtoN $inet_sip]
    set inet_dip [lindex $eventList 10]
    set dec_dip [InetAtoN $inet_dip]
    set ip_proto [lindex $eventList 11]
    set src_port [lindex $eventList 12]
    set dst_port [lindex $eventList 13]
    set gen_id [lindex $eventList 14]
    set sig_id [lindex $eventList 15]
    set revision [lindex $eventList 16]
    set hexDetail [lindex $eventList 17]

    # The merge table prefix is hostname_YYYYMMDD
    set tmpDate [clock format [clock scan $timestamp] -gmt true -format "%Y%m%d"]
    set tablePrefix "${hostname}_${tmpDate}"

    # Insert data into the event hdr
    if [catch { InsertEventHdr $tablePrefix $sensorID $alertID $alertID $refID $timestamp \
                $msg $gen_id $sig_id $revision $timestamp $priority $class $status $dec_sip \
                $dec_dip $ip_proto {} {} {} {} {} {} {} {} {} {} {} $src_port $dst_port } tmpError] {

        # DEBUG Foo
        LogMessage "ERROR: While inserting event info: $tmpError"

        SendSensorAgent $agentSocketID [list Failed $tmpError]
        return

    }

    # Insert hex detail into the data table
    if [catch { InsertDataPayload $tablePrefix $sensorID $alertID $hexDetail } tmpError] {

        # DEBUG Foo
        LogMessage "ERROR: While inserting event info: $tmpError"

        SendSensorAgent $agentSocketID [list Failed $tmpError]
        return

    }

    # Send RT Event if status is 0
    if { $status == 0 } {

        EventRcvd [list $status $priority $class $hostname $timestamp $sensorID $alertID  \
                   $msg $inet_sip $inet_dip $ip_proto $src_port $dst_port $gen_id $sig_id \
                   $revision $alertID $refID]

    }

    # Update last event time
    if [info exists agentStatusList($sensorID)] {

        set agentStatusList($sensorID) [lreplace $agentStatusList($sensorID) 3 3 $timestamp]

    }


    # Send the agent confirmation 
    SendSocket $agentSocketID [list ConfirmEvent $alertID]

}

proc GetGenericDetail { socketID sid eventID } {

    set tmpQuery "SELECT data_payload FROM data WHERE data.sid=$sid and data.cid=$eventID"
    set queryResults [FlatDBQuery $tmpQuery]

    if [catch {SendSocket $socketID [list InsertGenericDetail $queryResults]} tmpError] {

        LogMessage "Error: $tmpError"

    }

}
