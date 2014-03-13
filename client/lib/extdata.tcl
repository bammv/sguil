################################################
# Sguil proc for getting/displaying external   #
# data (rules, references, xscript, dns,       #
# etc)                                         #
################################################
# $Id: extdata.tcl,v 1.70 2011/06/29 03:07:26 bamm Exp $

proc GetRuleInfo {} {

    global CUR_SEL_PANE ACTIVE_EVENT SHOWRULE socketID DEBUG MULTI_SELECT
    global CONNECTED eventArray generatorListMap sigIDListMap

    ClearRuleText

    if {$ACTIVE_EVENT && $SHOWRULE && !$MULTI_SELECT && $CUR_SEL_PANE(type) == "EVENT"} {

        if {!$CONNECTED} {
            ErrorMessage "Not connected to sguild. Cannot make rule request."
            return
        }

        set win $CUR_SEL_PANE(name)
        set selectedIndex [$CUR_SEL_PANE(name) curselection]

        set event_id [$CUR_SEL_PANE(name) getcells $selectedIndex,alertID]
        set genID $generatorListMap($event_id)

        if { $genID != "1" } {

            # For the detection engine only. Generator ID 1.
            ClearRuleText
            InsertRuleData "Rules and signatures are not available for the generator ID ${genID}."
            return

        }

        set sigID [lindex $sigIDListMap($event_id) 0]
        set sigRev [lindex $sigIDListMap($event_id) 1]

        set sensorName [$CUR_SEL_PANE(name) getcells $selectedIndex,sensor]

        if {$DEBUG} {puts "[list RuleRequest $event_id $sensorName]"}

        SendToSguild [list RuleRequest $event_id $sensorName $genID $sigID $sigRev]

    }

}

proc ClearRuleText {} {
 
    global ruleText

    $ruleText component text configure -state normal
    $ruleText clear
    $ruleText component text configure -state disabled

}
proc InsertRuleData { ruleData } {

    global ruleText 

    $ruleText component text configure -state normal

    # Check for line # match
    if [regexp {^/.*: Line [0-9]} $ruleData] {

        # Just a msg noting what rule and line # matched
        $ruleText component text insert end "$ruleData"

    } else {

        # This is the actual rule
        $ruleText component text insert end "$ruleData\n"

        set w [$ruleText component text]

        #Remove any existing tags
        eval {$w tag delete} [$w tag names]

        # Find the sid for sid_ref() links
        set sidIndex [$w search -count length -regexp -- {sid:.*?;} 0.0 end]
        if { $sidIndex != "" } {

            set row [lindex [split $sidIndex .] 0]
            set col [lindex [split $sidIndex .] 1]
            set start "$row.[expr $col + 4]"
            set end "$row.[expr [lindex [split $sidIndex .] 1] + $length - 1]"
            set sid [lindex [split [$w get $sidIndex $end] :] 1]
            $ruleText component text tag configure SID -foreground blue -underline 0
            $w tag add SID $start "$start + [expr $length - 5] char"
            $w tag bind SID <Enter> { %W configure -cursor hand2 }
            $w tag bind SID <Leave> { %W configure -cursor left_ptr }
            $w tag bind SID <ButtonRelease-1> [list DisplayReference %W $sidIndex $length]

        }

        # Marks all the reference tags.
        set i 0
        set cur 1.0
        while 1 {
	    set cur [$w search -count length -regexp -- {reference:.*?;} $cur end]
	    if {$cur == ""} {
	        break
	    }

            set row [lindex [split $cur .] 0]
            set col [lindex [split $cur .] 1]
            set start "$row.[expr $col + 10]"

            $ruleText component text tag configure URL$i -foreground blue -underline 0
	    $w tag add URL$i $start "$start + [expr $length - 11] char"
            $w tag bind URL$i <Enter> { %W configure -cursor hand2 }
            $w tag bind URL$i <Leave> { %W configure -cursor left_ptr }
            $w tag bind URL$i <ButtonRelease-1> [list DisplayReference %W $cur $length]
	    set cur [$w index "$cur + $length char"]
            incr i
        }

    }

    $ruleText component text configure -state disabled

}

