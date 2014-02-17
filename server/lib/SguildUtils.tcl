# $Id: SguildUtils.tcl,v 1.15 2011/05/29 15:17:32 bamm Exp $ #

proc Daemonize {} {
    global PID_FILE env LOGGER
    set childPID [fork]
    # Parent exits.
    if { $childPID == 0 } { exit }
    id process group set
    if {[fork]} {exit 0}
    set PID [id process]
    if { ![info exists PID_FILE] } { set PID_FILE "/var/run/sguild.pid" }
    set PID_DIR [file dirname $PID_FILE]
    if { ![file exists $PID_DIR] || ![file isdirectory $PID_DIR] || ![file writable $PID_DIR] } {
	LogMessage "ERROR: Directory $PID_DIR does not exists or is not writable. Process ID will not be written to file."
    } else {
	set pidFileID [open $PID_FILE w]
	puts $pidFileID $PID
	close $pidFileID
    }
}

proc HupTrapped {} {
  global AUTOCAT_FILE GLOBAL_QRY_FILE GLOBAL_QRY_LIST clientList REPORT_QRY_FILE REPORT_QRY_LIST
  global acRules acCat ACCESS_FILE EMAIL_FILE
  LogMessage "HUP signal caught."
  # Reload auto cat rules
  InfoMessage "Reloading AutoCat rules from DB."
  # Clear the current rules
  if [info exists acRules] { unset acRules }
  if [info exists acCat] { unset acCat }
  # Load autocat rules from the DB
  LoadAutoCats
  if { [file exists $EMAIL_FILE] } {
    LoadEmailConfig $EMAIL_FILE
    InfoMessage "Email config loaded: $EMAIL_FILE"
  }
  # reload global queries.
  InfoMessage "Reloaded Global Queries: $GLOBAL_QRY_FILE"
  # Clear the current list
  set GLOBAL_QRY_LIST ""
  if { [file exists $GLOBAL_QRY_FILE] } {
    LoadGlobalQueries $GLOBAL_QRY_FILE
  } else {
    set GLOBAL_QRY_LIST none
  }
  set REPORT_QRY_LIST ""
  if { [file exists $REPORT_QRY_FILE] } {
     LoadReportQueries $REPORT_QRY_FILE
  } else {
    set REPORT_QRY_LIST none
  }
  foreach clientSocket $clientList {
    SendSocket $clientSocket [list GlobalQryList $GLOBAL_QRY_LIST]
    SendSocket $clientSocket [list ReportQryList $REPORT_QRY_LIST]
  }
  LoadAccessFile $ACCESS_FILE
}

proc GetRandAlphaNumInt {} {
  set x [expr [random 74] + 48]
  while {!($x >= 48 && $x <= 57) && !($x >= 65 && $x <= 90)\
      && !($x >= 97 && $x <= 122)} {
     set x [expr [random 74] + 48]
  }
  return $x
}

# Return a list of chars of length
proc RandomString { length } {

    # Characters that can be used to create the string
    set chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ123456789!@#$%^&*()"
    # Number of chars
    set num [string length $chars]

    for {set i 0} {$i<$num} {incr i} {

        set char [string index $chars [expr {int(rand()*$num)}]]
        append results $char

    }

    return $results

}

#
# GetHostbyAddr: uses extended tcl (wishx) to get an ips hostname
#                May move to a server func in the future
#
proc GetHostbyAddr { ip } {
  if [catch {host_info official_name $ip} hostname] {
    set hostname "Unknown"
  }
  return $hostname
}

