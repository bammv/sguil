#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id #

##
## Default values and globals
##

# Default DB host
set DBHOST localhost

# Default DB name
set DBNAME sguildb

# Default DB user
set DBUSER root

# DEFAULT DB passwd
set DBPASS ""

# Default is to archive event
set EVENT 1

# Default is to NOT archive session
set SESSION 0
set DEL_SESSION 0

# Default is to NOT archive sancp
set SANCP 0
set DEL_SANCP 0

# Default mode is interactive
set ASSUME_YES 0

# Echo whats going on
set QUIET 0

# Default action for portscan data (delete or archive)
set PSDATA archive


# Load mysql support.
if [catch {package require mysqltcl} mysqltclVersion] {
  puts "ERROR: The mysqltcl extension does NOT appear to be installed on this sysem."
  puts "Download it at http://www.xdobry.de/mysqltcl/"
  CleanExit
}

############## procs ##################

# Proc to connect to the DB
proc ConnectToDB { dbhost dbname dbuser {dbpass {}} } {
  if { $dbpass == "" } {
    set mysqlConnect "mysqlconnect -host $dbhost -db $dbname -user $dbuser"
  } else {
    set mysqlConnect "mysqlconnect -host $dbhost -db $dbname -user $dbuser -password $dbpass"
  }
  if { [catch {eval $mysqlConnect} connectError] } {
    return -code error $connectError
  } else {
    return -code ok $connectError
  }
}

# Returns a list of sensor ids in the sensor table
proc GetSensorIDList { dbSocketID table } {
   set query "SELECT DISTINCT(sid) FROM $table"
   if { [catch {mysqlsel $dbSocketID $query -flatlist} qResults] } {
     puts "Error getting sensor list: $qResults"
     exit 1
   }
   return -code ok $qResults
}

# Creates a new event table based on dates
proc CreateNewEventTable { dbSocketID prefix end_date } {
  set query "CREATE TABLE ${prefix}event SELECT * FROM event WHERE timestamp < '$end_date'"
   if { [catch {mysqlexec $dbSocketID $query } execError] } {
     puts "Error creating ${prefix}event: $execError"
     exit 1
   }
}

# Deletes old events from event table
proc DeleteOldFromEvent { dbSocketID end_date } {
  set query "DELETE FROM event WHERE timestamp < '$end_date'"
   if { [catch {mysqlexec $dbSocketID $query } execError] } {
     puts "Error Deleting ${prefix}event: $execError"
     exit 1
   }
}

# Creates new table 
proc CreateNewTable { table prefix dbSocketID whereStatement } {
  set query "CREATE TABLE ${prefix}${table} SELECT * FROM $table WHERE $whereStatement"
   if { [catch {mysqlexec $dbSocketID $query } execError] } {
     puts "Error creating ${prefix}${table}: $execError"
     exit 1
   }
}

# Deletes data from old table
proc DeleteOldFromTable { table whereStatement dbSocketID } {
  set query "DELETE FROM $table WHERE $whereStatement"
   if { [catch {mysqlexec $dbSocketID $query } execError] } {
     puts "Error Deleting ${table}: $execError"
     exit 1
   }
}

# Number of rows in a table.
proc MysqlNumberOfRows { table dbSocketID } {
   set query "SELECT COUNT(*) FROM $table"
   if { [catch {mysqlsel $dbSocketID $query -flatlist} qResults] } {
     puts "Error getting number of rows: $qResults"
     exit 1
   }
   return -code ok $qResults
}

proc DisplayUsage { cmd } {
  puts "Usage: $cmd \[-h\] \[-q\] \[-y\] \[--delete-portscans\] \[--event\] \[--ignore-event\]\
               \[--session\] \[--ignore-session\] \[--sancp\] \[--ignore-sancp\]\
               \[-d <YYYY-MM-DD>\] \[-p <prefix>\] \[--dbname <db name>\]"
  puts ""
  puts "  -d <YYYY-MM-DD>:     Ending date for archiving (exclusive)."
  puts "  -p <prefix>:         What string to prepend to newly created tables."
  puts "  --dbname <db name>:  Name of DB to use."
  puts "  --dbhost <host>:     Database hostname."
  puts "  --dbuser <user>:     Username to connect to db as."
  puts "  -h:                  Display this help."
  puts "  -q:                  Be quiet (assumes yes to any prompts)."
  puts "  -y:                  Display output, but assume yes to any prompts."
  puts "  --delete-portscans:  Delete portscans, but don't archive them in a new table."
  puts "  --event:             (default) Archive event tables (including *hdr, data, history, etc)."
  puts "  --ignore-event:      Ignore archive event tables."
  puts "  --session:           Archive the session table."
  puts "  --delete-session:    Delete matching rows from the session table and do NOT archive."
  puts "  --ignore-session:    (default) Ignore the session table."
  puts "  --sancp:             Archive the sancp table."
  puts "  --delete-sancp:      Delete matching rows from the sancp table and do NOT archive."
  puts "  --ignore-sancp:      (default)  Ignore the sancp table."
  puts ""
  puts " Example: $cmd --event --sancp --delete-portscans -p june_ -d 2004-08-01 --dbname sguildb"
  puts "   This would create the tables june_event, june_tcphdr, june_sancp, etc"
  puts "   in the database sguildb using WHERE timestamp < '2004-08-01'. Portscan data would"
  puts "   NOT be archived."
  exit
}

