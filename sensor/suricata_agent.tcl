#!/usr/bin/env tclsh

# Copyright (C) 2002-2017 Robert (Bamm) Visscher <bamm@sguil.net>
#
# This program is distributed under the terms of version 3 of the
# GNU Public License.  See LICENSE for further details.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

#    Sending sguild (sock3) BYEventRcvd sock6 0 7 5565145 fin-int 3 3 {2017-02-22 03:17:48} 1 2019876 4 {ET SCAN SSH BruteForce Tool with fake PUTTY version} {2017-02-22 03:17:48} 3 network-scan 1948218411 116.31.116.43 3232237576 192.168.8.8 6 4 5 0 55 0 0 0 0 2503 {} {} {} {} {} 57898 22 0 0 5 0 0 0 5895 0 {} {} 5353482D322E302D50555454590D0A

##
# Config options in suricata_agent.conf.
#
# Don't touch these
set VERSION "SGUIL-0.9.0"
set CONNECTED 0
set EXIT_ON_FAIL 0

#
# Convert hex to string. Non-printables print a dot.
#
proc hex2string { h } {

    set dataLength [string length $h]
    set asciiStr {}

    for { set i 1 } { $i < $dataLength } { incr i 2 } {

        set currentByte [string range $h [expr $i - 1] $i]
        lappend hexStr $currentByte
        set intValue [format "%i" 0x$currentByte]
        set currentChar [format "%c" $intValue]
        append asciiStr "$currentChar"

    }

    return $asciiStr

}

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

proc DecodePacket { linktype p } {

    global packet

    set i [binary scan $p H* P]
  
    switch -exact -- $linktype {

        1  	{ etherNet $P }
	12	{ DecodeIPv4 $P }
        default { puts "Unknown linktype -> $linktype" }

    }

}

proc etherNet { P } {

    global packet

    set packet(ethernet) 1
    set packet(e_src) [string range $P 0 11]
    set packet(e_dst) [string range $P 12 23]
    set packet(e_type) [string range $P 24 27]

    set P [string range $P 28 end]

    switch -exact --  $packet(e_type) {

        0800	{ DecodeIPv4 $P }
        8100    { DecodeVLAN $P }
        86dd	{ DecodeIPv6 $P }
        default	{ puts "Unknown ether type -> $packet(e_type)" }

    }

}

proc PacketHex2Dec { P start end } { 

    set results [scan [string range $P $start $end] %x ]
    return $results

}

proc DecodeICMP { P } { 

    global packet

    set packet(icmp) 1
    set packet(icmp_type) [PacketHex2Dec $P 0 1]
    set packet(icmp_code) [PacketHex2Dec $P 2 3]
    set packet(icmp_csum) [PacketHex2Dec $P 4 7]
    set packet(icmp_id) [PacketHex2Dec $P 8 11]
    set packet(icmp_seq) [PacketHex2Dec $P 12 15]

    # We use payload data since stream alerts may not have the correct info
    
}

proc DecodeUDP { P } { 

    global packet

    set packet(udp) 1
    set packet(src_port) [PacketHex2Dec $P 0 3]
    set packet(dst_port) [PacketHex2Dec $P 4 7]
    set packet(udp_len) [PacketHex2Dec $P 8 11]
    set packet(udp_csum) [PacketHex2Dec $P 12 15]

    # We use payload data since stream alerts may not have the correct info
    
}

proc DecodeTCP { P } {

    global packet

    set packet(tcp) 1
    set packet(src_port) [PacketHex2Dec $P 0 3]
    set packet(dst_port) [PacketHex2Dec $P 4 7]
    set packet(tcp_seq) [PacketHex2Dec $P 8 15]
    set packet(tcp_ack) [PacketHex2Dec $P 16 23]
    set packet(tcp_off) [expr [PacketHex2Dec $P 24 24] * 4]
    set packet(tcp_res) [PacketHex2Dec $P 25 25]
    set packet(tcp_flags) [PacketHex2Dec $P 26 27]
    set packet(tcp_win) [PacketHex2Dec $P 28 31]
    set packet(tcp_csum) [PacketHex2Dec $P 32 35]
    set packet(tcp_urp) [PacketHex2Dec $P 36 39]
    set tcp_end [expr $packet(tcp_off) * 2]
    if { $tcp_end > 40 } {

        set packet(tcp_opts) [PacketHex2Dec $P 40 [expr $tcp_end - 1]]

    }
    
    # We use payload data since stream alerts may not have the correct info

}

