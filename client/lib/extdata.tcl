################################################
# Sguil proc for getting/displaying external   #
# data (rules, references, xscript, dns,       #
# etc)                                         #
################################################
# $Id: extdata.tcl,v 1.43 2007/03/08 06:39:40 bamm Exp $

proc GetRuleInfo {} {

    global CUR_SEL_PANE ACTIVE_EVENT SHOWRULE socketID DEBUG referenceButton icatButton MULTI_SELECT
    global CONNECTED eventArray

    ClearRuleText

    if {$ACTIVE_EVENT && $SHOWRULE && !$MULTI_SELECT && $CUR_SEL_PANE(type) == "EVENT"} {

        if {!$CONNECTED} {
            ErrorMessage "Not connected to sguild. Cannot make rule request."
            return
        }

        set selectedIndex [$CUR_SEL_PANE(name) curselection]
        set event_id [$CUR_SEL_PANE(name) getcells $selectedIndex,alertID]
        set message [$CUR_SEL_PANE(name) getcells $selectedIndex,event]
        set sensorName [$CUR_SEL_PANE(name) getcells $selectedIndex,sensor]

        if {$DEBUG} {puts "RuleRequest $event_id $sensorName $message"}

        SendToSguild "RuleRequest $event_id $sensorName $message"

    } else {

        $referenceButton configure -state disabled
        $icatButton configure -state disabled

    }

}

