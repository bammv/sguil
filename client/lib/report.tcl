# $Id: report.tcl,v 1.38 2008/03/07 19:33:46 bamm Exp $ #

# sguil functions for generating reports for events (Just email at this point)
# note:  This is just the sguil-specific code, the actual emailing is done by
# email17.tcl

proc EmailEvents { detail sanitize } {
    global ACTIVE_EVENT CUR_SEL_PANE RETURN_FLAG
    global EMAIL_FROM EMAIL_CC EMAIL_HEAD EMAIL_TAIL EMAIL_SUBJECT DEBUG
    set RETURN_FLAG 0
    if {$ACTIVE_EVENT} {
	# save the currentSelectPane in case someone clicks a new pane while the report is being built
	set winname $CUR_SEL_PANE(name)
	set curselection [$CUR_SEL_PANE(name) curselection]
	set editEmail .editEmail
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
	set gpgBox [checkbox $editEmail.gpgBox -labeltext "GPG options" -labelpos n -orient horizontal]
	$gpgBox add sign -text sign
	$gpgBox add encrypt -text encrypt
	set buttonBox [buttonbox $editEmail.buttonBox]
	$buttonBox add send -state disabled -text "Send" -command "set RETURN_FLAG 1"
	$buttonBox add cancel -text "Cancel" -command "set RETURN_FLAG 0"
	pack $fromBox $toBox $ccBox $bccBox $subjectBox -side top -fill x -padx 10 -expand 0
	pack $textBox -side top -fill both -expand true
	pack $gpgBox $buttonBox -side top -fill none -expand 0 -pady 0
        iwidgets::Labeledwidget::alignlabels $fromBox $toBox $ccBox $bccBox $subjectBox
	set MessageText [HumanText $detail $sanitize $winname $curselection]
	
	# insert the String into the textbox
	$textBox insert end $MessageText

	#  Once this whole mess is displayed, enable the send button and wait for a click	
	$textBox insert end $EMAIL_TAIL
	$buttonBox buttonconfigure send -state normal
	$editEmail configure -cursor left_ptr
	tkwait variable RETURN_FLAG
	if {$RETURN_FLAG} {
	    global HOSTNAME MAILSERVER
	    set EmailTo [$toBox get]
	    set EmailCC [$ccBox get]
	    set EmailBCC [$bccBox get]
	    set EmailArgs ""
	    set EmailFrom [$fromBox get]
	    set EmailSubj [$subjectBox get]
	    set EmailBody [$textBox get 0.0 end]
	    set EmailRecips $EmailTo
	    if { [llength $EmailCC] > 0 } {
		lappend EmailRecips [lrange $EmailCC 0 end] 
	    }
	    if { [llength $EmailBCC] > 0 } {
		lappend EmailRecips [lrange $EmailBCC 0 end]
	    }
	    set gpgSign [$gpgBox get 0]
	    set gpgEncrypt [$gpgBox get 1]
	    if { $gpgSign || $gpgEncrypt } {
		set EmailBody [GpgText $editEmail $gpgSign $gpgEncrypt $EmailBody $EmailRecips $EmailFrom]
		if { $EmailBody == "cancel" } {
		    destroy $editEmail
		    EmailEvents $detail $sanitize
		    return
		}
	    }
            if { ![info exists HOSTNAME] } {
              set HOSTNAME [info hostname]
            }
            # Build and send the email here
            set token [mime::initialize -canonical text/plain -string $EmailBody]
            mime::setheader $token Subject $EmailSubj
            smtp::sendmessage $token -recipients $EmailTo -servers $MAILSERVER -originator $EmailFrom
            mime::finalize $token
	}  
	destroy $editEmail
	return
    }
}	
proc ExportResults { currentTab type } {
    global CUR_SEL_PANE RETURN_FLAG env quote header

    set RETURN_FLAG 0
    set exportPromptWin [dialogshell .exportPromptWin -title "Select a Text Report Type"\
	    -buttonboxpos s -width 150 ]
      $exportPromptWin add ok -text "Ok" -command "set RETURN_FLAG 1"
      $exportPromptWin add cancel -text "Cancel" -command "set RETURN_FLAG 0"
    set exportPromptFrame [$exportPromptWin childsite]
    set exportCBox [combobox $exportPromptFrame.cBox -dropdown false -labeltext "Separator:"]
    set checkBox [checkbox $exportPromptFrame.oBox -labeltext "Options" -labelpos n -orient vertical]
      $checkBox add quotebox -text "Quote Text Fields" -variable quote 
      $checkBox add headerbox -text "Include Field Names in First Row" -variable header
    #$checkBox select quotebox
    #$checkBox select headerbox
    set SepList [list , | || <TAB> HUMAN-READABLE]
    eval $exportCBox insert list end $SepList
    $exportCBox insert entry end ","
    wm geometry $exportPromptWin +[winfo pointerx .]+[winfo pointery .]
    pack $exportCBox $checkBox
    $exportPromptWin activate
    
    tkwait variable RETURN_FLAG
    
    if {$RETURN_FLAG == 0} {destroy $exportPromptWin; return}
    
    set SepChar [$exportCBox get]
    destroy $exportPromptWin
  
    set tabLabel [winfo name $currentTab]
    regsub -all { } $tabLabel {_} defaultname
    set defaultname "${defaultname}.csv"
    set filename [tk_getSaveFile -initialdir $env(HOME) -initialfile $defaultname]
    if { $filename == "" } {return}
    
    set winname $currentTab.tablelist
    if {$SepChar == "HUMAN-READABLE" } {
	if { $type == "event"} {
          set OutputText [ExportHumanText $winname]
	} elseif { $type == "ssn" || $type == "sancp" } {
          set OutputText [ExportHumanSSNText $winname]
        }
    } else {
	if { $type == "event"} {
          set OutputText [ExportDelimitedText $winname $SepChar $quote $header]
	} elseif { $type == "ssn" || $type == "sancp" } {
          set OutputText [ExportDelimitedSSNText $winname $SepChar $quote $header]
        }
    }
    if [catch {open $filename w} fileID] {
	puts "Error: Could not create/open $filename: $fileID"
	return
    } else {
	puts $fileID $OutputText
	close $fileID
    }
    tk_messageBox -type ok -icon info -parent $currentTab\
     -message "File Saved as $filename"
}
proc TextReport  { detail sanitize } {
    global ACTIVE_EVENT CUR_SEL_PANE RETURN_FLAG REPORTNUM REPORT_RESULTS REPORT_DONE
    global DEBUG env
    set RETURN_FLAG 0
    incr REPORTNUM
    if {$ACTIVE_EVENT} {
	set winname $CUR_SEL_PANE(name)
	set curselection [$CUR_SEL_PANE(name) curselection]

	set sepPromptWin [dialogshell .sepPromptWin_$REPORTNUM -title "Select a Text Report Type"\
		-buttonboxpos s -width 150]
	  $sepPromptWin add ok -text "Ok" -command "set RETURN_FLAG 1"
	  $sepPromptWin add cancel -text "Cancel" -command "set RETURN_FLAG 0"
	  set sepPromptFrame [$sepPromptWin childsite]
	    set sepCBox [combobox $sepPromptFrame.cBox -dropdown false -labeltext "Type:" -editable false]
	set SepList [list HUMAN-READABLE]
	    eval $sepCBox insert list end $SepList
	    $sepCBox insert entry end HUMAN-READABLE
	pack $sepCBox
	$sepPromptWin activate
	tkwait variable RETURN_FLAG
	if {$RETURN_FLAG == 0} {destroy $sepPromptWin; return}

	set SepChar [$sepCBox get]
	destroy $sepPromptWin

	set filename [tk_getSaveFile -initialdir $env(HOME)]
	if {$filename == "" } {return}
	# Build the text we are going to output before we open the file
	if { $SepChar == "HUMAN-READABLE" } {
	    set OutputText [HumanText $detail $sanitize $winname $curselection]
	} else {
	    set OutputText [HumanText $detail $sanitize $winname $curselection]
            # Not sure where srh was going with this. Srh?
	    #set OutputText [DelimitedText $detail $sanitize $winname $curselection $SepChar]
	}
	if [catch {open $filename w} fileID] {
	    puts "Error: Could not create/open $filename: $fileID"
	    return
	} else {
	    puts $fileID $OutputText
	    close $fileID
	}
        tk_messageBox -type ok -icon info -parent $winname\
         -message "File Saved as $filename"
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
	    if { $data == "done" } { 
		set REPORT_DONE 1
		return
	    }
	    set REPORT_RESULTS $data
	}
	BUILDER -
	NESSUS -
	NESSUS_DATA -
	PORTSCAN {
	    # We gotta get tricky here since this data is going to 
	    # come back in more than one response
	    
	    if { $data != "done" } {
		lappend REPORT_RESULTS $data
	    } else {
		set REPORT_DONE 1
	    }
	}
	
    }
}
	
