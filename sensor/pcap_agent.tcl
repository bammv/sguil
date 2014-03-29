#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: pcap_agent.tcl,v 1.13 2011/03/10 22:03:33 bamm Exp $ #

# Copyright (C) 2002-2013 Robert (Bamm) Visscher <bamm@sguil.net>
#
# This program is distributed under the terms of version 3 of the
# GNU Public License.  See LICENSE for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

#
# Config options in pcap_agent.conf.
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

proc UploadRawFile { fileName TRANS_ID fileSize } {

    global SERVER_HOST SERVER_PORT DEBUG VERSION HOSTNAME NET_GROUP TMP_DIR

    # Connect to server and establish the data channel
    if { [catch {set dataChannelID [socket $SERVER_HOST $SERVER_PORT]} ] > 0} {

        # Connection failed #

        if {$DEBUG} { puts "ERROR: Failed to open data channel" }
        if {$DEBUG} { puts "Trying again in 15 seconds" }
        after 15000 UploadRawFile $fileName $TRANS_ID $fileSize

    } else {

        # Connection Successful #

        # Configure the socket to line buffer for version checks
        fconfigure $dataChannelID -buffering line

        # Send version checks
        set tmpVERSION "$VERSION OPENSSL ENABLED"

        if [catch {gets $dataChannelID} serverVersion] {

            puts "ERROR: $serverVersion"
            catch {close $dataChannelID}

        }

        if { $serverVersion == "Connection Refused." } {

            puts $serverVersion
            catch {close $dataChannelID}

        } elseif { $serverVersion != $tmpVERSION } {

            catch {close $dataChannelID}
            puts "Mismatched versions.\nSERVER: ($serverVersion)\nAGENT: ($tmpVERSION)"

        }

        if [catch {puts $dataChannelID [list VersionInfo $tmpVERSION]} tmpError] {

            catch {close $dataChannelID}
            puts "Unable to send version string: $tmpError"

        }

        catch { flush $dataChannelID }
        tls::import $dataChannelID -ssl2 false -ssl3 false -tls1 true

        #
        # Connected and version checks finished.
        #

        # Register as a data agent
        if [catch {puts $dataChannelID [list RegisterAgent data $HOSTNAME $NET_GROUP]} tmpError] {

            catch {close $dataChannelID}
            puts "Error registering data agent: $tmpError"
            exit

        }
 
        # Notify sguild a raw data is coming.
        if {$DEBUG} { puts "Sending Sguild: [list RawDataFile $fileName $TRANS_ID $fileSize]" }
        if [catch {puts $dataChannelID [list RawDataFile [file tail $fileName] $TRANS_ID $fileSize]} tmpError] {

            # Copy failed
            if {$DEBUG} { puts "ERROR: Raw copy failed: $tmpError" }
            catch {close $dataChannelID}
            # Try again
            after 15000 UploadRawFile $fileName $TRANS_ID $fileSize

        } else {

            BinCopyToSguild $dataChannelID $fileName

        }

    }

}

proc BinCopyToSguild { dataChannelID fileName } {

    puts "DEBUG #### Sending file via $dataChannelID"

    if [ catch {open $fileName r} rFileID ] {

        # Error opening file
      
        puts "ERROR: Opening $fileName: $rFileID"
        catch {close $rFileID} tmpError
        return -code error "Error opening file $fileName"

    }

    # Configure the socket for a binary xfer
    fconfigure $rFileID -translation binary -encoding binary
    fconfigure $dataChannelID -translation binary -encoding binary

    if [ catch {fcopy $rFileID $dataChannelID -command [list BinCopyFinished $rFileID $dataChannelID $fileName] } tmpError ] {

        # fcopy failed.
        catch { close $dataChannelID }
        return -code error "Error transferring $fileName: $tmpError"

    } 

}

proc BinCopyFinished { fileID dataChannelID fileName bytes {error  {}} } {

    global DEBUG

    # Copy finished
    catch {close $fileID}
    catch {close $dataChannelID}

    if { [string length $error] != 0 } {

        # Error during copy - resend?

    }

    catch {file delete $fileName}
    if {$DEBUG} { puts "$fileName: Data copy finished. bytes -> $bytes" }

}

# Received a request for rawdata
proc RawDataRequest { socketID TRANS_ID sensor timestamp srcIP dstIP srcPort dstPort proto rawDataFileName type } {

    global SERVER_HOST SERVER_PORT DEBUG HOSTNAME TMP_DIR

    # Make sure the request isn't being worked.
    if { [file exists $TMP_DIR/$rawDataFileName] } {

        set tmpError "Request for pcap already in queue. Pls try again later"

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID [CleanMsg $tmpError]]

        } else {

            SendToSguild [list SystemMessage $tmpError]

        }

        return

    }

    # Create the data file.
    if { [catch {CreateRawDataFile $TRANS_ID $timestamp \
      $srcIP $srcPort $dstIP $dstPort $proto $rawDataFileName $type} tmpError] } {

        set tmpMsg "Error creating raw data file: $rawDataFileName"

        if {$DEBUG} { puts $tmpError }

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID [CleanMsg $tmpError]]

        } else {

            SendToSguild [list SystemMessage $tmpError]

        }


    }

}

