#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: migrate_sancp.tcl,v 1.1 2005/01/28 19:32:41 bamm Exp $ #

# Default vars
set DBHOST localhost
set DBPORT 3306
set DBUSER root
set DBNAME sguildb

proc DisplayUsage { cmd } {

    puts "Usage: $cmd \[--dbuser <username>\] \[--dbhost <hostname>\]\
                      \[--dbport <port>\] \[--dbname <dbname>\]"
    exit
}

# Load mysql support.
if [catch {package require mysqltcl} mysqltclVersion] {
  puts "ERROR: The mysqltcl extension does NOT appear to be installed on this sysem."
  puts "Download it at http://www.xdobry.de/mysqltcl/"
  exit
}

# Get db stuff
set STATE flag
foreach arg $argv {
                                                                                                                              
    switch -- $STATE {
        flag {
            switch -glob -- $arg {
                --dbuser         { set STATE dbuser }
                --dbhost         { set STATE dbhost }
                --dbport         { set STATE dbport }
                --dbname         { set STATE dbname }
                --startdate      { set STATE start  }
                --enddate        { set STATE end  }
                default          { DisplayUsage $argv0 }
            }
        }
        dbuser          { set DBUSER $arg; set STATE flag }
        dbhost          { set DBHOST $arg; set STATE flag }
        dbport          { set DBPORT $arg; set STATE flag }
        dbname          { set DBNAME $arg; set STATE flag }
        start           { set START_DATE $arg; set STATE flag }
        end             { set END_DATE $arg; set STATE flag }
        default         { DisplayUsage $argv0 }
    }
                                                                                                                              
}


# Get the DB pass
puts -nonewline "Database password: "
flush stdout
exec stty -echo
set DBPASS [gets stdin]
exec stty echo

if { $DBPASS == "" } {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"
} else {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"
}
puts -nonewline "Connecting to database..." 
flush stdout
# Connect to mysqld
if [catch {eval mysqlconnect $dbConnectCmd} dbSocketID] {
    puts "ERROR: Unable to connect to $DBHOST on $DBPORT: Make sure mysql is running."
    puts "$dbSocketID"
    exit
}
puts "Success"

# See if the DB we want to use exists
if { [catch {mysqluse $dbSocketID $DBNAME} noDBError] } {
  puts "Error: $noDBError"
  exit
}
                                                                                                                              
# Make sure there is a sancp table
puts -nonewline "Checking for sancp table..."
flush stdout
if { [mysqlsel $dbSocketID {SHOW TABLES LIKE 'sancp'} -list] == "" } {
    puts "No."
    puts "Error: sancp table doesn't exist"
    exit
}
puts "Yes."

# Find a start time
if { [info exists START_DATE] } {
    puts "Using start date: $START_DATE"
} else {
    # Query the DB for the oldest start_time
    set START_DATE [lindex [join [mysqlsel $dbSocketID {SELECT MIN(start_time) FROM sancp} -flatlist]] 0]
    puts "Oldest date in current sancp is $START_DATE."
    puts -nonewline "Do you want me to use this date? (Y/n) "
    flush stdout
    set ans [gets stdin]
    if { $ans != "" && $ans != "Y" && $ans != "y" } {
        puts -nonewline "Enter the date you would like to use (YYYY-mm-dd): "
        flush stdout
        set START_DATE [gets stdin]
    }
}

# Find an end date
if { [info exists END_DATE] } {
    puts "Using end date: $END_DATE"
} else {
    # Query the DB for the oldest start_time
    set END_DATE [lindex [join [mysqlsel $dbSocketID {SELECT MAX(start_time) FROM sancp} -flatlist]] 0]
    puts "Newest date in current sancp is $END_DATE."
    puts -nonewline "Do you want me to use this date? (Y/n) "
    flush stdout
    set ans [gets stdin]
    if { $ans != "" && $ans != "Y" && $ans != "y" } {
        puts -nonewline "Enter the date you would like to use (YYYY-mm-dd): "
        flush stdout
        set END_DATE [gets stdin]
    }
}

set curDate $START_DATE
while { 1 } {

    set DATE_CONSTR "start_time >= '$curDate 00:00:00' AND start_time <= '$curDate 23:59:59'"
    puts "Building tables for start times between '$curDate 00:00:00' and '$curDate 23:59:59'."

    # Get a list of sids 
    puts -nonewline "Getting a list of sensor IDs..."
    flush stdout
    set tmpQry "SELECT DISTINCT(sid) FROM sancp WHERE $DATE_CONSTR"
    set sidList [mysqlsel $dbSocketID $tmpQry -flatlist]
    puts "$sidList"

    foreach tmpSid $sidList {

        set sensor [mysqlsel $dbSocketID "SELECT hostname FROM sensor WHERE sid=$tmpSid" -flatlist]
        set tableDate [clock format [clock scan $curDate] -gmt true -f "%Y%m%d"]
        set tableName "sancp_${sensor}_$tableDate"
        set tmpQry "CREATE TABLE `$tableName`   \n\
                    SELECT * FROM sancp         \n\
                    WHERE $DATE_CONSTR AND sid=$tmpSid"
        puts "\n$tmpQry\n"

        # Create new table
        puts -nonewline "Creating table $tableName..."
        flush stdout
        if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
            puts "Failed"
            puts "Error creating $tableName: $tmpError"
            exit
        }
        puts "Success."

        # Add indexes
        set tmpQry "ALTER TABLE `$tableName`        \n\
                     ADD PRIMARY KEY (sid,sancpid), \n\
                     ADD INDEX src_ip (src_ip),     \n\
                     ADD INDEX dst_ip (dst_ip),     \n\
                     ADD INDEX dst_port (dst_port), \n\
                     ADD INDEX src_port (src_port), \n\
                     ADD INDEX start_time (start_time);"
        puts "\n$tmpQry\n"

        puts -nonewline "Adding indexes to $tableName..."
        flush stdout
        if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
            puts "Failed"
            puts "Error altering $tableName: $tmpError"
            exit
        }
        puts "Success.\n"

    }

    if { $curDate == $END_DATE } { break }

    set curDate [clock format [clock scan tomorrow -base [clock scan $curDate]] -gmt true -f "%Y-%m-%d"] 

}

puts "\n** Finished. **\n"

puts "The new tables have been created."
puts "Please check to make sure things are in order and then DROP your current sancp table."
puts "After you have dropped the current sancp table, start sguild."
puts "Sguild will create the new MERGE table called sancp on init."

