# $Id: SguildGenericDB.tcl,v 1.3 2004/10/18 15:28:20 shalligan Exp $ #

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
    DBCommand "INSERT INTO history (sid, cid, uid, timestamp, status, comment) VALUES ( $sid, $cid, $uid, '$timestamp', $status, '$comment')"
  }
}
                                                                                                     
proc GetSensorID { sensorName } {
  # For now we query the DB everytime we need the sid.
  set sid [FlatDBQuery "SELECT sid FROM sensor WHERE hostname='$sensorName'"]
  return $sid
}

proc ExecDB { socketID query } {
  global DBNAME DBUSER DBPASS DBPORT DBHOST
    if { [lindex $query 0] == "OPTIMIZE" } {
        SendSystemInfoMsg sguild "Table Optimization beginning, please stand by"
    }
  InfoMessage "Sending DB Query: $query"
  if { $DBPASS == "" } {
      set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
      set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  if [catch {mysqlexec $dbSocketID $query} execResults] {
        catch {SendSocket $socketID "InfoMessage \{ERROR running query, perhaps you don't have permission. Error:$execResults\}"} tmpError
  } else {
      if { [lindex $query 0] == "DELETE" } {
          catch {SendSocket $socketID "InfoMessage Query deleted $execResults rows."} tmpError
      } elseif { [lindex $query 0] == "OPTIMIZE" } {
          catch {SendSocket $socketID "InfoMessage Database Command Completed."} tmpError
          SendSystemInfoMsg sguild "Table Optimization Completed."
      } else {
          catch {SendSocket $socketID "InfoMessge Database Command Completed."} tmpError
      }
  }
  mysqlclose $dbSocketID
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
  global DBNAME DBUSER DBPORT DBHOST DBPASS
                                                                                                     
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set queryResults [mysqlsel $dbSocketID $query -flatlist]
  mysqlclose $dbSocketID
  return $queryResults
}

proc DBCommand { query } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
                                                                                                     
  if { $DBPASS == "" } {
    set dbCmd [list mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbCmd [list mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
                                                                                                     
  # Connect to the DB
  if { [ catch {eval $dbCmd} dbSocketID ] } {
    ErrorMessage "ERROR Connecting to the DB: $dbSocketID"
  }
                                                                                                     
  if [catch {mysqlexec $dbSocketID $query} tmpError] {
    puts "ERROR Execing DB cmd: $query"
    puts "$tmpError"
    CleanExit
  }
  catch {mysqlclose $dbSocketID}
  return
}
proc UpdateDBStatusList { whereTmp timestamp uid status } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
  set updateString "UPDATE event SET status=$status, last_modified='$timestamp', last_uid='$uid' WHERE $whereTmp"
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set execResults [mysqlexec $dbSocketID $updateString]
  mysqlclose $dbSocketID
  return $execResults
}
proc UpdateDBStatus { eventID timestamp uid status } {
  global DBNAME DBUSER DBPORT DBHOST DBPASS
  set sid [lindex [split $eventID .] 0]
  set cid [lindex [split $eventID .] 1]
  set updateString\
   "UPDATE event SET status=$status, last_modified='$timestamp', last_uid='$uid' WHERE sid=$sid AND cid=$cid"
  if { $DBPASS == "" } {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
  } else {
    set dbSocketID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
  }
  set execResults [mysqlexec $dbSocketID $updateString]
  mysqlclose $dbSocketID
}