# GetOpts
set state flag
foreach arg $argv {
  switch -- $state {
    flag {
      switch -glob -- $arg {
        -- { set state flag }
        -h { DisplayUsage $argv0}
        -d { set state date }
        -p { set state prefix }
        -q { set QUIET 1 }
        -y { set ASSUME_YES 1 }
        --dbname { set state dbname }
        --dbhost { set state dbhost }
        --dbuser { set state dbuser }
        --dbpass { set state dbpass }
        --delete-portscans { set PSDATA delete }
        --event { set EVENT 1 }
        --ignore-event { set EVENT 0 }
        --session { set SESSION 1 }
        --delete-session { set SESSION 1; set DEL_SESSION 1 }
        --ignore-session { set SESSION 0 }
        --sancp { set SANCP 1 }
        --delete-sancp { set SANCP 1; set DEL_SANCP 1 }
        --ignore-sancp { set SANCP 0 }
        default { DisplayUsage $argv0 }
      }
    }
    date { set END_DATE $arg; set state flag }
    prefix { set PREFIX $arg; set state flag }
    dbname { set DBNAME $arg; set state flag }
    dbuser { set DBUSER $arg; set state flag }
    dbhost { set DBHOST $arg; set state flag }
    dbpass { set DBPASS $arg; set state flag }
    default { DisplayUsage $argv0 }
  }
}

##
## Do some usage checks
##

# Have to have an END_DATE
if { ![info exists END_DATE] } {
  puts "Error: An end date is required (-d <end_date>)"
  exit 1
}
# Check date format
if { ![regexp {^\d{4}-\d{2}-\d{2}} $END_DATE] } {
  puts "Error: End date must be in YYYY-MM-DD format."
  exit 1
}
# Check for a prefix (not needed if EVENT == 0 and DEL_SESSION OR DEL_SANCP is set)
if { ![info exists PREFIX] } { 
  if { $EVENT || ( $SESSION && !$DEL_SESSION ) || ( $SANCP && !$DEL_SANCP ) } {
    puts "Error: You must include a prefix for the archive table names."
    puts "(i.e.:  -p aug_  would create tables like aug_event, aug_tcphdr, etc)"
    exit 1
  }
}

# Write out import info for the user to validate before pressing on
if { !$QUIET } {
  puts "database => $DBNAME"
  puts "DB host => $DBHOST"
  puts "DB user => $DBUSER"
  puts "SELECT condition => WHERE timestamp < '$END_DATE'"
  if { [info exists PREFIX] } {
    puts "Prefix for new tables (ie ${PREFIX}event) => $PREFIX"
  }
  puts -nonewline "Clean and archive event tables (including *hdr, data, etc) => "
  if { $EVENT } { 
    puts "Yes." 
    if { $PSDATA == "delete" } {
      puts "Portscan data will be deleted from main table and WILL NOT be archived."
    } else {
      puts "Portscan data will be deleted from main table and WILL be archived."
    }
  } else {
    puts "No."
  }
  puts -nonewline "Clean sessions table => "
  if { $SESSION } {
    puts "Yes."
    puts -nonewline "Create sessions archive => "
    if { !$DEL_SESSION } { puts "Yes." } else { puts "No." }
  } else {
    puts "No."
  }
  puts -nonewline "Clean sancp table => "
  if { $SANCP } {
    puts "Yes."
    puts -nonewline "Create sancp archive => "
    if { !$DEL_SANCP } { puts "Yes." } else { puts "No." }
  } else {
    puts "No."
  }
  puts "-----------------------------------------------"
  puts -nonewline "Is this info correct (y/n)? "
  flush stdout
  if { $ASSUME_YES } { 
    puts "Y"
  } else {
    set answer [gets stdin]
    if { ![regexp {^[yY]} $answer] } {
      puts "Aborting."
      exit
    }
  }
  puts ""
  puts -nonewline "Connecting to $DBHOST and using $DBNAME..."
}
if { [catch {ConnectToDB $DBHOST $DBNAME $DBUSER $DBPASS} connectError] } {
  if { !$QUIET} { puts "Failed." }
  puts "Error: $connectError"
  exit 1
} else {
  if { !$QUIET } { puts "Success." }
}
set DBSOCKETID $connectError

