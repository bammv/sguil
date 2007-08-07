#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: sancp_cleanup.tcl,v 1.1 2007/08/07 19:52:03 bamm Exp $ #

# Default vars
set DBHOST localhost
set DBPORT 3306
set DBUSER root
set DBNAME sguildb

proc DisplayUsage { cmd } {

    puts "Usage: $cmd \[--dbuser <username>\] \[--dbhost <hostname>\]\
                      \[--dbport <port>\] \[--dbname <dbname>\]\
                      \[--sensor <sensor name|all>\] \[--date <YYYYMMDD>\]"
    exit
}

# list returns { 1 foo } { 2 bar } { 3 fu }
# flatlist returns { 1 foo 2 bar 3 fu }
proc MysqlSelect { dbSocketID query { type {list} } } {

    if { $type == "flatlist" } {
        set queryResults [mysqlsel $dbSocketID $query -flatlist]
    } else {
         set queryResults [mysqlsel $dbSocketID $query -list]
    }
    return $queryResults

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
                --sensor         { set STATE sensor }
                --date           { set STATE date }
                default          { DisplayUsage $argv0 }
            }
        }
        dbuser          { set DBUSER $arg; set STATE flag }
        dbhost          { set DBHOST $arg; set STATE flag }
        dbport          { set DBPORT $arg; set STATE flag }
        dbname          { set DBNAME $arg; set STATE flag }
        sensor          { set SENSOR $arg; set STATE flag }
        date            { set TRIMDATE $arg; set STATE flag }
        default         { DisplayUsage $argv0 }
    }

}

if { ![info exists SENSOR] } { set SENSOR all } 

puts "This script is used to remove old SANCP tables from the database."
puts "This script DOES NOT archive these tables before they are deleted."
puts "Please make sure sguild has been STOPPED and backup your"
puts "data before continuing!"
puts ""
puts -nonewline "Do you want to continue? (y/N) "
flush stdout
set ans [gets stdin]
if { $ans != "Y" && $ans != "y" } {
    puts "You answered no. Goodbye"
    exit
}

# Get the DB pass
puts ""
puts -nonewline "Database password: "
flush stdout
exec stty -echo
set DBPASS [gets stdin]
exec stty echo

#
# Connect to the DB
#
if { $DBPASS == "" } {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"
} else {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"
}
puts ""
puts -nonewline "Connecting to database..."
flush stdout
if [catch {eval mysqlconnect $dbConnectCmd} dbSocketID] {
    puts "ERROR: Unable to connect to $DBHOST on $DBPORT: Make sure mysql is running."
    puts "$dbSocketID"
    exit
}
puts "Success."

#
# See if the DB we want to use exists
#
puts -nonewline "Trying to use database ${DBNAME}..."
if { [catch {mysqluse $dbSocketID $DBNAME} noDBError] } {
  puts "Failed."
  puts "Error: $noDBError"
  exit
}
puts "Success."

puts -nonewline "Getting a list of SANCP tables..."
if { $SENSOR == "all" } {
    set tmpQuery "SHOW TABLES LIKE 'sancp_%'"
} else {
    set tmpQuery "SHOW TABLES LIKE 'sancp_${SENSOR}_%'"
}

set sancpTableList [MysqlSelect $dbSocketID $tmpQuery list]
set sensors ""
foreach sancpTblName $sancpTableList {
    set tmpList [split $sancpTblName _]
    set sensorName [lindex $tmpList 1]
    set curDate [lindex $tmpList 2]
    if { [lsearch -exact $sensors $sensorName] < 0 } { lappend sensors $sensorName }
    if { ![info exists oldestDate($sensorName)] || $oldestDate($sensorName) > $curDate } {
        set oldestDate($sensorName) $curDate
    }
}
puts "Success."
puts ""
puts [format "%-24s | %-12s" Sensor "Oldest Date"]
puts "-------------------------|-------------"
foreach sensor $sensors { puts [format "%-24s | %-11s" $sensor $oldestDate($sensor)] }

if { ![info exists TRIMDATE] } {
    puts ""
    puts -nonewline "Trim table(s) to what date \[YYYYMMDD\]? "
    flush stdout
    set TRIMDATE [gets stdin]
    while { [string length $TRIMDATE] != 8 || ![regexp {^[0-9]+$} $TRIMDATE] } {
        puts "That date appears to be invalid."
        puts -nonewline "Trim table(s) to what date \[YYYYMMDD\]? "
        flush stdout
        set TRIMDATE [gets stdin]
    }
}
puts ""
set niceDate [clock format [clock scan $TRIMDATE] -f "%B %d, %Y"]
puts "Dropping tables from sensor(s) \"$SENSOR\" older than $TRIMDATE ($niceDate)"
puts ""
puts -nonewline "Do you want to continue? (y/N) "
flush stdout
set ans [gets stdin]
if { $ans != "Y" && $ans != "y" } {
    puts "You answered no. Goodbye"
    exit
}
puts ""
foreach table $sancpTableList {
    set tmpList [split $table _]
    set curDate [lindex $tmpList 2]
    if { $curDate < $TRIMDATE } {
        puts -nonewline "DROP TABLE `$table`..."
        mysqlexec $dbSocketID "DROP TABLE IF EXISTS `$table`"
        puts "Success."
    }
}
puts ""
puts -nonewline "Creating new SANCP MERGE table..."
flush stdout

# Drop table if exists first
mysqlexec $dbSocketID "DROP TABLE IF EXISTS sancp"

# New list of SANCP tables
set tmpQuery "SHOW TABLES LIKE 'sancp_%'"
set sancpTableList [MysqlSelect $dbSocketID $tmpQuery list]
# Have to add a tick
foreach table $sancpTableList { lappend tmpTables "`$table`" }

set createQuery "                                      \
    CREATE TABLE sancp                                 \
    (                                                  \
    sid           INT UNSIGNED            NOT NULL,    \
    sancpid       BIGINT UNSIGNED         NOT NULL,    \
    start_time    DATETIME                NOT NULL,    \
    end_time      DATETIME                NOT NULL,    \
    duration      INT UNSIGNED            NOT NULL,    \
    ip_proto      TINYINT UNSIGNED        NOT NULL,    \
    src_ip        INT UNSIGNED,                        \
    src_port      SMALLINT UNSIGNED,                   \
    dst_ip        INT UNSIGNED,                        \
    dst_port      SMALLINT UNSIGNED,                   \
    src_pkts      INT UNSIGNED            NOT NULL,    \
    src_bytes     INT UNSIGNED            NOT NULL,    \
    dst_pkts      INT UNSIGNED            NOT NULL,    \
    dst_bytes     INT UNSIGNED            NOT NULL,    \
    src_flags     TINYINT UNSIGNED        NOT NULL,    \
    dst_flags     TINYINT UNSIGNED        NOT NULL,    \
    INDEX p_key (sid,sancpid),                         \
    INDEX src_ip (src_ip),                             \
    INDEX dst_ip (dst_ip),                             \
    INDEX dst_port (dst_port),                         \
    INDEX src_port (src_port),                         \
    INDEX start_time (start_time)                      \
    ) TYPE=MERGE UNION=([join $tmpTables ,])      \
    "
# Create our MERGE sancp table
mysqlexec $dbSocketID $createQuery
puts "Success."
puts ""
puts "Finished!"
