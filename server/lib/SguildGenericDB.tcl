# $Id: SguildGenericDB.tcl,v 1.27 2010/03/02 04:05:49 bamm Exp $ #

proc GetUserID { username } {
  set uid [FlatDBQuery "SELECT uid FROM user_info WHERE username='$username'"]
  if { $uid == "" } {
    DBCommand\
     "INSERT INTO user_info (username, last_login) VALUES ('$username', '[GetCurrentTimeStamp]')"
    set uid [FlatDBQuery "SELECT uid FROM user_info WHERE username='$username'"]
  }
  return $uid
}
                                                                                                     
proc InsertHistory { sid cid uid timestamp status comment} {
  if {$comment == "none"} {
    DBCommand "INSERT INTO history (sid, cid, uid, timestamp, status) VALUES ( $sid, $cid, $uid, '$timestamp', $status)"
  } else {
    DBCommand "INSERT INTO history (sid, cid, uid, timestamp, status, comment) \
               VALUES ( $sid, $cid, $uid, '$timestamp', $status, '[mysqlescape $comment]')"
  }
}
                                                                                                     
proc MysqlGetNetName { sensorID } {

    set netName [FlatDBQuery "SELECT net_name FROM sensor WHERE sid='$sensorID'"]
    if { $netName == "" } { set netName "unknown" }
    return $netName
   
}

proc GetSensorID { sensorName type netName } {

    # For now we query the DB everytime we need the sid.
    set sensorID [FlatDBQuery "SELECT sid FROM sensor WHERE hostname='$sensorName' AND agent_type='$type'"]

    if { $sensorID == "" } {

        LogMessage "New sensor. Adding sensor $sensorName to the DB."

        set tmpQuery "INSERT INTO sensor (hostname, agent_type, net_name) VALUES ('$sensorName', '$type', '$netName')"

        if [catch {SafeMysqlExec $tmpQuery} tmpError] {
            # Insert failed exit on error
            ErrorMessage "ERROR: Unable to add new sensor: mysqld: $tmpError :\nQuery => $tmpQuery"
            return
        }

        set sensorID [FlatDBQuery "SELECT sid FROM sensor WHERE hostname='$sensorName' AND agent_type='$type'"]
        if { $sensorID == "" } {

            # Insert failed exit on error
            ErrorMessage "ERROR: Unable to add sensor using query => SELECT sid FROM sensor WHERE hostname='$sensorName' AND agent_type='$type'" 
            return

        }

    }

    return $sensorID

}

proc GetMaxCid { sid } {

    global mergeTableListArray

    if { $mergeTableListArray(event) != "" } {

        set cid [FlatDBQuery "SELECT MAX(cid) FROM event WHERE sid=$sid"]

    } 

    if { ![info exists cid] || $cid == "" || $cid == "{}"} {

        set cid 0

    }

    return $cid

}

proc ExecDB { socketID query } {
  global MAIN_DB_SOCKETID
    if { [lindex $query 0] == "OPTIMIZE" } {
        SendSystemInfoMsg sguild "Table Optimization beginning, please stand by"
    }
  InfoMessage "Sending DB Query: $query"
  if [catch {mysqlexec $MAIN_DB_SOCKETID $query} execResults] {
        catch {SendSocket $socketID [list InfoMessage "ERROR running query, perhaps you don't have permission. Error:$execResults"]} tmpError
  } else {
      if { [lindex $query 0] == "DELETE" } {
          catch {SendSocket $socketID [list InfoMessage "Query deleted $execResults rows."]} tmpError
      } elseif { [lindex $query 0] == "OPTIMIZE" } {
          catch {SendSocket $socketID [list InfoMessage "Database Command Completed."]} tmpError
          SendSystemInfoMsg sguild "Table Optimization Completed."
      } else {
          catch {SendSocket $socketID [list InfoMessge "Database Command Completed."]} tmpError
      }
  }
}