# Archive actions for the event tables.
if { $EVENT } { 
    # Give the number of events in the db for giggles
    if { !$QUIET } { puts "Total Number of rows in event: [MysqlNumberOfRows event $DBSOCKETID]" }

    #
    # Create our new event table
    #
    if { !$QUIET } { puts -nonewline "Creating new event table ${PREFIX}event..." }
    flush stdout
    CreateNewEventTable $DBSOCKETID $PREFIX $END_DATE
    if { !$QUIET } { puts "Success." }
    
    #
    # Check if anything was created.
    # 
    set newTableRows [MysqlNumberOfRows ${PREFIX}event $DBSOCKETID]
    if { $newTableRows == 0 } {
        # Nothing was archived.
        if { !$QUIET } { puts "No event data to archive." }
        exit
    }
    if { !$QUIET } { puts "Total Number of rows in ${PREVIX}event: $newTableRows" }
    
    #
    # Delete archived data from the event table
    #
    if { !$QUIET } { puts -nonewline "Deleting archived data from the event table..." }
    flush stdout
    DeleteOldFromEvent $DBSOCKETID $END_DATE
    if { !$QUIET } { puts "Success." }
    # Give the number of events in the db for giggles
    if { !$QUIET } { puts "Total Number of rows in event: [MysqlNumberOfRows event $DBSOCKETID]" }
    
    #
    # Get a list of sensors id's from our new table
    #
    if { !$QUIET } { puts -nonewline "Getting a list of sensors..." }
    set sensorIDList [GetSensorIDList $DBSOCKETID ${PREFIX}event]
    if { !$QUIET } { puts "Success." }
    if { !$QUIET } { puts "Sensor list: $sensorIDList" }
    
    #
    # The rest of the tables are archived based on each sensors
    # min and max cid in the new event table.
    #
    # Build a list of mins and maxs
    foreach sid $sensorIDList {
      set query "SELECT MIN(cid), MAX(cid) FROM ${PREFIX}event WHERE sid=$sid"
       if { [catch {mysqlsel $DBSOCKETID $query -flatlist} qResults] } {
         puts "Error running '$query':"
         puts "  $qResults"
         exit 1
       }
       lappend minmaxList "(sid=$sid AND cid >= [lindex $qResults 0] AND cid <= [lindex $qResults 1])"
    }
    # Make a big OR constraint for our future queries
    regsub -all {\) \(} [join $minmaxList] {) OR (} minmaxQuery
    
    # Go thru each table and strip out and delete the records
    foreach table "tcphdr udphdr icmphdr data history" {
      if { !$QUIET } { puts -nonewline "Creating ${PREFIX}${table}..." }
      flush stdout
      CreateNewTable $table $PREFIX $DBSOCKETID $minmaxQuery
      if { !$QUIET } { puts "Success." }
      flush stdout
      if { !$QUIET } { puts -nonewline "Deleting from ${table}..." }
      flush stdout
      DeleteOldFromTable $table $minmaxQuery $DBSOCKETID
      if { !$QUIET } { puts "Success." }
      flush stdout
    }
    
    # Last one is the portscan table. We use date here.
    # User has the option to delete or archive this data.
    if { $PSDATA == "archive" } {
      if { !$QUIET } { puts -nonewline "Creating ${PREFIX}portscan..." }
      flush stdout;
      CreateNewTable portscan $PREFIX $DBSOCKETID "timestamp < '$END_DATE'"
    } else {
      puts "The portscan table WILL NOT be archived."
    }
    if { !$QUIET } { puts -nonewline "Deleting from portscan..." }
    flush stdout;
    DeleteOldFromTable portscan "timestamp < '$END_DATE'" $DBSOCKETID
    if { !$QUIET } { puts "Success." }
}


# Archive for sessions table
if { $SESSION } {
    if { !$QUIET } { puts "Total Number of rows in sessions: [MysqlNumberOfRows sessions $DBSOCKETID]" }
    if { !$DEL_SESSION } {
      if { !$QUIET } { 
        puts -nonewline "Creating ${PREFIX}sessions..."
        flush stdout
      }
      CreateNewTable sessions $PREFIX $DBSOCKETID "start_time < '$END_DATE'"
      if { !$QUIET } { puts "Success." }
    }
    if { !$QUIET } { puts -nonewline "Deleting from sessions..." }
    flush stdout
    DeleteOldFromTable sessions "start_time < '$END_DATE'" $DBSOCKETID
    if { !$QUIET } { puts "Success." }
    if { !$QUIET } { puts "Total Number of rows in sessions: [MysqlNumberOfRows sessions $DBSOCKETID]" }
}
if { $SANCP } {
    if { !$QUIET } { puts "Total Number of rows in sancp: [MysqlNumberOfRows sancp $DBSOCKETID]" }
    if { !$DEL_SANCP } {
      if { !$QUIET } {
        puts -nonewline "Creating ${PREFIX}sancp..."
        flush stdout
      }
      CreateNewTable sancp $PREFIX $DBSOCKETID "start_time < '$END_DATE'"
      if { !$QUIET } { puts "Success." }
    }
    if { !$QUIET } {
      puts -nonewline "Deleting from sancp..."
      flush stdout
    }
    DeleteOldFromTable sancp "start_time < '$END_DATE'" $DBSOCKETID
    if { !$QUIET } { puts "Success." }
    if { !$QUIET } { puts "Total Number of rows in sancp: [MysqlNumberOfRows sancp $DBSOCKETID]" }
}
# DONE
if { !$QUIET } {
  puts "Finished."
  puts "You should now run 'mysqlcheck -a -o $DBNAME'."
}
