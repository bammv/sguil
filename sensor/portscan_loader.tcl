#!/usr/bin/tcl

set SERVER_HOST localhost
set SERVER_PORT 7736
set PORTSCAN_DIR /snort_data/portscans
# 10 secs default
set DELAY_IN_MSECS 10000
# 1=on 0=off
set DEBUG 1

proc FinishedCopy { fileID socketID bytes {error {}} } {
  global DEBUG
  close $fileID
  close $socketID
  if {$DEBUG} {puts "Bytes copied: $bytes"}
}
proc CopyDataToServer { fileName } {
  global SERVER_HOST SERVER_PORT DEBUG

  if [catch {set socketID [socket $SERVER_HOST $SERVER_PORT]}] {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"
  } else {
    if {$DEBUG} {puts "Copying $fileName to $SERVER_HOST."}
    fconfigure $socketID -translation binary
    puts $socketID "PSFile [file tail $fileName]"
    set fileID [open $fileName r]
    fconfigure $fileID -translation binary
    if [catch {fcopy $fileID $socketID -command [list FinishedCopy $fileID $socketID]} fcopyError] {
      puts "Error: $fcopyError"
    }
    file delete $fileName
  }
}
proc CheckForPortscanFiles {} {
  global PORTSCAN_DIR DELAY_IN_MSECS DEBUG
  if {$DEBUG} {puts "Checking for PS files in $PORTSCAN_DIR."}
  foreach fileName [glob -nocomplain $PORTSCAN_DIR/portscan_log.*] {
    puts $fileName
    CopyDataToServer $fileName
  }
  after $DELAY_IN_MSECS CheckForPortscanFiles
}

CheckForPortscanFiles
vwait FOREVER
