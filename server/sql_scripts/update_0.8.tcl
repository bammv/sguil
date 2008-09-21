#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id: update_0.8.tcl,v 1.1 2008/09/21 02:58:49 bamm Exp $ #

# Default vars
set DBHOST localhost
set DBPORT 3306
set DBUSER root
set DBNAME sguildb

proc DisplayUsage { cmd } {

    puts "Usage: $cmd \[--dbuser <username>\] \[--dbhost <hostname>\] \
                      \[--dbport <port>\] \[--dbname <dbname>\]       \
                      \[-u <usersfile>\]"
    exit
}

proc UpdateUserInfo { username hash } {

    global dbSocketID

    set query "UPDATE user_info SET password='$hash' WHERE username='$username'"

    if [catch {mysqlexec $dbSocketID $query} tmpError] {
        puts "        ERROR Execing DB cmd: $query\n        Error: $tmpError"
    }

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
                -u		 { set STATE usersfile }
                default          { DisplayUsage $argv0 }
            }
        }
        dbuser          { set DBUSER $arg; set STATE flag }
        dbhost          { set DBHOST $arg; set STATE flag }
        dbport          { set DBPORT $arg; set STATE flag }
        dbname          { set DBNAME $arg; set STATE flag }
        usersfile       { set USERSFILE $arg; set STATE flag }
        default         { DisplayUsage $argv0 }
    }
                                                                                                                              
}

puts "This script is used for upgrading from Sguil Version 0.7.x"
puts "to Sguil Version 0.8.x only."
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

# If the USERSFILE wasn't provided get it.
if { ![info exists USERSFILE] } {

    puts -nonewline "Enter path to sguild.users file: "
    flush stdout
    set USERSFILE [gets stdin]

}

# Fail if we don't have a users file.
if { ! [file exists $USERSFILE] } { puts "ERROR: Users file does not exist: $USERSFILE"; exit 1 }

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

if { $dbVersion != "0.13" } {

    if { $dbVersion != "0.12" } { 

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

    set fileName "./update_sguildb_v12-v13.sql"
    puts -nonewline "Path to update_sguildb_v12-v13.sql \[$fileName\]: "
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

puts "Migrating your password file ($USERSFILE) to the database:"

# Loop thru the users file and update the DB
for_file line $USERSFILE {

    # Filter comments
    if { ![regexp ^# $line] && ![regexp ^$ $line] } {

        # Probably should check for corrupted info here
        set username [ctoken line "(.)(.)"]
        set hash [ctoken line "(.)(.)"]

        puts "    Updating user name $username"
        UpdateUserInfo $username $hash

    }

}

puts "Success."

puts "\n** Finished. The DB has been upgraded. **\n"
