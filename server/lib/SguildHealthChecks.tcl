# $Id: SguildHealthChecks.tcl,v 1.3 2004/11/29 21:21:14 bamm Exp $ #
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
        set sensorAgentResponse($sensorName) disconnected
    }

    # Wait 2 secs for responses
    after 2000 ReportSensorAgentResponses

    # Schedule another health check if this wasn't a user requested check
    if { $userRequest == 0 } {
        after 300000 SensorAgentsHealthCheck
    }

}

# Send a PING thru the sensor_agent socket
proc PingSensorAgent { sensor } {

    global agentSocket

    if { [array exists agentSocket] && [info exists agentSocket($sensor)]} {

        set sensorSocketID $agentSocket($sensor)

        if { [catch { puts $sensorSocketID "PING" } tmpError] } {
            catch { close $sensorSocketID } tmpError
            CleanUpDisconnectedAgent $sensorSocketID
        }

    }

}

proc SensorAgentPongRcvd { socketID } {

    global agentSensorName sensorAgentResponse

    if { [array exists agentSensorName] && [info exists agentSensorName($socketID)]} {
       set sensorName $agentSensorName($socketID)
       set sensorAgentResponse($sensorName) connected
    }

}

# Right now we are sending a note to system msgs and are only going
# to report on active sensors.
proc ReportSensorAgentResponses {} {

    global sensorAgentResponse sensorAgentActive

    SendSystemInfoMsg sguild "====== Sensor Agent Status ======"
    InfoMessage "====== Sensor Agent Status ======"
    foreach sensorName [lsort [array names sensorAgentActive] ] {
       if { $sensorAgentActive($sensorName) == "active" } {
            set message [format "%-20s  %s"\
                    $sensorName \
                    $sensorAgentResponse($sensorName)] 
        }
        InfoMessage "$message"
        SendSystemInfoMsg sguild $message
    }

}
