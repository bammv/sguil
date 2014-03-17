####################################################
# Sguil procs that deal with selection and         #
# Multi-selection of events                        #
####################################################
# $Id: sellib.tcl,v 1.7 2006/06/02 20:53:14 bamm Exp $
#
# ReSetMotion: Reset Motion Vars on a button release
#

proc SelectNextEvent { paneName index } {

    global ACTIVE_EVENT

    set listSize [$paneName size]

    if { $listSize == 0 } { set ACTIVE_EVENT 0; return }

    if { $index < $listSize  } {

        $paneName selection set $index
        SelectEventPane $paneName EVENT EVENT

    } elseif { $index > 0 } {

        $paneName selection set [expr $index - 1]
        SelectEventPane $paneName EVENT EVENT

    }

}

proc SelectUp {} {

    global CUR_SEL_PANE

    set listSize [$CUR_SEL_PANE(name) size]
    if { $listSize == 0 } { set ACTIVE_EVENT 0; return }

    set selectedIndex [$CUR_SEL_PANE(name) curselection]
    # Can't move up
    if { $selectedIndex == 0 } { return }

    set nIndex [expr $selectedIndex - 1]
    $CUR_SEL_PANE(name) selection clear $selectedIndex
    $CUR_SEL_PANE(name) selection set $nIndex
    $CUR_SEL_PANE(name) see $nIndex

    if { $CUR_SEL_PANE(type) == "EVENT" } {

        SelectEventPane $CUR_SEL_PANE(name) EVENT EVENT

    } elseif { $CUR_SEL_PANE(type) == "SANCP" } {

        SelectSessionPane $CUR_SEL_PANE(name) SANCP SSN

    } elseif { $CUR_SEL_PANE(type) == "PADS" } {

        SelectPadsPane $CUR_SEL_PANE(name) PADS PADS

    }

}

proc SelectDown {} {

    global CUR_SEL_PANE

    set listSize [$CUR_SEL_PANE(name) size]
    if { $listSize == 0 } { set ACTIVE_EVENT 0; return }

    set selectedIndex [$CUR_SEL_PANE(name) curselection]
    set nIndex [expr $selectedIndex + 1]
    # Can't move down
    if { $nIndex == $listSize } { return }

    $CUR_SEL_PANE(name) selection clear $selectedIndex
    $CUR_SEL_PANE(name) selection set $nIndex
    $CUR_SEL_PANE(name) see $nIndex

    if { $CUR_SEL_PANE(type) == "EVENT" } {

        SelectEventPane $CUR_SEL_PANE(name) EVENT EVENT

    } elseif { $CUR_SEL_PANE(type) == "SANCP" } {

        SelectSessionPane $CUR_SEL_PANE(name) SANCP SSN

    } elseif { $CUR_SEL_PANE(type) == "PADS" } {

        SelectPadsPane $CUR_SEL_PANE(name) PADS PADS

    }

}

proc UserSelectedEvent { eventID uid } {

   global rtPaneArray

    # Loop through each pane until we find the matching eventID (sid.alert)
    foreach rtPane [array names rtPaneArray] {

       # A list of eventIDs in this pane
       set eidList [$rtPaneArray($rtPane) getcolumns alertID]
       set ematch [lsearch -exact $eidList $eventID]

        # Act on a match
        if { $ematch >= 0 } {

            # Update the status txt to be the user's uid
            $rtPaneArray($rtPane) cellconfigure $ematch,status -window "EventStatusLabel [list white $uid]"

        }

    }

}

proc UserUnSelectedEvent { eventID uid } {

    global rtPaneArray eventArray

    foreach rtPane [array names rtPaneArray] {

        set eidList [$rtPaneArray($rtPane) getcolumns alertID]
        set ematch [lsearch -exact $eidList $eventID]

        # Found the match
        if { $ematch >= 0 } {

            set priority [lindex $eventArray($eventID) 1]
            set statusColor [GetColorByPriority $priority]
            $rtPaneArray($rtPane) cellconfigure $ematch,status -window "EventStatusLabel [list $statusColor RT]"

        }

    }


}