proc DecodeIPv4 { P } {

    global packet

    set packet(ipv4) 1
    set packet(ip_ver) [string index $P 0]
    set packet(ip_hlen) [expr [PacketHex2Dec $P 1 1] * 4]
    set packet(ip_tos) [string range $P 2 3]
    set packet(ip_len) [PacketHex2Dec $P 4 7]
    set packet(ip_id) [PacketHex2Dec $P 8 11]
    set packet(ip_flags) [PacketHex2Dec $P 12 12]
    set packet(ip_off) [PacketHex2Dec $P 13 15]
    set packet(ip_ttl) [PacketHex2Dec $P 16 17]
    set packet(ip_proto) [PacketHex2Dec $P 18 19]
    set packet(ip_csum) [PacketHex2Dec $P 20 23]
    set packet(ip_sip) [PacketHex2Dec $P 24 31]
    set packet(ip_dip) [PacketHex2Dec $P 32 39]

    set P [string range $P [expr $packet(ip_hlen) * 2] end]

    switch -exact --  $packet(ip_proto) {

        1    	{ DecodeICMP $P }
        6    	{ DecodeTCP $P }
        17	{ DecodeUDP $P }
        default { puts "Unknown IP protocol type $P" }

    }

}

proc DecodeVLAN { P } {

    global packet

    set packet(ipv4) 1
    set packet(ip_ver) [string index $P 8]
    set packet(ip_hlen) [expr [PacketHex2Dec $P 9 9] * 4]
    set packet(ip_tos) [string range $P 10 11]
    set packet(ip_len) [PacketHex2Dec $P 12 15]
    set packet(ip_id) [PacketHex2Dec $P 16 19]
    set packet(ip_flags) [PacketHex2Dec $P 20 20]
    set packet(ip_off) [PacketHex2Dec $P 21 23]
    set packet(ip_ttl) [PacketHex2Dec $P 24 25]
    set packet(ip_proto) [PacketHex2Dec $P 26 27]
    set packet(ip_csum) [PacketHex2Dec $P 28 31]
    set packet(ip_sip) [PacketHex2Dec $P 32 39]
    set packet(ip_dip) [PacketHex2Dec $P 40 47]

    set P [string range $P [expr $packet(ip_hlen) * 2] end]

    switch -exact --  $packet(ip_proto) {

        1       { DecodeICMP $P }
        6       { DecodeTCP $P }
        17      { DecodeUDP $P }
        default { puts "Unknown IP protocol type $P" }

    }

}

proc DecodeIPv6 { P } {

    # Somebody want to write this?
    # For now set fake info
    set packet(ipv6) 1
    set packet(ip_sip) "0.0.0.0"
    set packet(ip_dip) "0.0.0.0"

}

proc ReadNextEveLine {} {

    global EVE_FILE EVE_MD5 ROW EVE_ID CONFIRM_WAIT

    # Check for a new line every second
    if { ![eof $EVE_ID] } { 

        if { [catch {gets $EVE_ID line} tmpError] } {

            catch {close $EVE_ID} tmpError
            if { [info exists tmpError] } {
                set bgerror "Error while processing $EVE_FILE: $tmpError"
            } else {
                set bgerror "Error: Received EOF from $EVE_FILE"
            }
    
        } else {

            if { $ROW == 1 } { set EVE_MD5 [::md5::md5 -hex $line] }

            puts "DEBUG #### Read line: $line"
            ParseEveLine $line

        }

    } else {

        after 1000 ReadNextEveLine

    }

}