proc ClearRuleText {} {
 
    global ruleText

    $ruleText component text configure -state normal
    $ruleText clear
    $ruleText component text configure -state disabled

}
proc InsertRuleData { ruleData } {

    global ruleText referenceButton icatButton

    $ruleText component text configure -state normal

    # Check for line # match
    if [regexp {^/.*: Line [0-9]} $ruleData] {

        # Just a msg noting what rule and line # matched
        $ruleText component text insert end "$ruleData"

    } else {

        # This is the actual rule
        $ruleText component text insert end "$ruleData\n"
        $referenceButton configure -state normal

        if [regexp {cve,([^;]*)} $ruleData] {

            $icatButton configure -state normal

        } else {

            $icatButton configure -state disabled

        }

        set w [$ruleText component text]

        #Remove any existing tags
        eval {$w tag delete} [$w tag names]

        # Find the sid for snort.org and bleeding links.
        set sidIndex [$w search -count length -regexp -- {sid:.*?;} 0.0 end]
        if { $sidIndex != "" } {

            set row [lindex [split $sidIndex .] 0]
            set col [lindex [split $sidIndex .] 1]
            set start "$row.[expr $col + 4]"
            set end "$row.[expr [lindex [split $sidIndex .] 1] + $length - 1]"
            set sid [lindex [split [$w get $sidIndex $end] :] 1]

            if { $sid < 1000000 || ( $sid >= 2000000 && $sid < 3000000 )} { 
                # Within snort.org rule range
                $ruleText component text tag configure SID -foreground blue -underline 0
	        $w tag add SID $start "$start + [expr $length - 5] char"
                $w tag bind SID <Enter> { %W configure -cursor hand2 }
                $w tag bind SID <Leave> { %W configure -cursor left_ptr }
                $w tag bind SID <ButtonRelease-1> [list DisplayReference %W $sidIndex $length]
            }

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

    global BROWSER_PATH
    
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
    if ![regexp {^reference:(.*?),(.*?);} $ref match type content] {

        # Not a reference, maybe sid. 
        if [regexp {^(sid):([0-9]*);} $ref match type content] { set foo bar }

    }
 
     switch -exact -- $type {

        url        { exec $BROWSER_PATH http://$content & }
        bugtraq    { exec $BROWSER_PATH http://www.securityfocus.com/bid/$content & }
        cve        { exec $BROWSER_PATH http://nvd.nist.gov/nvd.cfm?cvename=CAN-$content & }
        nessus     { exec $BROWSER_PATH http://cgi.nessus.org/plugins/dump.php3?id=$content & }
        mcafee     { exec $BROWSER_PATH http://vil.nai.com/vil/content/v_$content & }
        arachnids  { InfoMessage "ArachNIDS references are no long supported." }
        sid        { 
                     if { $content < 1000000 } {
                         exec $BROWSER_PATH http://www.snort.org/pub-bin/sigs.cgi?sid=$content &
                     } else {
                         exec $BROWSER_PATH http://doc.bleedingthreats.net/$content &
                     }
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
	    exec $BROWSER_PATH http://www.dshield.org/port_report.php?port=$ipPort &

        } else {

            tk_messageBox -type ok -icon warning -message\
             "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
              to point your favorite browser."
            puts "Error: $BROWSER_PATH does not exist or is not executable."
        }

    }

}
proc GetReference {} {
  global DEBUG ruleText BROWSER_PATH
  
  set signature [$ruleText get 0.0 end]
  # parse the sig for the sid
  regexp {sid:\s*([0-9]+)\s*;} $signature match sid
  if {$sid > 1000000} {
    # Local Rule
    tk_messageBox -type ok -icon warning -message\
     "Sid $sid is a locally managed signature/rule."
    puts "Error: Sid $sid is a locally managed signature/rule."
  } elseif { $sid <= 100 } {
    tk_messageBox -type ok -icon warning -message\
     "Sid $sid is reserved for future use. Is there an error in the sig file?"
    puts "Error: Sid $sid is reserved for future use. Error?."
  } else {
    if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {
      exec $BROWSER_PATH http://www.snort.org/pub-bin/sigs.cgi?sid=$sid &
      if {$DEBUG} {puts "$BROWSER_PATH http://www.snort.org/pub-bin/sigs.cgi?sid=$sid launched."}
    } else {
      tk_messageBox -type ok -icon warning -message\
       "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
        to point your favorite browser."
      puts "Error: $BROWSER_PATH does not exist or is not executable."
    }
  }
}
proc GetIcat {} {

    global DEBUG ruleText BROWSER_PATH

    set signature [$ruleText get 0.0 end]

    # parse the sig for the cve
    regexp {cve,([^;]*)} $signature match cve

    if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {

        exec $BROWSER_PATH http://nvd.nist.gov/nvd.cfm?cvename=CAN-$cve &
        if {$DEBUG} {puts "$BROWSER_PATH http://nvd.nist.gov/nvd.cfm?cvename=CAN-$cve launched."}

    } else {

        tk_messageBox -type ok -icon warning -message\
         "$BROWSER_PATH does not exist or is not executable.\
          Please update the BROWSER_PATH variable\
          to point your favorite browser."
        puts "Error: $BROWSER_PATH does not exist or is not executable."

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
    set dataSearchFrame [frame $winName.dataSearchFrame -bd 0]
    set dataSearchText [entryfield $dataSearchFrame.dataSearchText -width 20 -background white]
    set dataSearchButton [button $dataSearchFrame.dataSearchButton -text "Search Transcript"\
	    -command "SearchXscript $winName"]
    set dataSearchCaseCheck [checkbutton $dataSearchFrame.dataSearchCaseCheck -variable dataSearchCase -text "NoCase"]
    pack $dataSearchText $dataSearchButton $dataSearchCaseCheck -side left -fill x
    
  scrolledtext $winName.debug -vscrollmode dynamic -hscrollmode none -wrap word\
   -visibleitems 85x5 -sbwidth 10 -labeltext "Debug Messages" -textbackground lightblue
  set termButtonFrame [frame $winName.termButtonsFrame]
    button $termButtonFrame.abortButton -text "Abort " -command "AbortXscript $winName" 
    button $termButtonFrame.closeButton -text "Close" -command "destroy $winName"
    pack $termButtonFrame.abortButton $termButtonFrame.closeButton -side left -padx 0 -expand true
  pack $winName.menubutton -side top -anchor w
  pack $winName.sText $termButtonFrame $winName.debug $winName.dataSearchFrame\
   -side top -fill both -expand true
}
proc AbortXscript { winName } {
  $winName.termButtonsFrame.abortButton configure -state disabled
  SendToSguild "AbortXscript $winName"
}

proc SearchXscript { winName } {
    global dataSearchCase
    set searchWidget $winName.sText
    $searchWidget tag delete highlight
    set searchtext [$winName.dataSearchFrame.dataSearchText get]
    if {$searchtext == "" || $searchtext == "\n"} {
	return
    }
    regsub -all {\n} $searchtext {} searchtext
    set searchRegexp ""
    for {set i 0} { $i < [string length $searchtext] } { incr i } {
	set searchRegexp "${searchRegexp}[string range $searchtext $i $i]\\n*"
    }
    set stop 1
    set nextchar 0
    set textinds {}
    while {$stop == 1} {
	set inds {}
	if { $dataSearchCase == 0 } {
	    set stop [regexp -start $nextchar  -indices -- $searchRegexp [$searchWidget get 0.0 end-1c] inds]
	} else {
	    set stop [regexp -nocase -start $nextchar  -indices -- $searchRegexp [$searchWidget get 0.0 end-1c] inds]
	}
	set nextchar [expr [lindex $inds 1] +1]
	if {$stop == 1 } {
	    foreach index $inds {
		lappend textinds [$searchWidget index "1.0 +$index chars"]
	    }
	}
    }    
    set i 0
    puts $textinds
    if { [llength $textinds] == 0 } { 
	InfoMessage "Search string $searchtext not found."
	return 
    }

    while {$i < [llength $textinds] } {
	$searchWidget tag add highlight [lindex $textinds $i] "[lindex $textinds [expr $i + 1]] + 1 chars"
    set i [expr $i + 2] 
    }
    
    $searchWidget tag configure highlight -background yellow
    $searchWidget see [lindex $textinds 0]
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
proc EtherealDataPcap { socketID fileName bytes } {
  global ETHEREAL_STORE_DIR ETHEREAL_PATH
  set outFileID [open $ETHEREAL_STORE_DIR/$fileName w]
  fconfigure $outFileID -translation binary
  fconfigure $socketID -translation binary
  fcopy $socketID $outFileID -size $bytes
  close $outFileID
  fconfigure $socketID -encoding utf-8 -translation {auto crlf}
  eval exec $ETHEREAL_PATH -n -r $ETHEREAL_STORE_DIR/$fileName &
  InfoMessage\
   "Raw file is stored in $ETHEREAL_STORE_DIR/$fileName. Please delete when finished"
}
# Archiving this till I know for sure binary xfers are working correctly
proc EtherealDataBase64 { fileName data } {
  global ETHEREAL_PATH ETHEREAL_STORE_DIR b64FileID DEBUG
  if { $data == "BEGIN" } {
    set tmpFileName $ETHEREAL_STORE_DIR/${fileName}.base64
    set b64FileID($fileName) [open $tmpFileName w]
  } elseif { $data == "END" } {
    if [info exists b64FileID($fileName)] {
      close $b64FileID($fileName)
      set outFileID [open $ETHEREAL_STORE_DIR/$fileName w]
      set inFileID [open $ETHEREAL_STORE_DIR/${fileName}.base64 r]
      fconfigure $outFileID -translation binary
      fconfigure $inFileID -translation binary
      puts -nonewline $outFileID [::base64::decode [read -nonewline $inFileID]]
      close $outFileID
      close $inFileID
      file delete $ETHEREAL_STORE_DIR/${fileName}.base64
      eval exec $ETHEREAL_PATH -n -r $ETHEREAL_STORE_DIR/$fileName &
      InfoMessage "Raw file is stored in $ETHEREAL_STORE_DIR/$fileName. Please delete when finished"
    }
  } else {
    if [info exists b64FileID($fileName)] {
      puts $b64FileID($fileName) $data
    }
  }
}

proc GetXscript { type force } {

    global ACTIVE_EVENT SERVERHOST XSCRIPT_SERVER_PORT DEBUG CUR_SEL_PANE XSCRIPTDATARCVD
    global socketWinName SESSION_STATE ETHEREAL_STORE_DIR

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
        SendToSguild "XscriptRequest $sensor $sensorID $xscriptWinName \{$timestamp\} $srcIP $srcPort $dstIP $dstPort $force"

        if {$DEBUG} {
            puts "Xscript Request sent: $sensor $sensorID $xscriptWinName \{$timestamp\} $srcIP $srcPort $dstIP $dstPort $force"
        }
  
    } elseif { $type == "ethereal" } {

      if {$DEBUG} {
          puts "Ethereal Request sent: $sensor $sensorID \{$timestamp\} $srcIP \{$srcPort\} $dstIP \{$dstPort\} $proto $force"
      }

      SendToSguild "EtherealRequest $sensor $sensorID \{$timestamp\} $srcIP \{$srcPort\} $dstIP \{$dstPort\} $proto $force"

    }

}

proc CopyDone { socketID tmpFileID tmpFile bytes {error {}} } {
  global DEBUG ETHEREAL_PATH
  close $tmpFileID
  close $socketID
  if {$DEBUG} {puts "Bytes Transfered: $bytes"}
  if { $bytes == 0 } { 
    ErrorMessage "No data available." 
    file delete $tmpFileID
  } else {
    eval exec $ETHEREAL_PATH -n -r $tmpFile &
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

proc NessusReport { arg } {
    global REPORTNUM REPORT_RESULTS REPORT_DONE RETURN_FLAG SGUILLIB env BROWSER_PATH
    global DEBUG BROWSER_PATH CUR_SEL_PANE ACTIVE_EVENT MULTI_SELECT
    if { $ACTIVE_EVENT && !$MULTI_SELECT} {
        set selectedIndex [$CUR_SEL_PANE(name) curselection]
        if { $arg == "srcip" } {
            set ipAddr [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]
        } else {
            set ipAddr [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]
        }
	random seed
	incr REPORTNUM
	set nessusWin .nessusWin_$REPORTNUM
	if { [winfo exists $nessusWin] } {
	    wm withdraw $nessusWin
	    wm deiconify $nessusWin
	    return
	}
	toplevel $nessusWin
	wm geometry $nessusWin +200+200
	wm title $nessusWin "Nessus Reports for $ip"
	set reportListBox [scrolledlistbox $nessusWin.reportListBox -labeltext "Reports" -selectmode single]
	set reportButtonBox [buttonbox $nessusWin.reportButtonBox]
	$reportButtonBox add ok -text "Show Report" -command "set RETURN_FLAG 1"
	$reportButtonBox add cancel -text "Cancel" -command "set RETURN_FLAG 0"
	set REPORT_RESULTS {}
	SendToSguild "ReportRequest NESSUS $ip NULL"
	
	# wait for the response to fill in
	tkwait variable REPORT_DONE
	# Reset REPORT_DONE to 0 for the next report
	set REPORT_DONE 0
	set reportList $REPORT_RESULTS
	set REPORT_RESULTS {}
	foreach report $reportList {
	    $reportListBox insert end [lindex $report 3]
	}	    
	pack $reportListBox $reportButtonBox
	
	tkwait variable RETURN_FLAG
	if {$RETURN_FLAG == 0} { destroy $nessusWin; return }
	
	# find the report ID for the selected report
	
	set rIndex [$reportListBox curselection]
	if { $rIndex == "" } { destroy $nessusWin; return }
	set rid [lindex [lindex $reportList $rIndex] 1]
	set sdate [lindex [lindex $reportList $rIndex] 3]
	set edate [lindex [lindex $reportList $rIndex] 4]
	set uid [lindex [lindex $reportList $rIndex] 0]
	puts "Requesting report for rid: $rid"
	
	destroy $nessusWin
	
	
	SendToSguild "ReportRequest NESSUS_DATA $rid NULL"
	
	# wait for the response to fill in
	tkwait variable REPORT_DONE
	# Reset REPORT_DONE to 0 for the next report
	set REPORT_DONE 0
	# Copy REPORT_RESULTS to a local var in case some overly
	# click happy analyst runs another report before this one is done
	
	set nessusResults $REPORT_RESULTS
	set REPORT_RESULTS {}
	
	# The actual report is going into a table the headers are sourced out of the lib dir
	set headerfile "$SGUILLIB/nessusheader.html"
	set headerFID [open $headerfile r]
	set reportHTML [read $headerFID]
	close $headerFID

	# Here is the start of the table
	set reportHTML "${reportHTML}<table bgcolor=\"#a1a1a1\" border=0 cellpadding=0 cellspacing=0 width=\"60%\">
	<tbody><tr><td><table cellpadding=2 cellspacing=1 border=0 width=\"100%\">
	<tbody><tr><td class=title colspan=4>Analysis of Host</td></tr><tr><td class=sub width=\"20%\">Address of Host</td>
	<td class=sub width=\"30%\">Scan Start Date/Time</td><td class=sub width=\"30%\">Scan End Date/Time</td>
	<td class=sub width=\"30%\">Imported By User</td></tr>"
	
	
	# Report meta info (ip, date, etc)
	set reportHTML "${reportHTML}<tr><td class=default width=\"20%\">${ip}</td>
	<td class=default width=\"30%\">${sdate}</a></td>
	<td class=default width=\"30%\">${edate}</td>
	<td class=default width=\"30%\">${uid}</td></tr>
	</tbody></table></td></tr></tbody></table><br><br>"
	
	
	# The actual report data
	set reportHTML "${reportHTML}<table bgcolor=\"#a1a1a1\" cellpadding=0 cellspacing=0 border=0 width=\"75%\">
	<tbody><tr><td><table cellpadding=2 cellspacing=1 border=0 width=\"100%\">
	<td class=title colspan=3>Security Issues and Fixes: ${ip}</td></tr><tr>
	<td class=sub width=\"10%\">Type</td><td class=sub width=\"10%\">Port</td>
	<td class=sub width=\"80%\">Issue and Fix</td></tr><tr>"
	
	foreach result $nessusResults {
	    
	    set reportHTML "${reportHTML}<td valign=top class=default width=\"10%\">[lindex $result 3]</td>
	    <td valign=top class=default width=\"10%\">[lindex $result 1]</td>
	    <td class=default width=\"80%\">[lindex $result 4]<br>
	    Nessus ID : <a href=\"http://cgi.nessus.org/nessus_id.php3?id=[lindex $result 2]\">[lindex $result 2]</a></td></tr>"
	    
	}
	
	
	# HTML footer crap
	set reportHTML "${reportHTML}</td></tr></tbody></table></td></tr></tbody></table>
	<hr><i>This file was generated by 
	<a href=\"http://www.nessus.org\">Nessus</a>, the open-sourced security scanner.</i></BODY></HTML>"
	
	
	# write it out to a tempfile
	set outFile "$env(HOME)/nessus_[random 100000].html"
	set outFID [open $outFile w]
	puts  $outFID $reportHTML
	close $outFID
	
	# open a browser
	
	if {[file exists $BROWSER_PATH] && [file executable $BROWSER_PATH]} {
	    exec $BROWSER_PATH $outFile &
	    InfoMessage\
		    "Temp file is stored in $env(HOME)/$outFile. Please delete when finished"
	    if {$DEBUG} {puts "$BROWSER_PATH $outFile launched."}
	} else {
	    tk_messageBox -type ok -icon warning -message\
		    "$BROWSER_PATH does not exist or is not executable. Please update the BROWSER_PATH variable\
		    to point your favorite browser."
	    puts "Error: $BROWSER_PATH does not exist or is not executable."                
	}
    }
}

proc NessusLoad { } {
    global socketID env
    set filename [tk_getOpenFile -title "Select Nessus Report to Load" -initialdir $env(HOME)]

    if {$filename == ""} {return}
    #reset random number generator
    random seed
    set ipaddressList {}
    set nessusOutFile "$env(HOME)/nessus-[random 100000].tmp"
    set nessusOutFID [open $nessusOutFile w]
    # Find the hosts in this nessus report
    for_file line $filename {
	if [regexp {^timestamps\|\|([^|]+)\|host_start\|([^|]+)\|$}  $line null ipaddress timestart] {
	    set reportID [::sha1::sha1 "${ipaddress}${timestart}[random 10000]"]
	    set hostList [list $ipaddress $timestart $timestart $reportID]
	    lappend ipaddressList $hostList
	}
	if [regexp {^timestamps\|\|([^|]+)\|host_end\|([^|]+)\|$} $line null ipaddress timeend] {
	    set i 0
	    foreach hostList $ipaddressList {
		if { [lindex $hostList 0] == $ipaddress } {
		    # The report id will be a sha1 of the ip and start time
		    # this is to avoid  autoincrement columns in the db
		    # and makes it so that we can just insert this whole mess
		    # without any selects to track
		    set timestart [lindex $hostList 1]
		    set hostList [lreplace [lindex $ipaddressList $i] 2 2 $timeend ]
		    set ipaddressList [lreplace $ipaddressList $i $i $hostList]
		}
		incr i
	    }
	    
	}
	if [regexp {^results\|[^|]+\|([^|]+)\|([^|]+)\|([0-9]+)\|([^|]+)\|(.*)$} $line null ipaddress port nessusid level desc] {
	    
	    # find the reportID for this IP
	    # and since the report is filled in cronologically, we know that the entry
	    # for this ip will already be in ipaddressList
	    foreach hostList $ipaddressList {
		if { [lindex $hostList 0] == $ipaddress } {
		    set reportID [lindex $hostList 3]
		    #puts $reportID
		    break
		}
	    }
	    regsub -all {\Br\Bn} $desc {<br>} desc
	    regsub -all {\r} $desc {<br>} desc
	    regsub -all {\Bn} $desc {<br>} desc
	    regsub -all {\n} $desc {<br>} desc
	    puts $nessusOutFID "||${reportID}|${port}|${nessusid}|${level}|$desc||"
	}
    }
    if { [llength $ipaddressList] == 0 } {
	puts "No host data found in report"
        ErrorMessage "No host data found in report"
	close $nessusOutFID
	file delete $nessusOutFile
	return
    }
    close $nessusOutFID
    # send the data file to the server for loading
    set filename [file tail $nessusOutFile]
    set filesize [file size $nessusOutFile]
    puts $socketID "LoadNessusReports $filename data $filesize"
    set rFileID [open $nessusOutFile r]
    fconfigure $rFileID -translation binary
    fconfigure $socketID -translation binary
    fcopy $rFileID $socketID
    fconfigure $socketID -encoding utf-8 -translation {auto crlf}
    close $rFileID
    #file delete $nessusOutFile
    
    # convert the ipaddressList into a file for loading
    # note that the uid field is missing, the server will stick it on
    # as we don't want to give the client the ability to fake it.
    
    set nessusOutFile "$env(HOME)/nessus-[random 100000].tmp"
    set nessusOutFID [open $nessusOutFile w] 
    foreach row $ipaddressList {
	puts $nessusOutFID "||[lindex $row 3]|[lindex $row 0]|[clock format [clock scan [lindex $row 1]] -format {%Y-%m-%d %T}]|[clock format [clock scan [lindex $row 2]] -format {%Y-%m-%d %T}]||"
    }
    close $nessusOutFID

    # send the data for the main nessus table

    set filename [file tail $nessusOutFile]
    set filesize [file size $nessusOutFile]
    puts $socketID "LoadNessusReports $filename main $filesize"
    set rFileID [open $nessusOutFile r]
    fconfigure $rFileID -translation binary
    fconfigure $socketID -translation binary
    fcopy $rFileID $socketID
    fconfigure $socketID -encoding utf-8 -translation {auto crlf}
    close $rFileID
    file delete $nessusOutFile

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

    # Get currently selected index
    set sIndex [$sensorStatusTable curselection]
    # Map it back to a sensor id (in case this is a sort that changes)
    if { $sIndex != "" }  {

        set tmpSid [$sensorStatusTable getcells [list ${sIndex},1]]

    }


    # And what our last sort was on
    set sortColumn [$sensorStatusTable sortcolumn]
    if { $sortColumn >= 0 } { set sortOrder [$sensorStatusTable sortorder] }

    array set sensorStatusArray [lindex $statusList 0]

    # Clear the current list
    $sensorStatusTable delete 0 end

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

        $sensorStatusTable insert end $tmpList
        $sensorStatusTable cellconfigure end,agentStatus -window "CreateStatusLabel [lindex $tmpList $agentStatusIndex]"
        #$sensorStatusTable cellconfigure end,sensorBY -window "CreateStatusLabel [lindex $tmpList $sensorBYIndex]"

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

}

proc CreateStatusLabel { status tableName row col win } {

    if { $status == 1 } {

        label $win -text "UP" -background green -relief flat -width 5

    } else {

        label $win -text "DOWN" -background red -relief flat -width 5

    }
}

proc EmptyString val { return "" }
