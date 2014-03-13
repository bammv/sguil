# $Id: SguildAutoCat.tcl,v 1.6 2013/09/05 00:38:45 bamm Exp $ #

# Format for the autocat file is:
#  +------------+----------------------+------+-----+---------+----------------+
#  | Field      | Type                 | Null | Key | Default | Extra          |
#  +------------+----------------------+------+-----+---------+----------------+
#  | autoid     | int(10) unsigned     | NO   | PRI | NULL    | auto_increment |
#  | erase      | datetime             | YES  |     | NULL    |                |
#  | sensorname | varchar(255)         | YES  |     | NULL    |                |
#  | src_ip     | varchar(18)          | YES  |     | NULL    |                |
#  | src_port   | int(10) unsigned     | YES  |     | NULL    |                |
#  | dst_ip     | varchar(18)          | YES  |     | NULL    |                |
#  | dst_port   | int(10) unsigned     | YES  |     | NULL    |                |
#  | ip_proto   | tinyint(3) unsigned  | YES  |     | NULL    |                |
#  | signature  | varchar(255)         | YES  |     | NULL    |                |
#  | status     | smallint(5) unsigned | NO   |     | NULL    |                |
#  | active     | enum('Y','N')        | YES  |     | Y       |                |
#  | timestamp  | datetime             | NO   |     | NULL    |                |
#  | uid        | int(10) unsigned     | NO   |     | NULL    |                |
#  | comment    | varchar(255)         | YES  |     | NULL    |                |
#  +------------+----------------------+------+-----+---------+----------------+


# Return a list of all autocats in the DB
proc GetAutoCatList {} {

    set aquery \
      "SELECT \
         autocat.active, autocat.autoid, autocat.erase, autocat.sensorname, \
         autocat.src_ip, autocat.src_port, autocat.dst_ip, autocat.dst_port, \
         autocat.ip_proto, autocat.signature, autocat.status, user_info.username, \
         autocat.timestamp, autocat.comment                \
       FROM autocat, user_info WHERE autocat.uid=user_info.uid"

    set l [MysqlSelect $aquery list]
    return $l

}

# Send a list of autocats to a requesting client
proc SendAutoCatList { socketID } {
    
    foreach r [GetAutoCatList] { SendSocket $socketID [list InsertAutoCat $r] } 
    SendSocket $socketID [list InsertAutoCat end]

}

proc LoadAutoCats {} {

    set aquery \
      "SELECT \
         autoid, erase, sensorname, src_ip, src_port, \
         dst_ip, dst_port, ip_proto, signature, status, comment \
       FROM autocat \
       WHERE active='Y'"

    foreach line [MysqlSelect $aquery list] { ProcessAutoCat $line }

}

proc ProcessAutoCat { line } {

    set rid [lindex $line 0]
    set clearTime [lindex $line 1]

    if { $clearTime != "" } {

        set cTimeSecs [clock scan "$clearTime" -gmt true]

        if { $cTimeSecs > [clock seconds] } {

            # Invoke the rule
            AddAutoCatRule $rid [lrange $line 2 end] 

            # Set up the removal
            set DELAY [expr ($cTimeSecs - [clock seconds]) * 1000]
            after $DELAY RemoveAutoCatRule $rid

        } else {
 
            # Disable the autocat rule
            RemoveAutoCatRule $rid

        }

    } else {

        AddAutoCatRule [lindex $line 0] [lrange $line 2 end] 

    }

}

proc DisableAutoCatRule { socketID rid } {

    global userIDArray

    LogMessage "User $userIDArray($socketID) disabled autocat ID $rid"
    RemoveAutoCatRule $rid

}

proc RemoveAutoCatRule { rid } {

    global acRules acCat MAIN_DB_SOCKETID

    LogMessage "Removing Rule: $rid"

    if { [info exists acRules($rid)] } { unset acRules($rid) }
    if { [info exists acCat($rid)] } { unset acCat($rid) }

    set q "UPDATE autocat SET active='N' WHERE autoid='$rid'"
    if { [catch {::mysql::exec $MAIN_DB_SOCKETID $q} tmpError] } {

        LogMessage "Unable to disable autocat rule $rid in the DB: $tmpError"

    }

}