# Try to determine the last time log_packets wrote to pcap (approx)
proc CheckLastPcapFile { { onetime {0} } } {

    global FILE_CHECK_IN_MSECS RAW_LOG_DIR CONNECTED
    global SENSOR_ID DEBUG

    if {$CONNECTED && [info exists SENSOR_ID] } {

        # Get a list of directories containing pcap files.
        set tmpDirList [glob -nocomplain $RAW_LOG_DIR/*]

        # Find the latest pcap file if files exist
        if { $tmpDirList != "" } {

            foreach i $tmpDirList { lappend dirList [file tail $i] }
            set lastDate [lindex [lsort -decreasing $dirList] 0]
            set checkDir "$RAW_LOG_DIR/$lastDate"
    
            if { [file exists $checkDir] && [file isdirectory $checkDir] } {
    
                # Get the name of the newest file 
                set logFile [lindex [lsort -decreasing [glob -nocomplain $checkDir/snort.log.*]] 0]

            }

            if { $logFile != "" } { 

                file stat $logFile fileStat
                set lastModified [clock format $fileStat(mtime) -gmt true -f "%Y-%m-%d %T"]
                SendToSguild [list LastPcapTime $lastModified]

            } else {

                if {$DEBUG} { puts "ERROR: No pcap files in $checkDir" }
                SendToSguild [list SystemMessage "Error: No pcap files in $checkDir."]

            }

        }

    }

    if { !$onetime } { after $FILE_CHECK_IN_MSECS CheckLastPcapFile }

}


proc CreateRawDataFile { TRANS_ID timestamp srcIP srcPort dstIP dstPort proto rawDataFileName type } {

    global RAW_LOG_DIR DEBUG TCPDUMP TMP_DIR

    set date [lindex $timestamp 0]

    if { [file exists $RAW_LOG_DIR/$date] && [file isdirectory $RAW_LOG_DIR/$date] } {

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID "Making a list of local log files."]
            SendToSguild [list XscriptDebugMsg $TRANS_ID "Looking in $RAW_LOG_DIR/$date."]

        } else {

            SendToSguild [list SystemMessage "Making a list of local log files."]
            SendToSguild [list SystemMessage "Looking in $RAW_LOG_DIR/$date."]

        }

    } else {

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID \
             "$RAW_LOG_DIR/$date does not exist. Make sure log_packets.sh is configured correctly."]

        } else {

            SendToSguild [list SystemMessage \
             "$RAW_LOG_DIR/$date does not exist. Make sure log_packets.sh is configured correctly."]

        }

        if {$DEBUG} {

           puts "$RAW_LOG_DIR/$date does not exist. Make sure log_packets.sh is configured correctly."

        }

        return -code error

    }

    cd $RAW_LOG_DIR/$date

    if { $type == "xscript" } {

        SendToSguild [list XscriptDebugMsg $TRANS_ID "Making a list of local log files in $RAW_LOG_DIR/$date."]

    } else {

        SendToSguild [list SystemMessage "Making a list of local log files in $RAW_LOG_DIR/$date."]

    }

    foreach logFile [glob -nocomplain snort.log.*] {

        lappend logFileTimes [lindex [split $logFile .] 2]

    }

    if { ! [info exists logFileTimes] } {

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID "No matching log files."]

        } else {

            SendToSguild [list SystemMessage "No matching log files."]

        }

        return -code error
    }

    set sLogFileTimes [lsort -decreasing $logFileTimes]
    if {$DEBUG} {puts $sLogFileTimes}

    if { $type == "xscript" } {

        SendToSguild [list XscriptDebugMsg $TRANS_ID "Available log files:"]
        SendToSguild [list XscriptDebugMsg $TRANS_ID "$sLogFileTimes"]

    } else {

        SendToSguild [list SystemMessage "Available log files:"]
        SendToSguild [list SystemMessage "$sLogFileTimes"]

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
        }

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID "ERROR: Unable to find the matching pcap file based on the time."]
            SendToSguild [list XscriptDebugMsg $TRANS_ID "The requested event time is: $eventTime"]

        } else {

            SendToSguild [list SystemMessage "ERROR: Unable to find the matching pcap file based on the time."]
            SendToSguild [list SystemMessage "The requested event time is: $eventTime"]

        }

        return -code error

    }

    # Use ip or vlan for the filter
    if {$proto != "6" && $proto != "17"} {

        set tcpdumpFilter "(ip and host $srcIP and host $dstIP and proto $proto) or (vlan and host $srcIP and host $dstIP and proto $proto)"

    } else {

        set tcpdumpFilter "(ip and host $srcIP and host $dstIP and port $srcPort and port $dstPort and proto $proto) or (vlan and host $srcIP and host $dstIP and port $srcPort and port $dstPort and proto $proto)"

    }

    set tcpdumpCmd "$TCPDUMP -r $RAW_LOG_DIR/$date/$logFileName -w $TMP_DIR/$rawDataFileName $tcpdumpFilter"

    if { $type == "xscript" } {

        SendToSguild [list XscriptDebugMsg $TRANS_ID "Creating unique data file: $tcpdumpCmd"]

    } else {

        SendToSguild [list SystemMessage "Creating unique data file: $tcpdumpCmd"]

    }

    if [catch { open "| $tcpdumpCmd" r } cmdID] {

        set tmpMsg "Error running $tcpdumpCmd: $cmdID"
        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID [CleanMsg $cmdID]]

        } else {

            SendToSguild [list SystemMessage $cmdID]

        }

    } else {

        fileevent $cmdID readable [list ProcessTcpdump $cmdID $TMP_DIR/$rawDataFileName $TRANS_ID $type]

    }

}

proc ProcessTcpdump { cmdID fileName TRANS_ID type } {

    if { [eof $cmdID] || [catch {gets $socketID data}] } {

        # Socket closed
        catch {close $cmdID}

        if { [file exists $fileName] } {

            # Copy the file up to sguild via a data channel.
            UploadRawFile $fileName $TRANS_ID [file size $fileName]

        } else {

            if { $type == "xscript" } {

                SendToSguild [list XscriptDebugMsg $TRANS_ID "Error creating file: $fileName"]

            } else {

                SendToSguild [list SystemMessage "Error creating file: $fileName"]

            }

        }

    } else {

        if { $type == "xscript" } {

            SendToSguild [list XscriptDebugMsg $TRANS_ID "tcpdump: $data"]

        } else {

            SendToSguild [list SystemMessage "tcpdump: $data"]

        }

    }

}

proc CheckDiskSpace {} {

    global DEBUG WATCH_DIR DISK_CHECK_DELAY_IN_MSECS CONNECTED

    if { $CONNECTED && [info exists WATCH_DIR] && [file exists $WATCH_DIR] } {

        if [catch {exec df -h $WATCH_DIR} output] {

            SendToSguild "DiskReport Error: $output"

        } else {

            set diskUse [lindex [lindex [split $output \n] 1] 4]
            SendToSguild "DiskReport $WATCH_DIR $diskUse"
            after $DISK_CHECK_DELAY_IN_MSECS CheckDiskSpace

        }

    }

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
        InitSnortAgent

    }

}

proc InitSnortAgent {} {

    global CONNECTED DEBUG HOSTNAME NET_GROUP

    if {!$CONNECTED} {

       if {$DEBUG} { puts "Not connected to sguild. Sleeping 15 secs." }
       after 15000 InitSnortAgent

    } else {

        SendToSguild [list RegisterAgent pcap $HOSTNAME $NET_GROUP]

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
            RawDataRequest        { eval $sguildCmd $socketID [lrange $data 1 end] }
            AgentInfo             { AgentInfo [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] }
            default               { if {$DEBUG} {puts "Sguil Cmd Unkown: $sguildCmd"} }

        }

    }

}

proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-D\] \[-c\] \[-o\] <filename>"
    puts "  -c <filename>: PATH to config (pcap_agent.conf) file."
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
    if { ![info exists PID_FILE] } { set PID_FILE "/var/run/pcap_agent.pid" }
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
    CheckLastPcapFile 1

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

                --       { set state flag }
                -D       { set DAEMON_CONF_OVERRIDE 1 }
                -c       { set state conf }
                -O       { set state sslpath }
                default  { DisplayUsage $argv0 }

            }

        }

        conf      { set CONF_FILE $arg; set state flag }
        sslpath   { set TLS_PATH $arg; set state flag }
        default   { DisplayUsage $argv0 }

    }

}

# Parse the config file here
# Default location is /etc/pcap_agent.conf or pwd
if { ![info exists CONF_FILE] } {

    # No conf file specified check the defaults
    if { [file exists /etc/pcap_agent.conf] } {

        set CONF_FILE /etc/pcap_agent.conf

    } elseif { [file exists ./pcap_agent.conf] } {

        set CONF_FILE ./pcap_agent.conf

    } else {

        puts "Couldn't determine where the pcap_agent.tcl config file is"
        puts "Looked for /etc/pcap_agent.conf and ./pcap_agent.conf."
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
if { [info exists FILE_CHECK_IN_MSECS] && $FILE_CHECK_IN_MSECS > 0 } { CheckLastPcapFile }
if { [info exists DISK_CHECK_DELAY_IN_MSECS] && $DISK_CHECK_DELAY_IN_MSECS > 0 } { CheckDiskSpace }
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
