# $Id: SguildHealthChecks.tcl,v 1.9 2007/03/08 05:45:06 bamm Exp $ #
#
# SensorAgentsHealthCheck is called to initialize the check for connected
# tunnels. First we send  PING and then go back thru and check who
# successfully replied w/a PONG.
# 
# 
proc SensorAgentsHealthCheck { { userRequest { 0 } } } {

    global sensorAgentActive sensorAgentResponse

    # Get a list of sensors and their status
    set query "SELECT hostname, active FROM sensor ORDER BY hostname ASC"
    set sensorList [MysqlSelect $query]

    foreach  sensorInfo $sensorList { 
        set sensorName [lindex $sensorInfo 0]
        set sensorActive [lindex $sensorInfo 1]
        if { $sensorActive == "Y" } {
            set sensorAgentActive($sensorName) active
            PingSensorAgent $sensorName
        } else {
            set sensorAgentActive($sensorName) inactive
        }
        set sensorAgentResponse($sensorName) 0
    }

    # Wait 2 secs for responses
    #after 2000 ReportSensorAgentResponses

    # Schedule another health check if this wasn't a user requested check
    if { $userRequest == 0 } {
        after 300000 SensorAgentsHealthCheck
    }

}

# Send a PING thru the sensor_agent socket
proc PingSensorAgent { sensor } {

    global agentSocketArray

    if { [array exists agentSocketArray] && [info exists agentSocketArray($sensor)]} {

        set sensorSocketID $agentSocketArray($sensor)

        if { [catch { puts $sensorSocketID "PING" } tmpError] } {
            catch { close $sensorSocketID } tmpError
            CleanUpDisconnectedAgent $sensorSocketID
        }

    }

}

proc SensorAgentPongRcvd { socketID } {

    global agentSensorNameArray sensorAgentResponse

    if { [array exists agentSensorNameArray] && [info exists agentSensorNameArray($socketID)]} {
       set sensorName $agentSensorNameArray($socketID)
       set sensorAgentResponse($sensorName) 1
    }

}

# Right now we are sending a note to system msgs and are only going
# to report on active sensors.
#
# Depreciated
#
#proc ReportSensorAgentResponses {} {
#
#    global sensorAgentResponse sensorAgentActive
#
#    SendSystemInfoMsg sguild "====== Sensor Agent Status ======"
#    InfoMessage "====== Sensor Agent Status ======"
#    foreach sensorName [lsort [array names sensorAgentActive] ] {
#       if { $sensorAgentActive($sensorName) == "active" } {
#            set message [format "%-20s  %s"\
#                    $sensorName \
#                    $sensorAgentResponse($sensorName)] 
#        }
#        InfoMessage "$message"
#        SendSystemInfoMsg sguild $message
#    }
#
#}

proc SendClientSensorStatusInfo { socketID } {

    global agentStatusList 

    if { [array exists agentStatusList] && [array names agentStatusList] != "" } {

        catch { SendSocket $socketID [list SensorStatusUpdate [array get agentStatusList]] } tmpError

    }

}

proc SendAllSensorStatusInfo {} {

    global clientList

    # Broadcast status info to all connected clients.
    if { [info exists clientList] && [llength $clientList] > 0 } {

        foreach clientSocket $clientList {

            SendClientSensorStatusInfo $clientSocket

        }

    }

}
