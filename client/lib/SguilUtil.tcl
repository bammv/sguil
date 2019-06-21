# $Id: SguilUtil.tcl,v 1.22 2007/05/16 19:07:31 bamm Exp $
#
#  Sguil.Util.tcl:  Random and various tool like procs.
#
package require ip
package require textutil
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
    
    set version [ip::version $fullip]
    if { -1 == $version } { return 0 }

    foreach {ipaddress mask} [split $fullip /] break

    set mask [ip::mask $fullip]
    switch -exact $version {
	4 {
	    if { "" == $mask } {
	        set mask 32
	    	set netnumber $fullip
	        set bcastaddress $fullip
	    } elseif { $mask < 0 || $mask > 32} {
		return 0
	    } else {
	    	set netnumber [ip::prefix $fullip]
	    	set bcastaddress [ip::broadcastAddress $fullip]
	    }
	  }
	6 {
	    if { "" == $mask } {
	        set mask 128
	    	set netnumber $fullip
	        set bcastaddress $fullip
	    } elseif { $mask < 0 || $mask > 128} {
		return 0
	    } else {
	    	set netnumber [ip::prefix $fullip]
        	set hostpart ""
        	set reminder [expr 128 - $mask]
        	set hostpart [string repeat 0 $mask]
        	append hostpart [string repeat 1 $reminder]
        	set normIP [ip::normalize $ipaddress]
        	set ipparts [split $normIP ":"]
        	set binip ""
        	foreach part $ipparts {
                	binary scan [binary format H* $part] B* bits
                	append binip $bits
        	}
        	set bbin [expr (0b$binip | 0b$hostpart)]
        	set bhex [format %032llx $bbin]
        	set bcastaddress [join [textutil::splitn $bhex 4] :]
	    }
	  }
    }

    set iplist [list $ipaddress $mask $netnumber $bcastaddress]

    return $iplist
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

    global FONTFILE SERVERHOST ES_PROFILE


    if [catch {write_file $FONTFILE \
      "ourStandardFont [font configure ourStandardFont]" \
      "ourFixedFont [font configure ourFixedFont]" \
      "RecentServersList $SERVERHOST" \
      "[list ESProfile $ES_PROFILE(host) $ES_PROFILE(user) $ES_PROFILE(auth)]" \
      } writError] {

        InfoMessage "Unable to write preferences to $FONTFILE"

    }

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

# Signs and/or encrypts provided text using gpg
# Requires a valid GPG_PATH in sguil.conf
proc GpgText { winName sign encrypt text recips sender } {
    global GPG_PATH env
    # get the senders gpg passphrase
    set recipstr ""
    foreach recip $recips {
	set recipstr "$recipstr -r $recip "
    }
    set DONE 0
    set passPrompt [promptdialog $winName.pd -modality global -title Passphrase -labeltext "GPG Passphrase:" -show *]
    while { !$DONE } {
	if { $sign } {
	    $passPrompt hide Apply
	    $passPrompt hide Help
	    $passPrompt center
	    focus [$passPrompt component prompt component entry]
	    if { [$passPrompt activate] } {
		set passphrase [$passPrompt get]
	    } else {
		destroy $passPrompt
		return cancel
	    }
	}
	# write the text out to a tempfile
	random seed
	set tempOutFile "$env(HOME)/gpgout-[random 100000]"
	set tempOutFID [open $tempOutFile w]
	puts $tempOutFID $text
	close $tempOutFID
	set tempInFile "$tempOutFile.asc"
	if { $sign && $encrypt } {
	    set gpgcmd "$GPG_PATH -ase --yes --passphrase-fd 0 -u $sender --no-tty $recipstr --batch $tempOutFile"
	} elseif { $encrypt } {
	    set gpgcmd "$GPG_PATH -ae --yes -u $sender --no-tty $recipstr --batch $tempOutFile"
	} else {
	    set gpgcmd "$GPG_PATH --clearsign --yes --passphrase-fd 0 -u $sender --no-tty --batch $tempOutFile"
	}

	if [ catch {open "| $gpgcmd" r+ } gpgID ] { 
	    ErrorMessage $gpgID
	    destroy $passPrompt
	    return cancel
	}
	if { $sign } {
	    puts $gpgID "$passphrase\n"
	}
	flush $gpgID
	if [ catch {close $gpgID } err ] { 
	    if [regexp "gpg: skipped.*bad passphrase" $err realerr] {
		ErrorMessage "GPG Error: $realerr"
		destroy $passPrompt
		continue
	    } else {
		ErrorMessage "GPG Error: $err"
		destroy $passPrompt
		return cancel
	    }
	} else {
	    set DONE 1
	}
    }
    set tempInFID [open $tempInFile r]
    set newtext [read $tempInFID]
    close $tempInFID
    # delete the temp files
    file delete $tempInFile
    file delete $tempOutFile
    destroy $passPrompt
    return $newtext
}