proc QueryDB { socketID clientWinName query } {
  global mainWritePipe
  global DBNAME DBUSER DBPASS DBPORT DBHOST
                                                                                                     
  # Just pass the query to queryd.
  if { $DBPASS == "" } {
    set dbCmd "mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT"
  } else {
    set dbCmd "mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS"
  }
  puts $mainWritePipe [list $socketID $clientWinName $query $dbCmd]
  flush $mainWritePipe
}
proc FlatDBQuery { query } {

    global MAIN_DB_SOCKETID
                                                                                                     
    set queryResults [mysqlsel $MAIN_DB_SOCKETID $query -flatlist]
    return $queryResults

}
# type can be list or flatlist.
# list returns { 1 foo } { 2 bar } { 3 fu }
# flatlist returns { 1 foo 2 bar 3 fu } 
proc MysqlSelect { query { type {list} } } {

    global MAIN_DB_SOCKETID

    if { $type == "flatlist" } {
        set queryResults [mysqlsel $MAIN_DB_SOCKETID $query -flatlist]
    } else {
         set queryResults [mysqlsel $MAIN_DB_SOCKETID $query -list]
    }
    return $queryResults

}

proc DBCommand { query } {

    global MAIN_DB_SOCKETID
                                                                                                     
    if [catch {mysqlexec $MAIN_DB_SOCKETID $query} tmpError] {
        ErrorMessage "ERROR Execing DB cmd: $query Error: $tmpError"
    }
    return

}

proc UpdateDBStatusList { tableName whereTmp timestamp uid status } {

    global MAIN_DB_SOCKETID

    set updateString "UPDATE `$tableName` SET status=$status, last_modified='$timestamp', last_uid='$uid' WHERE $whereTmp"

    InfoMessage "Updating events: $updateString"

    if { [catch {mysqlexec $MAIN_DB_SOCKETID $updateString} execResults] } {

        # Update failed.
        LogMessage "DB Error during:\n$updateString\n: $execResults"
        return 0

    } else {

        return $execResults

    }

}

proc UpdateDBStatus { sensorName date sid cid timestamp uid status } {

    global MAIN_DB_SOCKETID

    set tmpDate [clock format [clock scan $date] -gmt true -format "%Y%m%d"]
    set tableName "event_${sensorName}_$tmpDate"
    set updateString\
     "UPDATE `$tableName` SET status=$status, last_modified='$timestamp', last_uid='$uid' WHERE sid=$sid AND cid=$cid"

    InfoMessage $updateString 

    set execResults [mysqlexec $MAIN_DB_SOCKETID $updateString]

}

proc SafeMysqlExec { query } {

    global MAIN_DB_SOCKETID

    if [catch { mysqlexec $MAIN_DB_SOCKETID $query } execResults ] {
                                                                                                                       
        LogMessage "DB Error during:\n$query\n: $execResults"
        set ERROR 1
                                                                                                                       
    } else {

        set ERROR 0
                                                                                                                       
    }

    if { $ERROR } {
        return -code error $execResults
    } else {
        return
    }

}

