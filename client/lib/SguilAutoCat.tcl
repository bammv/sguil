# $Id: SguilAutoCat.tcl,v 1.2 2013/09/05 00:38:45 bamm Exp $

proc AutoCatBldr { erase sensor sip sport dip dport proto sig status } {

    global autocat USERNAME

    # Grab the current pointer locations
    set xy [winfo pointerxy .]

    # Create the window
    set autoBldWin .autoBldWin
    if { [winfo exists $autoBldWin] } {

        wm withdraw $autoBldWin
        wm deiconify $autoBldWin
        return

    }

    toplevel $autoBldWin
    wm title $autoBldWin "AutoCat Rule Builder"
    set height [winfo height .]
    set width [winfo width .]
    set y [expr ( ( $height / 2 ) - 250)]
    if { $y < 0 } { set y 0 }
    set x [expr ( ( $width / 2 ) - 350)]
    if { $x < 0 } { set x 0 }
    wm geometry $autoBldWin +$x+$y

    set bf [frame $autoBldWin.bf -background #dcdcec -borderwidth 1]

   
    set eraseEntry [ iwidgets::entryfield $bf.time \
      -labeltext "Expire Time" \
      -labelpos n \
      -width 18 \
      -focuscommand { UpdateACText erase } \
      -command "ACConvertTime $bf.time" \
    ]

    set sensorEntry [ iwidgets::entryfield $bf.sensor \
      -labeltext "Sensor Name" \
      -labelpos n \
      -width 18 \
      -focuscommand { UpdateACText sensor } \
    ]

    set sipEntry [ iwidgets::entryfield $bf.sip \
      -labeltext "Src IP" \
      -labelpos n \
      -width 16 \
      -focuscommand { UpdateACText sip } \
      -command "ACIPNormalize $bf.sip" \
    ]

    set sportEntry [ iwidgets::entryfield $bf.sport \
      -labeltext "Src Port" \
      -labelpos n \
      -width 6 \
      -focuscommand { UpdateACText sport } \
    ]

    set dipEntry [ iwidgets::entryfield $bf.dip \
      -labeltext "Dst IP" \
      -labelpos n \
      -width 16 \
      -focuscommand { UpdateACText dip } \
      -command "ACIPNormalize $bf.dip" \
    ]

    set dportEntry [ iwidgets::entryfield $bf.dport \
      -labeltext "Dst Port" \
      -labelpos n \
      -width 6 \
      -focuscommand { UpdateACText dport } \
    ]

    set protoEntry [ iwidgets::entryfield $bf.proto \
      -labeltext "Pr" \
      -labelpos n \
      -width 3 \
      -focuscommand { UpdateACText proto } \
    ]

    set sigEntry [ iwidgets::entryfield $bf.sig\
      -labeltext "Signature" \
      -labelpos n \
      -width 30 \
      -focuscommand { UpdateACText sig } \
    ]

    set statusEntry [ iwidgets::entryfield $bf.status\
      -labeltext "St" \
      -labelpos n \
      -width 3 \
      -focuscommand { UpdateACText status } \
    ]

    pack $eraseEntry $sensorEntry $sipEntry $sportEntry $dipEntry $dportEntry $protoEntry \
      -side left \
      -expand false

    pack $sigEntry \
      -side left \
      -fill x \
      -expand true

    pack $statusEntry \
      -side left \
      -expand false

    set commentEntry [ iwidgets::entryfield $autoBldWin.cmnt\
      -labeltext "Comment" \
      -labelpos w \
      -width 80 \
      -focuscommand { UpdateACText comment } \
    ]

    set h [message $autoBldWin.h \
      -justify left \
      -width 800 \
      -text "Modify auto cat rule above." \
    ]

    set bb [buttonbox $autoBldWin.bb]
      $bb add cancel -text "Cancel" -command "set autocat(state) cancel"
      $bb add submit -text "Submit" -command "set autocat(state) submit"

    pack $bf $commentEntry -side top -fill x
    pack $h -side top -fill both -expand true
    pack $bb -side top

    foreach value [list erase sensor sip sport dip dport proto sig status] { 

        eval $${value}Entry insert 0 $$value

    }

    vwait autocat(state)
   
    if { $autocat(state) == "submit" } {

        ACConvertTime $eraseEntry 
        ACIPNormalize $sipEntry
        ACIPNormalize $dipEntry

       foreach value [list erase sensor sip sport dip dport proto sig status comment] { 

            set $value [eval $${value}Entry get]

        }

        destroy $autoBldWin

        if { [catch {ValidateAutoCat $erase $sensor $sip $sport $dip $dport $proto $sig $status $comment} tmpError] } {

            ErrorMessage "You have an error with your rule syntax:\n $tmpError"
            AutoCatBldr $erase $sensor $sip $sport $dip $dport $proto $sig $status

        } else {

            SendToSguild [list AutoCatRequest $erase $sensor $sip $sport $dip $dport $proto $sig $status $comment]
            InfoMessage "Autocat rule sent to server."

        }
 
    } else {

        destroy $autoBldWin

    }

}

proc AutoCatFromEvent {} { 

    global ACTIVE_EVENT MULTI_SELECT CUR_SEL_PANE

    if { $ACTIVE_EVENT && !$MULTI_SELECT } {

        set selectedIndex [$CUR_SEL_PANE(name) curselection]
        set sensor [$CUR_SEL_PANE(name) getcells $selectedIndex,sensor]
        set sip [$CUR_SEL_PANE(name) getcells $selectedIndex,srcip]
        set sport [$CUR_SEL_PANE(name) getcells $selectedIndex,srcport]
        set dip [$CUR_SEL_PANE(name) getcells $selectedIndex,dstip]
        set dport [$CUR_SEL_PANE(name) getcells $selectedIndex,dstport]
        set proto [$CUR_SEL_PANE(name) getcells $selectedIndex,ipproto]
        set sig [$CUR_SEL_PANE(name) getcells $selectedIndex,event]

        AutoCatBldr {1 day} $sensor $sip $sport $dip $dport $proto $sig 1 

    }


} 

proc UpdateACText { name } {

    # Update help text based on entry w/focus

    set winName .autoBldWin.h

    switch -exact -- $name {

        erase   { set msgtxt "Time (YYYY-MM-DD HH:MM:SS) this autocat rule expires or \"none\".\nStrings like '2 days' or '48 hours' will be converted." } 
        sensor  { set msgtxt "Enter a sensor name or any" }
        sip     { set msgtxt "Source IP address or CIDR (192.168.1.2 or 192.168.1.0/24 or 127/8) or any" }
        sport   { set msgtxt "Source port or any" }
        dip     { set msgtxt "Destination IP address or CIDR (192.168.1.2 or 192.168.1.0/24 or 127/8) or any" }
        dport   { set msgtxt "Destination port or any" }
        proto   { set msgtxt "IP protocol in decimal (ICMP = 0, TCP = 6, UDP = 17)" }
        sig     { set msgtxt "Sig msg can use TCL regexp  format.  To make a sig msg a regexp begin the rule with %%REGEXP%%\n\
                              Matching is case sensitive unless the string is preceded by a (?i).\n\
                              Use ^ to match the beginning of the line and $ for the end.\n\
                              Examples:\n\n\
                              '%%REGEXP%%Testing' would match '123Testing123' but not '123testing123'\n\
                              '%%REGEXP%%(?i)testing' would match both '123Testing123' and '123testing123'\n\
                              '%%REGEXP%%^Testing' would match 'Testing' but not '123Testing' and not 'testing'\n\
                              '%%REGEXP%%(?i)^testing would match 'Testing' and 'testing' but not '123testing'\n\n\
                              If you don't use %%REGEXP%% the string you type in the sig must EXACTLY match the rule." }
        status   { set msgtxt "Status the alert matches will be automatically categorized to (NA=1, Cat I-VII = 11-17)" }
        comment  { set msgtxt "Add a comment for this rule." }
        default { return }

    } 

    $winName configure -text $msgtxt
}

proc ACConvertTime { winName } {

    set erase [$winName get]

    if { $erase != "none" && $erase != "NONE" } { 

        if { [catch {clock scan $erase} secs] } {

            ErrorMessage {Timestamp is not formatted correctly. Use the format YYYY-MM-DD HH:MM:SS or a descriptor like "24 hours".}

        } else {

            set timestamp [clock format $secs -gmt true -f "%Y-%m-%d %T"]
            $winName clear
            $winName insert 0 $timestamp

        }

    }

}

proc ACIPNormalize { winName } {

    set ip [$winName get]

    if { $ip != "any" && $ip != "ANY" } { 

        if { [catch {ip::normalize $ip} ip] } {

            ErrorMessage "The IP address is not formatted correctly. \
            Please use dotted notation or a CIDR. (192.168.8.8 or 127/8 or 192.168.8.0/24)"

        } else {

            $winName clear
            $winName insert 0 $ip

        }

    }

}

proc ValidateAutoCat { erase sensor sip sport dip dport proto sig status comment } {

    if { $erase != "none" && $erase != "NONE" && [catch {clock scan $erase} tmpError] } {

        return -code error "Timestamp is not formatted correctly."

    } 

    if { $sip != "any" && $sip != "ANY" && [ip::version $sip] != 4 } { return -code error "Source IP is invalid." }

    if { $sensor == "" } { return -code error "Sensor cannot be left blank" }

    if { $sport != "any" && $sport != "ANY" && [string is integer $sport] && ($sport < 0 || $sport > 65535) } { 
        return -code error "Source Port is invalid."
    }
    
    if { $dip != "any" && $dip != "ANY" && [ip::version $dip] != 4 } { return -code error "Destination IP is invalid." }

    if { $dport != "any" && $dport != "ANY" && ($dport < 0 || $dport > 65535) } { 
        return -code error "Destination Port is invalid."
    }

    if { $proto != "any" && $proto != "ANY" && ($proto < 0 || $proto > 255) } { 
        return -code error "IP Protocol \"$proto\" is invalid."
    }

    if { ![string is integer -strict $status] || $status < 1 } { 
       return -code error "An invalid status was provided"
    }

    if { [string length $comment] > 255 } { return -code error "Comments are limited to 255 characters." }

}

proc LaunchAutoCatViewer {} {

    set winName .acViewer

    if { ![winfo exists $winName] } { 

        CreateAutoCatViewer $winName 

    } else {

        wm withdraw $winName
        wm deiconify $winName

    }

    $winName configure -cursor watch
    SendToSguild SendAutoCatList

}

proc emptyStr { val } { return "" }

proc CreateAutoCatViewer { winName } {

    toplevel $winName
    wm title $winName "AutoCat Viewer"
    wm geometry $winName +[winfo rootx .]+[winfo pointery .]

    set aceFrame $winName.frame
    frame $aceFrame

    set aceTable $aceFrame.table
    set aceVScroll $aceFrame.vscroll
    set aceHScroll $winName.hscroll

    # erase sensor sip sport dip dport proto sig status comment
    tablelist::tablelist $aceTable \
        -columns {7   "Active"      center
                  3   "ID"          left
                  18  "Erase"       left
                  15  "Sensor"      left
                  16  "Src IP"      left
                  6   "SPort"       left
                  16  "Dst IP"      left
                  6   "DPort"       left
                  4   "Pr"          left
                  40  "Signature"   left
                  4   "ST"          left
                  12  "Owner"       left
                  18  "Created"     left
                  50  "Comment"     left}   \
        -stretch all \
        -width 150 \
        -height 5 \
        -movablecolumns 1 \
        -instanttoggle 1 \
        -yscrollcommand [list $aceVScroll set] \
        -xscrollcommand [list $aceHScroll set] \
        -editstartcommand ConfirmAutoCatChange \
        -editendcommand ChangeAutoCatStatus

    $aceTable columnconfigure 0 -name active -editable yes -width 0 -editwindow checkbutton -formatcommand emptyStr
    $aceTable columnconfigure 1 -name autoid -editable no -sortmode integer -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 2 -name erase -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 3 -name sensor -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 4 -name sip -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 5 -name sport -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 6 -name dip -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 7 -name dport -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 8 -name ipproto -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 9 -name signature -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 10 -name status -editable no -sortmode integer -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 11 -name owner -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 12 -name timestamp -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0
    $aceTable columnconfigure 13 -name comment -editable no -sortmode dictionary -resizable 1 -stretchable 1 -width 0

    scrollbar $aceVScroll -orient vertical -width 10 -command [list $aceTable yview]
    scrollbar $aceHScroll -orient horizontal -width 10 -command [list $aceTable xview]

    pack $aceTable -side left -fill both -expand true
    pack $aceVScroll -side right -fill y

    button $winName.close -text "Close" -command "destroy $winName"
    pack $aceFrame -side top -fill both -expand true
    pack $aceHScroll -side top -fill x
    pack $winName.close -side bottom

    return $aceTable

}

proc ConfirmAutoCatChange { tbl row col text} {

    set w [$tbl editwinpath]
    set r [lindex [$tbl get $row $row] 0]
    set clearTime [lindex $r 2]

    # Cannot enable a future rule
    if { $text == "0" && $clearTime != "none" } {

        set cTimeSecs [clock scan "$clearTime" -gmt true]
        if { $cTimeSecs < [clock seconds] } {

            tk_messageBox -parent $tbl -message "Cannot enable this rule, its erase time is in the past." -type ok -icon info
            $tbl cancelediting
            return [$tbl cellcget $row,$col -text]

        }

    }

    # Give the user an option to cancel this edit
    set answer [tk_messageBox -parent $tbl -message "Are you sure you want to modify this autocat rule?" -type yesno -icon question]
    if {$answer == "no"} { $tbl cancelediting }

    return [$tbl cellcget $row,$col -text]

}

proc ChangeAutoCatStatus { tbl row col text} {

    set img [expr {$text ? "checkedButton" : "uncheckedButton"}]
    $tbl cellconfigure $row,$col -image $img

    set r [lindex [$tbl get $row $row] 0]
    set rid [lindex $r 1]

    if { $text == "1" } {

        SendToSguild [list EnableAutoCatRule $rid]
        tk_messageBox -parent $tbl -message "AutoCat enable request for autocat id $rid sent." -type ok -icon info

    } else {

        SendToSguild [list DisableAutoCatRule $rid]
        tk_messageBox -parent $tbl -message "AutoCat disable request for autocat id $rid sent." -type ok -icon info

    }

    return $text

}

proc InsertAutoCat { r } { 

    set winName .acViewer
    set aceFrame $winName.frame
    set aceTable $aceFrame.table

    if { $r == "end" } { $winName configure -cursor left_ptr; return }

    # Y ==1 N == 0
    if { [lindex $r 0] == "Y" || [lindex $r 0] == "y" } { set r [lreplace $r 0 0 1] } else { set r [lreplace $r 0 0 0] }
    # Map nulls to "none" or "any"
    if { [lindex $r 2] == "" } { set r [lreplace $r 2 2 "none"] } 
    if { [lindex $r 13] == "" } { set r [lreplace $r 13 13 "none"] }
    for {set i 2}  {$i < 13} {incr i} { if { [lindex $r $i] == "" } { set r [lreplace $r $i $i "any"] } }

    # Insert row into table
    $aceTable insert end $r

    # Upate the checkbox
    set availImg [expr {([lindex $r 0] == 1) ? "checkedButton" : "uncheckedButton"}]
    $aceTable cellconfigure end,active -image $availImg

}

proc AutoCatEditButton { tbl row col w } {

    set key [$tbl getkeys $row]
    button $w -text "Edit" -command [list EditAutoCatRule $tbl $key]

}

proc EditAutoCatRule { tbl key } {

    puts "tbl -> $tbl ; key -> $key"

}


