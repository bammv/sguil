# $Id: SguildLoaderd.tcl,v 1.1 2004/10/05 15:23:20 bamm Exp $ #

proc ForkLoader {} {
  global DEBUG loaderWritePipe
  # First create some pipes to communicate thru
  pipe loaderReadPipe loaderWritePipe
  # Fork the child
  if {[set childPid [fork]] == 0 } {
    # We are the child now.
    proc ParentCmdRcvd { pipeID } {
      global DEBUG
      fconfigure $pipeID -buffering line
      if { [eof $pipeID] || [catch {gets $pipeID data}] } {
        exit
      } else {
        set fileName [lindex $data 0]
        set cmd [lindex $data 1]
        if [catch {eval exec $cmd} loadError] {
          puts "Unable to load PS data into DB."
          puts $loadError
        } else {
          file delete $fileName
          if {$DEBUG} {puts "$cmd"}
        }
      }
    }
    fileevent $loaderReadPipe readable [list ParentCmdRcvd $loaderReadPipe]
    if {$DEBUG} { puts "Loader Forked" }
  }
  return $childPid
}
