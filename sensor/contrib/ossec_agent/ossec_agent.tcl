#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# OSSEC agent for Sguil 0.7.0.  Based on the "example_agent.tcl" code
# distributed with sguil.  
# 
# Portions Copyright (C) 2007 David J. Bianco <david@vorant.com>
#
#
# Copyright (C) 2002-2007 Robert (Bamm) Visscher <bamm@sguil.net>
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
set VERSION "SGUIL-0.7.0-ALPHA"

# Define the agent type here. It will be used to register the agent with sguild.
# The template also prepends the agent type in all caps to all event messages.
set AGENT_TYPE "ossec"

# The generator ID is a unique id for a generic agent.
# If you don't use 10001, then you will not be able to
# display detail in the client.
set GEN_ID 10001

# Used internally, you shouldn't need to edit these.
set CONNECTED 0
set OPENSSL 0


proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-D\] \[-o\] \[-c <config filename>\] \[-f <syslog filename>\] -i <ipaddr>"
    puts "  -i <ipaddr>: IP address to associate alert with (required)."
    puts "  -c <filename>: PATH to config (ossec_agent.conf) file."
    puts "  -f <filename>: PATH to OSSEC alert log to monitor."
    puts "  -o Enable OpenSSL"
    puts "  -D Runs ossec_agent in daemon mode."
    puts "  -p <int>: Minimum OSSEC event priority on which to alert."
    exit

}

# bgerror: This is a generic error catching proc. You shouldn't need to change it.
proc bgerror { errorMsg } {

    global errorInfo

    puts "Error: $errorMsg"
    if { [info exists errorInfo] } {
        puts $errorInfo
    }

    exit 1

}

# InitAgent: Use this proc to initialize your specific agent.
# Open a file to monitor or even a socket to receive data from.
proc InitAgent {} {

    global DEBUG FILENAME MIN_PRIORITY  DNS DEFAULT_DNS_DOMAIN
    global nDate sig_id priority message src_ip user hexPayload payload agent

    set nDate ""
    set sig_id ""
    set priority ""
    set message ""
    set src_ip ""
    set user ""
    set hexPayload ""
    set payload ""
    set agent ""
    
    if { ![info exists MIN_PRIORITY] } {
	set MIN_PRIORITY 7
    }

    # Configure the DNS resolver
    dns::configure -nameserver $DNS 

    if { ![info exists FILENAME] } { 
	# Set a reasonable default
        set FILENAME /var/ossec/logs/alerts/alerts.log
    }
    if { ![file readable $FILENAME] } {
        puts "Error: Unable to read $FILENAME"
        exit 1
    }
    
    # USe of the -F (to auto-reopen the file when it rotates at night)
    # is not portable beyond GNU tail!
    if [catch {open "| tail -n 0 -F $FILENAME" r} fileID] {
        puts "Error opening $FILENAME : $fileID"
        exit 1
    }

    fconfigure $fileID -buffering line
    # Proc ReadFile will be called as new lines are appended.
#    fileevent $fileID readable [list ReadFile $fileID]

    ReadFile $fileID
}

#
# ReadFile: Read and process each new line.
#
proc ReadFile { fileID } {

    while { ! [eof $fileID] } { 
	catch { [gets $fileID line] tmpError } {
	    
	    puts "Error processing file."
	    if { [info exits tmpError] } { puts "$tmpError" }
	    catch {close $fileID} 
	    exit 1
	    
	}
        # I prefer to process the data in a different proc.
        ProcessData $line
    }

}

#
# resolve a hostname to an IP, or return 0.0.0.0 if this isn't possible.
# IP addresses are OK, too, and they just return the same value.
#
proc ResolveHostname { hostName } {

   global DEFAULT_DNS_DOMAIN 

   set retVal $hostName

   if { ! [regexp {(?x)
	            \.
           } $retVal ] } {
	set retVal "$retVal.$DEFAULT_DNS_DOMAIN"
   }

   # This could be a IPv6-formatted IPv4 address
   # (e.g., "::ffff:192.168.1.1").  If so, strip off the 
   # "::ffff:" prefix, because sguild can't deal with it.
   set retVal [ regsub {(?x)
	^::ffff:
   } $retVal ""]

   if {$retVal == "(none)" || $retVal == "UNKNOWN"} {
	set retVal "0.0.0.0"
   } elseif { [regexp {(?x)
	[a-zA-Z\-]
   } $retVal] } {
	# This must be a hostname.  Try to look it up in DNS
       if { [catch {
	   set tok [dns::resolve $retVal]
	   dns::wait $tok
	   if { [dns::status $tok] == "error" } {
	       set retVal "0.0.0.0"
	   } else {
	       set retVal [dns::address $tok]
	   }
	   # Don't leave crap laying around for this request.  
	   dns::cleanup $tok
       }]
	} {
	   # If anything went wrong with the DNS lookup, return the
	   # default value.
	   set retVal "0.0.0.0"
       }
   }


   return $retVal
}

