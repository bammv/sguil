# $Id: SguildConnect.tcl,v 1.17 2007/03/08 05:45:06 bamm Exp $

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
    LogMessage "ERROR: $clientVersion"
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

  global VERSION AGENT_OPENSSL AGENT_VERSION KEY PEM

  LogMessage "Sensor agent connect from $IPAddr:$port $socketID"

  # Check the sensor access list
  if { ![ValidateSensorAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    LogMessage "Invalid access attempt from $IPAddr"
    return
  }
  LogMessage "Valid sensor agent: $IPAddr"
  fconfigure $socketID -buffering line
  # Version check
  if [catch {puts $socketID $AGENT_VERSION} tmpError] {
    LogMessage "ERROR: $tmpError"
    catch {close $socketID}
    return
  }
  if [catch {gets $socketID} agentVersion] {
    LogMessage "ERROR: Unable to get agent version: $agentVersion"
    catch {close $socketID}
    return
  }
  if { $agentVersion != $AGENT_VERSION } {
    catch {close $socketID} 
    LogMessage "ERROR: Agent connect denied - mismatched versions"
    LogMessage "AGENT VERSION: $agentVersion"
    LogMessage "SERVER VERSION: $VERSION"
    return
  }
  #fconfigure $socketID -buffering line -blocking 0
  if {$AGENT_OPENSSL} {
    tls::import $socketID -server true -keyfile $KEY -certfile $PEM
    fileevent $socketID readable [list HandShake $socketID SensorCmdRcvd]
  } else {
    fileevent $socketID readable [list SensorCmdRcvd $socketID]
  }
}

proc AgentInit { socketID sensorName byStatus } {

    global agentSocketArray agentSensorNameArray
    global socketInfo

    set sensorID [GetSensorID $sensorName]

    set agentSocketArray($sensorName) $socketID
    set agentSensorNameArray($socketID) $sensorName
    set agentSocketSid($socketID) $sensorID

    SendSensorAgent $socketID [list BarnyardSensorID $sensorID]
    SendSystemInfoMsg $sensorName "Agent connected."
    SendAllSensorStatusInfo

}

proc CleanUpDisconnectedAgent { socketID } {

    global agentSocketArray agentSensorNameArray validSensorSockets
    global agentStatusList agentSocketInfo

    # Remove the agent socket from the valid (registered) list. 
    if [info exists validSensorSockets] {
        set validSensorSockets [ldelete $validSensorSockets $socketID]
    }

    if { [array exists agentSocketInfo] && [info exists agentSocketInfo($socketID)] } {
  
        set sid [lindex $agentSocketInfo($socketID) 0]
        if { [array exists agentStatusList] && [info exists agentStatusList($sid)] } {

            set agentStatusList($sid) [lreplace $agentStatusList($sid) 4 4 0 ]

        } 

        unset agentSocketInfo($socketID)

    }

    SendAllSensorStatusInfo

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