proc PHBReport {} { 
    global RETURN_FLAG REPORTNUM REPORT_DONE REPORT_RESULTS monitorList REPORT_QRY_LIST sbList
#    puts $REPORT_QRY_LIST
#    puts [string length $REPORT_QRY_LIST]
    set rList {}
    set sensors {}
    if {[string length $REPORT_QRY_LIST] > 0} {
	set scanindex 0
	set stop 0
	for {set cIndex 0} { $stop != 1 } {incr cIndex} {
	    if { [regexp -start $scanindex {(.*?)\|\|(.*?)\|\|(.*?)\|\|(.*?)\|\|(.*?)\|\|} \
		    $REPORT_QRY_LIST match name description type sql fields] } {
		set rName($cIndex) $name
#		puts "$name $description $type"
		set rDesc($cIndex) $description
		lappend rList $description
		set rType($cIndex) $type
		set rSQL($cIndex) $sql
		set rFields($cIndex) $fields
		
		regexp -indices -start $scanindex {.*?\|\|.*?\|\|.*?\|\|.*?\|\|.*?\|(\|)} $REPORT_QRY_LIST match endindex
		set scanindex [expr [lindex $endindex 1] + 1]
	    } else { 
		set stop 1
	    }
	}
    } else { 
	InfoMessage "There are no reports defined.  Reports are defined on the Sguil Server at this time."
	return
    }
    set RETURN_FLAG 0
    incr REPORTNUM
    set phbReport .phbReport
    if { [winfo exists $phbReport] } {
	wm withdraw $phbReport
	wm deiconify $phbReport
	return
    }
    toplevel $phbReport
    wm geometry $phbReport +300+300
    wm title $phbReport "Sensor Summary Report"
    set sensorFrame [frame $phbReport.sensorFrame -borderwidth 2 -background lightblue -relief raised]
    set winLabel [label $sensorFrame.label -text "Select Sensor(s) to Report" -background lightblue]
    pack $winLabel -side top -fill both -expand true
     # We create a new frame for every 5 sensors to keep the look clean.
    set abMonitorList [lsort -dictionary $monitorList]
    set i 0
    set boxNumber 0
    set currentBox [checkbox $sensorFrame.subBox$boxNumber -orient horizontal -borderwidth 0 -background lightblue]
    lappend sbList $currentBox
    foreach sensorName $abMonitorList {
	if { $i < 5 } {
	    $currentBox add $sensorName -text [string totitle $sensorName] -selectcolor darkred \
		    -activebackground lightblue -width 12 \
		    -command "$phbReport.buttonBox buttonconfigure 0 -state normal"
	    incr i
	} else {
	    pack $currentBox -side top  -anchor w -pady 0
	    incr boxNumber
	    set currentBox [checkbox $sensorFrame.subBox$boxNumber -orient horizontal -borderwidth 0 -background lightblue]
	    lappend sbList $currentBox
	    $currentBox add $sensorName -text [string totitle $sensorName] -selectcolor darkred \
		    -activebackground lightblue -width 12 \
		    -command "$phbReport.buttonBox buttonconfigure 0 -state normal"
	    set i 1
	}
	
    }
    pack $currentBox -side top -anchor w -pady 0 
    set selectAll [button $sensorFrame.selectAll -text "Select All" \
	    -command "$phbReport.buttonBox buttonconfigure 0 -state normal; ReportSelectAll"]
    pack $selectAll -side top -fill x -pady 0
    set timestampLabelFrame [frame $phbReport.timestampLabelFrame]
        set timeStartLabel [label $timestampLabelFrame.timeStartLabel -text "Start Date/Time"]
        set timeEndLabel [label $timestampLabelFrame.timeEndLabel -text "End Date/Time"]
        pack $timeStartLabel $timeEndLabel -side left -expand 1 -fill x
    set timestampFrame [frame $phbReport.timestampFrame]
        set timeStartFrame [frame $timestampFrame.timeStartFrame]
            set dateStart [dateentry $timeStartFrame.dateStart]
            set timeStart [timeentry $timeStartFrame.timeStart -format military]
            $dateStart show [clock scan "5 days ago" -gmt true]
            $timeStart show [clock format [clock scan "now"] -gmt true -f "%T" ]
            pack $dateStart $timeStart -side left
        set timeEndFrame [frame $timestampFrame.timeendFrame]
            set dateEnd [dateentry $timeEndFrame.dateEnd]
            set timeEnd [timeentry $timeEndFrame.timeEnd -format military]
            $dateEnd show [clock scan "now" -gmt true]
            $timeEnd show [clock format [clock scan "now"] -gmt true -f "%T" ]
            pack $dateEnd $timeEnd -side left
        pack $timeStartFrame $timeEndFrame -side left -expand 1 -fill x

    set reportFrame [frame $phbReport.rFrame]
    set reportBox [disjointlistbox $reportFrame.reportBox -lhslabeltext "Select Report Elements"\
	    -rhslabeltext "Selected Report Elements"]
	$reportBox insertlhs $rList
    $reportBox component lhs configure -visibleitems 30x12
    $reportBox component rhs configure -visibleitems 30x12
    set orderButton [buttonbox $reportFrame.oBox -orient vertical]
      $orderButton add up -text "\u2191" -command "MoveReportUp $reportFrame"
      $orderButton add down -text "\u2193" -command "MoveReportDown $reportFrame"
    pack $reportBox $orderButton -side left -expand 1 -fill both
    
    set buttonBox [buttonbox $phbReport.buttonBox]
      $buttonBox add build  -state disabled -text "Build Report" -command "set RETURN_FLAG 1"
      $buttonBox add cancel -text "Cancel" -command "set RETURN_FLAG 0"
    pack $sensorFrame $timestampLabelFrame $timestampFrame $reportFrame $buttonBox -expand 1 -fill x
    tkwait variable RETURN_FLAG
    if {$RETURN_FLAG == 1} {
	set reports [$reportBox getrhs]
	#this is pretty hinky, I am scanning one array to see what the index of the report
	#we want is and then grabbing all of those indicies and sticking them in new arrays
	set j 0
	foreach reportdesc $reports {
#	    puts "desc is $reportdesc"
	    for { set i 0 } { $i < $cIndex } {incr i} {
		if { $reportdesc == $rDesc($i) } {
		    set sName($j) $rName($i)
		    set sDesc($j) $rDesc($i)
		    set sSql($j) $rSQL($i)
		    set sType($j) $rType($i)
		    set sFields($j) $rFields($i)
		    incr j
		    break
		}
	    }
	}
	foreach sensorBox [winfo children $sensorFrame] {
	    if { [winfo name $sensorBox] != "label" &&\
                 [winfo name $sensorBox] != "selectAll"} {
		set sensorSelect [$sensorBox get]
		foreach s $sensorSelect {
		    lappend sensors $s
		}
	    }
	}
	if {$sensors == ""} {
	    ErrorMessage "Error.  You need to select at least one sensor"
	    destroy $phbReport
	    return
	}
	set datetimestart "[clock format [$dateStart get -clicks] -f "%Y-%m-%d"] [$timeStart get]"
	set datetimeend "[clock format [$dateEnd get -clicks] -f "%Y-%m-%d"] [$timeEnd get]"

	destroy $phbReport
	BuildPHBReport $sensors $datetimestart $datetimeend sName sDesc sType sSql sFields
    } else {
	destroy $phbReport
    }
    return
}

