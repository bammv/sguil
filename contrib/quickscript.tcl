#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: quickscript.tcl,v 1.4 2012/03/19 21:28:17 bamm Exp $ #

# Copyright (C) 2002-2006 Robert (Bamm) Visscher <bamm@sguil.net>
#
# This program is distributed under the terms of version 1.0 of the
# Q Public License.  See LICENSE.QPL for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

########################## GLOBALS ##################################

set VERSION "SGUIL-0.8.0 OPENSSL ENABLED"

set SERVER localhost
set PORT 7734

#########################################################################
# Get cmd line args
#########################################################################

proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-s <server>\] \[-p <port>\] \[-u <username>\]"
    puts "    \[-a <alertid>\] \[-o <filename>\]"
    puts "  -s <servername>: Hostname of sguild server."
    puts "  -p <port>: Port of sguild server."
    puts "  -u <username>: Username to connect as."
    puts "  -a <alertid>: Alert ID (1.12345)"
    puts "  -o <filename>: PATH to tls libraries if needed."
    exit 1

}


set state flag

foreach arg $argv {

    switch -- $state {

        flag {
            switch -glob -- $arg {
                -s { set state server }
                -p { set state port }
                -u { set state username }
                -a { set state alertid }
                -o { set state openssl }
                default { DisplayUsage $argv0 }
            }
        }

        server { set SERVER $arg; set state flag }
        port { set PORT $arg; set state flag }
        username { set USERNAME $arg; set state flag }
        alertid { set alertid $arg; set state flag }
        openssl { set TLS_PATH $arg; set state flag }
        default { DisplayUsage $argv0 }

    }

}

#########################################################################
# Package/Extension Requirements
#########################################################################

# Check to see if a path to the tls libs was provided
if { [info exists TLS_PATH] } {

    if [catch {load $TLS_PATH} tlsError] {

        puts "ERROR: Unable to load tls libs ($TLS_PATH): $tlsError"
        DisplayUsage $argv0

    }

}

if { [catch {package require tls} tlsError] } {

    puts "ERROR: The tcl tls package does NOT appear to be installed on this sysem."
    puts "Please see http://tls.sourceforge.net/ for more info."
    exit 1

}


#########################################################################
# Procs 
#########################################################################

# A simple proc to send commands to sguild and catch errors
proc SendToSguild { socketID message } {

    if { [catch {puts $socketID $message} sendError] } {

        # Send failed. Close the socket and exit.
        catch {close $socketID} closeError

        if { [info exists sendError] } { 

            puts "ERROR: Caught exception while sending data: $sendError"

        } else {

            puts "ERROR: Caught unknown exception"

        }

        exit 1

    }

}

#########################################################################
# Main
#########################################################################

puts -nonewline "Connecting to $SERVER on port $PORT..."
flush stdout

# Try to connect to sguild
if [catch {socket $SERVER $PORT} socketID ] {

    # Exit on fail.
    puts "failed"
    exit 1

}

# Successfully connected
fconfigure $socketID -buffering line

# Check version compatibality
if [catch {gets $socketID} serverVersion] {

    # Caught an unknown error
    puts "failed."
    puts "ERROR: $serverVersion"
    catch {close $socketID}
    exit 1

}

if { $serverVersion == "Connection Refused." } {

    # Connection refused error
    puts "failed."
    puts "ERROR: $serverVersion"
    catch {close $socketID}
    exit 1

} 

if { $serverVersion != $VERSION } {

    # Mismatched versions
    catch {close $socketID}
    puts "failed."
    puts "Mismatched versions.\nSERVER: ($serverVersion)\nCLIENT: ($VERSION)"
    exit 1

}

# Send the server our version info
SendToSguild $socketID [list VersionInfo $VERSION]

# SSL-ify the socket
if { [catch {tls::import $socketID -ssl2 false -ssl3 false -tls1 true} tlsError] } {

    puts "failed."
    puts "ERROR: $tlsError"
    exit 1

}

# Give SSL a sec
after 1000

# Send sguild a ping to confirm comms
SendToSguild $socketID "PING"
# Get the PONG
set INIT [gets $socketID]
# Success
puts "success!"
puts ""


#
# Auth starts here
#

# Get username if not provided at cmd line
if { ![info exists USERNAME] } {

    puts -nonewline "Enter username: "
    flush stdout
    set USERNAME [gets stdin]

}

# Get users password
puts -nonewline "Enter password: "
flush stdout
exec stty -echo
set PASSWD [gets stdin]
exec stty echo
flush stdout
puts ""

# Authenticate with sguild
SendToSguild $socketID [list ValidateUser $USERNAME $PASSWD]

# Get the response. Success will return the users ID and failure will send INVALID.
if { [catch {gets $socketID} authMsg] } { 

    puts "Error during authentication: $authMsg"
    exit 1

}

set authResults [lindex $authMsg 1]
if { $authResults == "INVALID" } { 

    puts "Authentication failed."
    exit 1

}

puts "User $USERNAME successfully logged in."
puts ""

# Check to see if the alertid was passed as an arg.
if { ![info exists alertid] } {

    # Get the AlertID for transcript generation"
    puts -nonewline "Enter AlertID: "
    flush stdout
    set alertid [gets stdin]

}

# Send info to Sguild
SendToSguild $socketID [list QuickScript $alertid]

set SESSION_STATE DEBUG

# Xscript data comes in the format XscriptMainMsg window message
# Tags are HDR, SRC, and DST. They are sent when state changes.
while { 1 } {

    if { [eof $socketID] } { puts "ERROR: Lost connection to server."; exit 1 }

    if { [catch {gets $socketID} msg] } {

        puts "ERROR: $msg"
        exit 1

    }
  
    # Strip the command and faux winname from the msg
    set data [lindex $msg 2]


    switch -exact -- $data {

        HDR     { set SESSION_STATE HDR }
        SRC     { set SESSION_STATE SRC }
        DST     { set SESSION_STATE DST }
        DEBUG   { set SESSION_STATE DEBUG }
        DONE    { break }
        ERROR   { set SESSION_STATE ERROR }
        default { puts "${SESSION_STATE}: [lindex $msg 2]" }

    }

}

catch {close $socketID} 
