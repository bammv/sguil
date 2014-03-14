#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: example_agent.tcl,v 1.8 2011/02/17 02:55:48 bamm Exp $ #

# Copyright (C) 2002-2008 Robert (Bamm) Visscher <bamm@sguil.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# This is a template to use for building your own generic agents
# for sending alerts to a Sguil server. I tried to document with
# comments where appropriate. 
#
# This template will monitor your /var/log/secure file for sshd
# systlog messages and forward them to sguil.
#

# Make sure you define the version this agent will work with. 
set VERSION "SGUIL-0.9.0"

# Define the agent type here. It will be used to register the agent with sguild.
# The template also prepends the agent type in all caps to all event messages.
set AGENT_TYPE "sshd"

# The generator ID is a unique id for a generic agent.
# If you don't use 10001, then you will not be able to
# display detail in the client.
set GEN_ID 10001

# Used internally, you shouldn't need to edit these.
set CONNECTED 0


proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-D\] \[-o\] \[-c <config filename>\] \[-f <syslog filename>\] -i <ipaddr>"
    puts "  -i <ipaddr>: IP address to associate alert with (required)."
    puts "  -c <filename>: PATH to config (pads_agent.conf) file."
    puts "  -f <filename>: PATH to syslog file to monitor."
    puts "  -D Runs sensor_agent in daemon mode."
    exit

}

# bgerror: This is a generic error catching proc. You shouldn't need to change it.
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

# InitAgent: Use this proc to initialize your specific agent.
# Open a file to monitor or even a socket to receive data from.
proc InitAgent {} {

    global DEBUG FILENAME

    if { ![info exists FILENAME] } { 
        # Default file is /var/log/secure
        set FILENAME /var/log/secure
    }
    if { ![file readable $FILENAME] } {
        puts "Error: Unable to read $FILENAME"
        exit 1
    }
    
    if [catch {open "| tail -n 0 -f $FILENAME" r} fileID] {
        puts "Error opening $FILENAME : $fileID"
        exit 1
    }

    fconfigure $fileID -buffering line
    # Proc ReadFile will be called as new lines are appended.
    fileevent $fileID readable [list ReadFile $fileID]

}

#
# ReadFile: Read and process each new line.
#
proc ReadFile { fileID } {

    if { [eof $fileID] || [catch {gets $fileID line} tmpError] } {
    
        puts "Error processing file."
        if { [info exits tmpError] } { puts "$tmpError" }
        catch {close $fileID} 
        exit 1

    } else {
            
        # I prefer to process the data in a different proc.
        ProcessData $line

    }

}