proc ReportSelectAll {} {
    global sbList
    foreach sb $sbList {
	set i [llength [winfo children $sb.childsite]]
	for {set j 0} { $j < $i } {incr j} {
	    $sb select $j
	}
    }
}
	    
proc MoveReportUp { reportFrame } {

    set reportBox $reportFrame.reportBox
    if { [$reportBox rhs selecteditemcount] == 1 } {
	set SelectedIndex [$reportBox rhs curselection]
	if { $SelectedIndex == 0 } { return }
	set SelectedName [$reportBox rhs get $SelectedIndex]
	$reportBox rhs delete $SelectedIndex
	$reportBox rhs insert [expr $SelectedIndex-1] $SelectedName
	$reportBox rhs selection set [expr $SelectedIndex-1]
    }
}
proc MoveReportDown { reportFrame } {

    set reportBox $reportFrame.reportBox
    if { [$reportBox rhs selecteditemcount] == 1 } {
	set SelectedIndex [$reportBox rhs curselection]
	set SelectedName [$reportBox rhs get $SelectedIndex]
	$reportBox rhs delete $SelectedIndex
	$reportBox rhs insert [expr $SelectedIndex+1] $SelectedName
	$reportBox rhs selection set [expr $SelectedIndex+1]
    }
}
proc BuildPHBReport { sensors datetimestart datetimeend sName sDesc sType sSql sFields } {

    global REPORT_DONE REPORT_RESULTS
    upvar 1 $sName Name
    upvar 1 $sDesc Desc
    upvar 1 $sType Type
    upvar 1 $sSql Sql
    upvar 1 $sFields Fields
    set timelist [list $datetimestart $datetimeend]
    set datalist [list $sensors $timelist]
    # build the window for the output
    set phbReportOut .phbReportOut
    if { [winfo exists $phbReportOut] } {
	wm withdraw $phbReportOut
	wm deiconify $phbReportOut
	return
    }
    toplevel $phbReportOut
    wm geometry $phbReportOut +400+400
    wm title $phbReportOut "Summary Report"
    set reportText [scrolledtext $phbReportOut.reportText]
    set reportButtonBox [buttonbox $phbReportOut.reportButtonBox]
    $reportButtonBox add reportCloseButton -text "Close" -command "destroy $phbReportOut; return" -state disabled
    $reportButtonBox add reportSaveButton -text "Save Report" -command "SavePHBReport $reportText" -state disabled
    pack $reportText -expand true -fill both
    pack $reportButtonBox -expand false 
    $reportText insert end "Summary Report\n"
    $reportText insert end "===============================================================\n"
    $reportText insert end "\n"
    $reportText insert end "Networks included in the report:\n"
    $reportText insert end "\n"
    foreach sName $sensors {
        $reportText insert end "$sName\n"
    }
    $reportText insert end "\n"
    # Send the Report Request to the server
    set k [array size Name]
    for {set i 0 } { $i < $k } {incr i} {
	if { $Type($i) == "query" } {
	    set REPORT_RESULTS {}
	    SendToSguild "ReportRequest BUILDER $Name($i) $datalist"
    
	    # wait for the response to fill in
	    tkwait variable REPORT_DONE
	    # Reset REPORT_DONE to 0 for the next report
	    set REPORT_DONE 0
	    set description $Desc($i)
	    $reportText insert end "${description}\n"
	    $reportText insert end "--------------------\n"
	    if { $REPORT_RESULTS == {} } {
		$reportText insert end "Zero Rows Returned\n"
	    } else {
		foreach report $REPORT_RESULTS {
		    for { set j 0 } { $j < $Fields($i) } { incr j } {
			$reportText insert end [lindex $report $j]
			$reportText insert end "\t"
		    }
		    $reportText insert end "\n"
		}
	    }	
	    $reportText insert end "\n"
	    #$reportText insert end "${REPORT_RESULTS}\n"
	    #puts $REPORT_RESULTS
	    # clear REPORT_RESULTS 
	    set REPORT_RESULTS {}
	} else {
	    $reportText insert end $Sql($i)
	}
    }
    $reportButtonBox buttonconfigure reportCloseButton -state active
    $reportButtonBox buttonconfigure reportSaveButton -state active
}

