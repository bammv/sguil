# $Id: SguildQueryd.tcl,v 1.2 2004/10/18 15:28:20 shalligan Exp $ #

proc ForkQueryd {} {
  global mainWritePipe mainReadPipe
  # This pipe sends to queryd
  pipe queryReadPipe mainWritePipe
  # THis pipe lets queryd send back.
  pipe mainReadPipe queryWritePipe
  # Fork the child
  if {[set childPid [fork]] == 0 } {
    # We are the child now.
    proc mainCmdRcvd { inPipeID outPipeID } {
      fconfigure $inPipeID -buffering line
      if { [eof $inPipeID] || [catch {gets $inPipeID data}] } {
        exit
      } else {
        set dbCmd [lindex $data 3]
        set clientSocketID [lindex $data 0]
        set clientWinName [lindex $data 1]
        if {[lindex $clientWinName 0] == "REPORT"} {
            set ClientCommand "ReportResponse"
            set clientWinName [lindex $clientWinName 1]
        } else {
            set ClientCommand "InsertQueryResults"
        }
        set query [lindex $data 2]
        InfoMessage "Sending DB Query: $query"
        set dbSocketID [eval $dbCmd]
        if [catch {mysqlsel $dbSocketID "$query" -list} selResults] {
          puts $outPipeID "$clientSocketID InfoMessage $selResults"
        } else {
          set count 0
          foreach row $selResults {
            puts $outPipeID "$clientSocketID $ClientCommand $clientWinName $row"
            incr count
          }
          if { $ClientCommand != "ReportResponse" } {puts $outPipeID "$clientSocketID InfoMessage Query returned $count row(s)."}
        }
        puts $outPipeID "$clientSocketID $ClientCommand $clientWinName done"
        flush $outPipeID
        mysqlclose $dbSocketID
      }
    }
    fileevent $queryReadPipe readable [list mainCmdRcvd $queryReadPipe $queryWritePipe]
    LogMessage "Queryd Forked"
  }
  return $childPid
}

