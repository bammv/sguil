#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: migrate_event.tcl,v 1.2 2005/10/27 03:39:04 bamm Exp $ #

# Default vars
set DBHOST localhost
set DBPORT 3306
set DBUSER root
set DBNAME sguildb

proc DisplayUsage { cmd } {

    puts "Usage: $cmd \[--dbuser <username>\] \[--dbhost <hostname>\]\
                      \[--dbport <port>\] \[--dbname <dbname>\]\
                      \[--startdate \"YYYY-MM-DD\"\] \[--enddate \"YYYY-MM-DD\"\]"
    exit
}

proc CreateTcpHdrTable { tableName sid minCid maxCid } {

    global dbSocketID

    puts "Creating Table => $tableName"
    puts "\n Running query:"
    set tmpQry "CREATE TABLE `$tableName`                              \n\
                SELECT sid, cid, tcp_seq, tcp_ack, tcp_off, tcp_res,   \n\
                tcp_flags, tcp_win, tcp_csum, tcp_urp                  \n\
                FROM tcphdr                                            \n\
                WHERE sid=$sid AND cid >= $minCid AND cid <= $maxCid"
    puts "\n$tmpQry\n"
    flush stdout

    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }

    puts "Adding INDEXES to $tableName"
    set tmpQry "ALTER TABLE `$tableName`  \n\
                ADD PRIMARY KEY (sid,cid)"
    puts "\n$tmpQry\n"
    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
                
    puts "Success."

}

proc CreateUdpHdrTable { tableName sid minCid maxCid } {

    global dbSocketID

    puts "Creating Table => $tableName"
    puts "\n Running query:"
    set tmpQry "CREATE TABLE `$tableName`                           \n\
                SELECT sid, cid, udp_len, udp_csum                  \n\
                FROM udphdr                                         \n\
                WHERE sid=$sid AND cid >= $minCid AND cid <= $maxCid"
    puts "\n$tmpQry\n"
    flush stdout

    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
    puts "Adding INDEXES to $tableName"
    set tmpQry "ALTER TABLE `$tableName`  \n\
                ADD PRIMARY KEY (sid,cid)"
    puts "\n$tmpQry\n"
    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
                
    puts "Success."

}

proc CreateIcmpHdrTable { tableName sid minCid maxCid } {

    global dbSocketID

    puts "Creating Table => $tableName"
    puts "\n Running query:"
    set tmpQry "CREATE TABLE `$tableName`                           \n\
                SELECT sid, cid, icmp_csum, icmp_id, icmp_seq       \n\
                FROM icmphdr                                        \n\
                WHERE sid=$sid AND cid >= $minCid AND cid <= $maxCid"
    puts "\n$tmpQry\n"
    flush stdout

    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
    puts "Adding INDEXES to $tableName"
    set tmpQry "ALTER TABLE `$tableName`  \n\
                ADD PRIMARY KEY (sid,cid)"
    puts "\n$tmpQry\n"
    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
                
    puts "Success."

}