proc SavePHBReport { reporttextbox } {
    global env
    set filename [tk_getSaveFile -initialdir $env(HOME) -initialfile "report.txt"]
    if { $filename == "" } { return }
    if [catch {open $filename w} fileID] {
	puts "Error: Could not create/open $filename: $fileID"
	return
    } else {
	puts $fileID [$reporttextbox get 0.0 end]
	close $fileID
    }
    tk_messageBox -type ok -icon info -parent [winfo parent $reporttextbox]\
	    -message "File Saved as $filename"
}

proc HumanText { detail sanitize winname curselection } {
    global DEBUG REPORT_DONE REPORT_RESULTS
    set ReturnString ""
    set TotalSelections [llength $curselection]
    set progressShell [shell .progressShell ]
    set progressBar [feedback $progressShell.progressBar -steps $TotalSelections -labeltext "Exporting Events..." -barcolor red -troughcolor ghostwhite]
    pack $progressBar -fill y
    $progressShell activate
    foreach selectedIndex $curselection {
	if {$DEBUG} {puts "Reporting index: $selectedIndex"}
	set eventID [split [$winname getcells $selectedIndex,alertID] .]
	if {[lindex [$winname getcells $selectedIndex,event] 0] != "spp_portscan:"} {
	    set ReturnString "${ReturnString}------------------------------------------------------------------------\n"
	    set ReturnString "${ReturnString}Count:[$winname getcells $selectedIndex,count] "
	    set ReturnString "${ReturnString}Event#[$winname getcells $selectedIndex,alertID] "
	    set ReturnString "${ReturnString}[$winname getcells $selectedIndex,date]\n"
	    set ReturnString "${ReturnString}[$winname getcells $selectedIndex,event]\n"
	    if { $sanitize == 0 } {
		set ReturnString "${ReturnString}[$winname getcells $selectedIndex,srcip] -> "
		set ReturnString "${ReturnString}[$winname getcells $selectedIndex,dstip]\n"
	    } else {
		set ReturnString "${ReturnString}a.b.c.d -> e.f.g.h\n"
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
	    set ReturnString "${ReturnString}IPVer=[lindex $eventIpHdr 2] "
	    set ReturnString "${ReturnString}hlen=[lindex $eventIpHdr 3] "
	    set ReturnString "${ReturnString}tos=[lindex $eventIpHdr 4] "
	    set ReturnString "${ReturnString}dlen=[lindex $eventIpHdr 5] "
	    set ReturnString "${ReturnString}ID=[lindex $eventIpHdr 6] "
	    set ReturnString "${ReturnString}flags=[lindex $eventIpHdr 7] "
	    set ReturnString "${ReturnString}offset=[lindex $eventIpHdr 8] "
	    set ReturnString "${ReturnString}ttl=[lindex $eventIpHdr 9] "
	    set ReturnString "${ReturnString}chksum=[lindex $eventIpHdr 10]\n"
	    set ReturnString "${ReturnString}Protocol: [$winname getcells $selectedIndex,ipproto] "
	    
	    #
	    # If it is TCP or UDP put in port numbers
	    #
	    if {[$winname getcells $selectedIndex,ipproto] == "6" || \
		    [$winname getcells $selectedIndex,ipproto] == "17"} {
		set ReturnString "${ReturnString}sport=[$winname getcells $selectedIndex,srcport] -> "
		set ReturnString "${ReturnString}dport=[$winname getcells $selectedIndex,dstport]\n\n"
		
		#
		# If TCP get the TCP hdr, parse it out and insert
		#
		if {[$winname getcells $selectedIndex,ipproto] == "6"} {
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
		    set ReturnString "${ReturnString}Seq=[lindex $eventTcpHdr 0] "
		    set ReturnString "${ReturnString}Ack=[lindex $eventTcpHdr 1] "
		    set ReturnString "${ReturnString}Off=[lindex $eventTcpHdr 2] "
		    set ReturnString "${ReturnString}Res=[lindex $eventTcpHdr 3] "
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
		    set ReturnString "${ReturnString}Flags=$r1Flag"
		    set ReturnString "${ReturnString}${r0Flag}"
		    set ReturnString "${ReturnString}${urgFlag}"
		    set ReturnString "${ReturnString}${ackFlag}"
		    set ReturnString "${ReturnString}${pshFlag}"
		    set ReturnString "${ReturnString}${rstFlag}"
		    set ReturnString "${ReturnString}${synFlag}"
		    set ReturnString "${ReturnString}${finFlag} "
		    
		    set ReturnString "${ReturnString}Win=[lindex $eventTcpHdr 5] "
		    set ReturnString "${ReturnString}urp=[lindex $eventTcpHdr 6] "
		    set ReturnString "${ReturnString}chksum=[lindex $eventTcpHdr 7]\n"
		}
		
		#
		# If UDP get the UDP hdr and Insert it
		#
		if {[$winname getcells $selectedIndex,ipproto] == "17"} {
		    # Send the Report Request to the server
		    SendToSguild "ReportRequest UDP [lindex $eventID 0] [lindex $eventID 1]"
		    
		    # wait for the response to fill in
		    tkwait variable REPORT_DONE
		    # Reset REPORT_DONE to 0 for the next report
		    set REPORT_DONE 0
		    
		    set eventUdpHdr $REPORT_RESULTS
		    set REPORT_RESULTS ""
		    if { $eventUdpHdr == "error" } {
			ErrorMessage "Error getting UDP Header Data."
		    }
		    set ReturnString "${ReturnString}len=[lindex $eventUdpHdr 0] "
		    set ReturnString "${ReturnString}chksum=[lindex $eventUdpHdr 1]\n"
		}
	    }
	    
	    # 
	    # If ICMP get the ICMP hdr and payload, parse and insert
	    #
	    if {[$winname getcells $selectedIndex,ipproto] == "1"} {
		# Send the Report Request to the server
		SendToSguild "ReportRequest ICMP [lindex $eventID 0] [lindex $eventID 1]"
		
		# wait for the response to fill in
		tkwait variable REPORT_DONE
		# Reset REPORT_DONE to 0 for the next report
		set REPORT_DONE 0
		
		set eventIcmpHdr $REPORT_RESULTS
		set REPORT_RESULTS ""
		set ReturnString "${ReturnString}Type=[lindex $eventIcmpHdr 0] "
		set ReturnString "${ReturnString}Code=[lindex $eventIcmpHdr 1] "
		set ReturnString "${ReturnString}chksum=[lindex $eventIcmpHdr 2] "
		set ReturnString "${ReturnString}ID=[lindex $eventIcmpHdr 3] "
		set ReturnString "${ReturnString}seq=[lindex $eventIcmpHdr 4]\n"
		
		# If the ICMP packet is a dest unreachable or a time exceeded,
		# check to see if it is network, host, port unreachable or admin prohibited or filtered
		# then show some other stuff
		set ICMPList [DecodeICMP [lindex $eventIcmpHdr 0] [lindex $eventIcmpHdr 1] [lindex $eventIcmpHdr 5]]
		if { $ICMPList != "NA" } {
		    if { [lindex $ICMPList 0] != "" } {
			set ReturnString "${ReturnString}Gateway Address=[lindex $ICMPList 0] "
		    }
		    set ReturnString "${ReturnString}Orig Protocol=[lindex $ICMPList 1] "
		    
		    if { $sanitize == 0 } {
			set ReturnString "${ReturnString}\
				    Orig Src IP:Port->Dst IP:Port [lindex $ICMPList 2]:"
		    } else {
			set ReturnString "${ReturnString}Orig Src IP:Port->Dst IP:Port a.b.c.d:"
		    }
		    set ReturnString "${ReturnString}[lindex $ICMPList 4]->"
			
		    if { $sanitize == 0 } {
			set ReturnString "${ReturnString}[lindex $ICMPList 3]:"
			} else {
			    set ReturnString "${ReturnString}e.f.g.h:"
			}
			
			# Dest Port
		
		    set ReturnString "${ReturnString}[lindex $ICMPList 5]\n"
			
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
		set ReturnString "${ReturnString}Payload:\n"
		if {$eventPayload  == "" || [string length $eventPayload] == 0 || $eventPayload == "{}"} { 
		    set ReturnString "${ReturnString}None.\n"
		} else {
		    set dataLength [string length $eventPayload]
		    set asciiStr ""
		    set hexStr ""
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
			    set ReturnString "${ReturnString}$hexStr $asciiStr\n"
			    set hexStr ""
			    set asciiStr ""
			    set counter 2
			} else {
			    incr counter 2
			}
		    }
		    set ReturnString "${ReturnString}[format "%-47s %s\n" $hexStr $asciiStr]"
		}
	    }
	} else {
	    # Send the Report Request to the server
	    SendToSguild "ReportRequest PORTSCAN [lindex [$winname getcells $selectedIndex,date] 0]\
		    [$winname getcells $selectedIndex,srcip]"
	    
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
		set ReturnString "${ReturnString}$psrow\n"
	    }
	}
	$progressBar step 1
    }
    destroy $progressShell
    return $ReturnString
}
    
