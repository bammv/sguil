# $Id: SguildAutoCat.tcl,v 1.1 2004/10/05 15:23:20 bamm Exp $ #

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
  global acRules acCat DEBUG
  if {$DEBUG} { puts "Removing Rule: $acRules($rid)" }
  unset acRules($rid)
  unset acCat($rid)
}

proc AddAutoCatRule { line rid } {
  global acRules acCat DEBUG
  if {$DEBUG} {puts "Adding AutoCat Rule: $line"}
  # dIndex are the indexes within each data line
  # that we want to look at.
  foreach dIndex [list 3 8 11 9 12 10 7] {
    # Next field in the rule
    set tmpVar [ctoken line "||"]
    # Need to test the regexp if we are looking at the sig index
    if { $dIndex == 7 } {
        if [regsub "^%%REGEXP%%" $tmpVar "" regVar] {
            if [catch {regexp $regVar "XXTESTINGXX"} tmpError] {
                puts "Bad regexp in autocat rule $rid Error: $tmpError dropping rule"
                # Rm any parts from the rule
                if { [info exists acRules($rid)] } { unset acRules($rid) }
                return
            }
        }
    }
    # All the fields have the option of being 'any'.
    # If one is, then we basically ignore that field.
    if { $tmpVar != "any" && $tmpVar != "ANY" } {
      lappend acRules($rid) [list $dIndex $tmpVar]
    }
  }
  set acCat($rid) [ctoken line "||"]
}

proc AutoCat { data } {
  global acRules acCat DEBUG AUTOID
  foreach rid [array names acRules] {
    set MATCH 1
    foreach rule [lrange $acRules($rid) 0 end] {
        set rIndex [lindex $rule 0]
        set rMatch [lindex $rule 1]
        # Check if we are looking for a sig msg match (index 7)
        if { $rIndex != 7 } {
            if { [lindex $data $rIndex] != $rMatch } {
                set MATCH 0
                break
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
      if {$DEBUG} {puts "AUTO MARKING EVENT AS : $acCat($rid)"}
      UpdateDBStatus "[lindex $data 5].[lindex $data 6]" [GetCurrentTimeStamp] $AUTOID $acCat($rid)
      InsertHistory [lindex $data 5] [lindex $data 6] $AUTOID [GetCurrentTimeStamp] $acCat($rid) "Auto Update"
      return 1
    }
  }
  return 0
}

