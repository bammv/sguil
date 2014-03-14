#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: pads_agent.tcl,v 1.13 2011/02/17 02:55:48 bamm Exp $ #

# Copyright (C) 2002-2013 Robert (Bamm) Visscher <bamm@sguil.net>
#
# This program is distributed under the terms of version 3 of the
# Gnu Public License.  See LICENSE for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

#
# Config options moved to pads_agent.conf.
#

# Don't touch these
set VERSION "SGUIL-0.9.0"
set CONNECTED 0

proc bgerror { errorMsg } {
                                                                                                                           
    global errorInfo sguildSocketID

    # Catch SSL errors, close the channel, and reconnect.
    # else write the error and exit.
    if { [regexp {^SSL channel "(.*)":} $errorMsg match socketID] } {

        catch { close $sguildSocketID } tmpError
        ConnectToSguilServer

    } else {

        puts "Error: $errorMsg"
        if { [info exists errorInfo] } {
            puts $errorInfo
        }
        exit

    }

}

proc InitPads {} {

    global DEBUG PADS_FIFO HOSTNAME

    if { ![info exists PADS_FIFO] } { 
        puts "Error: No path to PADS FIFO specified"
        exit
    }
    if { ![file readable $PADS_FIFO] } {
        puts "Error: Unable to read $PADS_FIFO"
        exit
    }
    
    if [catch {open "| cat $PADS_FIFO" r} fifoID] {
        puts "Error opening $PADS_FIFO for reading: $fifoID"
        exit
    }

    # Tcl will go crazy processing eof if the writing
    # fifo goes away, so we open the file for writing
    # but never write to it.
    if [catch {open $PADS_FIFO w} doNotFlushMeID] {
        puts "Error opening $PADS_FIFO for writing: $doNotFlushMeID"
        exit
    }
    
    if { ![file writable $PADS_FIFO] } {
        puts "Error: Unable to write to $PADS_FIFO"
        exit
    }

    #SendToSguild [list PadsSensorIDReq $HOSTNAME]

    fileevent $fifoID readable [list GetFifoData $fifoID]

}

# Data from pads looks like
# * action_id            action
# * 01                   TCP / ICMP Asset Discovered
# * 02                   ARP Asset Discovered
# * 03                   TCP / ICMP Statistic Information
#
# * Sguil patch adds ntohl ip addrs in output as well as client ips, ports, and hex payload
# * 01,10.10.10.83,168430163,10.10.10.82,168430162,22,6,ssh,OpenSSH 3.8.1 (Protocol 2.0),1100846817,0101080A006C94FA3A...
# * 02,10.10.10.81,168430161,3Com 3CRWE73796B,00:50:da:5a:2d:ae,1100846817
# * 03,10.10.10.83,168430163,22,6,1100847309
proc GetFifoData { fifoID } {

    global dataList DEBUG

    if { [eof $fifoID] || [catch {gets $fifoID data} tmpError] } {
    
        if { [info exists tmpError] } { 
            puts "Error with FIFO: $tmpError"
        } else { 
            puts "Error with FIFO: Caught EOF"
        }
        exit

    } else {
            
         # PADS writes out a field per line ended with a "." on its own.
        if { $data != "." } {
    
            if { $DEBUG } { puts "New line from FIFO: $data" }
            lappend dataList $data

        } else { 

            if { $DEBUG } { puts "ProcessData: $dataList" }
            ProcessPadsData $dataList
            set dataList ""

        }

    }

}

proc ProcessPadsData { dataList } {

    global CONNECTED HOSTNAME SENSOR_ID

    # Grab asset discoveries for now
    if { [lindex $dataList 0] == "01" } {

        if { $CONNECTED && [info exists SENSOR_ID] } {

            SendToSguild [list PadsAsset [linsert $dataList 0 $HOSTNAME $SENSOR_ID]]

        } else {

            # Try to send later
            after 5000 [list ProcessPadsData $dataList]

        }

    }

}

proc SendToSguild { data } {

    global sguildSocketID CONNECTED DEBUG

    if {!$CONNECTED} {

         if {$DEBUG} { puts "Not connected to sguild. Unable to process this request." }
         return 0

    } else {

        if {$DEBUG} {puts "Sending sguild ($sguildSocketID) $data"}
        if [catch { puts $sguildSocketID $data } tmpError ] { puts "ERROR: $tmpError : $data" }
        catch { flush $sguildSocketID }
        return 1

    }

}

proc CleanMsg { msg } {

    regsub -all {\n} $msg {} tmpMsg
    return $tmpMsg

}

proc PingServer {} {

    global CONNECTED PING_DELAY DEBUG
    if {$CONNECTED} { SendToSguild "PING" }
    after $PING_DELAY PingServer

}

