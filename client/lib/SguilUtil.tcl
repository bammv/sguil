# $Id: SguilUtil.tcl,v 1.5 2005/01/26 17:12:12 shalligan Exp $
#
#  Sguil.Util.tcl:  Random and various tool like procs.
#
#
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
    set octetlist [split $ipaddress "."]
    set oct1 [lindex $octetlist 0]
    set oct2 [lindex $octetlist 1]
    set oct3 [lindex $octetlist 2]
    set oct4 [lindex $octetlist 3]
    # tcl uses type long for ints and this next expr could very well overflow that
    # so we have to use float instead
    set decIP [expr ($oct1 * 16777216.0) + ($oct2 * 65536) + ($oct3 *256) + $oct4]
    # we don't want the .0 in the query and we can't use round() since it may overflow the int type
    # so let treat it like a string and lop off the .0
    set decIP [string trimright $decIP ".0"
    return $decIP
}

#
# Send PING/PONG every 60 secs to keep comms open thru pesky FWs.
#
proc HeartBeat {} {
  global CONNECTED
  if {$CONNECTED} { SendToSguild "PING" }
  after 60000 HeartBeat
}

#
# GetCurrentTimeStamp: Returns date/time in YYYYY-MM-DD HH:MM:SS.
#
proc GetCurrentTimeStamp { {clockOption {today} } } {
  set timestamp [clock format [clock scan "$clockOption"] -gmt true -f "%Y-%m-%d %T"]
  return $timestamp
}

proc GetStatusNameByNumber { status } {
  switch -exact $status {
    1  { set statusName NA }
    2  { set statusName ES }
    11 { set statusName C1 }
    12 { set statusName C2 }
    13 { set statusName C3 }
    14 { set statusName C4 }
    15 { set statusName C5 }
    16 { set statusName C6 }
    17 { set statusName C7 }
    default { set statusName UN }
  }
}


proc CleanExit {} {
  puts "Goodbye."
  exit
}

proc GoToSleep {} {
  global SLEEP
  set SLEEP 1
  wm iconify .
}
proc WakeUp {} {
  global SLEEP
  set SLEEP 0
  wm deiconify .
  bell
}
proc DisplayUsage { cmdName } {
  puts "Usage: $cmdName -- \[-c <filename>\] \[-d <DEBUG level>\]"
  puts "  where <filename> is the PATH to the sguil config file"
  exit 1
}

proc GetCurrentFont { fontOptionsList } {
  set state flag
  foreach fontOption $fontOptionsList {
    switch -- $state {
      flag {
      	switch -exact -- $fontOption {
          -family 	{set state family}
          -size		{set state size}
	  -weight	{set state weight}
	  -slant	{set state slant}
	  -underline	{set state underline}
	  -overstrike	{set state overstrike}
          default	{set state unknown}
        }
      }
      family	{set family $fontOption; set state flag}
      size	{set size $fontOption; set state flag}
      weight	{lappend options $fontOption; set state flag}
      slant	{lappend options $fontOption; set state flag}
      underline { if {$fontOption} {lappend options underline}; set state flag}
      overstrike { if {$fontOption} {lappend options overstrike}; set state flag}
      unknown	{puts "Unknown flag"; set state flag}
      default	{puts "Unknown option"; set state flag}
    }
  }
  return "{$family} $size [list $options]"
}
proc ChangeFont  { fontType } {
  set newFont [dkf_chooseFont -parent . -title "Font Select" \
   -initialfont [GetCurrentFont [font configure $fontType]] ]
  GetCurrentFont [font configure $fontType]
  if { [llength $newFont] == 0 } { return }
  eval font configure $fontType [ParseFontInfo $newFont]
  SaveNewFonts
}
proc SaveNewFonts {} {
  global FONTFILE
  write_file $FONTFILE "ourStandardFont [font configure ourStandardFont]" "ourFixedFont [font configure ourFixedFont]"
}



proc Working {} {
  global BUSY
  . configure -cursor watch
  set BUSY 1
}
proc Idle {} {
  global BUSY
  . configure -cursor left_ptr
  set BUSY 0
}