#
# ProcessData: Here we actually process the line
#
proc ProcessData { line } {

    global HOSTNAME IPADDR AGENT_ID NEXT_EVENT_ID AGENT_TYPE GEN_ID 
    global MIN_PRIORITY
    global sguildSocketID DEBUG
    global nDate sig_id priority message src_ip user hexPayload payload agent

    if { [regexp {(?x)
	^\*\*\s+Alert
    } $line] } {

	# Make some last minute adjustments to format everything properly
	if {$src_ip == "(none)" || \
	    $src_ip == "UNKNOWN" || \
	    $src_ip == ""} { set src_ip "0.0.0.0" }

	if {$agent == "(none)" || \
	    $agent == "UNKNOWN" || \
	    $agent == ""} { set agent "0.0.0.0" }

	# If we meet the minimum priority threshold to issue an alert,
	# do it here.  
	if { $priority >= $MIN_PRIORITY } {
 	    if {$DEBUG} {
 		puts "Found Alert: "
 		puts "\ttime: $nDate"
 		puts "\tAgent: $agent"
 		puts "\tSigID: $sig_id"
 		puts "\tPriority: $priority"
 		puts "\tSrcIP: $src_ip"
 		puts "\tUser: $user"
 		puts "\tMessage: $message"
 		puts "\tPayload: $payload"
 		puts "\n"
 	    }



	    set event [list GenericEvent 0 $priority {} \
			   $HOSTNAME $nDate $AGENT_ID $NEXT_EVENT_ID \
			   $NEXT_EVENT_ID [string2hex $message] \
			   $src_ip $agent {} {} {} \
			   $GEN_ID $sig_id 1 [string2hex $payload]]
	    
	    # Send the event to sguild
	    if { $DEBUG } { puts "Sending: $event" }
	    while { [catch {puts $sguildSocketID $event} tmpError] } {
		
		# Send to sguild failed
		if { $DEBUG } { puts "Send Failed: $tmpError" }
		
		# Close open socket
		catch {close $sguildSocketID}
		
		# Reconnect loop
		while { ![ConnectToSguilServer] } { after 15000 }
		
	    }
	    
	    # Sguild response should be "ConfirmEvent eventID"
	    if { [catch {gets $sguildSocketID response} readError] } {
		
		# Couldn't read from sguild
		if { $DEBUG } { puts "Read Failed: $readError" }
		
		# Close open socket
		catch {close $sguildSocketID}
		
		# Reconnect loop
		while { ![ConnectToSguilServer] } { after 15000 }
		return 0
		
	    }
	    if {$DEBUG} { puts "Received: $response" }
	    
	    if { [llength $response] != 2 || [lindex $response 0] != "ConfirmEvent" || [lindex $response 1] != $NEXT_EVENT_ID } {
		
		# Send to sguild failed
		if { $DEBUG } { puts "Recv Failed" }
		
		# Close open socket
		catch {close $sguildSocketID}
		
		# Reconnect loop
		while { ![ConnectToSguilServer] } { after 15000 }
		return 0
		
	    }
	    
	    # Success! Increment the next event id
	    incr NEXT_EVENT_ID
	}

	# Now clear all these vars for the next event
	set nDate ""
	set sig_id ""
	set priority ""
	set src_ip ""
	set user ""
	set message ""
	set payload ""
	set hexPayload ""


    } else {  
	# See if this looks like a date line (the alert header, not the
	# syslog line, which also begins with a date)
	if { [regexp {(?x)    
#	    ^(\d\d\d\d)\s+(...)\s+(\d\d)\s+(\d\d:\d\d:\d\d)\s+(.*)->
	  ^(\d\d\d\d)\s+(...)\s+(\d\d)\s+(\d\d:\d\d:\d\d)\s+(\(.*\)\s+)*(.*)->
	} $line MatchVar year month day time placeholder agent] } {
	    set nDate [clock format [clock scan "$day $month $year $time" ] -gmt true -f "%Y-%m-%d %T"]
	    # Ok, this is confusing, but the regexp can return either one 
	    # or two variables, depending on the format of the input line.
	    # if the line is from a windows agent, it will usually contain
	    # "(host) X.X.X.X", but if it's from some other agent, it will
	    # usually just be one field (either a hostname or an IP address,
	    # depending on the log source).  In either case, the $agent
	    # variable ends up holding the correct value for our purposes.
	    set agent [ResolveHostname $agent]
	} elseif { [regexp {(?x)
	             ^Rule:\s+(\d+)\s+\(level\s+(\d+)\)\s+->\s+'(.*)'
	} $line MatchVar sig_id priority message ] } {
	    set message "\[[string toupper $AGENT_TYPE]\] $message"
	} elseif { [regexp {(?x)
 	              ^User:\s+(.*)
	} $line MatchVar user ] } {
	    # We really don't have anything to do here, since we matched all
	    # our variables directly in the conditional for this block	
	} elseif { [regexp {(?x)
    	              ^Src\s+IP:\s+(.*)
	} $line MatchVar src_ip ] } {
	    set src_ip [ResolveHostname $src_ip]
	} else {
	    # If we haven't matched anything specific in the OSSEC alert
	    # structure, this must be a copy of the original alert.
	    # Add it to our payload.
	    append payload "$line\n"
	}

    }
}


