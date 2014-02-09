# $Id: SguildConnect.tcl,v 1.27 2012/03/19 21:13:29 bamm Exp $

#
# ClientConnect: Sets up comms for client/server
#
proc ClientConnect { socketID IPAddr port } {

    global socketInfo VERSION 
    #global CLIENT_PIDS

    LogMessage "Client Connect: $IPAddr $port $socketID"
  
    # Check the client access list
    if { ![ValidateClientAccess $IPAddr] } {

        SendSocket $socketID "Connection Refused."
        catch {close $socketID} tmpError
        LogMessage "Invalid access attempt from $IPAddr"
        return

    }

    # Valid client
    LogMessage "Valid client access: $IPAddr"
    
    set socketInfo($socketID) [list $IPAddr $port]
    fconfigure $socketID -buffering line
    fileevent $socketID readable [list ClientCmdRcvd $socketID]

    # Send version info
    if [catch {SendSocket $socketID "$VERSION"} sendError ] { return }

    # Give the user 90 seconds to send login info
    after 90000 CheckLoginStatus $socketID $IPAddr $port

    # Not used yet
    #set childPid [ForkClient $socketID $IPAddr $port]
    #if { $childPid != 0 } { lappend CLIENT_PIDS $childPid }

}

# Not used yet
proc ForkClient { socketID IPAddr port } {

    global socketInfo VERSION

    if { [set childPid [fork]] == 0 } { 

        # In the child now
        LogMessage "Valid client access: $IPAddr"
        set socketInfo($socketID) [list $IPAddr $port]
        fconfigure $socketID -buffering line
        fileevent $socketID readable [list ClientCmdRcvd $socketID]

        # Send version info
        if [catch {SendSocket $socketID "$VERSION"} sendError ] { return }

        # Give the user 90 seconds to send login info
        after 90000 CheckLoginStatus $socketID $IPAddr $port

    }

    return $childPid

}

proc ClientVersionCheck { socketID clientVersion } {

  global socketInfo VERSION
  global KEY PEM

  if { $clientVersion != $VERSION } {
    catch {close $socketID} tmpError
    LogMessage "ERROR: Client connect denied - mismatched versions"
    LogMessage "CLIENT VERSION: $clientVersion"
    LogMessage "SERVER VERSION: $VERSION"
    ClientExitClose $socketID
    return
  }

  if { [catch {tls::import $socketID -server true -keyfile $KEY -certfile $PEM -ssl2 false -ssl3 false -tls1 true} importError] } {
        LogMessage "ERROR: $importError"
        close $socketID
        ClientExitClose $socketID
  }

  if { [catch {tls::handshake $socketID} results] } {
        LogMessage "ERROR: $results"
        close $socketID
        ClientExitClose $socketID
  } 

}

proc SensorConnect { socketID IPAddr port } {

  global VERSION AGENT_VERSION KEY PEM

  LogMessage "Sensor agent connect from $IPAddr:$port $socketID"
  LogAgentAccess "[GetCurrentTimeStamp]: Sensor agent connect from $IPAddr:$port $socketID"


  # Check the sensor access list
  if { ![ValidateSensorAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    LogMessage "Invalid access attempt from $IPAddr"
    LogAgentAccess "[GetCurrentTimeStamp]: ($socketID) Invalid access attempt from $IPAddr"
    return
  }
  LogMessage "Valid sensor agent: $IPAddr"
  LogAgentAccess "[GetCurrentTimeStamp]: ($socketID) Valid Sensor agent: $IPAddr"
  fconfigure $socketID -buffering line
  fileevent $socketID readable [list SensorCmdRcvd $socketID]
  # Version check
  if [catch {puts $socketID $AGENT_VERSION} tmpError] {
    LogMessage "ERROR: $tmpError"
    catch {close $socketID}
    return
  }
}

proc AgentVersionCheck { socketID agentVersion } {

  global VERSION AGENT_VERSION KEY PEM

  if { $agentVersion != $AGENT_VERSION } {
    catch {close $socketID} 
    LogMessage "ERROR: Agent connect denied - mismatched versions"
    LogMessage "AGENT VERSION: $agentVersion"
    LogMessage "SERVER VERSION: $VERSION"
    return
  }

  if { [catch {tls::import $socketID -server true -keyfile $KEY -certfile $PEM -ssl2 false -ssl3 false -tls1 true} importError] } {
        LogMessage "ERROR: $importError"
        catch {close $socketID}
        CleanUpDisconnectedAgent $socketID
        return
  }

  if { [catch {tls::handshake $socketID} results] } {
        LogMessage "ERROR: $results"
        close $socketID
        ClientExitClose $socketID
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
    ClientExitClose $socketID
  } elseif { [catch {tls::handshake $socketID} results] } {
    LogMessage "ERROR: $results"
    close $socketID
    ClientExitClose $socketID
  } elseif {$results == 1} {
    InfoMessage "Handshake complete for $socketID"
    fileevent $socketID readable [list $cmd $socketID]
  }
}


proc CheckLoginStatus { socketID IPAddr port } {

    global socketInfo

    if { [array exists socketInfo] && [info exists socketInfo($socketID)] } {
 
        # Check to make sure the socket is being used by the same dst ip and port
        if { [lindex $socketInfo($socketID) 0] == "$IPAddr" && [lindex $socketInfo($socketID) 1] == "$port" } {

            # Finally see if there is a username associated
            if { [llength $socketInfo($socketID)] < 3 } {

                LogMessage "Removing stale client: $socketInfo($socketID)"
                # Looks like the socket is stale.
                catch {close $socketID}
                ClientExitClose $socketID

            }

        }

    }

}

proc LogAgentAccess { message } {

    global AGENT_LOG

    if { [catch {open $AGENT_LOG a} fileID] } {

        puts "ERROR: Unable to log access -> $message"
        puts "ERROR: $fileID"
        return

    }

    puts $fileID $message
    catch {close $fileID}

}

