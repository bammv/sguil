# $Id: SguildConnect.tcl,v 1.3 2005/01/27 19:25:25 bamm Exp $

#
# ClientConnect: Sets up comms for client/server
#
proc ClientConnect { socketID IPAddr port } {
  global socketInfo VERSION
  global OPENSSL KEY PEM

  LogMessage "Client Connect: $IPAddr $port $socketID"
  
  # Check the client access list
  if { ![ValidateClientAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    LogMessage "Invalid access attempt from $IPAddr"
    return
  }
  LogMessage "Valid client access: $IPAddr"
  set socketInfo($socketID) "$IPAddr $port"
  fconfigure $socketID -buffering line
  # Do version checks
  if [catch {SendSocket $socketID "$VERSION"} sendError ] {
    return
  }
  if [catch {gets $socketID} clientVersion] {
    LogMessage "$ERROR: $clientVersion"
    return
  }
  if { $clientVersion != $VERSION } {
    catch {close $socketID} tmpError
    LogMessage "ERROR: Client connect denied - mismatched versions"
    LogMessage "CLIENT VERSION: $clientVersion"
    LogMessage "SERVER VERSION: $VERSION"
    ClientExitClose $socketID
    return
  }
  if {$OPENSSL} {
    tls::import $socketID -server true -keyfile $KEY -certfile $PEM
    fileevent $socketID readable [list HandShake $socketID ClientCmdRcvd]
  } else {
    fileevent $socketID readable [list ClientCmdRcvd $socketID]
  }
}

proc SensorConnect { socketID IPAddr port } {

  LogMessage "Connect from $IPAddr:$port $socketID"
  # Check the client access list
  if { ![ValidateSensorAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    LogMessage "Invalid access attempt from $IPAddr"
    return
  }
  LogMessage "ALLOWED"
  fconfigure $socketID -buffering line -blocking 0
  fileevent $socketID readable [list SensorCmdRcvd $socketID]
}

proc SensorAgentConnect { socketID sensorName } {
  global connectedAgents agentSocket agentSensorName
  lappend connectedAgents $sensorName
  set agentSocket($sensorName) $socketID
  set agentSensorName($socketID) $sensorName
  set sensorID [GetSensorID $sensorName]
  SendSystemInfoMsg $sensorName "Agent connected."
  SendSensorAgent $socketID [list SensorID $sensorID]
}


proc CleanUpDisconnectedAgent { socketID } {
  global connectedAgents agentSocket agentSensorName
                                                                                                                                   
  set connectedAgents [ldelete $connectedAgents $agentSensorName($socketID)]
  set sensorName $agentSensorName($socketID)
  unset agentSocket($sensorName)
  unset agentSensorName($socketID)
}

proc HandShake { socketID cmd } {
  if {[eof $socketID]} {
    close $socketID
    ClientExitClose socketID
  } elseif { [catch {tls::handshake $socketID} results] } {
    LogMessage "ERROR: $results"
    close $socketID
    ClientExitClose socketID
  } elseif {$results == 1} {
    InfoMessage "Handshake complete for $socketID"
    fileevent $socketID readable [list $cmd $socketID]
  }
}



