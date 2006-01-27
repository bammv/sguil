# $Id: SguildSensorCmdRcvd.tcl,v 1.18 2006/01/27 19:33:57 bamm Exp $ #

proc SensorCmdRcvd { socketID } {
  global connectedAgents agentSensorNameArray
  if { [eof $socketID] || [catch {gets $socketID data}] } {
    # Socket closed
    catch { close $socketID } closeError
    InfoMessage "Socket $socketID closed"
    if { [info exists connectedAgents] && [info exists agentSensorNameArray($socketID)] } {
      CleanUpDisconnectedAgent $socketID
    }
  } else {
    InfoMessage "Sensor Data Rcvd: $data"
    set sensorCmd [lindex $data 0]
    switch -exact -- $sensorCmd {
      SsnFile            { RcvSsnFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
      SancpFile          { RcvSancpFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
      PSFile             { RcvPortscanFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      AgentInit          { SensorAgentInit $socketID [lindex $data 1] [lindex $data 2] }
      AgentLastCidReq    { AgentLastCidReq $socketID [lindex $data 1] [lindex $data 2] }
      BYEventRcvd        { eval BYEventRcvd $socketID [lrange $data 1 end] }
      DiskReport         { $sensorCmd $socketID [lindex $data 1] [lindex $data 2] }
      PING               { puts $socketID "PONG"; flush $socketID }
      PONG               { SensorAgentPongRcvd $socketID }
      XscriptDebugMsg    { $sensorCmd [lindex $data 1] [lindex $data 2] }
      RawDataFile        { $sensorCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      SystemMessage      { SystemMsgRcvd $socketID [lindex $data 1] }
      BarnyardConnect    { BarnyardConnect $socketID [lindex $data 1] }
      BarnyardDisConnect { BarnyardDisConnect $socketID [lindex $data 1] }
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

    global TMPDATADIR sguildWritePipe

    set sancpFile $TMPDATADIR/$fileName
    RcvBinCopy $socketID $sancpFile $bytes
 
    update
    
    # The loader child proc does the LOAD for us.
    puts $sguildWritePipe [list LoadSancpFile $sensorName $sancpFile $date]
    flush $sguildWritePipe

}

proc RcvPortscanFile { socketID sensorName fileName bytes } {

    global TMPDATADIR sguildWritePipe

    InfoMessage "Receiving portscan file $fileName."
    set PS_OUTFILE $TMPDATADIR/$fileName
    # Copy file from sensor_agent
    RcvBinCopy $socketID $PS_OUTFILE $bytes

    # The loader child proc does the LOAD for us.
    puts $sguildWritePipe [list LoadPSFile $sensorName $PS_OUTFILE]
    flush $sguildWritePipe

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