#  I have disabled use of this proc while I think about how the heck to use it.
#  Not gonna delete it for now, but it is dead code 

#proc DelimitedText { detail sanitize winname curselection delimiter} {
#    global DEBUG REPORT_DONE REPORT_RESULTS
#    set ReturnString ""
#    if { $delimiter == "TAB"} {set delimiter "\t"}
#    foreach selectedIndex $curselection {
#	if {$DEBUG} {puts "Reporting index: $selectedIndex"}
#	set eventID [split [$winname getcells $selectedIndex,alertID] .]
#	if {[lindex [$winname.msgFrame.list get $selectedIndex] 0] != "spp_portscan:"} {
#	    set ReturnString "${ReturnString}[$winname.countFrame.list get $selectedIndex]${delimiter}"
#	    set ReturnString "${ReturnString}[$winname.eventIDFrame.list get $selectedIndex]${delimiter}"
#	    set ReturnString "${ReturnString}[$winname.dateTimeFrame.list get $selectedIndex]${delimiter}"
#	    set ReturnString "${ReturnString}[$winname.msgFrame.list get $selectedIndex]${delimiter}"
#	    if { $sanitize == 0 } {
#		set ReturnString "${ReturnString}[$winname.srcIPFrame.list get $selectedIndex]${delimiter}"
#		set ReturnString "${ReturnString}[$winname.dstIPFrame.list get $selectedIndex]${delimiter}"
#	    } else {
#		set ReturnString "${ReturnString}a.b.c.d${delimiter}e.f.g.h${delimiter}"
#	    }
#	    #
#	    # Get the IP hdr details
#	    #
#	    # Send the Report Request to the server
#	    SendToSguild "ReportRequest IP [lindex $eventID 0] [lindex $eventID 1]"
#	    
#	    # wait for the response to fill in
#	    tkwait variable REPORT_DONE
#	    # Reset REPORT_DONE to 0 for the next report
#	    set REPORT_DONE 0
#	    
#	    set eventIpHdr $REPORT_RESULTS
#	    # clear REPORT_RESULTS 
#	    set REPORT_RESULTS ""
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 2]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 3]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 4]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 5]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 6]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 7]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 8]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 9]${delimiter}"
#	    set ReturnString "${ReturnString}[lindex $eventIpHdr 10]${delimiter}"
#	    set ReturnString "${ReturnString}[$winname.protoFrame.list get $selectedIndex]${delimiter}"
#	    
#	    #
#	    # If it is TCP or UDP put in port numbers
#	    #
#	    if {[$winname.protoFrame.list get $selectedIndex] == "6" || \
#		    [$winname.protoFrame.list get $selectedIndex] == "17"} {
#		set ReturnString "${ReturnString}[$winname.srcPortFrame.list get $selectedIndex]${delimiter}"
#		set ReturnString "${ReturnString}[$winname.dstPortFrame.list get $selectedIndex]${delimiter}"
#		
#		#
#		# If TCP get the TCP hdr, parse it out and insert
#		#
#		if {[$winname.protoFrame.list get $selectedIndex] == "6"} {
#		    # Send the Report Request to the server
#		    SendToSguild "ReportRequest TCP [lindex $eventID 0] [lindex $eventID 1]"
#		    
#		    # wait for the response to fill in
#		    tkwait variable REPORT_DONE
#		    # Reset REPORT_DONE to 0 for the next report
#		    set REPORT_DONE 0
#		    
#		    set eventTcpHdr $REPORT_RESULTS
#		    set REPORT_RESULTS ""
#		    if { $eventTcpHdr == "error"} {
#			ErrorMessage "Error getting TCP Header Data."
#		    }
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 0]${delimiter}"
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 1]${delimiter}"
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 2]${delimiter}"
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 3]${delimiter}"
#		    # TCP Flags
#		    set ipFlags [lindex $eventTcpHdr 4]
#		    set r1Flag "."
#		    set r0Flag "."
#		    set urgFlag "."
#		    set ackFlag "."
#		    set pshFlag "."
#		    set rstFlag "."
#		    set synFlag "."
#		    set finFlag "."
#		    if { $ipFlags != "" } {
#			if { 128 & $ipFlags } {
#			    set r1Flag "1"
#			    set ipFlags [expr $ipFlags - 128]
#			} else {
#			    set r1Flag "*"
#			}
#			if { 64 & $ipFlags } {
#			    set r0Flag "0"
#			    set ipFlags [expr $ipFlags - 64]
#			} else {
#			    set r0Flag "*"
#			}
#			if { 32 & $ipFlags } {
#			    set urgFlag "U"
#			    set ipFlags [expr $ipFlags - 32]
#			} else {
#			    set urgFlag "*"
#			}
#			if { 16 & $ipFlags } {
#			    set ackFlag "A"
#			    set ipFlags [expr $ipFlags - 16]
#			} else {
#			    set ackFlag "*"
#			}
#			if { 8 & $ipFlags } {
#			    set pshFlag "P"
#			    set ipFlags [expr $ipFlags - 8]
#			} else {
#			    set pshFlag "*"
#			}
#			if { 4 & $ipFlags } {
#			    set rstFlag "R"
#			    set ipFlags [expr $ipFlags - 4]
#			} else {
#			    set rstFlag "*"
#			}
#			if { 2 & $ipFlags } {
#			    set synFlag "S"
#			    set ipFlags [expr $ipFlags - 2]
#			} else {
#			    set synFlag "*"
#			}
#			if { 1 & $ipFlags } {
#			    set finFlag "F"
#			} else {
#			    set finFlag "*"
#			}
#		    }
#		    set ReturnString "${ReturnString}$r1Flag"
#		    set ReturnString "${ReturnString}${r0Flag}"
#		    set ReturnString "${ReturnString}${urgFlag}"
#		    set ReturnString "${ReturnString}${ackFlag}"
#		    set ReturnString "${ReturnString}${pshFlag}"
#		    set ReturnString "${ReturnString}${rstFlag}"
#		    set ReturnString "${ReturnString}${synFlag}"
#		    set ReturnString "${ReturnString}${finFlag}${delimiter}"
#		    
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 5]${delimiter}"
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 6]${delimiter}"
#		    set ReturnString "${ReturnString}[lindex $eventTcpHdr 7]${delimiter}"
#		}
#		
#		#
#		# If UDP get the UDP hdr and Insert it
#		#
#		if {[$winname.protoFrame.list get $selectedIndex] == "17"} {
#		    # Send the Report Request to the server
#		    SendToSguild "ReportRequest UDP [lindex $eventID 0] [lindex $eventID 1]"
#		    
#		    # wait for the response to fill in
#		    tkwait variable REPORT_DONE
#		    # Reset REPORT_DONE to 0 for the next report
#		    set REPORT_DONE 0
#		    
#		    set eventUDPHdr $REPORT_RESULTS
#		    set REPORT_RESULTS ""
#		    if { $eventUdpHdr == "error" } {
#			ErrorMessage "Error getting UDP Header Data."
#		    }
#		    set ReturnString "${ReturnString}[lindex $eventUdpHdr 0]${delimiter}"
#		    set ReturnString "${ReturnString}[lindex $eventUdpHdr 1]${delimiter}"
#		}
#	    }
#	    
#	    # 
#	    # If ICMP get the ICMP hdr and payload, parse and insert
#	    #
#	    if {[$winname.protoFrame.list get $selectedIndex] == "1"} {
#		# Send the Report Request to the server
#		SendToSguild "ReportRequest ICMP [lindex $eventID 0] [lindex $eventID 1]"
#		
#		# wait for the response to fill in
#		tkwait variable REPORT_DONE
#		# Reset REPORT_DONE to 0 for the next report
#		set REPORT_DONE 0
#		
#		set eventIcmpHdr $REPORT_RESULTS
#		set REPORT_RESULTS ""
#		set ReturnString "${ReturnString}[lindex $eventIcmpHdr 0]${delimiter}"
#		set ReturnString "${ReturnString}[lindex $eventIcmpHdr 1]${delimiter}"
#		set ReturnString "${ReturnString}[lindex $eventIcmpHdr 2]${delimiter}"
#		set ReturnString "${ReturnString}[lindex $eventIcmpHdr 3]${delimiter}"
#		set ReturnString "${ReturnString}[lindex $eventIcmpHdr 4]${delimiter}"
#		
#		# If the ICMP packet is a dest unreachable or a time exceeded,
#		# check to see if it is network, host, port unreachable or admin prohibited or filtered
#		# then show some other stuff
#		if {[lindex $eventIcmpHdr 0] == "3" || [lindex $eventIcmpHdr 0] == "11"} {
#		    if {[lindex $eventIcmpHdr 1] == "0" || [lindex $eventIcmpHdr 1] == "4"\
#			    || [lindex $eventIcmpHdr 1] == "9" || [lindex $eventIcmpHdr 1] == "13"\
#			    || [lindex $eventIcmpHdr 1] == "1" || [lindex $eventIcmpHdr 1] == "3"} {
#			
#			#  There may be 32-bits of NULL padding at the start of the payload
#			set offset 0
#			set pldata [lindex $eventIcmpHdr 5]
#			
#			if {[string range $pldata 0 7] == "00000000"} {
#			    set offset 8
#			}
#			# puts [string range $pldata [expr $offset+24] [expr $offset+25]]
#			
#			# Build the protocol
#			set protohex [string range $pldata [expr $offset+18] [expr $offset+19]]
#			set ReturnString "${ReturnString}Orig Protocol=[format "%i" 0x$protohex] "
#			
#			if { $sanitize == 0 } {
#			    # Build the src address 
#			    set srchex1 [string range $pldata [expr $offset+24] [expr $offset+25]]
#			    set srchex2 [string range $pldata [expr $offset+26] [expr $offset+27]]
#			    set srchex3 [string range $pldata [expr $offset+28] [expr $offset+29]]
#			    set srchex4 [string range $pldata [expr $offset+30] [expr $offset+31]]
#			    set ReturnString "${ReturnString}[format "%i" 0x$srchex1].[format "%i" 0x$srchex2]\
#				    .[format "%i" 0x$srchex3].[format "%i" 0x$srchex4]${delimiter}"
#			} else {
#			    set ReturnString "${ReturnString}a.b.c.d${delimiter}"
#			}
#			
#			# Find and build the src port
#			set hdroffset [expr [string index $pldata [expr ($offset+1)]] * 8 + $offset]
#			set sporthex [string range $pldata $hdroffset [expr $hdroffset+3]]
#			set ReturnString "${ReturnString}[format "%i" 0x$sporthex]${delimiter}"
#			
#			if { $sanitize == 0 } {
#			    # Build the dst address
#			    set dsthex1 [string range $pldata [expr $offset+32] [expr $offset+33]]
#			    set dsthex2 [string range $pldata [expr $offset+34] [expr $offset+35]]
#			    set dsthex3 [string range $pldata [expr $offset+36] [expr $offset+37]]
#			    set dsthex4 [string range $pldata [expr $offset+38] [expr $offset+39]]
#			    set ReturnString "${ReturnString}\
#				    [format "%i" 0x$dsthex1].[format "%i" 0x$dsthex2]\
#				    .[format "%i" 0x$dsthex3].[format "%i" 0x$dsthex4]${delimiter}"
#			} else {
#			    set ReturnString "${ReturnString}e.f.g.h${delimiter}"
#			}
#			
#			# Dest Port
#			set dporthex [string range $pldata [expr $hdroffset+4] [expr $hdroffset+7]]
#			set ReturnString "${ReturnString}[format "%i" 0x$dporthex]${delimiter}"
#			
#		    }
#		}
#	    }
#	    # Get and insert the pack payload all pretty like if detail is set to 1
#	    if { $detail == "1" } {
#		# Send the Report Request to the server
#		SendToSguild "ReportRequest PAYLOAD [lindex $eventID 0] [lindex $eventID 1]"
#		
#		# wait for the response to fill in
#		tkwait variable REPORT_DONE
#		# Reset REPORT_DONE to 0 for the next report
#		set REPORT_DONE 0
#		
#		set eventPayload [lindex $REPORT_RESULTS 0]
#		set REPORT_RESULTS ""
#		if { $eventPayload == "error" } {
#		    ErrorMessage "Error getting payload data."
#		}
#		if {$eventPayload  == "" || [string length $eventPayload] == 0 || $eventPayload == "{}"} { 
#		    set ReturnString "${ReturnString}None${delimiter}"
#		} else {
#		    set dataLength [string length $eventPayload]
#		    set asciiStr ""
#		    set counter 2
#		    for {set i 1} {$i < $dataLength} {incr i 2} {
#			set currentByte [string range $eventPayload [expr $i - 1] $i]
#			lappend hexStr $currentByte
#			set intValue [format "%i" 0x$currentByte]
#			if { $intValue < 32 || $intValue > 126 } {
#			    # Non printable char
#			    set currentChar "."
#			} else {
#			    set currentChar [format "%c" $intValue]
#			}
#			set asciiStr "$asciiStr$currentChar"
#			if { $counter == 32 } {
#			    set ReturnString "${ReturnString}$asciiStr"
#			    set hexStr ""
#			    set asciiStr ""
#			    set counter 2
#			} else {
#			    incr counter 2
#			}
#		    }
#		    set ReturnString "${ReturnString}$asciiStr${delimiter}"
#		}
#	    }
#	} else {
#	    # Send the Report Request to the server
#	    SendToSguild "ReportRequest PORTSCAN [lindex [$winname.dateTimeFrame.list get $selectedIndex] 0]\
#		    [$winname.srcIPFrame.list get $selectedIndex]"
#	    
#	    # wait for the response to fill in
#	    tkwait variable REPORT_DONE
#	    # Reset REPORT_DONE to 0 for the next report
#	    set REPORT_DONE 0
#	    
#	    set psdata $REPORT_RESULTS
#	    set REPORT_RESULTS ""
#	    
#	    for { set i 0 } { $i < [llength $psdata] } {incr i} {
#		if { $sanitize == 1 } {
#		    set psrow1 [lreplace [lindex $psdata $i] 2 2 "a.b.c.d"]
#		    set psrow [lreplace $psrow1 4 4 "e.f.g.h"]
#		} else {
#		    set psrow [lindex $psdata $i]
#		}
#		set ReturnString "${ReturnString}$psrow${delimiter}"
#	    }
#	}
#	set ReturnString "${ReturnString}\n"
#    }
#    
#    return $ReturnString
#}
    