proc InsertEventHdr { tablePostfix sid cid u_event_id u_event_ref u_ref_time msg sig_gen \
                      sig_id sig_rev timestamp priority class_type status   \
                      dec_sip dec_dip ip_proto ip_ver ip_hlen ip_tos ip_len \
                      ip_id ip_flags ip_off ip_ttl ip_csum icmp_type        \
                      icmp_code src_port dst_port } {

    global mergeTableListArray


    set tmpTableName event_$tablePostfix

    # Check to see our table exists.
    if { [lsearch -exact $mergeTableListArray(event) $tmpTableName] < 0 } {

        CreateMysqlAlertTables $tablePostfix

    }

    # Event columns we are INSERTing
    set tmpTables \
         "sid, cid, unified_event_id, unified_event_ref, unified_ref_time,  \
         signature, signature_gen, signature_id, signature_rev, timestamp,  \
         priority, class, status, src_ip, dst_ip, ip_proto, ip_ver, ip_hlen,\
         ip_tos, ip_len, ip_id, ip_flags, ip_off, ip_ttl, ip_csum"
                                                                                                                       
    # And their corresponding values.
    set tmpValues \
         "'$sid', '$cid', '$u_event_id', '$u_event_ref', '$u_ref_time', '[mysqlescape $msg]',  \
         '$sig_gen', '$sig_id', '$sig_rev', '$timestamp', '$priority',   \
         '$class_type', '$status', '$dec_sip', '$dec_dip', '$ip_proto',  \
         '$ip_ver', '$ip_hlen', '$ip_tos', '$ip_len', '$ip_id',          \
         '$ip_flags', '$ip_off', '$ip_ttl', '$ip_csum'"
                                                                                                                       
    # ICMP, TCP, & UDP have extra columns
    if { $ip_proto == "1" } {
                                                                                                                       
        # ICMP event
        set tmpTables "${tmpTables}, icmp_type, icmp_code"
        set tmpValues "${tmpValues}, '$icmp_type', '$icmp_code'"
                                                                                                                       
    } elseif { $ip_proto == "6" || $ip_proto == "17" } {
                                                                                                                       
        # TCP || UDP event
        set tmpTables "${tmpTables}, src_port, dst_port"
        set tmpValues "${tmpValues}, '$src_port', '$dst_port'"

    }
 
    # The final INSERT gets built
    set tmpQuery "INSERT INTO `$tmpTableName` ($tmpTables) VALUES ($tmpValues)"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

proc InsertUDPHdr { tablePostfix sid cid udp_len udp_csum } {

    set tmpTableName udphdr_$tablePostfix

    set tmpQuery "INSERT INTO `$tmpTableName` (sid, cid, udp_len, udp_csum) \
                  VALUES ('$sid', '$cid', '$udp_len', '$udp_csum')"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }
}

proc InsertTCPHdr { tablePostfix sid cid tcp_seq tcp_ack tcp_off tcp_res \
                    tcp_flags tcp_win tcp_csum tcp_urp } {

    set tmpTableName tcphdr_$tablePostfix

    set tmpQuery "INSERT INTO `$tmpTableName` (sid, cid, tcp_seq, tcp_ack, \
                  tcp_off, tcp_res, tcp_flags, tcp_win, tcp_csum, tcp_urp) \
                  VALUES ('$sid', '$cid', '$tcp_seq', '$tcp_ack', '$tcp_off', \
                  '$tcp_res', '$tcp_flags', '$tcp_win', '$tcp_csum', '$tcp_urp')"
                 
    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

proc InsertICMPHdr { tablePostfix sid cid icmp_csum icmp_id icmp_seq } {

    set tmpTableName icmphdr_$tablePostfix

    set tmpTables "sid, cid, icmp_csum"
    set tmpValues "'$sid', '$cid', '$icmp_csum'"

    if { $icmp_id != "" } {
        set tmpTables "$tmpTables, icmp_id"
        set tmpValues "$tmpValues, '$icmp_id'"
    }

    if { $icmp_seq != "" } {
        set tmpTables "$tmpTables, icmp_seq"
        set tmpValues "$tmpValues, '$icmp_seq'"
    }

    set tmpQuery "INSERT INTO `$tmpTableName` ($tmpTables)  VALUES ($tmpValues)"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

proc InsertDataPayload { tablePostfix sid cid data_payload } {

    set tmpTableName data_$tablePostfix

    set tmpQuery "INSERT INTO `$tmpTableName` (sid, cid, data_payload) \
                  VALUES ('$sid', '$cid', '$data_payload')"

    if { [catch {SafeMysqlExec $tmpQuery} tmpError] } {
  
        return -code error $tmpError

    }

}

# Escape backslash, single quote, and double quote

proc MysqlEscapeString { tmpStr } {

    regsub -all {\\} $tmpStr {\\\\} tmpStr 
    regsub -all {\'} $tmpStr {\'} tmpStr
    regsub -all {\"} $tmpStr {\"} tmpStr

    return $tmpStr

}