proc DisplayReference { win start length } {

    global BROWSER_PATH sid_ref
    
    if { ![info exists BROWSER_PATH] } { 
        ErrorMessage "Error: BROWSER_PATH is NOT defined."
        return
    }

    if { ![file exists $BROWSER_PATH] || ![file executable $BROWSER_PATH] } {
        ErrorMessage "Error: The application $BROWSER_PATH does not exist or is not executable."
        return
    }

    set row [lindex [split $start .] 0]
    set end "$row.[expr [lindex [split $start .] 1] + $length]"
    set ref [$win get $start $end]

    set type ""
    if ![regexp {^reference:\s*(.*?),(.*?);} $ref match type content] {

        # Not a reference, maybe sid. 
        if [regexp {^(sid):\s*([0-9]*);} $ref match type content] { set foo bar }

    }
 
     switch -exact -- $type {

        url        { exec $BROWSER_PATH http://$content & }
        bugtraq    { exec $BROWSER_PATH http://www.securityfocus.com/bid/$content & }
        cve        { exec $BROWSER_PATH http://nvd.nist.gov/nvd.cfm?cvename=CAN-$content & }
        nessus     { exec $BROWSER_PATH http://cgi.nessus.org/plugins/dump.php3?id=$content & }
        mcafee     { exec $BROWSER_PATH http://vil.nai.com/vil/content/v_$content & }
        arachnids  { InfoMessage "ArachNIDS references are no long supported." }
        sid        { 
                     set f 0
                     foreach a [array names sid_ref] {
                         set min [lindex $sid_ref($a) 1]
                         set max [lindex $sid_ref($a) 2]
                         set uri "[lindex $sid_ref($a) 0]$content"
                         if { $content >= $min && $content <= $max } { exec $BROWSER_PATH $uri; set f 1; break }
                     }
                     if { !$f } { InfoMessage "Unable to find url for sid $content. Check your sguil.conf." } 
        }
        default    { InfoMessage "Unknown reference in rule: $ref" }

    }

}

proc GetDshieldIP { arg } {

    global DEBUG BROWSER_PATH CUR_SEL_PANE ACTIVE_EVENT MULTI_SELECT

    if { $ACTIVE_EVENT && !$MULTI_SELECT} {

        set selectedIndex [$CUR_SEL_PANE(name) curselection]

        if { $arg == "srcip" } {
            set ipAddr [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]
        } else {
            set ipAddr [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]
        }

        if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {

            # Launch browser
	    exec $BROWSER_PATH http://www.dshield.org/ipinfo.php?ip=$ipAddr &

        } else {

            tk_messageBox -type ok -icon warning -message\
             "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
              to point your favorite browser."
            puts "Error: $BROWSER_PATH does not exist or is not executable."

        }

    }

}

proc GetDshieldPort { arg } {

    global DEBUG BROWSER_PATH CUR_SEL_PANE ACTIVE_EVENT MULTI_SELECT

    if { $ACTIVE_EVENT && !$MULTI_SELECT} {
 
        set selectedIndex [$CUR_SEL_PANE(name) curselection]

        if { $arg == "srcport" } {
            set ipPort [$CUR_SEL_PANE(name) getcells $selectedIndex,srcport]
        } else {
            set ipPort [$CUR_SEL_PANE(name) getcells $selectedIndex,dstport]
        }

        if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {

            # Launch browser
	    exec $BROWSER_PATH http://www.dshield.org/port.html?port=$ipPort &

        } else {

            tk_messageBox -type ok -icon warning -message\
             "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
              to point your favorite browser."
            puts "Error: $BROWSER_PATH does not exist or is not executable."
        }

    }

}

#
# DnsButtonActy: Called when the reverse DNS button is released
#
proc ResolveHosts {} {

    global REVERSE_DNS CUR_SEL_PANE ACTIVE_EVENT MULTI_SELECT

    ClearDNSText

    if {$REVERSE_DNS && $ACTIVE_EVENT && !$MULTI_SELECT} {

        Working

        set selectedIndex [$CUR_SEL_PANE(name) curselection]
        # PADS data only has a single IP
        if { $CUR_SEL_PANE(type) == "PADS" } {

            set ip [$CUR_SEL_PANE(name) getcells $selectedIndex,ip]
            set name [GetHostbyAddr $ip]
            InsertDNSData $ip $name $ip $name

        } else {

            set srcIP [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]
            set dstIP [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]
            set srcName [GetHostbyAddr $srcIP]
            set dstName [GetHostbyAddr $dstIP]
            InsertDNSData $srcIP $srcName $dstIP $dstName

        }

        Idle

    }

}

proc GetWhoisData {} {

    global ACTIVE_EVENT CUR_SEL_PANE WHOISLIST whoisText WHOIS_PATH MULTI_SELECT

    ClearWhoisData

    $whoisText configure -state normal

    if {$ACTIVE_EVENT && $WHOISLIST != "none" && !$MULTI_SELECT} {

        Working
        update
        set selectedIndex [$CUR_SEL_PANE(name) curselection]

        if { $CUR_SEL_PANE(type) == "PADS" } { 

            set ip [$CUR_SEL_PANE(name) getcells $selectedIndex,ip]

        } else {

            set ip [$CUR_SEL_PANE(name) getcells $selectedIndex,$WHOISLIST]

        }

        if { $WHOIS_PATH == "SimpleWhois" } {

            foreach line [SimpleWhois $ip] {

                $whoisText insert end "$line\n"
            }

        } else {

            $whoisText insert end "Attempting whois query on $ip\n"
            update
            set whoisCommandID [open "| $WHOIS_PATH $ip" r]

            while { [gets $whoisCommandID data] >= 0 } {

                $whoisText insert end "$data\n"

            }

            catch {close $whoisCommandID} closeError
            $whoisText insert end $closeError

        }

        Idle

    }

    $whoisText configure -state disabled

}

proc GetSQLAddrsFromHostname { hostname } {

    set addrs [GetHostbyName $hostname]

    if { $addrs == "Unknown" } {
	ErrorMessage "The hostname $hostname could not be resolved."
	return $hostname
    } else {
	regsub -all {(\d+\.\d+\.\d+\.\d+)} $addrs {INET_ATON("\1"), } addrs
	regsub {,\s*$} $addrs {} addrs
    }

    return $addrs
}


#
# GetHostbyName: uses extended tcl (wishx) to get an hostname's IP, or list
# of IPs (space-separated)
#
proc GetHostbyName { hostname } {

    global EXT_DNS EXT_DNS_SERVER HOME_DOMAINS

    # In case there are any # chars in the hostname (from the Query Builder
    # substitutions) get rid of them.
    regsub -all {#} $hostname {} hostname

    if { $EXT_DNS } {

        if { ![info exists EXT_DNS_SERVER] } { 

            ErrorMessage "An external name server has not been configured in sgu
il.conf. Resolution aborted." 
            return

        } else {
	    set nameserver $EXT_DNS_SERVER

	    if { [info exists HOME_DOMAINS] } { 
		# Loop through HOME_DOMAINS.  If lookup domain matches
		# any of these home domains, use the locally configured
		# nameserver
		foreach homeDomain $HOME_DOMAINS {
		    if {[regexp "$homeDomain$" $hostname]} { set nameserver local}
		}
	    }

	    # If there are no '.' chars in the hostname, assume it's local
	    # In reality, the tcllib DNS resolver usually doesn't look up
	    # unqualified hostnames anyway, so this will most likely result
	    # in an error later.  But at least the names won't be leaked
	    # to an external DNS server.
	    if { ![regexp "\\." $hostname] } { set nameserver local }

	}
    }  else {
	set nameserver local
    }

    if { $nameserver == "local" } {
	set tok [dns::resolve $hostname]
    } else {
	set tok [dns::resolve $hostname -nameserver $nameserver]
    }

    # Wait for the request to finish
    dns::wait $tok

    set ip [dns::address $tok]
    dns::cleanup $tok
    if { $ip == "" } { set ip "Unknown" }
    return $ip

}




#
# GetHostbyAddr: uses extended tcl (wishx) to get an ips hostname
#                May move to a server func in the future
#
proc GetHostbyAddr { ip } {

    global EXT_DNS EXT_DNS_SERVER HOME_NET

    if { $ip == "" } { return }

    if { $EXT_DNS } {

        if { ![info exists EXT_DNS_SERVER] } { 

            ErrorMessage "An external name server has not been configured in sguil.conf. Resolution aborted." 
            return

        } else {

            set nameserver $EXT_DNS_SERVER

            if { [info exists HOME_NET] } { 

                # Loop thru HOME_NET. If ip matches any networks than use a the locally configured
                # name server
                foreach homeNet $HOME_NET {

                    set netMask [ip::mask $homeNet]
                    if { [ip::equal ${ip}/${netMask} $homeNet] } { set nameserver local }

                }

            }

        }

    } else { 

        set nameserver local

    }

    if { $nameserver == "local" } {

        set tok [dns::resolve $ip]

    } else {

        set tok [dns::resolve $ip -nameserver $nameserver]

    }

    # Wait for the request to finish
    dns::wait $tok

    set hostname [dns::name $tok]
    dns::cleanup $tok
    if { $hostname == "" } { set hostname "Unknown" }
    return $hostname

}

#
# ClearDNSText: Clears the src/dst dns results
#
proc ClearDNSText {} {
    global srcDnsDataEntryTextFrame dstDnsDataEntryTextFrame

    foreach i "nameText ipText" {

      $srcDnsDataEntryTextFrame.$i configure -state normal
      $dstDnsDataEntryTextFrame.$i configure -state normal
      $srcDnsDataEntryTextFrame.$i delete 0.0 end
      $dstDnsDataEntryTextFrame.$i delete 0.0 end
      $srcDnsDataEntryTextFrame.$i configure -state disabled
      $dstDnsDataEntryTextFrame.$i configure -state disabled

    }

} 

proc InsertDNSData { srcIP srcName dstIP dstName} {

    global srcDnsDataEntryTextFrame dstDnsDataEntryTextFrame

    $srcDnsDataEntryTextFrame.ipText configure -state normal
    $srcDnsDataEntryTextFrame.nameText configure -state normal
    $dstDnsDataEntryTextFrame.ipText configure -state normal
    $dstDnsDataEntryTextFrame.nameText configure -state normal

    $srcDnsDataEntryTextFrame.ipText insert 0.0 $srcIP
    $srcDnsDataEntryTextFrame.nameText insert 0.0 $srcName
    $dstDnsDataEntryTextFrame.ipText insert 0.0 $dstIP
    $dstDnsDataEntryTextFrame.nameText insert 0.0 $dstName

    $srcDnsDataEntryTextFrame.ipText configure -state disabled
    $srcDnsDataEntryTextFrame.nameText configure -state disabled
    $dstDnsDataEntryTextFrame.ipText configure -state disabled
    $dstDnsDataEntryTextFrame.nameText configure -state disabled

}
proc ClearWhoisData {} {
    global whoisText

    $whoisText configure -state normal
    $whoisText delete 0.0 end
    $whoisText configure -state disabled

}

proc CreateXscriptWin { winName } {
    toplevel $winName
    menubutton $winName.menubutton -underline 0 -text File -menu $winName.menubutton.menu
    menu $winName.menubutton.menu -tearoff 0
    $winName.menubutton.menu add command -label "Save As" -command "SaveXscript $winName"
    $winName.menubutton.menu add command -label "Close Window" -command "destroy $winName"
    scrolledtext $winName.sText -vscrollmode dynamic -hscrollmode dynamic -wrap word\
	    -visibleitems 85x30 -sbwidth 10
    $winName.sText tag configure hdrTag -foreground black -background "#00FFFF"
    $winName.sText tag configure srcTag -foreground blue
    $winName.sText tag configure dstTag -foreground red
    
  scrolledtext $winName.debug -vscrollmode dynamic -hscrollmode none -wrap word\
   -visibleitems 85x5 -sbwidth 10 -labeltext "Debug Messages" -textbackground lightblue
  set termButtonFrame [frame $winName.termButtonsFrame]
    button $termButtonFrame.searchButton -text "Search" -command "SearchDialog $winName" 
    button $termButtonFrame.abortButton -text "Abort " -command "AbortXscript $winName" 
    button $termButtonFrame.closeButton -text "Close" -command "CleanupXscriptWin $winName"
    pack $termButtonFrame.searchButton $termButtonFrame.abortButton $termButtonFrame.closeButton \
     -side left -padx 0 -expand true
  pack $winName.menubutton -side top -anchor w
  pack $winName.sText $termButtonFrame $winName.debug \
   -side top -fill both -expand true
}
proc AbortXscript { winName } {
  $winName.termButtonsFrame.abortButton configure -state disabled
  SendToSguild [list AbortXscript $winName]
}

proc SearchDialog { winName } {

    set dg ${winName}dg

    if { ![winfo exists $dg] } {

        iwidgets::finddialog $dg \
         -textwidget $winName.sText \
         -patternbackground yellow \
         -patternforeground red

        wm title $dg "$winName - Search"

    }
    
    $dg activate

}

proc CleanupXscriptWin { winName } {

    if { [winfo exists $winName] } { destroy $winName }
    set dg ${winName}dg
    if { [winfo exists $dg] } { destroy $dg }

}

proc XscriptMainMsg { winName data } {
  global XSCRIPTDATARCVD SESSION_STATE
  if { ! [winfo exist $winName] } {
    CreateXscriptWin $winName
  }
  if {! $XSCRIPTDATARCVD($winName)} {
    $winName.sText clear
    set XSCRIPTDATARCVD($winName) 1
  }
  switch -exact -- $data {
     HDR    { set SESSION_STATE($winName) HDR }
     SRC    { set SESSION_STATE($winName) SRC }
     DST    { set SESSION_STATE($winName) DST }
     DEBUG  { set SESSION_STATE($winName) DEBUG }
     DONE   { unset SESSION_STATE($winName)
              unset XSCRIPTDATARCVD($winName)
              InsertXscriptData $winName DEBUG "Finished."
              $winName.sText configure -cursor left_ptr
            }
     ERROR { set SESSION_STATE($winName) ERROR }
     default { InsertXscriptData $winName $SESSION_STATE($winName) $data }
  }
}
  
proc InsertXscriptData { winName state data } {
  if { $state == "HDR" } {
    $winName.sText component text insert end "$data\n" hdrTag
  } elseif { $state == "SRC" } {
    $winName.sText component text insert end "$state: $data\n" srcTag
  } elseif { $state == "DST" } { 
    $winName.sText component text insert end "$state: $data\n" dstTag
  } elseif { $state == "ERROR" } {
    puts "data: $data"
    if { $data != "" } {
      ErrorMessage "$data"
    }
  } else {
    $winName.debug component text insert end "$data\n"
    $winName.debug see end
  } 
}
proc XscriptDebugMsg { winName data } {
    if [winfo exists $winName] {
      $winName.debug component text insert end "$data\n"
      $winName.debug see end
    }
}

proc PcapAvailable { socketID sKey fileName } {

    global WIRESHARK_STORE_DIR WIRESHARK_PATH

    # Windows doesn't like colons
    regsub -all {:} [file tail $fileName] {_} fileName

    set fileName $WIRESHARK_STORE_DIR/$fileName
    if { [catch {open $fileName w} outfileID] } {

        ErrorMessage "Error opening $fileName. $outfileID"
        return

    }

    # Make a new connection to sguild.
    if { [catch {ConnectToSguild} dataSocketID] } {

        ErrorMessage "Failed to connect to sguild. Cannot copy pcap $fileName\n\n$dataSocketID"
        return

    }

    puts $dataSocketID [list SendPcap $sKey]

    fconfigure $dataSocketID -translation binary
    fconfigure $outfileID -translation binary

    if { [catch {fcopy $dataSocketID $outfileID \
      -command [list PcapCopyFinished $fileName $outfileID $dataSocketID]} tmpError] } {

        # fcopy failed
        ErrorMessage "Failed to copy file. $tmpError"
        catch {close $outfileID}
        catch {close $dataSocketID}

    }

}

proc PcapCopyFinished { fileName outfileID dataSocketID bytes {error {}} } {

    global WIRESHARK_PATH

    # Data copy finished
    catch {close $outfileID}
    catch {close $dataSocketID}

    if { [string length $error] != 0 } {

        ErrorMessage "Error during copy to $fileName. $error"

    }

    
    eval exec $WIRESHARK_PATH -n -r $fileName &

    InfoMessage\
     "Raw file is stored in $fileName. Please delete when finished"

}

proc WiresharkDataPcap { socketID fileName bytes } {
  global WIRESHARK_STORE_DIR WIRESHARK_PATH
  set outFileID [open $WIRESHARK_STORE_DIR/$fileName w]
  fconfigure $outFileID -translation binary
  fconfigure $socketID -translation binary
  fcopy $socketID $outFileID -size $bytes
  close $outFileID
  fconfigure $socketID -encoding utf-8 -translation {auto crlf}
  eval exec $WIRESHARK_PATH -n -r $WIRESHARK_STORE_DIR/$fileName &
  InfoMessage\
   "Raw file is stored in $WIRESHARK_STORE_DIR/$fileName. Please delete when finished"
}
# Archiving this till I know for sure binary xfers are working correctly
proc WiresharkDataBase64 { fileName data } {
  global WIRESHARK_PATH WIRESHARK_STORE_DIR b64FileID DEBUG
  if { $data == "BEGIN" } {
    set tmpFileName $WIRESHARK_STORE_DIR/${fileName}.base64
    set b64FileID($fileName) [open $tmpFileName w]
  } elseif { $data == "END" } {
    if [info exists b64FileID($fileName)] {
      close $b64FileID($fileName)
      set outFileID [open $WIRESHARK_STORE_DIR/$fileName w]
      set inFileID [open $WIRESHARK_STORE_DIR/${fileName}.base64 r]
      fconfigure $outFileID -translation binary
      fconfigure $inFileID -translation binary
      puts -nonewline $outFileID [::base64::decode [read -nonewline $inFileID]]
      close $outFileID
      close $inFileID
      file delete $WIRESHARK_STORE_DIR/${fileName}.base64
      eval exec $WIRESHARK_PATH -n -r $WIRESHARK_STORE_DIR/$fileName &
      InfoMessage "Raw file is stored in $WIRESHARK_STORE_DIR/$fileName. Please delete when finished"
    }
  } else {
    if [info exists b64FileID($fileName)] {
      puts $b64FileID($fileName) $data
    }
  }
}

proc GetXscript { type force } {

    global ACTIVE_EVENT SERVERHOST XSCRIPT_SERVER_PORT DEBUG CUR_SEL_PANE XSCRIPTDATARCVD
    global socketWinName SESSION_STATE WIRESHARK_STORE_DIR WIRESHARK_PATH

    if {!$ACTIVE_EVENT} {return}

    set selectedIndex [$CUR_SEL_PANE(name) curselection]
    set sidcidList [split [$CUR_SEL_PANE(name) getcells $selectedIndex,alertID] .]
    set cnxID [lindex $sidcidList 1]
    set sensorID [lindex $sidcidList 0]
    set proto [$CUR_SEL_PANE(name) getcells $selectedIndex,ipproto]

    if { $CUR_SEL_PANE(format) == "SSN" } {

        set timestamp [$CUR_SEL_PANE(name) getcells $selectedIndex,starttime]

    } else {

        set timestamp [$CUR_SEL_PANE(name) getcells $selectedIndex,date]

    }

    if { $type == "xscript" && $proto != "6" } {

        tk_messageBox -type ok -icon warning -message\
         "Transcripts can only be generated for TCP traffic at this time."
        return

    }

    set sensor [$CUR_SEL_PANE(name) getcells $selectedIndex,sensor]
    set srcIP [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]
    set srcPort [$CUR_SEL_PANE(name) getcells $selectedIndex,srcport]
    set dstIP [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]
    set dstPort [$CUR_SEL_PANE(name) getcells $selectedIndex,dstport]

    set xscriptWinName ".[string tolower ${sensor}]_${cnxID}"

    if { $type == "xscript"} {

        if { ![winfo exists $xscriptWinName] } {

            CreateXscriptWin $xscriptWinName

        } else {

            InfoMessage "This transcipt is already being displayed by you. Please close\
             that window before you request a new one."
            # Try and bring the window to the top in case it is hidden.
            wm withdraw $xscriptWinName
            wm deiconify $xscriptWinName
            return
        }

        set SESSION_STATE($xscriptWinName) HDR
        XscriptDebugMsg $xscriptWinName\
         "Your request has been sent to the server.\nPlease be patient as this can take some time."
        $xscriptWinName.sText configure -cursor watch
        set XSCRIPTDATARCVD($xscriptWinName) 0
        SendToSguild [list XscriptRequest $sensor $sensorID $xscriptWinName $timestamp $srcIP $srcPort $dstIP $dstPort $force]

        if {$DEBUG} {
            puts "Xscript Request sent: [list $sensor $sensorID $xscriptWinName $timestamp $srcIP $srcPort $dstIP $dstPort $force]"
        }
  
    } elseif { $type == "wireshark" } {

        # If WIRESHARK_PATH isn't set use the default location /usr/sbin/wireshark
        if { ![info exists WIRESHARK_PATH] } { set WIRESHARK_PATH /usr/sbin/wireshark }

        # Make sure the file exists and is executable.
        if { ![file exists $WIRESHARK_PATH] || ![file executable $WIRESHARK_PATH] } {

            tk_messageBox -type ok -icon warning -message \
             "Unable to find wireshark to process this request. Looked in $WIRESHARK_PATH. Please \
              check your sguil.conf."
            return

        }

        if {$DEBUG} {
            puts "Wireshark Request sent: [list $sensor $sensorID $timestamp $srcIP $srcPort $dstIP $dstPort $proto $force]"
        }

        SendToSguild [list WiresharkRequest $sensor $sensorID $timestamp $srcIP $srcPort $dstIP $dstPort $proto $force]

    }

}

proc CopyDone { socketID tmpFileID tmpFile bytes {error {}} } {
  global DEBUG WIRESHARK_PATH
  close $tmpFileID
  close $socketID
  if {$DEBUG} {puts "Bytes Transfered: $bytes"}
  if { $bytes == 0 } { 
    ErrorMessage "No data available." 
    file delete $tmpFileID
  } else {
    eval exec $WIRESHARK_PATH -n -r $tmpFile &
    InfoMessage "Raw file is stored in $tmpFile. Please delete when finished"
  }
}
proc CopyRawData { socketID tmpFileID tmpFile } {
  catch {fcopy $socketID $tmpFileID -command [list CopyDone $socketID $tmpFileID $tmpFile]} dataError
}
proc SaveXscript { win } {
  set initialFile [string trimleft $win .]
  set saveFile [tk_getSaveFile -parent $win -initialfile $initialFile.txt]
  if { $saveFile == "" } {
    tk_messageBox -type ok -icon warning -parent $win -message\
     "No filename selected. Transcipt was NOT saved."
    return
  }
  if { [catch {$win.sText export $saveFile} saveError] } {
    tk_messageBox -type ok -icon warning -parent $win -message $saveError
  }
}

proc SensorStatusRequest {} {

    global STATUS_UPDATE CONNECTED

    if { ![info exists STATUS_UPDATE]} {

        set STATUS_UPDATE 15

    }

    if { $CONNECTED } {

        SendToSguild "SendClientSensorStatusInfo"

    }

    after [expr $STATUS_UPDATE * 1000] SensorStatusRequest

}

proc NewSnortStats { statsList } {

    global snortStatsTable

    $snortStatsTable delete 0 end
    foreach row $statsList {

        $snortStatsTable insert end [ParseSnortStatsLine $row]
        
    }

}

proc ParseSnortStatsLine { stats } {

    # Add % to Loss and Match
    foreach i [list 2 7] {

        if { [lindex $stats $i] != "N/A" } {
            set tmpValue [lindex $stats $i]
            set stats [lreplace $stats $i $i "${tmpValue}%"]
        }

    }

    # Add Mb/s to Wire
    if { [lindex $stats 3] != "N/A" } {
        set tmpValue [lindex $stats 3]
        set stats [lreplace $stats 3 3 "${tmpValue}Mb/s"]
    }

    # Add k/sec to packets
    if { [lindex $stats 5] != "N/A" } {
        set tmpValue [lindex $stats 5]
        set stats [lreplace $stats 5 5 "${tmpValue}k/sec"]
    }

    # Per packet for bytes
    if { [lindex $stats 6] != "N/A" } {
        set tmpValue [lindex $stats 6]
        set stats [lreplace $stats 6 6 "${tmpValue}/pckt"]
    }


    # Add /sec 
    foreach i [list 4 8] {

        if { [lindex $stats $i] != "N/A" } {
            set tmpValue [lindex $stats $i]
            set stats [lreplace $stats $i $i "${tmpValue}/sec"]
        }

    }

    return $stats

}

proc UpdateSnortStats { stats } {

    global snortStatsTable

    set sid [lindex $stats 0]
    set match [lsearch -exact [lindex [$snortStatsTable getcolumns 0 0] 0] $sid]
    set tmpStats [ParseSnortStatsLine $stats]

    if { $match >= 0 } {

        $snortStatsTable delete $match $match
        $snortStatsTable insert $match $tmpStats

    } else {

        $snortStatsTable insert end $tmpStats

    }
    # And what our last sort was on
    set sortColumn [$snortStatsTable sortcolumn]
    if { $sortColumn >= 0 } { 
        set sortOrder [$snortStatsTable sortorder]
        $snortStatsTable sortbycolumn $sortColumn -$sortOrder
    }
 
}
 
proc SensorStatusUpdate { statusList } {

    global sensorStatusTable

    set yscrollPos [$sensorStatusTable yview]

    # Get currently selected index
    set sIndex [$sensorStatusTable curselection]
    # Map it back to a sensor id (in case this is a sort that changes)
    if { $sIndex != "" }  {

        set tmpSid [$sensorStatusTable getcells [list ${sIndex},1]]

    }

    # And what our last sort was on
    set sortColumn [$sensorStatusTable sortcolumn]
    if { $sortColumn >= 0 } { set sortOrder [$sensorStatusTable sortorder] }

    array set sensorStatusArray $statusList

    # Clear the current list
    #$sensorStatusTable delete 0 end

    set agentSidIndex [$sensorStatusTable columnindex agentSid]
    set agentNetnameIndex [$sensorStatusTable columnindex agentNetname]
    set agentHostnameIndex [$sensorStatusTable columnindex agentHostname]
    set agentTypeIndex [$sensorStatusTable columnindex agentType]
    set agentLastIndex [$sensorStatusTable columnindex agentLast]
    set agentStatusIndex [$sensorStatusTable columnindex agentStatus]

    foreach sensorID [lsort [array names sensorStatusArray]] {

        set tmpList [list "" "" "" "" "" ""]
        set tmpList [lreplace $tmpList $agentSidIndex $agentSidIndex $sensorID]
        set tmpList [lreplace $tmpList $agentNetnameIndex $agentNetnameIndex [lindex $sensorStatusArray($sensorID) 0]]
        set tmpList [lreplace $tmpList $agentHostnameIndex $agentHostnameIndex [lindex $sensorStatusArray($sensorID) 1]]
        set tmpList [lreplace $tmpList $agentTypeIndex $agentTypeIndex [lindex $sensorStatusArray($sensorID) 2]]
        set tmpList [lreplace $tmpList $agentLastIndex $agentLastIndex [lindex $sensorStatusArray($sensorID) 3]]
        set tmpList [lreplace $tmpList $agentStatusIndex $agentStatusIndex [lindex $sensorStatusArray($sensorID) 4]]

        set match [lsearch -exact [lindex [$sensorStatusTable getcolumns 0 0] 0] $sensorID]
        if { $match >= 0 } {

            $sensorStatusTable delete $match $match
            $sensorStatusTable insert $match $tmpList
            $sensorStatusTable cellconfigure $match,agentStatus -window "CreateStatusLabel [lindex $tmpList $agentStatusIndex]"

        } else {
          
            $sensorStatusTable insert end $tmpList
            $sensorStatusTable cellconfigure end,agentStatus -window "CreateStatusLabel [lindex $tmpList $agentStatusIndex]"
            #$sensorStatusTable cellconfigure end,sensorBY -window "CreateStatusLabel [lindex $tmpList $sensorBYIndex]"

        }

    }

    # Resort if needed
    if { $sortColumn >= 0 } {

        $sensorStatusTable sortbycolumn $sortColumn -$sortOrder

    }
    # Reselect previous selected sensor.
    if { $sIndex != "" } {

        set newIndex [lsearch -exact [$sensorStatusTable getcolumns 1] $tmpSid]
        if { $newIndex >= 0 } { $sensorStatusTable selection set $newIndex }

    }

    $sensorStatusTable yview moveto [lindex $yscrollPos 0]

}

proc CreateStatusLabel { status tableName row col win } {

    if { $status == 1 } {

        label $win -text "UP" -background green -relief flat -width 5

    } else {

        label $win -text "DOWN" -background red -relief flat -width 5

    }
}

proc EmptyString val { return "" }