# Initialize connection to sguild
proc ConnectToSguilServer {} {

    global sguildSocketID HOSTNAME CONNECTED 
    global SERVER_HOST SERVER_PORT DEBUG BYCONNECT VERSION

    # Connect
    if {[catch {set sguildSocketID [socket $SERVER_HOST $SERVER_PORT]}] > 0} {

        # Connection failed #

        set CONNECTED 0
        if {$DEBUG} {puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT."}
        if {$DEBUG} {puts "Trying again in 15 seconds"}
        after 15000 ConnectToSguilServer

    } else {

        # Connection Successful #

        fconfigure $sguildSocketID -buffering line

        # Version checks
        set tmpVERSION "$VERSION OPENSSL ENABLED"

        if [catch {gets $sguildSocketID} serverVersion] {
            puts "ERROR: $serverVersion"
            catch {close $sguildSocketID}
            exit
         }

        if { $serverVersion == "Connection Refused." } {

            puts $serverVersion
            catch {close $sguildSocketID}
            exit

        } elseif { $serverVersion != $tmpVERSION } {

            catch {close $sguildSocketID}
            puts "Mismatched versions.\nSERVER: ($serverVersion)\nAGENT: ($tmpVERSION)"
            after 15000 ConnectToSguilServer
            return

        }

        if [catch {puts $sguildSocketID [list VersionInfo $tmpVERSION]} tmpError] {
            catch {close $sguildSocketID}
            puts "Unable to send version string: $tmpError"
        }

        catch { flush $sguildSocketID }
        tls::import $sguildSocketID -ssl2 false -ssl3 false -tls1 true

        fileevent $sguildSocketID readable [list SguildCmdRcvd $sguildSocketID]
        set CONNECTED 1
        if {$DEBUG} {puts "Connected to $SERVER_HOST"}
        InitPadsAgent

    }

}

proc InitPadsAgent {} {

    global CONNECTED DEBUG HOSTNAME NET_GROUP

    if {!$CONNECTED} {

       if {$DEBUG} { puts "Not connected to sguild. Sleeping 15 secs." }
       after 15000 InitPadsAgent


    } else {

        SendToSguild [list RegisterAgent pads $HOSTNAME $NET_GROUP]

    }

}

# May need to add more to this later
proc AgentInfo { sensorName type netName sensorID } {

    global SENSOR_ID

    set SENSOR_ID $sensorID

}


proc SguildCmdRcvd { socketID } {

    global DEBUG SANCPFILEWAIT CONNECTED

    if { [eof $socketID] || [catch {gets $socketID data}] } {

        # Socket closed
        close $socketID
        set CONNECTED 0

        if {$DEBUG} { puts "Socket $socketID closed" }
        if {$DEBUG} { puts "Attempting to reconnect." }

        ConnectToSguilServer

    } else {
        if {$DEBUG} { puts "Sensor Data Rcvd: $data" }
        update

        set sguildCmd [lindex $data 0]

        switch -exact -- $sguildCmd {

            PONG                  { if {$DEBUG} {puts "PONG received"} }
            PING                  { SendToSguild "PONG" }
            AgentInfo             { AgentInfo [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
            PadsID                { SetPadsID [lindex $data 1] }
            default               { if {$DEBUG} {puts "Sguil Cmd Unkown: $sguildCmd"} }

        }

    }

}

proc DisplayUsage { cmdName } {
  puts "Usage: $cmdName \[-D\] \[-c\] \[-o\] <filename>"
  puts "  -c <filename>: PATH to config (pads_agent.conf) file."
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

proc GetCurrentTimeStamp {} {
  set timestamp [clock format [clock seconds] -gmt true -f "%Y-%m-%d %T"]
  return $timestamp
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
        -O { set state sslpath }
        default { DisplayUsage $argv0 }
      }
    }
    conf    { set CONF_FILE $arg; set state flag }
    sslpath { set TLS_PATH $arg; set state flag }
    default { DisplayUsage $argv0 }
  }
}
# Parse the config file here
# Default location is /etc/pads_agent.conf or pwd
if { ![info exists CONF_FILE] } {
  # No conf file specified check the defaults
  if { [file exists /etc/pads_agent.conf] } {
    set CONF_FILE /etc/pads_agent.conf
  } elseif { [file exists ./pads_agent.conf] } {
    set CONF_FILE ./pads_agent.conf
  } else {
    puts "Couldn't determine where the sensor_agent.tcl config file is"
    puts "Looked for /etc/pads_agent.conf and ./pads_agent.conf."
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

# OpenSSL is required
if { [info exists TLS_PATH] } {

    if [catch {load $TLS_PATH} tlsError] {

        puts "ERROR: Unable to load tls libs ($TLS_PATH): $tlsError"
        DisplayUsage $argv0

    }

}
if { [catch {package require tls} tmpError] }  {

    puts "ERROR: Unable to load tls package: $tmpError"
    DisplayUsage $argv0

}

ConnectToSguilServer
InitPads
#if { [info exists PADS] && $PADS } { InitPads } else { set PADS 0 }
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
