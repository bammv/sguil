####################################################
# Sguil procs that deal with selection and         #
# Multi-selection of events                        #
####################################################

#
# ReSetMotion: Reset Motion Vars on a button release
#
proc ReSetMotion {} {
    global MotionStart MotionLoxIndex MotionHighIndex MOVEMENT_DIR
    set MotionStart -1
    set MotionHighIndex -1
    set MotionLowIndex -1
    set MOVEMENT_DIR ""
}
#
# ShiftSelect: Enable MultiSelection using shift-click
#
proc ShiftSelect { winName index } {
    global MULTI_SELECT currentSelectedPane LASTINDEXSELECTED MOVEMENT_DIR BUSY
    # If we are busy then abort.
    if {$BUSY} { bell; return }
    # check to see if we are in a new pane and if so, error.
    if { [info exists currentSelectedPane] && [winfo parent [winfo parent $winName]] != $currentSelectedPane } {
	ErrorMessage "You may only shift-select from within the same event pane."
	return
    }
    # check to see if anything is currently selected, if no this is basically a single select
    if { [llength [$winName curselection]] < 1 } {
	SingleSelect $winName $index
	return
    }
    set MULTI_SELECT 1
    UnSelectPacketOptions
    UnSelectHostLookups
    # Check to see if the current index is higher or lower that the LASTSELECTEDINDEX
    if { $index > $LASTINDEXSELECTED } {
	set MOVEMENT_DIR "shift"
	foreach childWin [winfo children $currentSelectedPane] {
	      if { [winfo name $childWin] != "scroll" } {
		  $childWin.list select clear 0 end
	      }
	  }
	  HighLightListLine $currentSelectedPane $index $LASTINDEXSELECTED 
	  return
      } else {
	  set MOVEMENT_DIR "shift"
	  foreach childWin [winfo children $currentSelectedPane] {
	      if { [winfo name $childWin] != "scroll" } {
		  $childWin.list select clear 0 end
	      }
	  }
	  HighLightListLine $currentSelectedPane $index $LASTINDEXSELECTED 
	  return
      }
}
    
    
#
# MotionSelect: Enable selection of multiple rows using button-1 motion
#
proc MotionSelect { winName index } {
  global currentSelectedPane MULTI_SELECT MotionHighIndex MotionLowIndex MotionStart MOVEMENT_DIR
  global BUSY

  # If we are busy then abort.
  if {$BUSY} { bell; return }

  # check to see if we are in a new pane and if so, error.
  if { [info exists currentSelectedPane] && [winfo parent [winfo parent $winName]] != $currentSelectedPane } {
    ErrorMessage "You may only control-select from within the same event pane."
    return
  }
  # Check to see if something is currently selected
  # If so, this is going to add to the selection and set MULTI_SELECT to 1
  # If this is the first selection, it is essentially the same as clicking w/o the ctrl
  # and Multi-select should stay at 0
  if { [llength [$winName curselection]] > 0 } {
    set MULTI_SELECT 1 
  } else {
    # If this is the first item selected then treat as a SingleSelect
    SingleSelect $winName $index
    return
  }
  #  Motion events will always select consecutive indicies.  The click or ctrl-click
  # at the start of the motion will be either the high or the low.  When motion begins
  # we will set $MotionIndexHigh and $MotionIndexLow to the index that motion started on
  # but won't select or deselect it.  That should already have been done by the click.
  if { $MotionHighIndex == -1 } {
      set MotionHighIndex $index
      set MotionLowIndex $index
      set MotionStart $index
      return
  }
  # If the current index is the same as MotionStart we either haven't moved and only the
  # index at MotionStart should be selected.  So lets do a singleselect.  I know that this breaks
  # a user adding to a selection made with a ctrl-click, but deal with it.
  if { $index == $MotionStart } {
      SingleSelect $winName $index
      set MotionHighIndex $index
      set MotionLowIndex $index
      return
  }
  # Check to see if the current index falls between our existing low and High indices
  # if it does, we turned around
  if { $index > $MotionLowIndex && $index < $MotionHighIndex && $index != $MotionStart} {
      # Were we going up and turned down?
      if { $MotionHighIndex == $MotionStart } {
	  #unselect everything between the current index and the old MotionLowIndex
	  foreach childWin [winfo children $currentSelectedPane] {
	      if { [winfo name $childWin] != "scroll" } {
		  $childWin.list select clear $MotionLowIndex [expr $index-1]
	      }
	  }
	  # Set the new low to the current index
	  set MotionLowIndex $index
	 
      }
      # Were we going down and turned up?
      if { $MotionLowIndex == $MotionStart } {
	  #unselect everything between the current index and the old MotionHighIndex
	  foreach childWin [winfo children $currentSelectedPane] {
	      if { [winfo name $childWin] != "scroll" } {
		  $childWin.list select clear [expr $index+1] $MotionHighIndex
	      }
	  }
	  # Set the new High to the current index
	  set MotionHighIndex $index
      }
  }
  # If MotionIndexHigh/Low are set then this is not the first event.  Check the index to see
  # which direction the motion is going
  set MULTI_SELECT 1
  UnSelectPacketOptions
  UnSelectHostLookups
  if { $index > $MotionHighIndex } {
      set MotionHighIndex $index
      set MOVEMENT_DIR down
  }
  if { $index < $MotionLowIndex } {
      set MotionLowIndex $index
      set MOVEMENT_DIR up
  }
  # Select everything between high and low
  if { $MOVEMENT_DIR == "down" } {
        HighLightListLine $currentSelectedPane $MotionHighIndex $MotionLowIndex
  } else {
        HighLightListLine $currentSelectedPane $MotionLowIndex $MotionHighIndex
  }
    
  return
}



