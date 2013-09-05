# $Id: SguildSensorCmdRcvd.tcl,v 1.32 2013/09/05 00:38:45 bamm Exp $ #

proc SensorCmdRcvd { socketID } {
  global agentSensorNameArray validSensorSockets
  if { [eof $socketID] || [catch {gets $socketID data} getsError] } {
    # Socket closed
    catch { close $socketID } closeError
    if { [info exists getsError] } { LogMessage "Error from $socketID: $getsError" }
    InfoMessage "Socket $socketID closed"
    if { [info exists agentSensorNameArray($socketID)] } {
      CleanUpDisconnectedAgent $socketID
    }
  } else {
    InfoMessage "Sensor Data Rcvd: $data"
    if { [catch {lindex $data 0} sensorCmd] } {
        LogMessage "Ignoring bad command received from $socketID: $data"
        return
    }

    # Make sure agent has registered
    if { $sensorCmd != "RegisterAgent" && $sensorCmd != "VersionInfo" } {

        if { [lsearch -exact $validSensorSockets $socketID] < 0 } {

            LogMessage "Ignoring cmd from unregistered agent: $data"
            return

        }

    }

    switch -exact -- $sensorCmd {
      LastPcapTime       { set cmd [list UpdateLastPcapTime $socketID [lindex $data 1]] }
      RegisterAgent      { set cmd [list RegisterAgent $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3]] }
      GenericEvent       { set cmd [list GenericEvent $socketID [lrange $data 1 end]] }
      PadsAsset          { set cmd [list ProcessPadsAsset [lindex $data 1]] }
      SancpFile          { set cmd [list RcvSancpFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3]] }
      AgentInit          { set cmd [list AgentInit $socketID [lindex $data 1] [lindex $data 2]] }
      BarnyardInit       { set cmd [list BarnyardInit $socketID [lindex $data 1] [lindex $data 2]] }
      AgentLastCidReq    { set cmd [list AgentLastCidReq $socketID [lindex $data 1] [lindex $data 2]] }
      BYEventRcvd        { set cmd "BYEventRcvd $socketID [lrange $data 1 end]" }
      DiskReport         { set cmd [list DiskReport $socketID [lindex $data 1] [lindex $data 2]] }
      PING               { set cmd [list SendSensorAgent $socketID "PONG"] }
      PONG               { set cmd [list SensorAgentPongRcvd $socketID] }
      XscriptDebugMsg    { set cmd [list XscriptDebugMsg [lindex $data 1] [lindex $data 2]] }
      RawDataFile        { set cmd [list RawDataFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3]] }
      SystemMessage      { set cmd [list SystemMsgRcvd $socketID [lindex $data 1]] }
      SnortStats         { set cmd [list SnortStatsRcvd $socketID [lindex $data 1]] }
      BarnyardConnect    { set cmd [list BarnyardConnect $socketID [lindex $data 1]] }
      BarnyardDisConnect { set cmd [list BarnyardDisConnect $socketID [lindex $data 1]] }
      PadsSensorIDReq    { set cmd [list GetPadsID $socketID [lindex $data 1]] }
      VersionInfo        { set cmd [list AgentVersionCheck $socketID [lindex $data 1]] }
      default            { if {$sensorCmd != ""} { LogMessage "Sensor Cmd Unknown ($socketID): $sensorCmd" } }
    }

    # Catch poorly formatted cmds
    if { $sensorCmd != "" } { 
      if { [catch {eval $cmd} tmpError] } {
          LogMessage "Error: Improper sensor cmd received: $data: $tmpError"
      }
    }

  }
}

proc RcvBinCopy { socketID outFile bytes {callback {}} } {

    # Turn off the fileevent handler
    fileevent $socketID readable {}

    # Open the output file for writing
    set outFileID [open $outFile w]

    # Binary transfer
    fconfigure $outFileID -translation binary -encoding binary
    fconfigure $socketID -translation binary -encoding binary

    # Copy in the background
    fcopy $socketID $outFileID -size $bytes -command [list BinCopyFinished $socketID $outFileID $outFile $callback]

}

proc BinCopyFinished { socketID outFileID outFile callback bytes {error {}} } {

    global validSensorSockets

    # Remove the agent socket from the valid (registered) list.
    if [info exists validSensorSockets] {
        set validSensorSockets [ldelete $validSensorSockets $socketID]
    }

    catch {close $outFileID}
    catch {close $socketID}

    if { $error != "" } { LogMessage "Error during background copy: $error" }


    # Callback is what we do after the copy is finished.
    if { $callback != ""} { eval $callback }

}

proc RcvSancpFile { socketID sensorID fileName bytes } {

    global TMP_LOAD_DIR agentStatusList

    set sancpFile $TMP_LOAD_DIR/$fileName
    set callback [list ProcessSancpUpload $sancpFile socketID]
    RcvBinCopy $socketID $sancpFile $bytes
    if [info exists agentStatusList($sensorID)] {
        set agentStatusList($sensorID) [lreplace $agentStatusList($sensorID) 3 3 [GetCurrentTimeStamp]]
    }

}

# Not used right now
proc ProccessSancpUpload { fileName socketID } {

    global agentSocketInfo agentStatusList

    catch {close $socketID}

    # Update last load time
    #set sid [lindex $agentSocketInfo($socketID) 0]
    #if [info exists agentStatusList($sid)] {
    #    set agentStatusList($sid) [lreplace $agentStatusList($sid) 3 3 [GetCurrentTimeStamp]]
    #}

}

proc DiskReport { socketID fileSystem percentage } {

    global agentSensorNameArray

    if [info exists agentSensorNameArray($socketID)] { 
        SendSystemInfoMsg $agentSensorNameArray($socketID) "$fileSystem $percentage"
    }

}

proc SystemMsgRcvd { socketID msg } {

    global agentSensorNameArray

    if [info exists agentSensorNameArray($socketID)] { 
        SendSystemInfoMsg $agentSensorNameArray($socketID) $msg
    }

}