# 
# DecodeICMP: Breaks an ICMP Payload out into fields
#             Returns a List of the ICMP Fields in this order:
#             {GatewayIP} {Protocol} {SourceIP} {DestIP} {SourcePort} {DestPort}
#
proc DecodeICMP { type code payload } {
    
    set GatewayIP ""
    set Protocol ""
    set SourceIP ""
    set DestIP ""
    set SourcePort ""
    set DestPort ""
    
    if { $type  == "3" || $type == "11" || $type == "5"} {
	if { $code == "0" || $code  == "4" || $code == "9" || $code == "13" || $code == "1" || \
		 $code == "3" || $code == "2" } {
	    
	    #  There may be 32-bits of NULL padding at the start of the payload
	    # or a 32-bit gateway address on a redirect
	    set offset 0
	    if {[string range $payload 0 7] == "00000000" || $type == "5"} {
		set offset 8
		if { $type == "5"} {
		    set giphex1 [string range $payload 0 1]
		    set giphex2 [string range $payload 2 3]
		    set giphex3 [string range $payload 4 5]
		    set giphex4 [string range $payload 6 7]
		    set GatewayIP [format "%i" 0x$giphex1].[format "%i" 0x$giphex2].[format "%i" 0x$giphex3].[format "%i" 0x$giphex4]
		}
	    }
	    
	    # Build the protocol
	    set protohex [string range $payload [expr $offset+18] [expr $offset+19]]
	    set Protocol [format "%i" 0x$protohex]

	    # Build the src address
	    set srchex1 [string range $payload [expr $offset+24] [expr $offset+25]]
	    set srchex2 [string range $payload [expr $offset+26] [expr $offset+27]]
	    set srchex3 [string range $payload [expr $offset+28] [expr $offset+29]]
	    set srchex4 [string range $payload [expr $offset+30] [expr $offset+31]]
	    set SourceIP [format "%i" 0x$srchex1].[format "%i" 0x$srchex2].[format "%i" 0x$srchex3].[format "%i" 0x$srchex4]
	    
	    # Build the dst address
	    set dsthex1 [string range $payload [expr $offset+32] [expr $offset+33]]
	    set dsthex2 [string range $payload [expr $offset+34] [expr $offset+35]]
	    set dsthex3 [string range $payload [expr $offset+36] [expr $offset+37]]
	    set dsthex4 [string range $payload [expr $offset+38] [expr $offset+39]]
	    set DestIP [format "%i" 0x$dsthex1].[format "%i" 0x$dsthex2].[format "%i" 0x$dsthex3].[format "%i" 0x$dsthex4]
	    
	    # Find and build the src port
	    set hdroffset [expr [string index $payload [expr ($offset+1)]] * 8 + $offset]
	    set sporthex [string range $payload $hdroffset [expr $hdroffset+3]]
	    set SourcePort [format "%i" 0x$sporthex]
	    
	    # Dest Port
	    set dporthex [string range $payload [expr $hdroffset+4] [expr $hdroffset+7]]
	    set DestPort [format "%i" 0x$dporthex]
	    
	    # Create the list to return 
	    set ICMPList [list $GatewayIP $Protocol $SourceIP $DestIP $SourcePort $DestPort]
	} else {
	    # not a decodable code
	    set ICMPList "NA"
	}
    } else {
	# not a decodable type
	set ICMPList "NA"
    }
    
    return $ICMPList
}
proc DecodeSFPPayload { payload } {
    set asciiPayload ""
    set dataLength [string length $payload]
    #convert the hex payload string into ascii
    for {set i 1} {$i < $dataLength} {incr i 2} {
	set currentByte [string range $payload [expr $i - 1] $i]
	set intValue [format "%i" 0x$currentByte]
	if { $intValue < 32 || $intValue > 126 } {
	    # Non printable char
	    set currentChar "."
	} else {
	    set currentChar [format "%c" $intValue]
	}
	set asciiPayload "${asciiPayload}${currentChar}"
    }
    
    # Regexp the pertainant fields out of the ascii payload
     set regStr "Priority Count: (\\d*)\.Connection Count: (\\d*)\.IP Count: (\\d*)\.Scanne. IP Range: (\\d*\.\\d*\.\\d*\.\\d*:\\d*\.\\d*\.\\d*\.\\d*).Port/Proto Count: (\\d*).Port/Proto Range: (\\d*:\\d*)."
    if [regexp $regStr $asciiPayload fullmatch PriorityCount ConnectCount IPCount IPRange PortCount PortRange] {
	regsub ":" $IPRange "-" IPRange
	regsub ":" $PortRange "-" PortRange
	set SFPList [list $PriorityCount $ConnectCount $IPCount $IPRange $PortCount $PortRange]
    } else { 
	set SFPList "NOMATCH"
    }
    return $SFPList
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

