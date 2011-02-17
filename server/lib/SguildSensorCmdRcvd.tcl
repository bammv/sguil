# $Id: SguildSensorCmdRcvd.tcl,v 1.28 2011/02/17 03:13:52 bamm Exp $ #

proc SensorCmdRcvd { socketID } {
  global agentSensorNameArray validSensorSockets
  if { [eof $socketID] || [catch {gets $socketID data}] } {
    # Socket closed
    catch { close $socketID } closeError
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
      LastPcapTime       { UpdateLastPcapTime $socketID [lindex $data 1] }
      RegisterAgent      { RegisterAgent $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      GenericEvent       { GenericEvent $socketID [lrange $data 1 end] }
      PadsAsset          { ProcessPadsAsset [lindex $data 1] }
      SancpFile          { RcvSancpFile $socketID [lindex $data 1] [lindex $data 2] }
      AgentInit          { AgentInit $socketID [lindex $data 1] [lindex $data 2] }
      BarnyardInit       { BarnyardInit $socketID [lindex $data 1] [lindex $data 2] }
      AgentLastCidReq    { AgentLastCidReq $socketID [lindex $data 1] [lindex $data 2] }
      BYEventRcvd        { eval BYEventRcvd $socketID [lrange $data 1 end] }
      DiskReport         { $sensorCmd $socketID [lindex $data 1] [lindex $data 2] }
      PING               { SendSensorAgent $socketID "PONG" }
      PONG               { SensorAgentPongRcvd $socketID }
      XscriptDebugMsg    { $sensorCmd [lindex $data 1] [lindex $data 2] }
      RawDataFile        { $sensorCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      SystemMessage      { SystemMsgRcvd $socketID [lindex $data 1] }
      SnortStats         { SnortStatsRcvd $socketID [lindex $data 1] }
      BarnyardConnect    { BarnyardConnect $socketID [lindex $data 1] }
      BarnyardDisConnect { BarnyardDisConnect $socketID [lindex $data 1] }
      PadsSensorIDReq    { GetPadsID $socketID [lindex $data 1] }
      VersionInfo        { AgentVersionCheck $socketID [lindex $data 1] }
      default            { if {$sensorCmd != ""} { LogMessage "Sensor Cmd Unknown ($socketID): $sensorCmd" } }
    }
  }
}

proc RcvBinCopy { socketID outFile bytes {callback {}} } {

    set outFileID [open $outFile w]
    fconfigure $outFileID -translation binary
    fconfigure $socketID -translation binary

    fcopy $socketID $outFileID -command [list BinCopyFinished $socketID $outFileID $outFile $callback]

}

proc BinCopyFinished { socketID outFileID outFile {callback {}} {error {}} } {

    catch {close $outFileID}
    CleanUpDisconnectedAgent $socketID
    if { $callback != ""} { eval $callback }

}

proc RcvSancpFile { socketID fileName bytes } {

    global TMP_LOAD_DIR 

    set sancpFile $TMP_LOAD_DIR/$fileName
    set callback [list ProcessSancpUpload $sancpFile socketID]
    RcvBinCopy $socketID $sancpFile $bytes

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