# ValidateIPAddress:  Verifies that a string fits a.b.c.d/n CIDR format.
#                     the / notation is optional. 
#                     returns a list with the following elements or 0 if the syntax is invalid:
#                     { ipaddress } { maskbits } { networknumber } { broadcastaddress }
#                     for example:
#                     given 10.2.1.3/24 it will return:
#                     { 10.2.1.3 } { 24 } { 10.2.1.0 }
proc ValidateIPAddress { fullip } {

    set valid 0
    
    set valid [regexp "^((\\d{1,3})\.(\\d{1,3})\.(\\d{1,3})\.(\\d{1,3}))(/)?(\\d{1,2})?$" \
	    $fullip foo ipaddress oct1 oct2 oct3 oct4 slash maskbits]
    if { !$valid } { return 0 }
    
    if { $oct1 < 0 || $oct1 > 255 } { set valid 0 }
    if { $oct2 < 0 || $oct2 > 255 } { set valid 0 }
    if { $oct3 < 0 || $oct3 > 255 } { set valid 0 }
    if { $oct4 < 0 || $oct4 > 255 } { set valid 0 }
    if { $maskbits!="" && ($maskbits < 0 || $maskbits > 32) } { set valid 0 }
    if { !$valid } { return 0 }

    # if the bitmask is 32 or absent, return the ip address as the network number
    if { $maskbits=="" || $maskbits == 32 } {
	set iplist [list $ipaddress 32 $ipaddress $ipaddress]
    } else { 
	if { $maskbits > 23 } {
	    set hostbits [expr 32 - $maskbits]
	    set hostmask [expr pow(2,$hostbits)]
	    set netmask [expr 256 - $hostmask]
	    set netmask [expr round($netmask)]
	    set netoct [expr $oct4 & $netmask]
	    set netnumber "${oct1}.${oct2}.${oct3}.${netoct}"
	    set bcastoct [expr $netoct + round($hostmask) - 1 ]
	    set bcastaddress "${oct1}.${oct2}.${oct3}.${bcastoct}"
	} elseif { $maskbits > 15 } {
	    set hostbits [expr 24 - $maskbits]
	    set hostmask [expr pow(2,$hostbits)]
	    set netmask [expr 256 - $hostmask]
	    set netmask [expr round($netmask)]
	    set netoct [expr $oct3 & $netmask]
	    set netnumber "${oct1}.${oct2}.${netoct}.0"
	    set bcastoct [expr $netoct + round($hostmask) - 1 ]
	    set bcastaddress "${oct1}.${oct2}.${bcastoct}.255"
	} elseif { $maskbits > 7 } {
	    set hostbits [expr 16 - $maskbits]
	    set hostmask [expr pow(2,$hostbits)]
	    set netmask [expr 256 - $hostmask]
	    set netmask [expr round($netmask)]
	    set netoct [expr $oct3 & $netmask]
	    set netnumber "${oct1}.${netoct}.0.0"
	    set bcastoct [expr $netoct + round($hostmask) - 1 ]
	    set bcastaddress "${oct1}.${bcastoct}.255.255"
	} else {
	    set hostbits [expr 8 - $maskbits]
	    set hostmask [expr pow(2,$hostbits)]
	    set netmask [expr 256 - $hostmask]
	    set netmask [expr round($netmask)]
	    set netoct [expr $oct3 & $netmask]
	    set netnumber "${netoct}.0.0.0"
	    set bcastoct [expr $netoct + round($hostmask) - 1 ]
	    set bcastaddress "${bcastoct}.255.255.255"
	}
	set iplist [list $ipaddress $maskbits $netnumber $bcastaddress]
    }

    return $iplist
}

#
# InetAtoN:  Convert a string dotted quad ip address to decimal ala
#            INET_ATON in mysql
#
proc InetAtoN { ipaddress } {

    if { $ipaddress == "" } { return "" }
    set octetlist [split $ipaddress "."]
    set oct1 [lindex $octetlist 0]
    set oct2 [lindex $octetlist 1]
    set oct3 [lindex $octetlist 2]
    set oct4 [lindex $octetlist 3]
    set decIP [expr ($oct1 * 16777216.0) + ($oct2 * 65536.0) + ($oct3 * 256.0) + $oct4]
    return $decIP
}

proc GetCurrentTimeStamp {} {
  set timestamp [clock format [clock seconds] -gmt true -f "%Y-%m-%d %T"]
  return $timestamp
}

#
# ldelete: Delete item from a list
#
proc ldelete { list value } {
  set ix [lsearch -exact $list $value]
  if {$ix >= 0} {
    return [lreplace $list $ix $ix]
  } else {
    return $list
  }
}