# Initialize connection to sguild
proc ConnectToSguilServer {} {

    global sguildSocketID HOSTNAME CONNECTED OPENSSL
    global SERVER_HOST SERVER_PORT DEBUG VERSION
    global AGENT_ID NEXT_EVENT_ID
    global AGENT_TYPE NET_GROUP

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
        if {$OPENSSL} {
            set tmpVERSION "$VERSION OPENSSL ENABLED"
        } else {
            set tmpVERSION "$VERSION OPENSSL DISABLED"
        }

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
        if {$OPENSSL} { tls::import $sguildSocketID  -ssl2 false -ssl3 false -tls1 true}

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

# First make sure we can lod the DNS resolver library from tcllib
if [catch {package require dns 1.3.1} dnsVersion] {
    puts "ERROR: The tcllib_dns package v1.3.1 or later is requred."
    puts "The tcllib_dns package is part of the tcllib extension. More information"
    puts "is available at http://tcllib.sourceforge.net"
    puts ""
    puts "$dnsVersion"
    exit 0
}

# GetOpts
set state flag
foreach arg $argv {

    switch -- $state {

        flag {

            switch -glob -- $arg {

                -- { set state flag }
                -D { set DAEMON_CONF_OVERRIDE 1 }
                -c { set state conf }
                -o { set OPENSSL 1 }
                -O { set state sslpath }
                -f { set state filename }
                -i { set state ipaddr }
		-p { set state minpri }
		-d { set state dns }
		-n { set state defaultdomain }
                default { DisplayUsage $argv0 }

            }

        }

        conf     { set CONF_FILE $arg; set state flag }
        sslpath  { set TLS_PATH $arg; set state flag }
        filename { set FILENAME $arg; set state flag }
        ipaddr   { set IPADDR $arg; set state flag }
	minpri   { set MIN_PRIORITY $arg; set state flag }
	dns      { set DNS $arg; set state flag }
	defaultdomain { set DEFAULT_DNS_DOMAIN; set state flag }
        default { DisplayUsage $argv0 }

    }

}

# Set up the default dst IPADDR for events to "0.0.0.0"
if { ![info exists IPADDR] } {
    set IPADDR "0.0.0.0"
}

# Parse the config file here. Make sure you define the default config file location
if { ![info exists CONF_FILE] } {

    # No conf file specified check the defaults
    if { [file exists /etc/ossec_agent.conf] } {

        set CONF_FILE /etc/ossec_agent.conf

    } elseif { [file exists ./ossec_agent.conf] } {

        set CONF_FILE ./ossec_agent.conf

    } else {

        puts "Couldn't determine where the ossec_agent.tcl config file is"
        puts "Looked for /etc/ossec_agent.conf and ./ossec_agent.conf."
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

# Check for OPENSSL
if { $OPENSSL } {

    # Need path?
    if { [info exists TLS_PATH] } {

        if [catch {load $TLS_PATH} tlsError] {

            puts "ERROR: Unable to load tls libs ($TLS_PATH): $tlsError"
            DisplayUsage $argv0

        }

    }

    package require tls

}

# Connect to sguild
while { ![ConnectToSguilServer] } {

    # Wait 15 secs before reconnecting
    after 15000
}

# Intialize the Agent
InitAgent

# This causes tcl to go to it's event loop
#vwait FOREVER
