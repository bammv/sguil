#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: sensor_agent.tcl,v 1.27 2005/01/28 00:07:39 bamm Exp $ #

# Copyright (C) 2002-2004 Robert (Bamm) Visscher <bamm@satx.rr.com>
#
# This program is distributed under the terms of version 1.0 of the
# Q Public License.  See LICENSE.QPL for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

#
# Config options moved to sensor_agent.conf.
#

# Don't touch these
set CONNECTED 0
set BUSY 0

proc SendToSguild { data } {
  global sguildSocketID CONNECTED DEBUG
  if {!$CONNECTED} {
     if {$DEBUG} { puts "Not connected to sguild. Unable to process this request." }
     return 0
  } else {
    if {$DEBUG} {puts "Sending sguild ($sguildSocketID) $data"}
    catch { puts $sguildSocketID $data } 
    catch { flush $sguildSocketID }
    return 1
  }
}

proc CopyDataToServer { fileName socketID } {
  global DEBUG SERVER_HOST BUSY

  # We no do this any more
  puts "ACK === > CopyDataToServer $fileName $socketID"
  exit 

}

proc SendSsnDataToSvr { type fileName } {
  global SERVER_HOST SERVER_PORT DEBUG HOSTNAME 
  if [catch {socket $SERVER_HOST $SERVER_PORT} socketID ] {
    if {$DEBUG} {puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT"}
    if {$DEBUG} {puts "ERROR: $socketID"}
    catch {close $socketID} closeError
    # Buffers are probably full
    set COPY_WAIT 1
    after 10000 set COPY_WAIT 0
  } else {
    fconfigure $socketID -translation binary -buffering none
    puts $socketID "SsnFile $type [file tail $fileName] $HOSTNAME $lines"
    CopyDataToServer $fileName $socketID
  }
}

proc CheckForPortscanFiles {} {

    global PORTSCAN_DIR PS_CHECK_DELAY_IN_MSECS DEBUG CONNECTED

    if {$CONNECTED} {

        if {$DEBUG} {puts "Checking for PS files in $PORTSCAN_DIR."}

        foreach fileName [glob -nocomplain $PORTSCAN_DIR/portscan_log.*] {

            if { [file size $fileName] > 0 } {
                SendToSguild [list PSFile [file tail $fileName] [file size $fileName]]
                BinCopyToSguild $fileName
                file delete $fileName
            } else {
                file delete $fileName
            }

        }

    }

    after $PS_CHECK_DELAY_IN_MSECS CheckForPortscanFiles

}

proc CheckForSsnFiles {} {

    global SSN_DIR SSN_CHECK_DELAY_IN_MSECS DEBUG CONNECTED
    global SENSOR_ID

    if { !$CONNECTED || ![info exists SENSOR_ID] } {
        # Try again later
        after $SSN_CHECK_DELAY_IN_MSECS CheckForSsnFiles
        return
    }

    if {$DEBUG} {puts "Checking for Session files in $SSN_DIR."}

    foreach fileName [glob -nocomplain $SSN_DIR/ssn_log.*] {

        if { [file size $fileName] > 0 } {

            # Parse the file for rows with different dates.
            # The parse proc returns a list of filenames and dates.
            foreach fdPair [ParseSsnSancpFiles $fileName] {

                set tmpFile [lindex $fdPair 0]
                set tmpDate [lindex $fdPair 1]
                set fileBytes [file size $tmpFile]
                # Tell sguild it has a file coming
                SendToSguild [list SsnFile [file tail $tmpFile] $tmpDate $fileBytes] 
                BinCopyToSguild $tmpFile
                file delete $fileName

            }

        } else { 

            # Delete files with no data
            file delete $fileName

        }
  
    }
    after $SSN_CHECK_DELAY_IN_MSECS CheckForSsnFiles

}
  
proc CheckForSancpFiles {} {

    global DEBUG SANCP_DIR SENSOR_ID CONNECTED SSN_CHECK_DELAY_IN_MSECS

    if { !$CONNECTED || ![info exists SENSOR_ID] } {
        # Try again later
        after $SSN_CHECK_DELAY_IN_MSECS CheckForSancpFiles
        return
    }

    if {$DEBUG} {puts "Checking for sancp stats files in $SANCP_DIR."}

    foreach fileName [glob -nocomplain $SANCP_DIR/stats.*.*] {

        if { [file size $fileName] > 0 } {

            foreach fdPair [ParseSsnSancpFiles $fileName] {
                set tmpFile [lindex $fdPair 0]
                set tmpDate [lindex $fdPair 1]
                set fileBytes [file size $tmpFile]
                # Tell sguild it has a file coming
                SendToSguild [list SancpFile [file tail $tmpFile] $tmpDate $fileBytes] 
                BinCopyToSguild $tmpFile
                file delete $fileName
            }

        } else {

            file delete $fileName

        }

    }
    after $SSN_CHECK_DELAY_IN_MSECS CheckForSancpFiles

}

proc BinCopyToSguild { fileName } {

    global sguildSocketID

    set rFileID [open $fileName r]
    fconfigure $rFileID -translation binary
    fconfigure $sguildSocketID -translation binary
    fcopy $rFileID $sguildSocketID
    fconfigure $sguildSocketID -encoding utf-8 -translation {auto crlf}
    catch {close $rFileID} tmpError

}


#
#  Parses std sancp files. Prepends sensorID and puts each
#  line in its own date file
#
#  Returns a list of filenames and dates:
#  {file1 date1} {file2 date2} {etc etc}
#
proc ParseSsnSancpFiles { fileName } {

    global SENSOR_ID 
    
    set inFileID [open $fileName r]
    while { [ gets $inFileID line] >= 0 } {

        # Strips out the date
        if { ![regexp {^\d+\|(\d{4}-\d{2}-\d{2})\s.*\|.*$} $line foo date] } {
             # Corrupt File
             puts "ERROR"   
        }
        set fDate [clock format [clock scan $date] -gmt true -f "%Y%m%d"]
        # Files can contain data from different start days
        if { ![info exists outFileID($fDate)] } {
            set outFile($fDate) "[file dirname $fileName]/parsed.[file tail $fileName].$fDate"
            set outFileID($fDate) [open $outFile($fDate) w]
        } 
        # Prepend sensorID
        puts $outFileID($fDate) "${SENSOR_ID}|$line"  
        
    }
 
    close $inFileID
    file delete $fileName

    foreach date [array names outFileID] {
        close $outFileID($date) 
        lappend tmpFileNames [list $outFile($date) $date]
    }
    
    return $tmpFileNames

}

proc CheckDiskSpace {} {
  global DEBUG WATCH_DIR DISK_CHECK_DELAY_IN_MSECS CONNECTED
  if {$CONNECTED} {
    set output [exec df -h $WATCH_DIR]
    set diskUse [lindex [lindex [split $output \n] 1] 4]
    SendToSguild "DiskReport $WATCH_DIR $diskUse"
    after $DISK_CHECK_DELAY_IN_MSECS CheckDiskSpace
  }
}
proc PingServer {} {
  global CONNECTED PING_DELAY DEBUG
  if {$CONNECTED} { 
    SendToSguild "PING"
  }
  after $PING_DELAY PingServer
}
# Received a request for rawdata
proc RawDataRequest { socketID TRANS_ID sensor timestamp srcIP dstIP srcPort dstPort proto rawDataFileName type } {

    global SERVER_HOST SERVER_PORT DEBUG HOSTNAME

    # Create the data file.
    set tmpRawDataFile [CreateRawDataFile $TRANS_ID $timestamp\
      $srcIP $srcPort $dstIP $dstPort $proto $rawDataFileName $type]

    if { $tmpRawDataFile != "error" } {

        # Copy the file up to sguild.
        SendToSguild [list RawDataFile $rawDataFileName $TRANS_ID [file size $tmpRawDataFile]]
        BinCopyToSguild $tmpRawDataFile
        file delete $tmpRawDataFile

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
    if { $type == "xscript" } {
      SendToSguild [list XscriptDebugMsg $TRANS_ID "Making a list of local log files."]
      SendToSguild [list XscriptDebugMsg $TRANS_ID "Looking in $RAW_LOG_DIR/$date."]
    }
  } else {
    if { $type == "xscript" } {
      SendToSguild [list XscriptDebugMsg $TRANS_ID "$RAW_LOG_DIR/$date does not exist. Make sure log_packets.sh is configured correctly."]
    }
    if {$DEBUG} {puts "No matching log files."}
    return error
  }
  cd $RAW_LOG_DIR/$date
  if { $type == "xscript" } {
    SendToSguild [list XscriptDebugMsg $TRANS_ID "Making a list of local log files in $RAW_LOG_DIR/$date."]
  }
  foreach logFile [glob -nocomplain snort.log.*] {
    lappend logFileTimes [lindex [split $logFile .] 2]
  }
  if { ! [info exists logFileTimes] } {
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
    if {$DEBUG} {
      puts "ERROR: Unable to find the matching pcap file based on the time."
      puts "       The requested event time is: $eventTime"
      if { $type == "xscript" } {
        SendToSguild [list XscriptDebugMsg $TRANS_ID "ERROR: Unable to find the matching pcap file based on the time."]
        SendToSguild [list XscriptDebugMsg $TRANS_ID "The requested event time is: $eventTime"]
      }
    }
    return error
  }
  if { $type == "xscript" } {
    SendToSguild [list XscriptDebugMsg $TRANS_ID "Creating unique data file."]
  }
  if {$proto == "1"} {
    set tcpdumpFilter "host $srcIP and host $dstIP and proto $proto"
  } else {
    set tcpdumpFilter "host $srcIP and host $dstIP and port $srcPort and port $dstPort and proto $proto"
  }
  catch {exec $TCPDUMP -r $RAW_LOG_DIR/$date/$logFileName -w $TMP_DIR/$rawDataFileName $tcpdumpFilter >& /dev/null} tcpdumpError
  return $TMP_DIR/$rawDataFileName
}
proc ConnectToSguilServer {} {
  global sguildSocketID HOSTNAME CONNECTED
  global SERVER_HOST SERVER_PORT DEBUG
  while {[catch {set sguildSocketID [socket $SERVER_HOST $SERVER_PORT]}] > 0} {
    if {$DEBUG} {puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT."}
    if {$DEBUG} {puts "Trying again in 15 seconds"}
    after 15000
  }
  fconfigure $sguildSocketID -buffering line
  fileevent $sguildSocketID readable [list SguildCmdRcvd $sguildSocketID]
  set CONNECTED 1
  if {$DEBUG} {puts "Connected to $SERVER_HOST"}
  puts $sguildSocketID "CONNECT $HOSTNAME"
  flush $sguildSocketID
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
      PING      { SendToSguild "PONG" }
      RawDataRequest { eval $sguildCmd $socketID [lrange $data 1 end] }
      SensorID  { SetSensorID [lindex $data 1] }
      default   { if {$DEBUG} {puts "Sguil Cmd Unkown: $sguildCmd"} }
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

# May need to add more to this later
proc SetSensorID { sensorID } {

    global SENSOR_ID

    set SENSOR_ID $sensorID

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
if { [info exists S4_KEEP_STATS] && $S4_KEEP_STATS } { CheckForSsnFiles }
if { [info exists SANCP] && $SANCP } { CheckForSancpFiles }
CheckDiskSpace
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
