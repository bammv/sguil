# $Id: SguildSensorCmdRcvd.tcl,v 1.6 2005/01/27 19:25:26 bamm Exp $ #

proc SensorCmdRcvd { socketID } {
  global connectedAgents agentSensorName
  if { [eof $socketID] || [catch {gets $socketID data}] } {
    # Socket closed
    catch { close $socketID } closeError
    InfoMessage "Socket $socketID closed"
    if { [info exists connectedAgents] && [info exists agentSensorName($socketID)] } {
      CleanUpDisconnectedAgent $socketID
    }
  } else {
    InfoMessage "Sensor Data Rcvd: $data"
    # note that ctoken changes the string that it is operating on
    # so instead of re-writing all of the proc to move up one in
    # the index when looking at $data, I wrote $data to $tmpData
    # before using ctoken.  Probably should drop this and fix the
    # procs, but that can happen later
    set tmpData $data
    set sensorCmd [ctoken tmpData " "]
    # set sensorCmd [lindex $data 0]
    switch -exact -- $sensorCmd {
      RTEvent         { EventRcvd $socketID $data }
      SsnFile         { RcvSsnFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      SancpFile       { RcvSancpFile $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      PSFile          { RcvPortscanFile $socketID [lindex $data 1] [lindex $data 2] }
      CONNECT         { SensorAgentConnect $socketID [lindex $data 1] }
      DiskReport      { $sensorCmd $socketID [lindex $data 1] [lindex $data 2] }
      PING            { puts $socketID "PONG"; flush $socketID }
      PONG            { SensorAgentPongRcvd $socketID }
      XscriptDebugMsg { $sensorCmd [lindex $data 1] [lindex $data 2] }
      RawDataFile     { $sensorCmd $socketID [lindex $data 1] [lindex $data 2] [lindex $data 3] }
      default         { LogMessage "Sensor Cmd Unkown ($socketID): $sensorCmd" }
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

proc RcvSsnFile { socketID fileName date bytes } {

    global TMPDATADIR loaderWritePipe

    set ssnFile $TMPDATADIR/$fileName
    RcvBinCopy $socketID $ssnFile $bytes
    
    # The loader child proc does the LOAD for us.
    puts $loaderWritePipe [list LoadSsnFile $ssnFile $date]
    flush $loaderWritePipe

}

proc RcvSancpFile { socketID fileName date bytes } {

    global TMPDATADIR

    set sancpFile $TMPDATADIR/$fileName
    RcvBinCopy $socketID $sancpFile $bytes
    
}

proc RcvPortscanFile { socketID fileName bytes } {

    global TMPDATADIR loaderWritePipe

    InfoMessage "Recieving portscan file $fileName."
    set PS_OUTFILE $TMPDATADIR/$fileName
    # Copy file from sensor_agent
    RcvBinCopy $socketID $PS_OUTFILE $bytes

    # The loader child proc does the LOAD for us.
    puts $loaderWritePipe [list LoadPSFile $PS_OUTFILE]
    flush $loaderWritePipe

}

proc DiskReport { socketID fileSystem percentage } {
  global agentSensorName
  SendSystemInfoMsg $agentSensorName($socketID) "$fileSystem $percentage"
}







