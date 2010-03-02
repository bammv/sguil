# dataList format:
#        0       1   2       3       4        5       6       7     8       9      10    11    12       13
#    sensorName sid type s_inetIP s_intIP d_inetIP d_intIP s_port d_port ipproto service app intTime hex_payload
proc ProcessPadsAsset { dataList } {

    global PADS_CID agentStatusList

    set sid [lindex $dataList 1]
    set d_intIP [lindex $dataList 6]
    set d_port [lindex $dataList 8]
    set ip_proto [lindex $dataList 9]
    set app [lindex $dataList 11]
    set intTime [lindex $dataList 12]
    set timestamp [clock format $intTime -gmt true -f "%Y-%m-%d %T"]

    # Check for new assest
    set tmpQuery \
      "SELECT timestamp, application \
      FROM pads \
      WHERE sid=$sid AND ip=$d_intIP AND port=$d_port AND ip_proto=$ip_proto \
      ORDER BY timestamp DESC"

    set results [MysqlSelect $tmpQuery]

    if { [llength $results] == 0 } { 

        # New Asset
        set sensorName [lindex $dataList 0]
        set s_inetIP [lindex $dataList 3]
        set s_intIP [lindex $dataList 4]
        set d_inetIP [lindex $dataList 5]
        set s_port [lindex $dataList 7]
        set service [lindex $dataList 10]
        set hex_payload [lindex $dataList 13]

        if { ![array exists PADS_CID] || ![info exists PADS_CID($sid)] } { set PADS_CID($sid) [GetMaxCid $sid] }
        incr PADS_CID($sid)

        # Insert data into the asset DB
        if { [catch {InsertAsset $sensorName $sid $PADS_CID($sid) $timestamp \
         $d_intIP $service $d_port $ip_proto $app $hex_payload} insertError] } {

            # INSERT failed. Log a message and try reprocess the asset.
            LogMessage "Error inserting PADS data: $insertError"
            ProcessPadsAsset $dataList
            return
            
        }

        # Send RT Alert
        AlertAsset new-asset $sensorName $sid $PADS_CID($sid) $timestamp \
         $intTime $s_inetIP $s_intIP $d_inetIP $d_intIP $s_port $d_port $service $ip_proto $app

    } else {

        # Check to see if asset has changed
        set lastApp [lindex [lindex $results 0] 1]
 
        if { $app != $lastApp } {

            # Asset changed

            set sensorName [lindex $dataList 0]
            set s_inetIP [lindex $dataList 3]
            set s_intIP [lindex $dataList 4]
            set d_inetIP [lindex $dataList 5]
            set s_port [lindex $dataList 7]
            set service [lindex $dataList 10]
            set intTime [lindex $dataList 12]
            set timestamp [clock format $intTime -gmt true -f "%Y-%m-%d %T"]
            set hex_payload [lindex $dataList 13]

            if { ![array exists PADS_CID] || ![info exists PADS_CID($sid)] } { set PADS_CID($sid) [GetMaxCid $sid] }
            incr PADS_CID($sid)

            # Insert data into the asset DB
            if { [catch {InsertAsset $sensorName $sid $PADS_CID($sid) $timestamp \
             $d_intIP $service $d_port $ip_proto $app $hex_payload} insertError] } {

                # INSERT failed. Log a message and try reprocess the asset.
                LogMessage "Error inserting PADS data: $insertError"
                ProcessPadsAsset $dataList
                return
            
            }

            # Send RT Alert
            AlertAsset changed-asset $sensorName $sid $PADS_CID($sid) $timestamp \
             $intTime $s_inetIP $s_intIP $d_inetIP $d_intIP $s_port $d_port $service $ip_proto $app

        }

    }

    # Update last pads rcvd time
    if [info exists agentStatusList($sid)] {

        set agentStatusList($sid) [lreplace $agentStatusList($sid) 3 3 $timestamp]

    }

}

proc AlertAsset { type sensorName sid aid timestamp intTime s_inetIP s_intIP d_inetIP d_intIP s_port d_port service ip_proto app} {

    set generator_id 10000

    # Add to event table
    set tablePrefix "${sensorName}_[clock format [clock scan $timestamp] -gmt true -format "%Y%m%d"]"

    if { $type == "new-asset" } {
        set msg "PADS New Asset - $service $app"
        set sig_id 1
        set rev_id 1
    } elseif { $type == "changed-asset" } {
        set msg "PADS Changed Asset - $service $app"
        set sig_id 2
        set rev_id 1
    } else {
        set msg "PADS Unknown Asset - $service $app"
        set sig_id 3
        set rev_id 1
    }
    

    if [catch {InsertEventHdr $tablePrefix $sid $aid $aid $aid $timestamp $msg $generator_id $sig_id $rev_id \
               $timestamp 5 $type 0 $s_intIP $d_intIP $ip_proto {} {} {} {} {} {} {} \
               {} {} {} {} $s_port $d_port} tmpError] {

        # ErrorMessage calls CleanExit 1
        ErrorMessage "ERROR: While inserting event info: $tmpError"

    }
    
    # Send RT Event
    # RTEvent|st|priority|class_type|hostname|timestamp|sid|cid|msg|srcip|dstip|ipproto|srcport|dstport|sig_id|rev|u_event_id|u_event_ref
    EventRcvd [list 0 5 new-asset $sensorName $timestamp $sid $aid $msg \
               $s_inetIP $d_inetIP $ip_proto $s_port $d_port $generator_id $sig_id $rev_id $aid $aid]

}


proc InsertAsset { sensorName sid aid timestamp intIP service port ip_proto app hex_payload } {

    set tmpQuery "INSERT INTO pads (hostname, sid, asset_id, timestamp, ip, service, port, ip_proto, application, hex_payload) \
                  VALUES ('$sensorName', '$sid', '$aid', '$timestamp', '$intIP', '$service', '$port', '$ip_proto', '[MysqlEscapeString $app]', '$hex_payload')" 

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {

        # INSERT failed
        return -code error $tmpError

    }

}

proc GetAssetData { socketID sid asset_id } {

    set tmpQuery "SELECT hex_payload FROM pads WHERE sid='$sid' AND asset_id='$asset_id'"
    set qResults [FlatDBQuery $tmpQuery]

    catch {SendSocket $socketID [list InsertPadsBanner $qResults]} tmpError

}

# To merge or not to merge...
#
#proc CreatePadsTable { tableName } {
#
#    global MAIN_DB_SOCKETID mergeTableListArray
#
#    LogMessage "Creating pads table $tableName."
#
#    set createQuery "                                            \
#        CREATE TABLE IF NOT EXISTS `$tableName`                  \
#        (                                                        \
#        hostname              VARCHAR(255)     NOT NULL,         \
#        sid                   INT UNSIGNED     NOT NULL,         \
#        timestamp             DATETIME         NOT NULL,         \
#        ip                    INT UNSIGNED     NOT NULL,         \
#        port                  INT UNSIGNED     NOT NULL,         \
#        ip_proto              TINYINT UNSIGNED NOT NULL,         \
#        application           VARCHAR(255)     NOT NULL          \
#        )"
#        
#
#    mysqlexec $MAIN_DB_SOCKETID $createQuery
#    lappend mergeTableListArray(pads) $tableName
#
#}
