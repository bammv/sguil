#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: update_0.7.tcl,v 1.2 2007/08/07 19:53:01 bamm Exp $ #

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

# type can be list or flatlist.
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

proc CleanUpSancp { dbSocketID } {

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
                default          { DisplayUsage $argv0 }
            }
        }
        dbuser          { set DBUSER $arg; set STATE flag }
        dbhost          { set DBHOST $arg; set STATE flag }
        dbport          { set DBPORT $arg; set STATE flag }
        dbname          { set DBNAME $arg; set STATE flag }
        default         { DisplayUsage $argv0 }
    }
                                                                                                                              
}

puts "This script is used for upgrading from Sguil Version 0.6.x"
puts "to Sguil Version 0.7.x only."
puts ""
puts "If you are using SANCP and have a relatively large install,"
puts "it is highly recommended you trim your database prior to"
puts "running this script. The sancp_cleanup.tcl script can be"
puts "used to delete old data."
puts ""
puts "Use these scripts at your own risk. Be sure to back"
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

#
# Connect to the DB
#
if { $DBPASS == "" } {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"
} else {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"
}
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

#
# Check the schema version
#
set dbVersion [MysqlSelect $dbSocketID {SELECT version FROM version} flatlist]
puts "Sguild DB Versions: $dbVersion"

if { $dbVersion != "0.12" } {

    if { $dbVersion != "0.11" } { 

        puts "Error: The Sguil DB schema is too old. You must upgrade the schema manually before continuing"
        exit 1

    }

    puts -nonewline "The DB schema needs to be updated. Do it now (\[y\]/n)?: "
    flush stdout
    set answer [gets stdin]
    if { $answer == "" } { set answer y }

    if { ![regexp {^[yY]} $answer] } { 

        puts "This script cannot continue without upgrading the schema. Goodbye."
        exit

    }

    set fileName "./update_sguildb_v11-v12.sql"
    puts -nonewline "Path to update_sguildb_v11-v12.sql \[$fileName\]: "
    flush stdout
    set answer [gets stdin]
    if { $answer != "" } { set fileName $answer }
    if { ! [file exists $fileName] } { puts "File does not exist: $fileName"; exit 1 }
    if { [catch {set fileID [open $fileName r]} openFileError] } { puts "Error: $openFileError"; exit 1 }

    puts -nonewline "Updating database ${DBNAME}..."
    foreach line [split [read $fileID] \n] {

        puts -nonewline "."
        flush stdout
        if { $line != "" && ![regexp {^--} $line] } {

            if { [regexp {(^.*);\s*$} $line match data] } {

                lappend mysqlCmd $data
                #puts "CMD: [join $mysqlCmd]"
                mysqlexec $dbSocketID [join $mysqlCmd]
                set mysqlCmd ""

            } else {

                lappend mysqlCmd $line

            }

        }

    }

    puts "Success."

}

puts ""
puts "WARNING: The next step is important. Please make"
puts "sure you understand the concept before continuing."
puts ""
puts "The functions of the old sensor agent have been split out into"
puts "separate agents (snort_agent, pcap_agent, sancp_agent, and"
puts "pads_agent). Each agent requires its own sensor id (sid). Older"
puts "Sguil installs used the same sid for Snort alerts and SANCP"
puts "flows. The separation of these agents also allows you to place"
puts "agents on different pieces of hardware."
puts ""
puts "Net names are used to correlate data between these agents. For"
puts "example, when an analyst requests the pcap associated with"
puts "hosts from a specific alert, sguild will use the net name to"
puts "determine which pcap agent to make the request too (each agent"
puts "registers its net name when it connects)."
puts ""
puts "This next process will create a new sid for any sensors and"
puts "also prompt you for a net name to assign to them. Make sure"
puts "you remember these net names as you will need them when"
puts "you configure the agents. Net names should be simple"
puts "descriptors like Corp_Ext_Net, DMZ, or web_farm."
puts ""
puts -nonewline "** Press <Enter> when you are ready to continue **"
flush stdout
set ans [gets stdin]
puts ""
puts ""

puts -nonewline "Getting a list of current Snort sensors..."
set sensorList [MysqlSelect $dbSocketID {SELECT hostname FROM sensor}]
puts "Success."

foreach sensor $sensorList {

    puts [format "%-5s | %-20s | %-20s | %-20s" sid hostname net_name agent_type]
    puts "================================================================="
    set displayList [MysqlSelect $dbSocketID {SELECT sid, hostname, net_name, agent_type FROM sensor} list]
    foreach row $displayList {
    
        puts [format "%-5s | %-20s | %-20s | %-20s" [lindex $row 0] [lindex $row 1] [lindex $row 2] [lindex $row 3]]
    
    }
    puts ""

    set answer n
    while { ![regexp {^[yY]} $answer] } { 

        set query "SELECT sid FROM sensor WHERE hostname='$sensor'"
        set sid [MysqlSelect $dbSocketID $query]
        puts -nonewline "Please enter a net name for ${sensor}: "
        flush stdout
        set sensorNetName($sensor) [gets stdin]
        puts "The net name for $sensor will be set to $sensorNetName($sensor)."
        puts -nonewline "Is this correct (y/n)? "
        flush stdout
        set answer [gets stdin]

    }

    puts -nonewline "Updating net name and agent type for ${sensor}..."
    flush stdout
    set query "UPDATE sensor SET net_name='$sensorNetName($sensor)', agent_type='snort' WHERE sid=$sid"
    set execResults [mysqlexec $dbSocketID $query]
    puts "Success."

}


puts ""
puts "The next step is to modify the sensor IDs for any SANCP data"
puts "that has already been collected. These updates can take a long time"
puts "if your database has millions of rows of data."
puts ""

foreach sensor $sensorList {

    set query "SELECT sid FROM sensor WHERE hostname='$sensor'"
    set sid [MysqlSelect $dbSocketID $query]
    puts -nonewline "Checking for SANCP data from sensor ${sensor} and sid ${sid}..."
    flush stdout
    set query "SELECT sid FROM sancp WHERE sid=$sid LIMIT 1"
    set results [MysqlSelect $dbSocketID $query flatlist]
    puts "Success."

    if { $results == $sid } {

        puts "Found SANCP data for the sensor $sensor with an ID of ${sid}."
        puts -nonewline "Adding agent information to the sensor table..."
        flush stdout
        set query "INSERT INTO sensor (hostname, agent_type, net_name) VALUES ('$sensor', 'sancp', '$sensorNetName($sensor)')"
        set execResults [mysqlexec $dbSocketID $query]
        puts "Success."
        set query "SELECT sid FROM sensor WHERE hostname='$sensor' AND agent_type='sancp'"
        set sancpSid [MysqlSelect $dbSocketID $query flatlist]
        puts -nonewline "Updating SANCP data to reflect new sid ($sancpSid). This could take a bit..."
        flush stdout
        set query "UPDATE sancp SET sid=$sancpSid WHERE sid=$sid"
        set execResults [mysqlexec $dbSocketID $query]
        puts "Success."

    } else {

        puts "No SANCP data was found for the sensor $sensor with an ID of ${sid}."
    
    }

    puts ""
    puts ""

}

puts "\n** Finished. The DB has been upgraded. **\n"