#
# ProcessData: Here we actually process the line
#
proc ProcessData { line } {

    global HOSTNAME IPADDR AGENT_ID NEXT_EVENT_ID AGENT_TYPE GEN_ID
    global sguildSocketID DEBUG

    # Grab lines that match our sshd regexp. I only want successful logins.
    # Example line: Mar 25 14:02:57 localhost sshd[9016]: Accepted password for root from 127.0.0.1 port 48274 ssh2
    if { [regexp {(?x)                                           # Turn on expanded regexp
                   (^[a-zA-Z]+\s[0-9]+\s[0-9]+:[0-9]+:[0-9]+)\s  # date
                   .*\ssshd\[[0-9]+\]:\s(Accepted|Failed)\s      # status
                   password\sfor\s(.*?)\sfrom\s                  # user
                   ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s            # ipaddr 
                   port\s([0-9]+)                                # port
            } $line match date status user inet_src_ip src_port] } {

        # Convert date to YY-MM-DD HH:MM:SS format
        set nDate [clock format [clock scan "$date" -gmt true] -gmt true -f "%Y-%m-%d %T"]
    
        if { $status == "Accepted" } { 
    
            set message "[string toupper $AGENT_TYPE] Login accepted for $user"
            # Each sig should have it's on sig id.
            set sig_id "1"
            # Rev of this sig
            set rev "1"
            set priority 5 
            set class "successful-login"
    
        } else { 
    
            set message "[string toupper $AGENT_TYPE] Login failed for $user"
            # Each sig should have it's on sig id.
            set sig_id "2"
            # Rev of this sig
            set rev "1"
            set priority 4
            set class "failed-login"
    
        }
    
        # Format for GenericAlert below. Needs to be in tcl list format with 
        # appropriate chars escaped. See: http://www.tcl.tk/man/tcl8.5/tutorial/Tcl14.html
        #
        # GenericEvent status priority class hostname timestamp sensorID alertID hexMessage  \
        #               inet_src_ip inet_dst_ip ip_proto src_port dst_port generatorID sigID \
        #               revision hexDetail
        #
        # status........Status of the event. Should be 0 for RealTime
        # priority......Priority of the event. Usually 1-5 with 1 being high.
        # class.........Classification 
        # hostname......Hostname agent is running on
        # timestamp.....YYYY-MM-DD HH:MM:SS (in GMT)
        # agentID.......Agent ID from sguild
        # alertID.......Unique number (usually incremented starting with 1)
        # refID.........Reference ID if alert is associated with another
        # message.......Message to be displayed when in RT event view (in hex)
        # inet_src_ip...Source IP in dotted notation (192.168.1.1)
        # inet_dst_ip...Dest IP in dotted notation
        # ip_proto......Internet Protocol (6=TCP, 17=UDP, 1=ICMP, etc)
        # src_port......Source Port 
        # dst_port......Dest Port
        # generatorID...Unique generator ID. Each agent should have a unique generator ID.
        # sigID.........Unique signature ID. Each signature for a generator should have a unique ID
        # revision......Which rev of the signature
        # hexDetail.....Event detail in hex. Will be displayed when analyst views the event with more detail.
    
        # Build the event to send
        set event [list GenericEvent 0 $priority $class $HOSTNAME $nDate $AGENT_ID $NEXT_EVENT_ID \
                   $NEXT_EVENT_ID [string2hex $message] $inet_src_ip $IPADDR 6 $src_port 22       \
                   $GEN_ID $sig_id $rev [string2hex $match]]
    
        # Send the event to sguild
        if { $DEBUG } { puts "Sending: $event" }
        while { [catch {puts $sguildSocketID $event} tmpError] } {
    
            # Send to sguild failed
            if { $DEBUG } { puts "Send Failed: $tmpError" }
    
            # Close open socket
            catch {close $sguildSocketID}
            
            # Reconnect loop
            while { ![ConnectToSguild] } { after 15000 }

        }
    
        # Sguild response should be "ConfirmEvent eventID"
        if { [catch {gets $sguildSocketID response} readError] } {
    
            # Error getting a response. This one is fatal.
            puts "Fatal error: $readError"
            exit 1
    
        }
        if {$DEBUG} { puts "Received: $response" }
    
        if { [llength $response] != 2 || [lindex $response 0] != "ConfirmEvent" || [lindex $response 1] != $NEXT_EVENT_ID } {
    
            # Not a confirmation. Fatal error.
            puts "Fatal error: Expected => ConfirmEvent $NEXT_EVENT_ID   got => $response"
            exit 1
    
        }
    
        # Success! Increment the next event id
        incr NEXT_EVENT_ID
    
    }
    
}