proc CreateDataTable { tableName sid minCid maxCid } {

    global dbSocketID

    puts "Creating Table => $tableName"
    puts "\n Running query:"
    set tmpQry "CREATE TABLE `$tableName`                           \n\
                SELECT sid, cid, data_payload                       \n\
                FROM data                                           \n\
                WHERE sid=$sid AND cid >= $minCid AND cid <= $maxCid"
    puts "\n$tmpQry\n"
    flush stdout

    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
    puts "Adding INDEXES to $tableName"
    set tmpQry "ALTER TABLE `$tableName`  \n\
                ADD PRIMARY KEY (sid,cid)"
    puts "\n$tmpQry\n"
    if [catch {mysqlexec $dbSocketID $tmpQry} tmpError] {
        puts "Failed"
        puts "Error creating $tableName: $tmpError"
        exit
    }
                
    puts "Success."

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

puts "Use this script at your own risk. Be sure to back"
puts "up your data before proceeding!!"
puts -nonewline "Do you want to continue? (y/N) "
flush stdout
set ans [gets stdin]
if { $ans != "Y" && $ans != "y" } {
    puts "You answered no. Goodbye"
    exit
}

# Get the DB pass
puts -nonewline "Database password: "
flush stdout
exec stty -echo
set DBPASS [gets stdin]
exec stty echo

puts ""

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

                                                                                                                              
# Make sure there is a event table
puts -nonewline "Checking for event table..."
flush stdout
if { [mysqlsel $dbSocketID {SHOW TABLES LIKE 'event'} -list] == "" } {
    puts "No."
    puts "Error: event table doesn't exist"
    exit
}
puts "Yes."

# Find a start time
if { [info exists START_DATE] } {
    puts "Using start date: $START_DATE"
} else {
    # Query the DB for the oldest timestamp
    set START_DATE [lindex [join [mysqlsel $dbSocketID {SELECT MIN(timestamp) FROM event} -flatlist]] 0]
    puts "Oldest date in current event is $START_DATE."
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
    # Query the DB for the oldest timestamp
    set END_DATE [lindex [join [mysqlsel $dbSocketID {SELECT MAX(timestamp) FROM event} -flatlist]] 0]
    puts "Newest date in current event is $END_DATE."
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

    set DATE_CONSTR "timestamp >= '$curDate 00:00:00' AND timestamp <= '$curDate 23:59:59'"
    puts "Building tables for start times between '$curDate 00:00:00' and '$curDate 23:59:59'."

    # Get a list of sids 
    puts -nonewline "Getting a list of sensor IDs..."
    flush stdout
    set tmpQry "SELECT DISTINCT(sid) FROM event WHERE $DATE_CONSTR"
    set sidList [mysqlsel $dbSocketID $tmpQry -flatlist]
    puts "$sidList"

    foreach tmpSid $sidList {

        set sensor [mysqlsel $dbSocketID "SELECT hostname FROM sensor WHERE sid=$tmpSid" -flatlist]
        set tableDate [clock format [clock scan $curDate] -gmt true -f "%Y%m%d"]
        set tableName "event_${sensor}_$tableDate"
        set tmpQry "CREATE TABLE `$tableName`                                      \n\
                    SELECT sid, cid, signature, signature_gen, signature_id,       \n\
                    signature_rev, timestamp, unified_event_id, unified_event_ref, \n\
                    unified_ref_time, priority, class, status, src_ip, dst_ip,     \n\
                    src_port, dst_port, icmp_type, icmp_code, ip_proto, ip_ver,    \n\
                    ip_hlen, ip_tos, ip_len, ip_id, ip_flags, ip_off, ip_ttl,      \n\
                    ip_csum, last_modified, last_uid, abuse_queue, abuse_sent      \n\
                    FROM event                                                     \n\
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
        set tmpQry "ALTER TABLE `$tableName`                  \n\
                     ADD PRIMARY KEY (sid,cid),               \n\
                     ADD INDEX sid_time (sid, timestamp),     \n\
                     ADD INDEX src_ip (src_ip),               \n\
                     ADD INDEX dst_ip (dst_ip),               \n\
                     ADD INDEX dst_port (dst_port),           \n\
                     ADD INDEX src_port (src_port),           \n\
                     ADD INDEX icmp_type (icmp_type),         \n\
                     ADD INDEX icmp_code (icmp_code),         \n\
                     ADD INDEX timestamp (timestamp),         \n\
                     ADD INDEX last_modified (last_modified), \n\
                     ADD INDEX signature (signature),         \n\
                     ADD INDEX status (status)"
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

puts "\n** Finished Event Table(s) **\n"

if { [ catch { mysqlsel $dbSocketID {SHOW TABLES LIKE 'event_%'} -list} eventTableList ] } {
    puts "Error: Trying to get event_sensor_date table list: $eventTableList"
    exit
}
if { $eventTableList == "" } {
    puts "Error: Cannot find any event_sensor_date tables."
    exit
}

puts "\n** New event tables: $eventTableList **\n"

puts "\n** Building Secondary (TCP/UDP/ICMP/DATA) Tables **\n"

foreach eventTable $eventTableList {

    # eventTable in format event_$sensor_$date
    set tmpSensor [lindex [split $eventTable _] 1]
    set tmpDate [lindex [split $eventTable _] 2]

    puts "Working on $eventTable..."

    puts "Sensor Name => $tmpSensor"
    puts "Date => $tmpDate"

    set tmpQry "SELECT sid FROM sensor WHERE hostname='$tmpSensor'"
    set sid [mysqlsel $dbSocketID $tmpQry -flatlist]
    puts "  sid => $sid"

    set tmpQry "SELECT MIN(cid) FROM `$eventTable` WHERE sid=$sid"
    set minCid [mysqlsel $dbSocketID $tmpQry -flatlist]
    puts "    min cid => $minCid"
    set tmpQry "SELECT MAX(cid) FROM `$eventTable` WHERE sid=$sid"
    set maxCid [mysqlsel $dbSocketID $tmpQry -flatlist]
    puts "    max cid => $maxCid"

    # Create the other tables.
    CreateTcpHdrTable tcphdr_${tmpSensor}_${tmpDate} $sid $minCid $maxCid
    CreateUdpHdrTable udphdr_${tmpSensor}_${tmpDate} $sid $minCid $maxCid
    CreateIcmpHdrTable icmphdr_${tmpSensor}_${tmpDate} $sid $minCid $maxCid
    CreateDataTable data_${tmpSensor}_${tmpDate} $sid $minCid $maxCid
 
}

puts "The new tables have been created."
puts "Please check to make sure things are in order and then DROP your"
puts "current event, tcphdr, udphdr, icmphdr, and data tables."
puts "After you have dropped the current event table, start sguild."
puts "Sguild will create the new MERGE tables on init."

puts "\n** Finished. **\n"