#Reads file and sets email options
proc LoadEmailConfig { fileName } {

    global EMAIL_EVENTS SMTP_SERVER EMAIL_RCPT_TO
    global EMAIL_FROM EMAIL_SUBJECT EMAIL_MSG
    global EMAIL_CLASSES EMAIL_PRIORITIES EMAIL_DISABLE_SIDS EMAIL_ENABLE_SIDS

    set i 0

    for_file line $fileName {

        incr i

        if { ![regexp {^#} $line] && ![regexp {^$} $line] && ![regexp {^\s+$} $line] } {

            if { [llength $line] != 3 || [lindex $line 0] != "set" } { 

                ErrorMessage "Error at line $i in $fileName: $line"

            } else {

                if { [catch {eval $line} evalError] } {

                    ErrorMessage "Error parsing line $i in $fileName: $line\n\t$evalError"

                } 

            }

        } 

    }

    LogMessage "Email Configuration:"
    LogMessage "  Config file: $fileName"

    if {!$EMAIL_EVENTS} {

        LogMessage "  Enabled: No"

    } else {

        LogMessage "  Enabled: Yes"
        LogMessage "  Server: $SMTP_SERVER"
        LogMessage "  Rcpt To: $EMAIL_RCPT_TO"
        LogMessage "  From: $EMAIL_FROM"
        LogMessage "  Classes: $EMAIL_CLASSES"
        LogMessage "  Priorities: $EMAIL_PRIORITIES"
        LogMessage "  Disabled Sig IDs: $EMAIL_DISABLE_SIDS"
        LogMessage "  Enabled Sig IDs: $EMAIL_ENABLE_SIDS"

    }

}

# Reads file and adds queries to GLOBAL_QRY_LIST
proc LoadGlobalQueries { fileName } {
  global GLOBAL_QRY_LIST
  for_file line $fileName {
    if { ![regexp ^# $line] && ![regexp ^$ $line] } {
      lappend GLOBAL_QRY_LIST $line
    }
  }
}
# Reads file and adds report queries to REPORT_QRY_LIST
proc LoadReportQueries { fileName } {
    global REPORT_QRY_LIST
    set REPORT_QRY_LIST ""
    for_file line $fileName {
        if { ![regexp ^# $line] && ![regexp ^$ $line] } {
            set REPORT_QRY_LIST "${REPORT_QRY_LIST}${line}"
        }
    }
    #regsub -all {\n} $REPORT_QRY_LIST {} $REPORT_QRY_LIST
}

#  Puts an error to std_out or to syslog if in daemon
#  mode and then calls CleanExit {}
proc ErrorMessage { msg } {
    global DAEMON LOGGER
    if { $DAEMON && [string length $LOGGER] > 0 } {
	Syslog $msg err
    } else {
	puts "[GetCurrentTimeStamp] $msg"
    }
    CleanExit 1
}

#  Puts a message to std_out or to syslog if in daemon
#  mode only if debug == 2.  Use this for noisy less important
#  messages
proc InfoMessage { msg } {
    global DEBUG DAEMON LOGGER
    if { $DEBUG > 1 } {
	if { $DAEMON && [string length $LOGGER] > 0 } {
	    Syslog $msg info
	} else {
	    puts "[GetCurrentTimeStamp] pid([pid])  $msg"
	}
    }
}

#  Puts a message to std_out or to syslog if in daemon
#  mode only if debug >  0.  Use this for important messages
#  that we don't need to die on.
proc LogMessage { msg } {
    global DEBUG DAEMON LOGGER
    if { $DEBUG > 0 } {
	if { $DAEMON && [string length $LOGGER] > 0 } {
	    Syslog $msg notice
	} else {
	    puts "[GetCurrentTimeStamp] pid([pid])  $msg"
	}
    }
}

#  Logs a message to syslog to the facility defined by the
#  SyslogFacility conf option
proc Syslog { msg level } {
    global SYSLOGFACILITY
    # clean up mysql passwds
    regsub -all {password=\w+} $msg "password=XXXXXXXX " newMsg
    catch { exec logger -t "SGUILD" -p "$SYSLOGFACILITY.$level" $newMsg } logError
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
