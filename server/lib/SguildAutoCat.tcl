# $Id: SguildAutoCat.tcl,v 1.3 2005/01/26 17:16:15 shalligan Exp $ #

# Format for the autocat file is:
# <erase time>||<sensorName>||<src_ip>||<src_port>||<dst_ip>||<dst_port>||<proto>||<sig msg>||<cat value>
proc LoadAutoCatFile { filename } {
  set i 0
  for_file line $filename {
    if ![regexp ^# $line] {
      set cTime [ctoken line "||"]
      if { $cTime != "none" && $cTime != "NONE" } {
        set cTimeSecs [clock scan "$cTime" -gmt true]
        if { $cTimeSecs > [clock seconds] } {
          # Set up the removal
          set DELAY [expr ($cTimeSecs - [clock seconds]) * 1000]
          after $DELAY RemoveAutoCatRule $i
          AddAutoCatRule $line $i
          incr i
        }
      } else {
        AddAutoCatRule $line $i
        incr i
      }
    }
  }
}

proc RemoveAutoCatRule { rid } {
  global acRules acCat
  LogMessage "Removing Rule: $acRules($rid)"
  unset acRules($rid)
  unset acCat($rid)
}

proc AddAutoCatRule { line rid } {
    global acRules acCat
    InfoMessage "Adding AutoCat Rule: $line"
    # dIndex are the indexes within each data line
    # that we want to look at.
    foreach dIndex [list 3 8 11 9 12 10 7] {
	# Next field in the rule
	set tmpVar [ctoken line "||"]

	# All the fields have the option of being 'any'.
	# If one is, then we basically ignore that field.
	if { $tmpVar == "ANY" || $tmpVar == "any" } { continue }

	# Need to test the regexp if we are looking at the sig index
	if { $dIndex == 7 } {
	    if [regsub "^%%REGEXP%%" $tmpVar "" regVar] {
		if [catch {regexp $regVar "XXTESTINGXX"} tmpError] {
		    LogMessage "Bad regexp in autocat rule $rid Error: $tmpError dropping rule"
		    # Rm any parts from the rule
		    if { [info exists acRules($rid)] } { unset acRules($rid) }
		    return
		}
	    }
	} elseif { ($dIndex == 8 || $dIndex == 9) && ($tmpVar != "ANY" || $tmpVar != "any") } {
	    # test the ip address field for CIDR and convert the IP to decimal
	    set ipList [ValidateIPAddress $tmpVar]
	    if { $ipList == 0 } {
		LogMessage "Bad IP address in autocat rule $rid dropping rule"
		if { [info exists acRules($rid)] } { unset acRules($rid) }
		return
	    }
	    # IP is valid and now we have a list with our ip range (net number - bcast address)
	    # if it was a single address and not a net, these numbers will be the same
	    set tmpVar [list [InetAtoN [lindex $ipList 2]] [InetAtoN [lindex $ipList 3]]]
	}
	
	# add the match var to the rule list
	lappend acRules($rid) [list $dIndex $tmpVar]
	    
	}
	set acCat($rid) [ctoken line "||"]
}

proc AutoCat { data } {
    global acRules acCat AUTOID
    foreach rid [array names acRules] {
	set MATCH 1
	foreach rule [lrange $acRules($rid) 0 end] {
	    set rIndex [lindex $rule 0]
	    set rMatch [lindex $rule 1]
	    # Check if we are looking for a sig msg match (index 7)
	    if { $rIndex != 7 && $rIndex != 8 && $rIndex != 9 } {
		if { [lindex $data $rIndex] != $rMatch } {
		    set MATCH 0
		    break
		}
	    } elseif { $rIndex != 7 } {
		# ip address match vars are a list with a low and high ip address
		set dataVar [InetAtoN [lindex $data $rIndex]]
		set netIP [lindex $rMatch 0]
		set bcastIP [lindex $rMatch 1]
		if { $dataVar < $netIP || $dataVar > $bcastIP } {
		    set MATCH 0
		}
	    } else {
		# Check to see if the rule is a regexp if so
		# remove the %%REGEXP%% from the rule and use
		# regexp to check for a match
		if [regsub "^%%REGEXP%%" $rMatch "" rMatch] {
		    if { ![regexp $rMatch [lindex $data $rIndex]] } {
			set MATCH 0
			break
		    }
		} else {
		    # msg rule is not a regexp, just do a simple != test
		    if { [lindex $data $rIndex] != $rMatch } {
			set MATCH 0
			break
		    }
		}
	    }
	}
	if { $MATCH } {
	    InfoMessage "AUTO MARKING EVENT AS : $acCat($rid)"
	    UpdateDBStatus "[lindex $data 5].[lindex $data 6]" [GetCurrentTimeStamp] $AUTOID $acCat($rid)
	    InsertHistory [lindex $data 5] [lindex $data 6] $AUTOID [GetCurrentTimeStamp] $acCat($rid) "Auto Update"
	    return 1
	}
    }
    return 0
}