# Initialize connection to sguild
proc ConnectToSguilServer {} {

    global sguildSocketID HOSTNAME CONNECTED
    global SERVER_HOST SERVER_PORT DEBUG VERSION
    global AGENT_ID NEXT_EVENT_ID
    global AGENT_TYPE NET_GROUP

    # Connect
    if {[catch {set sguildSocketID [socket $SERVER_HOST $SERVER_PORT]}] > 0} {

        # Connection failed #

        set CONNECTED 0
        if {$DEBUG} {puts "Unable to connect to $SERVER_HOST on port $SERVER_PORT."}

    } else {

        # Connection Successful #
        fconfigure $sguildSocketID -buffering line

        # Version checks
        set tmpVERSION "$VERSION OPENSSL ENABLED"

        if [catch {gets $sguildSocketID} serverVersion] {
            puts "ERROR: $serverVersion"
            catch {close $sguildSocketID}
            exit 1
         }

        if { $serverVersion == "Connection Refused." } {

            puts $serverVersion
            catch {close $sguildSocketID}
            exit 1

        } elseif { $serverVersion != $tmpVERSION } {

            catch {close $sguildSocketID}
            puts "Mismatched versions.\nSERVER: ($serverVersion)\nAGENT: ($tmpVERSION)"
            return 0

        }

        if [catch {puts $sguildSocketID [list VersionInfo $tmpVERSION]} tmpError] {
            catch {close $sguildSocketID}
            puts "Unable to send version string: $tmpError"
            return 0
        }

        catch { flush $sguildSocketID }
        tls::import $sguildSocketID -ssl2 false -ssl3 false -tls1 true

        set CONNECTED 1
        if {$DEBUG} {puts "Connected to $SERVER_HOST"}

    }

    # Register the agent with sguild.
    set msg [list RegisterAgent $AGENT_TYPE $HOSTNAME $NET_GROUP]
    if { $DEBUG } { puts "Sending: $msg" }
    if { [catch { puts $sguildSocketID $msg } tmpError] } { 
 
        # Send failed
        puts "Error: $tmpError"
        catch {close $sguildSocketID} 
        return 0
    
    }

    # Read reply from sguild.
    if { [eof $sguildSocketID] || [catch {gets $sguildSocketID data}] } {
 
        # Read failed.
        catch {close $sockID} 
        return 0

    }
    if { $DEBUG } { puts "Received: $data" }

    # Process agent info returned from sguild
    # Should return:  AgentInfo sensorName agentType netName sensorID maxCid
    if { [lindex $data 0] != "AgentInfo" } {

        # This isn't what we were expecting
        catch {close $sguildSocketID}
        return 0

    }

    # AgentInfo    { AgentInfo [lindex $data 1] [lindex $data 2] [lindex $data 3] [lindex $data 4] [lindex $data 5]}
    set AGENT_ID [lindex $data 4]
    set NEXT_EVENT_ID [expr [lindex $data 5] + 1]

    return 1
    
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
        exit 1

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

#
# A simple proc to return the current time in 'YYYY-MM-DD HH:MM:SS' format
#
proc GetCurrentTimeStamp {} {

    set timestamp [clock format [clock seconds] -gmt true -f "%Y-%m-%d %T"]
    return $timestamp

}

#
# Converts strings to hex
#
proc string2hex { s } {

    set i 0
    set r {}
    while { $i < [string length $s] } {

        scan [string index $s $i] "%c" tmp
        append r [format "%02X" $tmp]
        incr i

    }

    return $r

}


################### MAIN ###########################

# Standard options are below. If you need to add more switches,
# put them here. For the sshd example, we add -f filename 
# to define which file we are monitoring and -i ip to define
# the dst ip we are monitoring.
# 
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
                -f { set state filename }
                -i { set state ipaddr }
                default { DisplayUsage $argv0 }

            }

        }

        conf     { set CONF_FILE $arg; set state flag }
        sslpath  { set TLS_PATH $arg; set state flag }
        filename { set FILENAME $arg; set state flag }
        ipaddr   { set IPADDR $arg; set state flag }
        default { DisplayUsage $argv0 }

    }

}

# Require an ipaddr
if { ![info exists IPADDR] } {

    puts "Error: No IP address was provided"
    DisplayUsage $argv0

}

# Parse the config file here. Make sure you define the default config file location
if { ![info exists CONF_FILE] } {

    # No conf file specified check the defaults
    if { [file exists /etc/example_agent.conf] } {

        set CONF_FILE /etc/example_agent.conf

    } elseif { [file exists ./example_agent.conf] } {

        set CONF_FILE ./example_agent.conf

    } else {

        puts "Couldn't determine where the example_agent.tcl config file is"
        puts "Looked for /etc/example_agent.conf and ./example_agent.conf."
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
                    exit 1

                }

            } else {

                puts "Error at line $i in $CONF_FILE: $line"
                exit 1

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

# Connect to sguild
while { ![ConnectToSguilServer] } {

    # Wait 15 secs before reconnecting
    after 15000
}

# Intialize the Agent
InitAgent

# This causes tcl to go to it's event loop
vwait FOREVER
