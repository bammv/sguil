# $Id: SguildLoaderd.tcl,v 1.3 2004/11/04 19:48:03 shalligan Exp $ #

proc ForkLoader {} {
  global loaderWritePipe
  # First create some pipes to communicate thru
  pipe loaderReadPipe loaderWritePipe
  # Fork the child
  if {[set childPid [fork]] == 0 } {
    # We are the child now.
    proc ParentCmdRcvd { pipeID } {
      fconfigure $pipeID -buffering line
      if { [eof $pipeID] || [catch {gets $pipeID data}] } {
        exit
      } else {
        set fileName [lindex $data 0]
        set cmd [lindex $data 1]
        if [catch {eval exec $cmd} loadError] {
          LogMessage "Unable to load data into DB. $loadError"
        } else {
          file delete $fileName
          InfoMessage "$cmd"
        }
      }
    }
    fileevent $loaderReadPipe readable [list ParentCmdRcvd $loaderReadPipe]
    LogMessage "Loader Forked"
  }
  return $childPid
}