proc ParseEveLine { line } {

    global DEBUG ROW EVE_MD5 SID CID HOSTNAME packet sguildSocketID WALDO_TRACKER ROW

    unset -nocomplain packet

    set data [::json::json2dict $line]

    # If this isn't an alert we ignore
    if { [dict get $data event_type] != "alert" } { incr ROW; return }

    array set alert [dict get $data alert]

    if { [dict exists $data flow_id] } {
        set flow_id [dict get $data flow_id]
    } else { 
        set flow_id 0
    }

    if { [catch {incr CID}] || $CID == "" || $CID == "{}" } {
      set CID 0
      incr CID
    }
  
    #
    # 2017-03-05T00:21:01.145558+0000
    #
    set ts [lindex [ split [regsub {T} [dict get $data timestamp] { }] .] 0] 
    set ts [clock format [clock scan $ts] -f "%Y-%m-%d %T"]
    set msg [list 0 $SID $CID $HOSTNAME $flow_id $flow_id $ts]
    foreach f { gid signature_id rev signature } { lappend msg $alert($f) }
    lappend msg $ts
    foreach f { severity category } { lappend msg $alert($f) }

    if { [dict exists $data packet_info] } {

        array set packet_info [dict get $data packet_info]
        DecodePacket $packet_info(linktype) [ base64::decode [dict get $data packet]]
    }

    set src_ip [dict get $data src_ip]
    set dst_ip [dict get $data dest_ip]

    # Add IP info
    if { ![info exists packet(ipv4)] || !$packet(ipv4) } {

        # Create empty fields for non IPv4 types. Most likely to see ipv6
        set packet(ip_sip) {}
        set packet(ip_dip) {}
        set src_ip {}
        set dst_ip {}

        # Set the IP proto
        set ip_proto_name [dict get $data proto]
        switch -exact -- $ip_proto_name {

            TCP	{ set packet(ip_proto) 6 }
            UDP { set packet(ip_proto) 17 }
            ICMP { set packet(ip_proto) 1 }
            default { set packet(ip_proto) {} }

        }

        lappend msg $packet(ip_sip) $src_ip $packet(ip_dip) $dst_ip $packet(ip_proto)

        # Append empty indexes for the unavaible fields. 
        #foreach i {ip_ver ip_hlen ip_tos ip_len ip_id ip_flags ip_off ip_ttl ip_csum } { lappend msg {} }
        lappend msg {}  {} {} {} {} {} {} {} {}

    }  else {

        lappend msg $packet(ip_sip) $src_ip $packet(ip_dip) $dst_ip
        foreach i {ip_proto ip_ver ip_hlen ip_tos ip_len ip_id ip_flags ip_off ip_ttl ip_csum } { lappend msg $packet($i) }

    }

    # Add ICMP info
    if { ![info exists packet(icmp)] || !$packet(icmp) } {

        # Add empty indexes
        lappend msg {} {} {} {} {}

    } else {

        foreach i { icmp_type icmp_code icmp_id icmp_seq } { lappend msg $packet($i) } 

    }

    # Add src and dest ports

    if { ![info exists packet(src_port)] } {
        if { [dict exists $data src_port] } { lappend msg [dict get $data src_port] } else { lappend msg {} }
    } else {
        lappend msg $packet(src_port)
    }
    if { ![info exists packet(dest_port)] } {
        if { [dict exists $data dest_port] } { lappend msg [dict get $data dest_port] } else { lappend msg {} }
    } else {
        lappend msg $packet(dest_port)
    }

    # Add TCP indexes
    if { ![info exists packet(tcp)] || !$packet(tcp) } {

        # Add empty indexes
        lappend msg {} {}  {} {} {} {} {} {}

    } else {

        foreach i { tcp_seq tcp_ack tcp_off tcp_res tcp_flags tcp_win tcp_csum tcp_urp } { lappend msg $packet($i) }

    }
    
    # Add UDP indexes
    if { ![info exists packet(udp)] || !$packet(udp) } {

        # Add empty indexes
        lappend msg {} {}

    } else {

        foreach i { udp_len udp_csum } { lappend msg $packet($i) }

    }

    # Add the payload
    if { [dict exists $data payload] } {

        set i [binary scan [ base64::decode [dict get $data payload]] H* payload]
        lappend msg $payload

    } else {

        lappend msg {}

    }

    set WALDO_TRACKER($CID) $ROW
    SendToSguild "BYEventRcvd $sguildSocketID $msg"
    incr ROW

}

proc UpdateWaldoFile { row } {

    global EVE_MD5 WALDO_FILE

    if { [catch {open $WALDO_FILE w} fileID] } {

        bgerror "ERROR: Failed to update waldo file: $WALDO_FILE: $fileID"

    }

    puts $fileID [list $EVE_MD5 $row]
    close $fileID

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
        InitSuricataAgent

    }

}

proc InitSuricataAgent {} {

    global CONNECTED DEBUG HOSTNAME NET_GROUP

    if {!$CONNECTED} {

       if {$DEBUG} { puts "Not connected to sguild. Sleeping 15 secs." }
       after 15000 InitSuricataAgent


    } else {

        SendToSguild [list RegisterAgent suricata $HOSTNAME $NET_GROUP]

    }

}

