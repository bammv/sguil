# sguil functions for generating reports for events (Just email at this point)
# note:  This is just the sguil-specific code, the actual emailing is done by
# email17.tcl

proc EmailEvents { detail sanitize } {
    global ACTIVE_EVENT currentSelectedPane RETURN_FLAG REPORTNUM REPORT_RESULTS REPORT_DONE
    global SERVERHOST SERVERPORT EMAIL_FROM EMAIL_CC EMAIL_HEAD EMAIL_TAIL EMAIL_SUBJECT DEBUG
    set RETURN_FLAG 0
    incr REPORTNUM
    if {$ACTIVE_EVENT} {
	set editEmail .editEmail_$REPORTNUM
	if { [winfo exists $editEmail] } {
	    wm withdraw $editEmail
	    wm deiconify $editEmail
	    return
	}
	toplevel $editEmail
	wm geometry $editEmail +200+200
	wm title $editEmail "E-Mail Event"
	$editEmail configure -cursor watch
	set textBox [scrolledtext $editEmail.textBox -textbackground white -vscrollmode dynamic \
		-sbwidth 10 -hscrollmode none -wrap word -visibleitems 80x10 -textfont ourFixedFont \
		-labeltext "Edit Email"]
	$textBox insert end $EMAIL_HEAD
	set fromBox [entryfield $editEmail.fromBox -labeltext "From:" ]
	$fromBox insert end $EMAIL_FROM
	set toBox [entryfield $editEmail.toBox  -labeltext "To:"]
	set ccBox [entryfield $editEmail.ccbox -labeltext "CC:" ]
	$ccBox insert end $EMAIL_CC
	set bccBox [entryfield $editEmail.bccbox -labeltext "BCC:" ]
	set subjectBox [entryfield $editEmail.subjectBox -labeltext "Subject:"]
	$subjectBox insert end $EMAIL_SUBJECT
	set buttonBox [buttonbox $editEmail.buttonBox]
	$buttonBox add send -state disabled -text "Send" -command "set RETURN_FLAG 1"
	$buttonBox add cancel -text "Cancel" -command "set RETURN_FLAG 0"
	pack $fromBox $toBox $ccBox $bccBox $subjectBox -side top -fill x -padx 10 -expand 0
	pack $textBox -side top -fill both -expand true
	pack $buttonBox -side top -fill none -expand 0
        iwidgets::Labeledwidget::alignlabels $fromBox $toBox $ccBox $bccBox $subjectBox
	
	foreach selectedIndex [$currentSelectedPane.eventIDFrame.list curselection] {
	    if {$DEBUG} {puts "Emailing index: $selectedIndex"}
	    set eventID [split [$currentSelectedPane.eventIDFrame.list get $selectedIndex] .]
	    if {[lindex [$currentSelectedPane.msgFrame.list get $selectedIndex] 0] != "spp_portscan:"} {
		$textBox insert end "------------------------------------------------------------------------\n"
		$textBox insert end "Count:[$currentSelectedPane.countFrame.list get $selectedIndex] "
		$textBox insert end "Event#[$currentSelectedPane.eventIDFrame.list get $selectedIndex] "
		$textBox insert end "[$currentSelectedPane.dateTimeFrame.list get $selectedIndex]\n"
		$textBox insert end "[$currentSelectedPane.msgFrame.list get $selectedIndex]\n"
		if { $sanitize == 0 } {
		    $textBox insert end "[$currentSelectedPane.srcIPFrame.list get $selectedIndex] -> "
		    $textBox insert end "[$currentSelectedPane.dstIPFrame.list get $selectedIndex]\n"
		} else {
		    $textBox insert end "a.b.c.d -> e.f.g.h\n"
		}
		#
		# Get the IP hdr details
		#
		# Send the Report Request to the server
		SendToSguild "ReportRequest IP [lindex $eventID 0] [lindex $eventID 1]"
		
		# wait for the response to fill in
		tkwait variable REPORT_DONE
		# Reset REPORT_DONE to 0 for the next report
		set REPORT_DONE 0

		set eventIpHdr $REPORT_RESULTS
		# clear REPORT_RESULTS 
		set REPORT_RESULTS ""
		$textBox insert end "IPVer=[lindex $eventIpHdr 2] "
		$textBox insert end "hlen=[lindex $eventIpHdr 3] "
		$textBox insert end "tos=[lindex $eventIpHdr 4] "
		$textBox insert end "dlen=[lindex $eventIpHdr 5] "
		$textBox insert end "ID=[lindex $eventIpHdr 6] "
		$textBox insert end "flags=[lindex $eventIpHdr 7] "
		$textBox insert end "offset=[lindex $eventIpHdr 8] "
		$textBox insert end "ttl=[lindex $eventIpHdr 9] "
		$textBox insert end "chksum=[lindex $eventIpHdr 10]\n"
		$textBox insert end "Protocol: [$currentSelectedPane.protoFrame.list get $selectedIndex] "
		
		#
		# If it is TCP or UDP put in port numbers
		#
		if {[$currentSelectedPane.protoFrame.list get $selectedIndex] == "6" || \
			[$currentSelectedPane.protoFrame.list get $selectedIndex] == "17"} {
		    $textBox insert end "sport=[$currentSelectedPane.srcPortFrame.list get $selectedIndex] -> "
		    $textBox insert end "dport=[$currentSelectedPane.dstPortFrame.list get $selectedIndex]\n\n"
		    
		    #
		    # If TCP get the TCP hdr, parse it out and insert
		    #
		    if {[$currentSelectedPane.protoFrame.list get $selectedIndex] == "6"} {
			# Send the Report Request to the server
			SendToSguild "ReportRequest TCP [lindex $eventID 0] [lindex $eventID 1]"
			
			# wait for the response to fill in
			tkwait variable REPORT_DONE
			# Reset REPORT_DONE to 0 for the next report
			set REPORT_DONE 0
			
			set eventTcpHdr $REPORT_RESULTS
			set REPORT_RESULTS ""
			if { $eventTcpHdr == "error"} {
			    ErrorMessage "Error getting TCP Header Data."
			}
			$textBox insert end "Seq=[lindex $eventTcpHdr 0] "
			$textBox insert end "Ack=[lindex $eventTcpHdr 1] "
			$textBox insert end "Off=[lindex $eventTcpHdr 2] "
			$textBox insert end "Res=[lindex $eventTcpHdr 3] "
			# TCP Flags
			set ipFlags [lindex $eventTcpHdr 4]
			set r1Flag "."
			set r0Flag "."
			set urgFlag "."
			set ackFlag "."
			set pshFlag "."
			set rstFlag "."
			set synFlag "."
			set finFlag "."
			if { $ipFlags != "" } {
			    if { 128 & $ipFlags } {
				set r1Flag "1"
				set ipFlags [expr $ipFlags - 128]
			    } else {
			    set r1Flag "*"
			    }
			    if { 64 & $ipFlags } {
				set r0Flag "0"
				set ipFlags [expr $ipFlags - 64]
			    } else {
				set r0Flag "*"
			    }
			    if { 32 & $ipFlags } {
				set urgFlag "U"
				set ipFlags [expr $ipFlags - 32]
			    } else {
				set urgFlag "*"
			    }
			    if { 16 & $ipFlags } {
				set ackFlag "A"
				set ipFlags [expr $ipFlags - 16]
			    } else {
				set ackFlag "*"
			    }
			    if { 8 & $ipFlags } {
				set pshFlag "P"
				set ipFlags [expr $ipFlags - 8]
			    } else {
				set pshFlag "*"
			    }
			    if { 4 & $ipFlags } {
				set rstFlag "R"
				set ipFlags [expr $ipFlags - 4]
			    } else {
				set rstFlag "*"
			    }
			    if { 2 & $ipFlags } {
				set synFlag "S"
				set ipFlags [expr $ipFlags - 2]
			    } else {
				set synFlag "*"
			    }
			    if { 1 & $ipFlags } {
				set finFlag "F"
			    } else {
				set finFlag "*"
			    }
			}
			$textBox insert end "Flags=$r1Flag"
			$textBox insert end $r0Flag
			$textBox insert end $urgFlag
			$textBox insert end $ackFlag
			$textBox insert end $pshFlag
			$textBox insert end $rstFlag
			$textBox insert end $synFlag
			$textBox insert end "$finFlag "
			
			$textBox insert end "Win=[lindex $eventTcpHdr 5] "
			$textBox insert end "urp=[lindex $eventTcpHdr 6] "
			$textBox insert end "chksum=[lindex $eventTcpHdr 7]\n"
		    }
		    
		    #
		    # If UDP get the UDP hdr and Insert it
		    #
		    if {[$currentSelectedPane.protoFrame.list get $selectedIndex] == "17"} {
			# Send the Report Request to the server
			SendToSguild "ReportRequest UDP [lindex $eventID 0] [lindex $eventID 1]"
			
			# wait for the response to fill in
			tkwait variable REPORT_DONE
			# Reset REPORT_DONE to 0 for the next report
			set REPORT_DONE 0
			
			set eventUDPHdr $REPORT_RESULTS
			set REPORT_RESULTS ""
			if { $eventUdpHdr == "error" } {
			    ErrorMessage "Error getting UDP Header Data."
			}
			$textBox insert end "len=[lindex $eventUdpHdr 0] "
			$textBox insert end "chksum=[lindex $eventUdpHdr 1]\n"
		    }
		}
		
		# 
		# If ICMP get the ICMP hdr and payload, parse and insert
		#
		if {[$currentSelectedPane.protoFrame.list get $selectedIndex] == "1"} {
		    # Send the Report Request to the server
		    SendToSguild "ReportRequest ICMP [lindex $eventID 0] [lindex $eventID 1]"
		    
		    # wait for the response to fill in
		    tkwait variable REPORT_DONE
		    # Reset REPORT_DONE to 0 for the next report
		    set REPORT_DONE 0
		    
		    set eventIcmpHdr $REPORT_RESULTS
		    set REPORT_RESULTS ""
		    $textBox insert end "Type=[lindex $eventIcmpHdr 0] "
		    $textBox insert end "Code=[lindex $eventIcmpHdr 1] "
		    $textBox insert end "chksum=[lindex $eventIcmpHdr 2] "
		    $textBox insert end "ID=[lindex $eventIcmpHdr 3] "
		    $textBox insert end "seq=[lindex $eventIcmpHdr 4]\n"

		    # If the ICMP packet is a dest unreachable or a time exceeded,
		    # check to see if it is network, host, port unreachable or admin prohibited or filtered
		    # then show some other stuff
		    if {[lindex $eventIcmpHdr 0] == "3" || [lindex $eventIcmpHdr 0] == "11"} {
			if {[lindex $eventIcmpHdr 1] == "0" || [lindex $eventIcmpHdr 1] == "4"\
				|| [lindex $eventIcmpHdr 1] == "9" || [lindex $eventIcmpHdr 1] == "13"\
				|| [lindex $eventIcmpHdr 1] == "1" || [lindex $eventIcmpHdr 1] == "3"} {
			    
			    #  There may be 32-bits of NULL padding at the start of the payload
			    set offset 0
			    set pldata [lindex $eventIcmpHdr 5]
		
			    if {[string range $pldata 0 7] == "00000000"} {
				set offset 8
			    }
			    # puts [string range $pldata [expr $offset+24] [expr $offset+25]]
			    
			    # Build the protocol
			    set protohex [string range $pldata [expr $offset+18] [expr $offset+19]]
			    $textBox insert end "Orig Protocol=[format "%i" 0x$protohex] "
			    
			    if { $sanitize == 0 } {
			     # Build the src address 
				set srchex1 [string range $pldata [expr $offset+24] [expr $offset+25]]
				set srchex2 [string range $pldata [expr $offset+26] [expr $offset+27]]
				set srchex3 [string range $pldata [expr $offset+28] [expr $offset+29]]
				set srchex4 [string range $pldata [expr $offset+30] [expr $offset+31]]
				$textBox insert end \
					"Orig Src IP:Port->Dst IP:Port [format "%i" 0x$srchex1]\
					.[format "%i" 0x$srchex2]\
					.[format "%i" 0x$srchex3].[format "%i" 0x$srchex4]:"
			    } else {
				$textBox insert end \
					"Orig Src IP:Port->Dst IP:Port a.b.c.d:"
			    }
			    
			    # Find and build the src port
			    set hdroffset [expr [string index $pldata [expr ($offset+1)]] * 8 + $offset]
			    set sporthex [string range $pldata $hdroffset [expr $hdroffset+3]]
			    $textBox insert end "[format "%i" 0x$sporthex]->"
			    
			    if { $sanitize == 0 } {
				# Build the dst address
				set dsthex1 [string range $pldata [expr $offset+32] [expr $offset+33]]
				set dsthex2 [string range $pldata [expr $offset+34] [expr $offset+35]]
				set dsthex3 [string range $pldata [expr $offset+36] [expr $offset+37]]
				set dsthex4 [string range $pldata [expr $offset+38] [expr $offset+39]]
				$textBox insert end \
					"[format "%i" 0x$dsthex1].[format "%i" 0x$dsthex2]\
					.[format "%i" 0x$dsthex3].[format "%i" 0x$dsthex4]:"
			    } else {
				$textBox insert end \
					"e.f.g.h:"
			    }
			    
			    # Dest Port
			    set dporthex [string range $pldata [expr $hdroffset+4] [expr $hdroffset+7]]
			    $textBox insert end "[format "%i" 0x$dporthex]\n"
			    
			}
		    }
		}
		# Get and insert the pack payload all pretty like if detail is set to 1
		if { $detail == "1" } {
		    # Send the Report Request to the server
		    SendToSguild "ReportRequest PAYLOAD [lindex $eventID 0] [lindex $eventID 1]"
		    
		    # wait for the response to fill in
		    tkwait variable REPORT_DONE
		    # Reset REPORT_DONE to 0 for the next report
		    set REPORT_DONE 0
		    
		    set eventPayload [lindex $REPORT_RESULTS 0]
		    set REPORT_RESULTS ""
		    if { $eventPayload == "error" } {
			ErrorMessage "Error getting payload data."
		    }
		    $textBox insert end "Payload:\n"
		    if {$eventPayload  == "" || [string length $eventPayload] == 0 || $eventPayload == "{}"} { 
			$textBox insert end "None.\n"
		    } else {
			set dataLength [string length $eventPayload]
			set asciiStr ""
			set counter 2
			for {set i 1} {$i < $dataLength} {incr i 2} {
			    set currentByte [string range $eventPayload [expr $i - 1] $i]
			    lappend hexStr $currentByte
			    set intValue [format "%i" 0x$currentByte]
			    if { $intValue < 32 || $intValue > 126 } {
				# Non printable char
				set currentChar "."
			    } else {
				set currentChar [format "%c" $intValue]
			    }
			    set asciiStr "$asciiStr$currentChar"
			    if { $counter == 32 } {
				$textBox insert end "$hexStr $asciiStr\n"
				set hexStr ""
				set asciiStr ""
				set counter 2
			    } else {
				incr counter 2
			    }
			}
			$textBox insert end "[format "%-47s %s\n" $hexStr $asciiStr]"
		    }
		}
	    } else {
		# Send the Report Request to the server
		SendToSguild "ReportRequest PORTSCAN [lindex [$currentSelectedPane.dateTimeFrame.list get $selectedIndex] 0]\
			[$currentSelectedPane.srcIPFrame.list get $selectedIndex]"
		
		# wait for the response to fill in
		tkwait variable REPORT_DONE
		# Reset REPORT_DONE to 0 for the next report
		set REPORT_DONE 0

		set psdata $REPORT_RESULTS
		set REPORT_RESULTS ""
		
		for { set i 0 } { $i < [llength $psdata] } {incr i} {
		    if { $sanitize == 1 } {
			set psrow1 [lreplace [lindex $psdata $i] 2 2 "a.b.c.d"]
			set psrow [lreplace $psrow1 4 4 "e.f.g.h"]
		    } else {
			set psrow [lindex $psdata $i]
		    }
		    $textBox insert end "$psrow\n"
		}
	    }
	}
	#  Once this whole mess is displayed, enable the send button and wait for a click	
	$textBox insert end $EMAIL_TAIL
	$buttonBox buttonconfigure send -state normal
	$editEmail configure -cursor left_ptr
	tkwait variable RETURN_FLAG
	if {$RETURN_FLAG} {
	    global HOSTNAME MAILSERVER
	    #load /usr/local/lib/email17.tcl
	    package require EMail 1.7
	    set EmailTo [$toBox get]
	    set EmailCC [$ccBox get]
	    set EmailBCC [$bccBox get]
	    set EmailArgs ""
	    set EmailFrom [$fromBox get]
	    set EmailSubj [$subjectBox get]
	    set EmailBody [$textBox get 0.0 end]
            if { ![info exists HOSTNAME] } {
              set HOSTNAME [info hostname]
            }
	    EMail::Init $EmailFrom $HOSTNAME $MAILSERVER
	    set EMailToken [EMail::Send $EmailTo $EmailCC $EmailBCC $EmailSubj $EmailBody -waitquit 1]
	    # EMail::Finish $EMailToken
	    EMail::Query $EMailToken
	    set EMailError [EMail::GetError $EMailToken]
	    if { $EMailError != "unknown" && $EMailError != "" } {
		ErrorMessage "Error $EMailError sending mail."
		return
	    }
	    EMail::Discard $EMailToken
	}  
	destroy $editEmail
	return
    }
}	
	
	

proc ReportResponse { type data } {
    
    global REPORT_DONE REPORT_RESULTS COUNTER

    # take the data and format it based on the type of request
    # when the data is formatted toggle REPORT_DONE to signal the 
    # requesting proc that the data is ready

    switch -exact $type {
	IP -
	TCP -
	ICMP -
	PAYLOAD -
	UDP { 
	    # UDP, IP, TCP, ICMP and PAYLOAD are all the same
	    set REPORT_RESULTS $data
	    set REPORT_DONE 1
	}
	PORTSCAN {
	    # We gotta get tricky here since this data is going to 
	    # come back in more than one response
	 
	    
	    if { $data != "DONE" } {
		lappend REPORT_RESULTS $data
	    } else {
		set REPORT_DONE 1
	    }
	}
    }
}
	