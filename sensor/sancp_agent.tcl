#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: sancp_agent.tcl,v 1.7 2008/03/21 16:13:41 bamm Exp $ #

# Copyright (C) 2002-2008 Robert (Bamm) Visscher <bamm@sguil.net>
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
set VERSION "SGUIL-0.7.0-RC1"
set CONNECTED 0
set SANCPFILEWAIT 0

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

proc CheckForSancpFiles {} {

    global DEBUG SANCP_DIR SENSOR_ID CONNECTED SANCP_CHECK_DELAY_IN_MSECS
    global HOSTNAME SANCPFILEWAIT

    # Have to have a sensor ID before we can send a sancp file.
    if { ![info exists SENSOR_ID] || !$CONNECTED } {
        # Try again later
        after $SANCP_CHECK_DELAY_IN_MSECS CheckForSancpFiles
        return
    }

    if {$DEBUG} {puts "Checking for sancp stats files in $SANCP_DIR."}

    foreach fileName [glob -nocomplain $SANCP_DIR/stats.*.*] {


        if { [file exists $fileName] && [file size $fileName] > 0 } {


            foreach fdPair [ParseSsnSancpFiles $fileName] {

                set tmpFile [lindex $fdPair 0]
                set tmpDate [lindex $fdPair 1]
                set fileBytes [file size $tmpFile]
                set SANCPFILEWAIT $tmpFile

                if { $CONNECTED } {

                    # Tell sguild it has a file coming
                    SendToSguild [list SancpFile $HOSTNAME [file tail $tmpFile] $tmpDate $fileBytes] 
                    if { [BinCopyToSguild $tmpFile] } {

                        # Check to see that that file was confirmed after 10 secs
                        after 5000 CheckSancpConfirmation $tmpFile
                        vwait SANCPFILEWAIT
                   
                    } else {

                        if { $DEBUG } { puts "Error copying $tmpFile to sguild." }

                    }

                } else {

                    # Lost our cnx
                    break

                }

            }

        } else {

            file delete $fileName

        }

        # break if we lost our cnx to sguild
        if { !$CONNECTED } { break }

    }

    after $SANCP_CHECK_DELAY_IN_MSECS CheckForSancpFiles

}

proc CheckSancpConfirmation { tmpFile } {

     global SANCPFILEWAIT DEBUG

     if { $SANCPFILEWAIT == $tmpFile } {

         # Something got held up. Release the vwait
         if { $DEBUG } { puts "No confirmation on $tmpFile" }
         set SANCPFILEWAIT 0
         
     }

}

proc ConfirmSancpFile { fileName } {

    global DEBUG SANCP_DIR SANCPFILEWAIT

    if { [file exists $SANCP_DIR/$fileName] } {

        if [catch [file delete $SANCP_DIR/$fileName] tmpError] {

            puts "ERROR: Deleting  $SANCP_DIR/$fileName: $tmpError"

        }

    }

    set SANCPFILEWAIT 0

}

proc BinCopyToSguild { fileName } {

    global sguildSocketID

    if [ catch {open $fileName r} rFileID ] {

        # Error opening file
      
        puts "ERROR: Opening $fileName: $rFileID"
        catch {close $rFileID} tmpError
        return 0

    }

    fconfigure $rFileID -translation binary
    fconfigure $sguildSocketID -translation binary

    set RETURN 1
    if [ catch {fcopy $rFileID $sguildSocketID} tmpError ] {

        # fcopy failed.
        set RETURN 0
        set CONNECTED 0
        catch { close $sguildSocketID } tmpError
        ConnectToSguilServer

    } else {

        fconfigure $sguildSocketID -encoding utf-8 -translation {auto crlf}

    }

    catch {close $rFileID} tmpError

    return $RETURN

}


#
#  Parses std sancp files. Prepends sensorID and puts each
#  line in its own date file
#
#  Returns a list of filenames and dates:
#  {file1 date1} {file2 date2} {etc etc}
#
proc ParseSsnSancpFiles { fileName } {

    global SENSOR_ID HOSTNAME DEBUG
    
    set inFileID [open $fileName r]
    while { [ gets $inFileID line] >= 0 } {

        # Strips out the date
        if { ![regexp {^\d+\|(\d{4}-\d{2}-\d{2})\s.*\|.*$} $line foo date] } {

            # Corrupt line in file
            if { $DEBUG } {
                 puts "ERROR: Bad line in file: $fileName"   
                 puts "$line"
            }

        } else {

            set fDate [clock format [clock scan $date] -f "%Y%m%d"]

            # Files can contain data from different start days
            if { ![info exists outFileID($fDate)] } {
                set outFile($fDate) "[file dirname $fileName]/parsed.$HOSTNAME.[file tail $fileName].$fDate"
                set outFileID($fDate) [open $outFile($fDate) w]
            } 

            # Prepend sensorID
            puts $outFileID($fDate) "${SENSOR_ID}|$line"  

        }

    }

    close $inFileID
    file delete $fileName

    foreach date [array names outFileID] {
        close $outFileID($date) 
        lappend tmpFileNames [list $outFile($date) $date]
    }
    
    return $tmpFileNames

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
        tls::import $sguildSocketID

        fileevent $sguildSocketID readable [list SguildCmdRcvd $sguildSocketID]
        set CONNECTED 1
        if {$DEBUG} {puts "Connected to $SERVER_HOST"}
        InitSancpAgent

    }

}

proc InitSancpAgent {} {

    global CONNECTED DEBUG HOSTNAME NET_GROUP

    if {!$CONNECTED} {

       if {$DEBUG} { puts "Not connected to sguild. Sleeping 15 secs." }
       after 15000 InitSancpAgent

    } else {

        SendToSguild [list RegisterAgent sancp $HOSTNAME $NET_GROUP]

    }

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
            ConfirmSancpFile      { ConfirmSancpFile [lindex $data 1] }
            AgentInfo             { AgentInfo [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
            default               { if {$DEBUG} {puts "Sguil Cmd Unkown: $sguildCmd"} }

        }

    }

}

proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-D\] \[-c\] \[-o\] <filename>"
    puts "  -c <filename>: PATH to config (sancp.conf) file."
    puts "  -D Runs $cmdName in daemon mode."
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
proc AgentInfo { sensorName type netName sensorID } {

    global SENSOR_ID

    set SENSOR_ID $sensorID

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

# OpenSSL is required
# Need path?
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
if { [info exists SANCP] && $SANCP } { CheckForSancpFiles }
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
