#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: autocat2mysql.tcl,v 1.2 2013/09/05 00:38:45 bamm Exp $ #

# Default vars
set DBHOST localhost
set DBPORT 3306
set DBUSER root
set DBNAME sguildb
set DB_VERSION "0.14"

proc DisplayUsage { cmd } {

    puts "Usage: $cmd \[--dbuser <username>\] \[--dbhost <hostname>\]\
                      \[--dbport <port>\] \[--dbname <dbname>\]\
                      --file </path/to/autocat.conf>\
                      --user <sguil user>"
    exit
}

proc FlatDBQuery { dbSocketID query } {

    set queryResults [mysqlsel $dbSocketID $query -flatlist]
    return $queryResults

}

# Load mysql support.
if [catch {package require mysqltcl} mysqltclVersion] {
  puts "ERROR: The mysqltcl extension does NOT appear to be installed on this sysem."
  puts "Download it at http://www.xdobry.de/mysqltcl/"
  exit
}

# Load extended tcl
if [catch {package require Tclx} tclxVersion] {
  puts "ERROR: The tclx extension does NOT appear to be installed on this sysem."
  puts "Extended tcl (tclx) is available as a port/package for most linux and BSD systems."
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
                --file           { set STATE fileName  }
                --user           { set STATE user  }
                default          { DisplayUsage $argv0 }
            }
        }
        dbuser          { set DBUSER $arg; set STATE flag }
        dbhost          { set DBHOST $arg; set STATE flag }
        dbport          { set DBPORT $arg; set STATE flag }
        dbname          { set DBNAME $arg; set STATE flag }
        fileName        { set fileName $arg; set STATE flag }
        user            { set user $arg; set STATE flag }
        default         { DisplayUsage $argv0 }
    }

}

if { ![info exists fileName] || ![file exists $fileName] } {

    puts "Error opening autocat file."
    DisplayUsage

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

# Make sure we have a compatible DB version
set currentDBVer [FlatDBQuery $dbSocketID "SELECT version FROM version"]
puts "SguilDB Version: $currentDBVer"

if { [lsearch $DB_VERSION $currentDBVer] < 0 } {
  puts "ERROR: Incompatable DB schema. Required Version: $DB_VERSION \
    Installed Version: $currentDBVer Check the server/sql_scripts directory of \
    the src that came with sguild for scripts to help you upgrade"
  exit
}

puts -nonewline "Available Sguil usernames: "
puts [FlatDBQuery $dbSocketID "SELECT username FROM user_info"]
puts ""

if { ![info exists user] } { 

    puts -nonewline "Please enter your sguil login username: "
    flush stdout
    set user [gets stdin]

}

set uid [FlatDBQuery $dbSocketID "SELECT uid FROM user_info WHERE username='$user'"]

if { $uid == "" } {

    puts "Error: Failed to get a uid for the user $user."
    puts "Please check the user_info table and ensure the user exists."
    exit

}

for_file line $fileName {

    set tmpLine $line

    if ![regexp ^# $line] {

        puts "Processing line: $line"

        set TABLES [list uid timestamp]
        set VALUES [list \'$uid\' "now()"]

        foreach t [list erase sensorname src_ip src_port dst_ip dst_port ip_proto signature status] {

            set v [ctoken line "||"]

            if { $v != "none" && $v != "NONE" && $v != "any" && $v != "ANY" } { 

               lappend TABLES $t
               lappend VALUES \'$v\'

            }

        }

        set q "INSERT INTO autocat ([join $TABLES ,]) VALUES ([join $VALUES ,])"
        puts "Inserting autocat rule to the DB: $q"

        if { [catch {mysqlexec $dbSocketID $q} tmpError] } { 

            puts "Error: Failed to add $tmpLine to the DB.\n$tmpError"

        }


    }

}

