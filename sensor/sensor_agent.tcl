#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# Name of sguild server
set SERVER_HOST syn
# Port sguild listens on for sensor connects
set SERVER_PORT 7736
# Local hostname
set HOSTNAME gateway
# Where to look for files created by modded spp_portscan
set PORTSCAN_DIR /snort_data/portscans
# Where to look for ssn files created by modded spp_stream4
set SSN_DIR /snort_data/ssn_logs
# What directory to report size stats (df -h) on.
set WATCH_DIR /snort_data

# Delay in milliseconds for doing different functions.
#
# Portscan files
set PS_CHECK_DELAY_IN_MSECS 10000
# Session files
set SSN_CHECK_DELAY_IN_MSECS 10000
# Disk space
set DISK_CHECK_DELAY_IN_MSECS 1800000
# Keep a heartbeat going w/PING PONG.
# 0 to disable else time in milliseconds.
set PING_DELAY 300000

# 1=on 0=off
set DEBUG 1

#################### End User Config ##########################

# Don't touch these
set CONNECTED 0
set BUSY 0

proc FinishedCopy { fileID socketID bytes {error {}} } {
  global DEBUG BUSY
  close $fileID
  close $socketID
  if {$DEBUG} {puts "Bytes copied: $bytes"}
  set BUSY 0
}
proc SendPSDataToSvr { fileName } {
  global SERVER_HOST SERVER_PORT DEBUG
  if [catch {set socketID [socket $SERVER_HOST $SERVER_PORT]}] {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"
  } else {
    fconfigure $socketID -translation binary
    puts $socketID "PSFile [file tail $fileName]"
    CopyDataToServer $fileName $socketID
  }
}

proc CopyDataToServer { fileName socketID } {
  global DEBUG SERVER_HOST BUSY
  if {$DEBUG} {puts "Copying $fileName to $SERVER_HOST."}
  set fileID [open $fileName r]
  fconfigure $fileID -translation binary
  if [catch {fcopy $fileID $socketID -command [list FinishedCopy $fileID $socketID]} fcopyError] {
    puts "Error: $fcopyError"
    return
  }
  set BUSY 1
  vwait BUSY
  file delete $fileName
}

proc SendSsnDataToSvr { fileName } {
  global SERVER_HOST SERVER_PORT DEBUG HOSTNAME
  if [catch {set socketID [socket $SERVER_HOST $SERVER_PORT]}] {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"
  } else {
    fconfigure $socketID -translation binary
    puts $socketID "SsnFile [file tail $fileName] $HOSTNAME"
    CopyDataToServer $fileName $socketID
  }
}
proc CheckForPortscanFiles {} {
  global PORTSCAN_DIR PS_CHECK_DELAY_IN_MSECS DEBUG CONNECTED
  if {$CONNECTED} {
    if {$DEBUG} {puts "Checking for PS files in $PORTSCAN_DIR."}
    foreach fileName [glob -nocomplain $PORTSCAN_DIR/portscan_log.*] {
      puts $fileName
      if { [file size $fileName] > 0 } {
        SendPSDataToSvr $fileName
      } else {
        file delete $fileName
      }
    }
  }
  after $PS_CHECK_DELAY_IN_MSECS CheckForPortscanFiles
}
proc CheckForSsnFiles {} {
  global SSN_DIR SSN_CHECK_DELAY_IN_MSECS DEBUG CONNECTED
  if {$CONNECTED} {
    if {$DEBUG} {puts "Checking for Session files in $SSN_DIR."}
    foreach fileName [glob -nocomplain $SSN_DIR/ssn_log.*] {
      puts $fileName
      if { [file size $fileName] > 0 } {
        SendSsnDataToSvr $fileName
      } else { 
        file delete $fileName
      }
    }
  }
  after $SSN_CHECK_DELAY_IN_MSECS CheckForSsnFiles
}
proc CheckDiskSpace {} {
  global DEBUG WATCH_DIR socketID DISK_CHECK_DELAY_IN_MSECS CONNECTED
  if {$CONNECTED} {
    set output [exec df -h $WATCH_DIR]
    set diskUse [lindex [lindex [split $output \n] 1] 4]
    puts "DiskReport $WATCH_DIR $diskUse"
    puts $socketID "DiskReport $WATCH_DIR $diskUse"
    after $DISK_CHECK_DELAY_IN_MSECS CheckDiskSpace
  }
}
proc PingServer {} {
  global socketID CONNECTED PING_DELAY DEBUG
  if {$CONNECTED} { 
    if {$DEBUG} {puts "Sending PING"}
    puts $socketID "PING"
  }
  after $PING_DELAY PingServer
}
proc ConnectToSguilServer {} {
  global socketID HOSTNAME CONNECTED
  global SERVER_HOST SERVER_PORT DEBUG
  while {[catch {set socketID [socket $SERVER_HOST $SERVER_PORT]}] > 0} {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT."
    puts "Trying again in 15 seconds"
    after 15000
  }
  fconfigure $socketID -buffering line
  puts $socketID "CONNECT $HOSTNAME"
  fileevent $socketID readable [list SguildCmdRcvd $socketID]
  set CONNECTED 1
  if {$DEBUG} {puts "Connected to $SERVER_HOST"}
}
proc SguildCmdRcvd { socketID } {
  global DEBUG
  if { [eof $socketID] || [catch {gets $socketID data}] } {
    # Socket closed
    close $socketID
    if {$DEBUG} { puts "Socket $socketID closed" }
    if {$DEBUG} { puts "Attempting to reconnect." }
    ConnectToSguilServer
  } else {
    if {$DEBUG} { puts "Sensor Data Rcvd: $data" }
    set sguildCmd [lindex $data 0]
    switch -exact -- $sguildCmd {
      PONG	{ if {$DEBUG} {puts "PONG recieved"} }
      default   { puts "Sguil Cmd Unkown: $sguildCmd" }
    }
  }
}

##### Off we go. ##########
ConnectToSguilServer
CheckForPortscanFiles
CheckForSsnFiles
CheckDiskSpace
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