proc EnableAutoCatRule { socketID rid } {

    global MAIN_DB_SOCKETID userIDArray

    LogMessage "User $userIDArray($socketID) enabled autocat ID $rid"

    set q "UPDATE autocat SET active='Y' WHERE autoid='$rid'"

    if { [catch {::mysql::exec $MAIN_DB_SOCKETID $q} tmpError] } {

        LogMessage "Unable to enable autocat rule $rid: $tmpError"
        return

    }

    set aquery \
      "SELECT \
         autoid, erase, sensorname, src_ip, src_port, \
         dst_ip, dst_port, ip_proto, signature, status \
       FROM autocat \
       WHERE autoid='$rid'"

    ProcessAutoCat [MysqlSelect $aquery list]

}

proc AddAutoCatRule { rid rList } {

    global acRules acCat acComment

    InfoMessage "Adding AutoCat Rule: $rid $rList"

    # Counter for moving through rList indexes
    set i 0

    # dIndex are the indexes within each data line
    # that we want to look at.
    foreach dIndex [list 3 8 11 9 12 10 7] {

	# Next field in the rule
	set tmpVar [lindex $rList $i ]

	# All the fields have the option of being empty except status.
	if { $tmpVar == "" || $tmpVar == "any" || $tmpVar == "ANY" || $tmpVar == "none" || $tmpVar == "NONE" } { incr i; continue }

	# Need to test the regexp if we are looking at the sig index
	if { $dIndex == "7" } {

	    if [regsub "^%%REGEXP%%" $tmpVar "" regVar] {

		if [catch {regexp $regVar "XXTESTINGXX"} tmpError] {

		    LogMessage "Bad regexp in autocat rule $rid Error: $tmpError dropping rule"

		    # Rm any parts from the rule
		    if { [info exists acRules($rid)] } { unset acRules($rid) }

		    return

		}

	    }


	} elseif { ($dIndex == 8 || $dIndex == 9) && $tmpVar != "" } {

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

        incr i
	    
    }

    # Define the status matches are updated to
    set acCat($rid) [lindex $rList 7]
    # Define the comment associated w/matches
    set comment [lindex $rList 8]
    if { $comment == "" } { set acComment($rid) "autoid $rid" } else { set acComment($rid) "autoid $rid: $comment" }

}

proc AutoCat { data } {
    global acRules acCat acComment AUTOID
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
	    InfoMessage "AUTO MARKING EVENT AS : $acCat($rid)"
	    UpdateDBStatus [lindex $data 3] [lindex $data 4] [lindex $data 5] [lindex $data 6] [GetCurrentTimeStamp] $AUTOID $acCat($rid)
	    InsertHistory [lindex $data 5] [lindex $data 6] $AUTOID [GetCurrentTimeStamp] $acCat($rid) $acComment($rid) 
	    return 1
	}
    }
    return 0
}

proc AutoCatRequest { clientSocketID ruleList } {

    global userIDArray MAIN_DB_SOCKETID

    if { [llength $ruleList] != 10 } {

        SendSocket $clientSocketID [list ErrorMessage "Invalid number of values in autocat list: $ruleList"]
        return

    }

    set i 0
    foreach t [list erase sensorname src_ip src_port dst_ip dst_port ip_proto signature status comment] { 

        set v [lindex $ruleList $i]

        lappend tables $t

        if { $v != "none" && $v != "NONE" && $v != "any" && $v != "ANY" } {

            lappend values "\'$v\'"

        } else {

            lappend values NULL

        }

        incr i

    }

    lappend tables active timestamp uid
    lappend values "\'Y\'" "\'[GetCurrentTimeStamp]\'" "\'$userIDArray($clientSocketID)\'"

    # Build INSERT query
    set q "INSERT INTO autocat ([join $tables ,])  VALUES ([join $values ,])"

    # INSERT
    if { [catch {::mysql::exec $MAIN_DB_SOCKETID $q} tmpError] } {

        SendSocket $clientSocketID [list ErrorMessage "Error inserting autocat rule into the DB: $tmpError"]
        return

    }

    if { [catch {::mysql::insertid $MAIN_DB_SOCKETID} rid] || $rid == "" } {

        SendSocket $clientSocketID [list ErrorMessage "Error retrieving new autocat rule id: $rid"]
        return

    }
    
    if { [catch {AddAutoCatRule $rid [lrange $ruleList 1 end]} tmpError] } {

        SendSocket $clientSocketID [list ErrorMessage "Error inserting autocat rule: $rid"]

    } else {
        
        SendSocket $clientSocketID [list InfoMessage "AutoCat rule $rid successfully implemented."]

    }

}
