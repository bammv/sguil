# $Id: SguildConnect.tcl,v 1.1 2004/10/05 15:23:20 bamm Exp $

#
# ClientConnect: Sets up comms for client/server
#
proc ClientConnect { socketID IPAddr port } {
  global DEBUG socketInfo VERSION
  global OPENSSL KEY PEM
  if {$DEBUG} {
    puts "Client Connect: $IPAddr $port $socketID"
  }
  # Check the client access list
  if { ![ValidateClientAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    if {$DEBUG} { puts "Invalid access attempt from $IPAddr" }
    return
  }
  if {$DEBUG} { puts "Valid client access: $IPAddr" }
  set socketInfo($socketID) "$IPAddr $port"
  fconfigure $socketID -buffering line
  # Do version checks
  if [catch {SendSocket $socketID "$VERSION"} sendError ] {
    return
  }
  if [catch {gets $socketID} clientVersion] {
    if {$DEBUG} {puts "$ERROR: $clientVersion"}
    return
  }
  if { $clientVersion != $VERSION } {
    catch {close $socketID} tmpError
    if {$DEBUG} {puts "ERROR: Client connect denied - mismatched versions" }
    if {$DEBUG} {puts "CLIENT VERSION: $clientVersion" }
    if {$DEBUG} {puts "SERVER VERSION: $VERSION" }
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
  global DEBUG
  if {$DEBUG} {puts "Connect from $IPAddr:$port $socketID"}
  # Check the client access list
  if { ![ValidateSensorAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    if {$DEBUG} { puts "Invalid access attempt from $IPAddr" }
    return
  }
  if {$DEBUG} { puts "ALLOWED" }
  fconfigure $socketID -buffering line -blocking 0
  fileevent $socketID readable [list SensorCmdRcvd $socketID]
}

proc SensorAgentConnect { socketID sensorName } {
  global connectedAgents agentSocket agentSensorName
  lappend connectedAgents $sensorName
  set agentSocket($sensorName) $socketID
  set agentSensorName($socketID) $sensorName
  SendSystemInfoMsg $sensorName "Agent connected."
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
    puts "ERROR: $results"
    close $socketID
    ClientExitClose socketID
  } elseif {$results == 1} {
    puts "Handshake complete for $socketID"
    fileevent $socketID readable [list $cmd $socketID]
  }
}

