#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: sensor_agent.tcl,v 1.17 2004/06/11 15:19:59 bamm Exp $ #

# Copyright (C) 2002-2004 Robert (Bamm) Visscher <bamm@satx.rr.com>
#
# This program is distributed under the terms of version 1.0 of the
# Q Public License.  See LICENSE.QPL for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

#
# Config options moved to sensor_agent.tcl.
#

# Don't touch these
set CONNECTED 0
set BUSY 0

proc SendToSguild { data } {
  global sguildSocketID CONNECTED DEBUG
  if {!$CONNECTED} {
     if {$DEBUG} { puts "Not connected to sguild. Unable to process this request." }
     after 10000 SentToSguild Data
  } else {
    catch { puts $sguildSocketID $data } 
    catch { flush $sguildSocketID }
  }
}

proc FinishedCopy { fileID socketID bytes {error {}} } {
  global DEBUG BUSY
  close $fileID
  close $socketID
  if {$DEBUG} {puts "Bytes copied: $bytes"}
  set BUSY 0
}
proc SendPSDataToSvr { fileName } {
  global SERVER_HOST SERVER_PORT DEBUG
  if [catch {socket $SERVER_HOST $SERVER_PORT} socketID] {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"
    puts "ERROR: $socketID"
    catch {close $socketID} closeError
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
  fconfigure $fileID -translation binary -buffering none
  if [catch {fcopy $fileID $socketID -command [list FinishedCopy $fileID $socketID]} fcopyError] {
    puts "Error: $fcopyError"
    return
  }
  set BUSY 1
  vwait BUSY
  file delete $fileName
}

proc SendSsnDataToSvr { type fileName } {
  global SERVER_HOST SERVER_PORT DEBUG HOSTNAME
  if [catch {socket $SERVER_HOST $SERVER_PORT} socketID ] {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"
    puts "ERROR: $socketID"
    catch {close $socketID} closeError
  } else {
    fconfigure $socketID -translation binary -buffering none
    puts $socketID "SsnFile $type [file tail $fileName] $HOSTNAME"
    CopyDataToServer $fileName $socketID
  }
}
proc CheckForPortscanFiles {} {
  global PORTSCAN_DIR PS_CHECK_DELAY_IN_MSECS DEBUG CONNECTED
  if {$CONNECTED} {
    if {$DEBUG} {puts "Checking for PS files in $PORTSCAN_DIR."}
    foreach fileName [glob -nocomplain $PORTSCAN_DIR/portscan_log.*] {
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
  global SSN_DIR S4_KEEP_STATS SANCP SANCP_DIR SSN_CHECK_DELAY_IN_MSECS DEBUG CONNECTED
  if {$CONNECTED} {
    if { $S4_KEEP_STATS } {
      if {$DEBUG} {puts "Checking for Session files in $SSN_DIR."}
      foreach fileName [glob -nocomplain $SSN_DIR/ssn_log.*] {
        if { [file size $fileName] > 0 } {
          SendSsnDataToSvr sessions $fileName
        } else { 
          file delete $fileName
        }
      }
    }
    if { $SANCP } {
      if {$DEBUG} {puts "Checking for sancp stats files in $SANCP_DIR."}
      foreach fileName [glob -nocomplain $SANCP_DIR/stats.*.*] {
        if { [file size $fileName] > 0 } {
          SendSsnDataToSvr sancp $fileName
        } else {
          file delete $fileName
        }
      }
    }
  }
  after $SSN_CHECK_DELAY_IN_MSECS CheckForSsnFiles
}
proc CheckDiskSpace {} {
  global DEBUG WATCH_DIR DISK_CHECK_DELAY_IN_MSECS CONNECTED
  if {$CONNECTED} {
    set output [exec df -h $WATCH_DIR]
    set diskUse [lindex [lindex [split $output \n] 1] 4]
    puts "DiskReport $WATCH_DIR $diskUse"
    SendToSguild "DiskReport $WATCH_DIR $diskUse"
    after $DISK_CHECK_DELAY_IN_MSECS CheckDiskSpace
  }
}
proc PingServer {} {
  global CONNECTED PING_DELAY DEBUG
  if {$CONNECTED} { 
    if {$DEBUG} {puts "Sending PING"}
    SendToSguild "PING"
  }
  after $PING_DELAY PingServer
}
# Received a request for rawdata
proc RawDataRequest { socketID TRANS_ID sensor timestamp srcIP dstIP srcPort dstPort proto rawDataFileName type } {
  global SERVER_HOST SERVER_PORT DEBUG HOSTNAME
  # Create the data file.
  set tmpRawDataFile [CreateRawDataFile $TRANS_ID $timestamp $srcIP $srcPort $dstIP $dstPort $proto $rawDataFileName $type]
  if { $tmpRawDataFile != "error" } {
    # Copy the file up to sguild.
    if [catch {socket $SERVER_HOST $SERVER_PORT} socketID ] {
      puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"
      puts "ERROR: $socketID"
      catch {close $socketID} closeError
      file delete $tmpRawDataFile
    } else {
      fconfigure $socketID -translation binary -buffering none
      puts $socketID [list RawDataFile $rawDataFileName $TRANS_ID]
      CopyDataToServer $tmpRawDataFile $socketID
    }
  } else {
    if {$DEBUG} { puts "Error creating raw data file: $rawDataFileName" }
    if { $type == "xscript" } {
      SendToSguild [list XscriptDebugMsg $TRANS_ID "Error creating raw file on sensor."]
    }
  }
}
proc CreateRawDataFile { TRANS_ID timestamp srcIP srcPort dstIP dstPort proto rawDataFileName type } {
  global RAW_LOG_DIR DEBUG TCPDUMP TMP_DIR
  set date [lindex $timestamp 0]
  if { [file exists $RAW_LOG_DIR/$date] && [file isdirectory $RAW_LOG_DIR/$date] } {
    if {$DEBUG} {puts "Making a list of local log files"}
    if {$DEBUG} {puts "Looking in $RAW_LOG_DIR/$date"}
    if { $type == "xscript" } {
      SendToSguild [list XscriptDebugMsg $TRANS_ID "Making a list of local log files."]
      SendToSguild [list XscriptDebugMsg $TRANS_ID "Looking in $RAW_LOG_DIR/$date."]
    }
  } else {
    if { $type == "xscript" } {
      SendtoSguild [list XscriptDebugMsg $TRANS_ID "$RAW_LOG_DIR/$date does not exist. Make sure log_packets.sh is configured correctly."]
    }
    if {$DEBUG} {puts "No matching log files."}
    return error
  }
  cd $RAW_LOG_DIR/$date
  if {$DEBUG} {puts $RAW_LOG_DIR/$date}
  if { $type == "xscript" } {
    SendToSguild [list XscriptDebugMsg $TRANS_ID "Making a list of local log files in $RAW_LOG_DIR/$date."]
  }
  foreach logFile [glob -nocomplain snort.log.*] {
    lappend logFileTimes [lindex [split $logFile .] 2]
  }
  if { ! [info exists logFileTimes] } {
    if {$DEBUG} {puts "No matching log files."}
    if { $type == "xscript" } {
      SendToSguild [list XscriptDebugMsg $TRANS_ID "No matching log files."]
    }
    return error
  }
  set sLogFileTimes [lsort -decreasing $logFileTimes]
  if {$DEBUG} {puts $sLogFileTimes}
  if { $type == "xscript" } {
    SendToSguild [list XscriptDebugMsg $TRANS_ID "Available log files:"]
    SendToSguild [list XscriptDebugMsg $TRANS_ID "$sLogFileTimes"]
  }
  set eventTime [clock scan $timestamp -gmt true]
  # The first file we find with a time >= to ours should have our packets.
  foreach logFileTime $sLogFileTimes {
    if { $eventTime >= $logFileTime } {
      set logFileName "snort.log.$logFileTime"
      break
    }
  }
  if { ![info exists logFileName] } {
    return error
  }
  if {$DEBUG} { puts "Creating unique data file." }
  if { $type == "xscript" } {
    SendToSguild [list XscriptDebugMsg $TRANS_ID "Creating unique data file."]
  }
  if {$proto == "1"} {
    set tcpdumpFilter "host $srcIP and host $dstIP and proto $proto"
  } else {
    set tcpdumpFilter "host $srcIP and host $dstIP and port $srcPort and port $dstPort and proto $proto"
  }
  exec $TCPDUMP -r $RAW_LOG_DIR/$date/$logFileName -w $TMP_DIR/$rawDataFileName $tcpdumpFilter
  return $TMP_DIR/$rawDataFileName
}
proc ConnectToSguilServer {} {
  global sguildSocketID HOSTNAME CONNECTED
  global SERVER_HOST SERVER_PORT DEBUG
  while {[catch {set sguildSocketID [socket $SERVER_HOST $SERVER_PORT]}] > 0} {
    puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT."
    puts "Trying again in 15 seconds"
    after 15000
  }
  fconfigure $sguildSocketID -buffering line
  fileevent $sguildSocketID readable [list SguildCmdRcvd $sguildSocketID]
  set CONNECTED 1
  if {$DEBUG} {puts "Connected to $SERVER_HOST"}
  puts $sguildSocketID "CONNECT $HOSTNAME"
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
      RawDataRequest { eval $sguildCmd $socketID [lrange $data 1 end] }
      default   { puts "Sguil Cmd Unkown: $sguildCmd" }
    }
  }
}
proc DisplayUsage { cmdName } {
  puts "Usage: $cmdName \[-D\] \[-c\] <filename>"
  puts "  -c <filename>: PATH to config (sensor_agent.conf) file."
  puts "  -D Runs sensor_agent in daemon mode."
  exit
}
proc Daemonize {} {
  global PID_FILE DEBUG
  # We need extended tcl to run in the background
  # Load extended tcl
  if [catch {package require Tclx} tclxVersion] {
    puts "ERROR: The tclx extension does NOT appear to be installed on this sysem."
    puts "Extended tcl (tclx) contains the 'fork' function needed to daemonize this"
    puts "process.  Install tclx or background the process manually.  Extended tcl"
    puts "(tclx) is available as a port/package for most linux and BSD systems."
    exit
  }
  set DEBUG 0
  set childPID [fork]
  # Parent exits.
  if { $childPID == 0 } { exit }
  id process group set
  if {[fork]} {exit 0}
  set PID [id process]
  if { ![info exists PID_FILE] } { set PID_FILE "/var/run/sensor_agent.pid" }
  set PID_DIR [file dirname $PID_FILE]
  if { ![file exists $PID_DIR] || ![file isdirectory $PID_DIR] || ![file writable $PID_DIR] } {
    puts "ERROR: Directory $PID_DIR does not exists or is not writable."
    puts "Process ID will not be written to file."
  } else {
    set pidFileID [open $PID_FILE w]
    puts $pidFileID $PID
    close $pidFileID
  }
}
#
# CheckLineFormat - Parses CONF_FILE lines to make sure they are formatted
#                   correctly (set varName value). Returns 1 if good.
#
proc CheckLineFormat { line } {
  set RETURN 1
  # Right now we just check the length and for "set".
  if { [llength $line] != 3 || [lindex $line 0] != "set" } { set RETURN 0 }
  return $RETURN
}

################### MAIN ###########################

# GetOpts
set state flag
foreach arg $argv {
  switch -- $state {
    flag {
      switch -glob -- $arg {
        -- { set state flag }
        -D { set DAEMON_CONF_OVERRIDE 1 }
        -c { set state conf }
        default { DisplayUsage $argv0 }
      }
    }
    conf { set CONF_FILE $arg; set state flag }
    default { DisplayUsage $argv0 }
  }
}
# Parse the config file here
# Default location is /etc/sensor_agent.conf or pwd
if { ![info exists CONF_FILE] } {
  # No conf file specified check the defaults
  if { [file exists /etc/sensor_agent.conf] } {
    set CONF_FILE /etc/sensor_agent.conf
  } elseif { [file exists ./sensor_agent.conf] } {
    set CONF_FILE ./sensor_agent.conf
  } else {
    puts "Couldn't determine where the sensor_agent.tcl config file is"
    puts "Looked for /etc/sensor_agent.conf and ./sensor_agent.conf."
    DisplayUsage $argv0
  }
}
set i 0
if { [info exists CONF_FILE] } {
  # Parse the config file. Currently the only option is to
  # create a variable using 'set varName value'
  set confFileID [open $CONF_FILE r]
  while { [gets $confFileID line] >= 0 } {
    incr i
    if { ![regexp ^# $line] && ![regexp ^$ $line] } {
      if { [CheckLineFormat $line] } {
        if { [catch {eval $line} evalError] } {
          puts "Error at line $i in $CONF_FILE: $line"
          exit
        }
      } else {
        puts "Error at line $i in $CONF_FILE: $line"
        exit
      }
    }
  }
  close $confFileID
} else {
  DisplayUsage $argv0
}

# Command line overrides the conf file.
if {[info exists DAEMON_CONF_OVERRIDE] && $DAEMON_CONF_OVERRIDE} { set DAEMON 1}
if {[info exists DAEMON] && $DAEMON} {Daemonize}

ConnectToSguilServer
CheckForPortscanFiles
CheckForSsnFiles
CheckDiskSpace
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