#
# CtrlSelect:  Enables selection of multiple rows using ctrl-click
#
proc CtrlSelect { winName index } {
  global currentSelectedPane MULTI_SELECT LASTINDEXSELECTED BUSY

  # If we are busy then abort.
  if {$BUSY} { bell; return }

  # Check to see if we are in a new pane and if so, error.
  if { [info exists currentSelectedPane] && [winfo parent [winfo parent $winName]] != $currentSelectedPane } {
    ErrorMessage "You may only control-select from within the same event pane."
    return
  }
  # Check to see if something is currently selected
  # If so, this is going to add to the selection and set MULTI_SELECT to 1
  # If this is the first selection, it is essentially the same as clicking w/o the ctrl
  # and Multi-select should stay at 0
  if { [llength [$winName curselection]] > 0 } {
    set MULTI_SELECT 1 
  } else {
    # If this is the first item selected then treat as a SingleSelect
    SingleSelect $winName $index
    return
  }
  # If ctrl-clicking an already selected event we should unselect it
  if { [$winName selection includes $index] == 1 } {
        foreach childWin [winfo children $currentSelectedPane] {
	  if { [winfo name $childWin] != "scroll" } {
	      $childWin.list select clear $index
	  }
      }
      return

  }
  # save the index in $LASTINDEXSELECTED
  set LASTINDEXSELECTED $index
  SelectAllLists $winName $index
}

#
# SingleSelect:  Selects a single row
#
proc SingleSelect { winName index } {
  global currentSelectedPane ACTIVE_EVENT MULTI_SELECT LASTINDEXSELECTED BUSY

  # If we are busy then abort.
  if {$BUSY} { bell; return }

  # On a right click, we could be called in on event that has
  # already been highlighted. We check so that we don't have to
  # go and get the whois etc info
  if { !$MULTI_SELECT && $ACTIVE_EVENT} {
    if { [$winName selection includes $index] } { 
      return
    }
  }

  set MULTI_SELECT 0 
  # Unhighlight anything that is highlighted
  if {[info exists currentSelectedPane]} {
    UnHighLightListLine $currentSelectedPane
  }
  # Save index in $LASTINDEXSELECTED
  set LASTINDEXSELECTED $index
  # Run SelectAllLists
  SelectAllLists $winName $index
}

