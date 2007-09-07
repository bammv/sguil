# $Id: SguildSensorCmdRcvd.tcl,v 1.26 2007/09/07 15:12:49 bamm Exp $ #

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
      SsnFile            { RcvSsnFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
      SancpFile          { RcvSancpFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
      PSFile             { RcvPortscanFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
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

proc RcvBinCopy { socketID outFile bytes } {

    set outFileID [open $outFile w]
    fconfigure $outFileID -translation binary
    fconfigure $socketID -translation binary
    fcopy $socketID $outFileID -size $bytes
    close $outFileID
    fconfigure $socketID -encoding utf-8 -translation {auto crlf}

}

proc RcvSsnFile { socketID sensorName fileName date bytes } {

    global TMPDATADIR sguildWritePipe

    set ssnFile $TMPDATADIR/$fileName
    RcvBinCopy $socketID $ssnFile $bytes
    
    # The loader child proc does the LOAD for us.
    puts $sguildWritePipe [list LoadSsnFile $sensorName $ssnFile $date]
    flush $sguildWritePipe

}

proc RcvSancpFile { socketID sensorName fileName date bytes } {

    global TMPDATADIR TMP_LOAD_DIR sguildWritePipe agentStatusList
    global agentSocketInfo

    set sancpFile $TMP_LOAD_DIR/$fileName
    RcvBinCopy $socketID $sancpFile $bytes

    SendSensorAgent $socketID [list ConfirmSancpFile $fileName]
    # Update last load time
    set sid [lindex $agentSocketInfo($socketID) 0]
    if [info exists agentStatusList($sid)] {
        set agentStatusList($sid) [lreplace $agentStatusList($sid) 3 3 [GetCurrentTimeStamp]]
    }

 
}

proc RcvPortscanFile { socketID sensorName fileName bytes } {

    global TMPDATADIR TMP_LOAD_DIR sguildWritePipe

    InfoMessage "Receiving portscan file $fileName."
    set PS_OUTFILE $TMP_LOAD_DIR/${sensorName}.${fileName}
    # Copy file from sensor_agent
    RcvBinCopy $socketID $PS_OUTFILE $bytes
    ConfirmPortscanFile $sensorName $fileName

    # The loader child proc does the LOAD for us.
    #puts $sguildWritePipe [list LoadPSFile $sensorName $PS_OUTFILE]
    #flush $sguildWritePipe

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