proc ExportHumanText { winname } {

    # leaving the sanitize toggle in here in case I want it later
    set sanitize 0
    set ReturnString ""
    set ListSize [llength [$winname getcolumns 1]]
    for {set i 0} {$i<$ListSize} {incr i} {
	set ReturnString "${ReturnString}------------------------------------------------------------------------\n"
	set ReturnString "${ReturnString}Status:[$winname getcells $i,status] "
	set ReturnString "${ReturnString}Count:[$winname getcells $i,count] "
	set ReturnString "${ReturnString}Sensor:[$winname getcells $i,sensor] "
	set ReturnString "${ReturnString}Event#[$winname getcells $i,alertID] "

	set ReturnString "${ReturnString}[$winname getcells $i,date]\n"
	set ReturnString "${ReturnString}[$winname getcells $i,event]\n"
	set ReturnString "${ReturnString}[$winname getcells $i,ipproto] "
	if { $sanitize == 0 } {
	    set ReturnString "${ReturnString}[$winname getcells $i,srcip]:"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport] -> "
	    set ReturnString "${ReturnString}[$winname getcells $i,dstip]:"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]\n"
	} else {
	    set ReturnString "${ReturnString}a.b.c.d:"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport] -> e.f.g.h:"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]\n"
	}
	
    }
    return $ReturnString
}