proc InitEveLog {} {

    global ROW EVE_FILE EVE_ID

    # Open stats file with tail.
    if { [catch {open "| tail -n +$ROW -f $EVE_FILE" r} EVE_ID] } {

        set errMsg "Error opening $EVE_FILE: $EVE_ID"
        bgerror "ERROR: Unable to open $EVE_FILE for reading"

    }

    fconfigure $EVE_ID -buffering line
    #fileevent $EVE_ID readable ReadNextEveLine
    ReadNextEveLine

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
            AgentInfo             { AgentInfo [lindex $data 4] [lindex $data 5] }
            LastCidResults        { SetLastCid [lindex $data 1] [lindex $data 2] }
            Confirm               { ConfirmMsg [lindex $data 1] [lindex $data 2] }
            Failed                { FailMsg [lindex $data 1] [lindex $data 2] [lindex $data 3] }
            default               { if {$DEBUG} {puts "Sguil Cmd Unkown: $sguildCmd"} }

        }

    }

}

proc ConfirmMsg { dummyID cid } {

    global WALDO_TRACKER

    UpdateWaldoFile $WALDO_TRACKER($cid)
    unset -nocomplain WALDO_TRACKER($cid)
    ReadNextEveLine

}

proc FailedMsg { dummy cid msg } {

    global WALDO_TRACKER EXIT_ON_FAIL

    if {$DEBUG} { puts "Sguild error: cid $cid: $msg" }
    if {$EXIT_ON_FAIL} { bgerror "Sguild error: cid $cid: $msg" }

}

proc SetLastCid { socketID lastCid } {

    global CID

    set CID $lastCID

}

proc DisplayUsage { cmdName } {

    puts "Usage: $cmdName \[-D\] \[-b\] \[-c\] \[-o\] <filename>"
    puts "  -c <filename>: PATH to config (suricata_agent.conf) file."
    puts "  -w <filename>: PATH to checkpoint (eve.waldo) file."
    puts "  -f Tells agent to exit on failed message from sguild."
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
    if { ![info exists PID_FILE] } { set PID_FILE "/var/run/snort_agent.pid" }
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
proc AgentInfo { sid cid } {

    global SID CID

    set SID $sid
    set CID $cid

    InitEveLog

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
                -f       { set EXIT_ON_FAIL 1 }
                -c       { set state conf }
                -w       { set state waldo }
                -O       { set state sslpath }
                default  { DisplayUsage $argv0 }

            }

        }

        conf      { set CONF_FILE $arg; set state flag }
        waldo     { set WALDO_FILE $arg; set state flag }
        sslpath   { set TLS_PATH $arg; set state flag }
        default   { DisplayUsage $argv0 }

    }

}

# Parse the config file here
# Default location is /etc/suricata_agent.conf or pwd
if { ![info exists CONF_FILE] } {

    # No conf file specified check the defaults
    if { [file exists /etc/suricata_agent.conf] } {

        set CONF_FILE /etc/suricata_agent.conf

    } elseif { [file exists ./suricata_agent.conf] } {

        set CONF_FILE ./suricata_agent.conf

    } else {

        puts "Couldn't determine where the snort_agent.tcl config file is"
        puts "Looked for /etc/suricata_agent.conf and ./suricata_agent.conf."
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

foreach pkg {tls md5 json base64 ip} {

    if { [catch {package require $pkg} tmpError] }  {

        puts "ERROR: Unable to load $pkg package: $tmpError"
        DisplayUsage $argv0

    }

}

if { ![info exists EVE_FILE] || ![file exists $EVE_FILE] } {

    puts "ERROR: Unable to determine Suricata output to process."
    DisplayUsage $argv0

} 

if { ![info exists WALDO_FILE] } {

    # Try to use the eve directory
    set WALDO_FILE "[file dirname $EVE_FILE]/eve.waldo"

}

# Read our waldo file
if { [file exists $WALDO_FILE] } {

    if { [catch {open $WALDO_FILE r} waldoID] } {

        bgerror "ERROR: Failed to read/write $WALDO_FILE"       

    }

    set waldoData [gets $waldoID]
    close $waldoID

    # Waldo provides line 1 md5 and last row read.
    set waldoMd5 [lindex $waldoData 0]
    set ROW [lindex $waldoData 1]

    # Grab the first line of the eve file and check to see if it's new
    if { [catch {open $EVE_FILE r} eveID] } {

        bgerror "ERROR: Unable to open $EVE_FILE for reading"

    }

    set EVE_MD5 [::md5::md5 -hex [gets $eveID]]
    close $eveID
    if { $EVE_MD5 != $waldoMd5 } {

        # New file, start at line 1
        set ROW 1

    } else {

        incr ROW

    }


} else {

    # Empty file, start at line 1
    set ROW 1

}

ConnectToSguilServer
if {$PING_DELAY != 0} { PingServer }
vwait FOREVER