proc SelectNextEvent { paneName index } {
    global ACTIVE_EVENT
  set listSize [$paneName.eventIDFrame.list size]
  if { $listSize == 0 } { set ACTIVE_EVENT 0; return }
  if { $index < $listSize  } {
    SelectAllLists $paneName.eventIDFrame.list $index
  } elseif { $index > 0 } {
    SelectAllLists $paneName.eventIDFrame.list [expr $index - 1]
  }
}

#
# SelectAllLists: Highlight all lists and update event data info.
#
proc SelectAllLists { winName index } {
  global MULTI_SELECT currentSelectedPane ACTIVE_EVENT DISPLAYEDDETAIL portscanDataFrame packetDataFrame
  global SSN_QUERY

  set ACTIVE_EVENT 1
  set currentSelectedPane [winfo parent [winfo parent $winName]]
  if { $index < 0 } {
    set ACTIVE_EVENT 0
    return
  }
 
  HighLightListLine $currentSelectedPane $index $index


  # Check to see if we are working with a session query tab
  if {[lindex [ split [winfo name $currentSelectedPane] _] 0] == "ssnquery" } { 
    set SSN_QUERY 1 
  } else {
    set SSN_QUERY 0
  }

#
# We don't want any detail displayed if this is a multi-select
# So lets stick this below bit in a conditional
#
  if { !$MULTI_SELECT } {
    if {$SSN_QUERY} {
      UnSelectPacketOptions
    } else {
      #puts [regexp "^spp_portscan:" [$currentSelectedPane.msgFrame.list get $index]]
      if { [regexp "^spp_portscan:" [$currentSelectedPane.msgFrame.list get $index]] } {
        if { $DISPLAYEDDETAIL != $portscanDataFrame } {
          pack forget $packetDataFrame
          pack $portscanDataFrame -fill both -expand true
        }
        set DISPLAYEDDETAIL $portscanDataFrame
        DisplayPortscanData
      } else {
        if { $DISPLAYEDDETAIL != $packetDataFrame } {
          pack forget $portscanDataFrame
          pack $packetDataFrame -fill both -expand true
          set DISPLAYEDDETAIL $packetDataFrame
        }
        DisplayPacketHdr $currentSelectedPane $index
        GetRuleInfo
        GetPacketInfo
      }
    }
    ResolveHosts
    GetWhoisData
  } else {
      UnSelectPacketOptions
      UnSelectHostLookups
  }
      
  
}
#
# UnHighLightListLine: Unhighlight currently highlighted line.
#
proc UnHighLightListLine { paneName } {
  if { [winfo exists $paneName] } {
    foreach childWin [winfo children $paneName] {
      if { [winfo name $childWin] != "scroll" } {
        $childWin.list select clear 0 end
      }
    }
  }
}

#
# HighLightListLine: Highlight all the lists.
# paneName = current pane name
# index = current index
# lastindex = other index for multi-selects.  If this is a single select
# put the same value as index
proc HighLightListLine { paneName index lastindex } {
  global MOVEMENT_DIR
  set activeIndex [$paneName.sensorFrame.list index active]
  foreach childWin [winfo children $paneName] {
    if { [winfo name $childWin] != "scroll" } {
      #$childWin.list select clear 0 end
      #$childWin.list select anchor $index
      #$childWin.list select set anchor $index
      $childWin.list activate $index
	if { $index > $lastindex } {
	    $childWin.list select set $lastindex $index 
	} else {
	    $childWin.list select set $index $lastindex
	}
	
	if { $MOVEMENT_DIR == "down" } {
	    $childWin.list see [expr $index+1]
	} elseif { $MOVEMENT_DIR == "up" } {
	    $childWin.list see [expr $index-1]
	} elseif { $MOVEMENT_DIR == "shift" } {
	    # do nothing
	} else {
	    $childWin.list see $index
	}
      $childWin.list itemconfigure $activeIndex -foreground black
    }
  }
}