proc ExportDelimitedText { winname SepChar quote header} {

    # leaving the sanitize toggle in here in case I want it later
    set sanitize 0
    if {$SepChar == "<TAB>"} {set SepChar "\t"}
    if { $header == 1 } {
	set ReturnString "STATUS${SepChar}COUNT${SepChar}Sensor${SepChar}sid.cid${SepChar}Date/Time${SepChar}Source IP\
		${SepChar}Source Port${SepChar}Dest IP${SepChar}Dest Port${SepChar}Protocol${SepChar}Event Message\n"
    } else {
	set ReturnString ""
    }
    set ListSize [llength [$winname getcolumns 1]]
    for {set i 0} {$i<$ListSize} {incr i} {
	set ReturnString "${ReturnString}[$winname getcells $i,status]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,count]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,sensor]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,alertID]${SepChar}"

	set ReturnString "${ReturnString}[$winname getcells $i,date]${SepChar}"
	
	
	if { $sanitize == 0 } {
	    set ReturnString "${ReturnString}[$winname getcells $i,srcip]${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport]${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstip]${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]${SepChar}"
	} else {
	    set ReturnString "${ReturnString}a.b.c.d${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport]${SepChar}e.f.g.h${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]${SepChar}"
	}
	set ReturnString "${ReturnString}[$winname getcells $i,ipproto]${SepChar}"
	if { $quote == 1 } {
	    set ReturnString "${ReturnString}\"[$winname getcells $i,event]\"\n"
	} else {
	    set ReturnString "${ReturnString}[$winname getcells $i,event]\n"
	}
    }
    return $ReturnString
}
proc ExportHumanSSNText { winname } {

    # leaving the sanitize toggle in here in case I want it later
    set sanitize 0
    set ReturnString ""
    set ListSize [llength [$winname getcolumns 1]]
    for {set i 0} {$i<$ListSize} {incr i} {
	set ReturnString "${ReturnString}------------------------------------------------------------------------\n"
	set ReturnString "${ReturnString}Sensor:[$winname getcells $i,sensor] "
	set ReturnString "${ReturnString}Session ID:[$winname getcells $i,alertID]\n"
	set ReturnString "${ReturnString}Start Time:[$winname getcells $i,starttime] "
	set ReturnString "${ReturnString}End Time:[$winname getcells $i,endtime]\n"

	if { $sanitize == 0 } {
	    set ReturnString "${ReturnString}[$winname getcells $i,srcip]:"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport] -> "
	    set ReturnString "${ReturnString}[$winname getcells $i,dstip]:"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]\n"
	} else {
	    set ReturnString "${ReturnString}a.b.c.d:"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport] -> e.f.g.h:"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]\n"
	}
	
	set ReturnString "${ReturnString}Source Packets:[$winname getcells $i,srcpckts] "
	set ReturnString "${ReturnString}Bytes:[$winname getcells $i,srcbytes]\n"
	set ReturnString "${ReturnString}Dest Packets:[$winname getcells $i,dstpckts] "
	set ReturnString "${ReturnString}Bytes:[$winname getcells $i,dstbytes]\n"
    }
    return $ReturnString
}
proc ExportDelimitedSSNText { winname SepChar quote header } {
    
    if {$SepChar == "<TAB>"} {set SepChar "\t"}
    if { $header == 1 } {
	set ReturnString "Sensor${SepChar}SSN ID${SepChar}Start Time${SepChar}End Time${SepChar}Source IP${SepChar}Source Port\
		${SepChar}Dest IP${SepChar}Dest Port${SepChar}Source Packets${SepChar}Source Bytes${SepChar}Dest Packets\
		${SepChar}Dest Bytes\n"
    } else {
	set ReturnString ""
    }
    # leaving the sanitize toggle in here in case I want it later
    set sanitize 0
    set ListSize [llength [$winname getcolumns 1]]
    for {set i 0} {$i<$ListSize} {incr i} {
	set ReturnString "${ReturnString}[$winname getcells $i,sensor]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,alertID]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,starttime]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,endtime]${SepChar}"

	if { $sanitize == 0 } {
	    set ReturnString "${ReturnString}[$winname getcells $i,srcip]${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport]${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstip]${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]${SepChar}"
	} else {
	    set ReturnString "${ReturnString}a.b.c.d${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,srcport]${SepChar}e.f.g.h${SepChar}"
	    set ReturnString "${ReturnString}[$winname getcells $i,dstport]${SepChar}"
	}
	
	set ReturnString "${ReturnString}[$winname getcells $i,srcpckts]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,srcbytes]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,dstpckts]${SepChar}"
	set ReturnString "${ReturnString}[$winname getcells $i,dstbytes]\n"
    }
    return $ReturnString
}

