#!/bin/sh
# Run tcl from users PATH \
exec tclsh "$0" "$@"

# $Id #

# Defaults you can set to what you want.
set RESOLVE_DNS 1
set SANCP 1
set CHAT 1
set TYPE weekly
set VERBOSE 1

set DBHOST localhost
set DBUSER root
set DBPASS ""
set ASKPASS 0
set DBPORT 3306
set DBNAME sguildb

set HOME_NET_START 192.168.8.0
set HOME_NET_END 192.168.8.255

############ end default vars #################

# Load extended tcl
if [catch {package require Tclx} tclxVersion] {
  puts "ERROR: The tclx extension does NOT appear to be installed on this sysem."
  puts "Extended tcl (tclx) is available as a port/package for most linux and BSD systems."
  exit
}

# Load mysql support.
if [catch {package require mysqltcl} mysqltclVersion] {
    puts "ERROR: The mysqltcl extension does NOT appear to be installed on this sysem."
    puts "Download it at http://www.xdobry.de/mysqltcl/"
    exit
}

# Load HTML Support
if [catch {package require html} htmlVersion] {
    puts "ERROR: The html package does NOT appear to be installed on this sysem."
    exit
}
if [catch {package require ncgi} ncgiVersion] {
    puts "ERROR: The ncgi package does NOT appear to be installed on this sysem."
    exit
}

###################### PROCS ###############################

proc MysqlSelFlatList { query } {

    global dbSocketID

    set qResult [mysqlsel $dbSocketID $query -flatlist]
    return $qResult
}

proc GetHostbyAddr { ip } {

  if [catch {host_info official_name $ip} hostname] {
    set hostname "Unknown"
  }

  return $hostname


}
proc DisplayUsage { cmd } {

    puts "Usage: $cmd \
                 \[--sancp\] \
                 \[--nosancp\] \
                 \[--dns\] \
                 \[--nodns\] \
                 \n \
                 \[--chat\] \
                 \[--nochat\] \
                 \[--start start_time\] \
                 \[--end end_time\] \
                 \n \
                 \[--outfile filename \] \
                 \[--weekly\] \
                 \[--monthly\] \
                 \[--dbuser username\] \
                 \n \
                 \[--dbpass password\] \
                 \[--askpass\] \
                 \[--dbhost hostname\] \
                 \[--dbport port\] \
                 \n \
                 \[--dbname database\] \
                 \[--verbose\] \
                 \[--noverbose\] \
                 \[--home_net_start ip_addr\] \
                 \n \
                 \[--home_net_end ip_addr\] \
                 \[--help\] \
                 \n\
                 Note: --start and --end can have standard values\n\
                 like \"2005-01-01\" or tcl date modifiers like \"today\",\n\
                 \"yesterday\", \"2 weeks ago\", etc."
    exit

}

#################### END PROCS ##############################

#
# Get Options
#
set STATE flag
foreach arg $argv {

    switch -- $STATE {
        flag {
            switch -glob -- $arg {
                --sancp          { set SANCP 1 }
                --nosancp        { set SANCP 0 }
                --dns            { set RESOLVE_DNS 1 }
                --nodns          { set RESOLVE_DNS 0 } 
                --chat           { set CHAT 1 }
                --nochat         { set CHAT 0 }
                --start          { set STATE start; set TYPE custom }
                --end            { set STATE end; set TYPE custom }
                --outfile        { set STATE outfile }
                --weekly         { set TYPE weekly }
                --monthly        { set TYPE monthly }
                --dbuser         { set STATE dbuser }
                --dbpass         { set STATE dbpass }
                --dbhost         { set STATE dbhost }
                --dbport         { set STATE dbport }
                --dbname         { set STATE dbname }
                --askpass        { set ASKPASS 1 }
                --verbose        { set VERBOSE 1 }
                --noverbose      { set VERBOSE 0 }
                --home_net_start { set STATE home_net_start }
                --home_net_end   { set STATE home_net_end }
                --help           { DisplayUsage $argv0 }
                default          { DisplayUsage $argv0 }
            }
        }
        start           { set START_DATE $arg; set STATE flag }
        end             { set END_DATE $arg; set STATE flag }
        outfile         { set outFilename $arg; set STATE flag }
        dbuser          { set DBUSER $arg; set STATE flag }
        dbpass          { set DBPASS $arg; set STATE flag }
        dbhost          { set DBHOST $arg; set STATE flag }
        dbport          { set DBPORT $arg; set STATE flag }
        dbname          { set DBNAME $arg; set STATE flag }
        home_net_start  { set HOME_NET_START $arg; set STATE flag } 
        home_net_end    { set HOME_NET_END $arg; set STATE flag } 
        default         { DisplayUsage $argv0 }
    }

}

#
# Date setting foo starts here.
# 
if { $TYPE == "weekly" } {

    set baseDate [clock scan yesterday]
    set startDate [clock format [clock scan "1 week ago" -base $baseDate] -gmt true -f "%Y-%m-%d"]
    set endDate [clock format [clock scan today] -gmt true -f "%Y-%m-%d"]
    set reportDate [clock format [clock scan yesterday] -gmt true -f "%Y-%m-%d"]

} elseif { $TYPE == "monthly" } {

    set baseDate [clock scan yesterday]
    set startDate [clock format [clock scan "1 month ago" -base $baseDate] -gmt true -f "%Y-%m-%d"]
    set endDate [clock format [clock scan today] -gmt true -f "%Y-%m-%d"]
    set reportDate [clock format [clock scan yesterday] -gmt true -f "%Y-%m-%d"]

} elseif { $TYPE == "custom" } {

    if { [info exists START_DATE] && [info exists END_DATE] } {
        set startDate [clock format [clock scan $START_DATE] -gmt true -f "%Y-%m-%d"]
        set endDate [clock format [clock scan $END_DATE] -gmt true -f "%Y-%m-%d"]
        set reportDate [clock format [clock scan yesterday -base [clock scan $END_DATE]] -gmt true -f "%Y-%m-%d"]
    } else {
        puts "ERROR: Need a start date and an end date for the report."
        DisplayUsage $argv0
    }

} else {

    # Ack we don't know what to do.
    puts "ERROR: Can't figure out what dates I am suppose to use."
    DisplayUsage $argv0

}
# Now we have the info to build our time constraint for all queries.
set TIMECONSTR "BETWEEN '$startDate' AND '$endDate'"

# 
# If an out filename wasn't specified we create it here.
# My boss likes that weird mdy stuff (Month Day Year).
if { ![info exists outFilename] } {

    set mdyDate [clock format [clock scan $reportDate] -f "%m%d%y"]
    set outFilename "/tmp/ids_report_$mdyDate.html"

}

# For those paranoid types who don't want to store their DB
# password in a this file or type it in the clear on the cmd line.
if { $ASKPASS } {
    puts -nonewline "Database password: "
    flush stdout
    exec stty -echo
    set DBPASS [gets stdin]
    exec stty echo
}

# Write out bunch of stuff if VERBOSE
if { $VERBOSE } {
  puts "Report Type:\t$TYPE"
  puts "Start Date:\t$startDate"
  puts "End Date:\t$endDate"
  puts "Report Date:\t$reportDate"
  puts "Out File:\t$outFilename"
  puts "DB User:\t$DBUSER"
  puts "DB Host:\t$DBHOST"
  puts "DB Port:\t$DBPORT"
  puts "DB Name:\t$DBNAME"
  puts -nonewline "Sancp total:\t"
    if { $SANCP } { puts "yes" } else { puts "no" } 
  puts -nonewline "Resolve IPs:\t"
    if { $RESOLVE_DNS } { puts "yes" } else { puts "no" } 
  puts -nonewline "Chat Table:\t"
    if { $CHAT } { puts "yes" } else { puts "no" } 
}

if { $DBPASS == "" } {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT"
} else {
    set dbConnectCmd "-host $DBHOST -user $DBUSER -port $DBPORT -password $DBPASS"
}

if { $VERBOSE } { puts -nonewline "Connecting to database..." }
# Connect to mysqld
if [catch {eval mysqlconnect $dbConnectCmd} dbSocketID] {
    puts "ERROR: Unable to connect to $DBHOST on $DBPORT: Make sure mysql is running."
    puts "$dbSocketID"
    exit
}

# See if the DB we want to use exists
if { [catch {mysqluse $dbSocketID $DBNAME} noDBError] } {
  puts "Error: $noDBError"
  exit
}

if { $VERBOSE } { puts "Success" }

# Open the file for writing.
if { $VERBOSE } { puts -nonewline "Opening $outFilename..." }
if [ catch {open $outFilename w} outFileID ] {
    puts "ERROR: $outFileID
    DisplayUsage $argv0
}
if { $VERBOSE } { puts "Success" }
if { $VERBOSE } { puts "####################################" }



############# HTML FOO STARTS HERE ########################

# HTML Header stuff
puts $outFileID [::html::head "IDS Report ($startDate to $reportDate)"]
puts $outFileID                                                                         \
"<style type=\"text/css\">                                                              \n\
<!--\n                                                                                  \n\
TD.head {     BACKGROUND-COLOR: #A9ACB6; COLOR: #000000;                                \n\
              FONT-FAMILY: tahoma,helvetica,verdana,lucida console,utopia;              \n\
              FONT-SIZE: 10pt; FONT-WEIGHT: bold; HEIGHT: 20px; TEXT-ALIGN: center }    \n\
TD.top {      BACKGROUND-COLOR: #FFFFFF; COLOR: #000000;                                \n\
              FONT-FAMILY: tahoma,helvetica,verdana,lucida console,utopia;              \n\
              FONT-SIZE: 8pt; FONT-WEIGHT: bold; TEXT-ALIGN: center }                   \n\
TD.title {    BACKGROUND-COLOR: #87CEFA; COLOR: #555555;                                \n\
              FONT-FAMILY: tahoma,helvetica,verdana,lucida console,utopia;              \n\
              FONT-SIZE: 10pt; FONT-WEIGHT: bold; HEIGHT: 20px; TEXT-ALIGN: left }      \n\
TD.sub {      BACKGROUND-COLOR: #BFEFFF; COLOR: #555555;                                \n\
              FONT-FAMILY: tahoma,helvetica,verdana,lucida console,utopia;              \n\
              FONT-SIZE: 10pt; FONT-WEIGHT: bold; HEIGHT: 18px; TEXT-ALIGN: left }      \n\
TD.content {  BACKGROUND-COLOR: white; COLOR: #000000;                                  \n\
              FONT-FAMILY: tahoma,arial,helvetica,verdana,lucida console,utopia;        \n\
              FONT-SIZE: 8pt; TEXT-ALIGN: left; VERTICAL-ALIGN: middle }                \n\
TD.default {  BACKGROUND-COLOR: WHITE; COLOR: #000000;                                  \n\
              FONT-FAMILY: tahoma,arial,helvetica,verdana,lucida console,utopia;        \n\
              FONT-SIZE: 8pt; }                                                         \n\
TD.border {   BACKGROUND-COLOR: #cccccc; COLOR: black;                                  \n\
              FONT-FAMILY: tahoma,helvetica,verdana,lucida console,utopia;              \n\
              FONT-SIZE: 10pt; HEIGHT: 25px }                                           \n\
-->                                                                                     \n\
</style>"

puts $outFileID [::html::bodyTag]

# Top Marker
puts -nonewline $outFileID [::html::openTag a "name=\"top\""]
puts $outFileID [::html::closeTag]
set topTag [::html::minorMenu [list "\[top\]" "\#top"] ]

puts $outFileID [::html::openTag table "bgcolor=#000000 border=0 cellpadding=2 cellspacing=1 width=85%"]
puts $outFileID [::html::paramRow [list "IDS Report ($startDate to $reportDate)"] "" "class=head colspan=2"]
puts $outFileID [::html::closeTag]
puts $outFileID "<br>"

######################
## Statistics Table ##
######################

puts "Report Period: $startDate - $reportDate"
puts $outFileID [::html::openTag table "bgcolor=#a1a1a1 border=0 cellpadding=2 cellspacing=1 width=75%"]
puts $outFileID [::html::paramRow [list "Statistics"] "" "class=title colspan=2"]

# Reporting period
puts $outFileID [::html::paramRow [list "Start Date" "$startDate" ] "" "class=sub"]
puts $outFileID [::html::paramRow [list "End Date" "$reportDate" ] "" "class=sub"]

# Number of sensors
set tmpQuery "SELECT COUNT(DISTINCT(sid)) FROM event WHERE timestamp $TIMECONSTR"
if { $VERBOSE } { puts $tmpQuery }
set totalSensors [MysqlSelFlatList $tmpQuery]
puts $outFileID [::html::paramRow [list "Number of Sensors" $totalSensors ] "" "class=sub"]

# Total connections logged
if { $SANCP } {
    set tmpQuery "SELECT COUNT(*) FROM sancp WHERE start_time $TIMECONSTR"
    if { $VERBOSE } { puts $tmpQuery }
    set totalSancp [MysqlSelFlatList $tmpQuery]
    puts $outFileID [::html::paramRow [list "Connections Logged" $totalSancp ] "" "class=sub"]
}

# Total alerts
set tmpQuery "SELECT COUNT(*) FROM event WHERE timestamp $TIMECONSTR"
if { $VERBOSE } { puts $tmpQuery }
set totalAlerts [MysqlSelFlatList $tmpQuery]
puts $outFileID [::html::paramRow [list "Total Alerts" $totalAlerts ] "" "class=sub"]

# Total alerts catted
set tmpQuery "SELECT COUNT(*) FROM event WHERE timestamp $TIMECONSTR AND status > 10 AND status < 18"
if { $VERBOSE } { puts $tmpQuery }
set totalCatAlerts [MysqlSelFlatList $tmpQuery]
puts $outFileID [::html::paramRow [list "Alerts Meeting Category Thresholds" $totalCatAlerts ] "" "class=sub"]

# Total Cat I-VII's
foreach cat "11 12 13 14 15 16 17" {

    set tmpQuery "SELECT COUNT(*) FROM event WHERE timestamp $TIMECONSTR AND status = $cat"
    if { $VERBOSE } { puts $tmpQuery }
    set tmpResults [MysqlSelFlatList $tmpQuery]

    set catName [join [MysqlSelFlatList "SELECT description FROM status WHERE status_id=$cat"] ]

    set tmpRef [::html::minorMenu [list $tmpResults "\#cat_[expr $cat - 10]"]]
    puts $outFileID [::html::paramRow [list "Total $catName Alerts" $tmpRef ] "" "class=sub"]

}

puts $outFileID [::html::closeTag]
puts $outFileID "<br>"

# Loop thru each incident category
foreach status "11 12 13 14 15 16 17" {

    set catName [join [MysqlSelFlatList "SELECT description FROM status WHERE status_id=$status"] ]
    set catDesc [join [MysqlSelFlatList "SELECT long_desc FROM status WHERE status_id=$status"] ]

    #############################
    ## Unique Signatures Table ##
    #############################

    # Build an anchor
    puts -nonewline $outFileID [::html::openTag a "name=\"cat_[expr $status - 10]\""]
    puts $outFileID [::html::closeTag]

    set tmpQuery \
        "SELECT COUNT(signature) as sCount, signature_id, signature \
         FROM event \
         WHERE timestamp $TIMECONSTR AND status=$status \
         GROUP BY signature_id \
         ORDER BY sCount DESC"

    set catRef [::html::minorMenu [list $catDesc "http://www.sguil.net/index.php?page=cat_[expr $status - 10]"]]
    puts $outFileID [::html::openTag table "bgcolor=#000000 border=0 cellpadding=2 cellspacing=1 width=85%"]
    puts $outFileID [::html::paramRow [list "$catName Alerts - $catRef"] "" "class=head colspan=2"]
    puts $outFileID [::html::closeTag]
    puts $outFileID "<br>"
    puts $outFileID [::html::openTag table "bgcolor=#a1a1a1 border=0 cellpadding=2 cellspacing=1 width=75%"]
    puts $outFileID [::html::paramRow [list "Unique Signatures"] "" "class=title colspan=2"]
    puts $outFileID [::html::paramRow [list Count Signature] "" "class=sub"]

    set EMPTY_FLAG 1

    if { $VERBOSE } { puts $tmpQuery }
    foreach tmpRow [mysqlsel $dbSocketID $tmpQuery -list] {

        set EMPTY_FLAG 0
        set cnt [lindex $tmpRow 0]
        set sig_id [lindex $tmpRow 1] 
        set sig [lindex $tmpRow 2]
        set sigRef [::html::minorMenu [list $sig "http://www.snort.org/pub-bin/sigs.cgi?sid=${sig_id}"]]
        puts $outFileID [::html::paramRow [list $cnt $sigRef] "" "class=default"]

    }

    if { $EMPTY_FLAG } { puts $outFileID [::html::paramRow [list None None] "" "class=default"] }

    puts $outFileID [::html::closeTag]
    puts $outFileID "<br>"

    if { !$EMPTY_FLAG } { 

        ###################################
        ## Unique Sigs With > 50 Sources ##
        ###################################

        set WHERE "timestamp $TIMECONSTR AND status=$status"

        # Chat alerts are not inculded in Cat V reports unless specified. Otherwise,
        # they have their own report table.
        if { $status == 15 && $CHAT } {
            set WHERE "$WHERE AND signature NOT LIKE 'CHAT%'"
        }

        # Get a list of sigs where there are too many distinct src ips to display.
        set tmpQuery \
            "SELECT COUNT(DISTINCT(src_ip)) as dips, signature_id, signature \
             FROM event \
             WHERE $WHERE \
             GROUP BY signature \
             HAVING dips > 50 \
             ORDER BY dips DESC" 
    
        set EMPTY_FLAG 1

        if { $VERBOSE } { puts $tmpQuery }
        foreach tmpRow [mysqlsel $dbSocketID $tmpQuery -list] {

            if { $EMPTY_FLAG } {
                # Build start of table
                puts $outFileID [::html::openTag table "bgcolor=#a1a1a1 border=0 cellpadding=2 cellspacing=1 width=75%"]
                puts $outFileID [::html::paramRow [list "Signatures With More Than 50 Unique Sources"] "" "class=title colspan=2"]
                puts $outFileID [::html::paramRow [list Count Signature] "" "class=sub"]
                set EMPTY_FLAG 0
            }

            set cnt [lindex $tmpRow 0]
            set sig_id [lindex $tmpRow 1]
            set sig [lindex $tmpRow 2]
            set sigRef [::html::minorMenu [list $sig "http://www.snort.org/pub-bin/sigs.cgi?sid=${sig_id}"]]
            puts $outFileID [::html::paramRow [list $cnt $sigRef] "" "class=default"]
            # Keep a list of these sigs.
            lappend LARGE_SIGS $sig

        }

        if { !$EMPTY_FLAG } { 
            puts $outFileID [::html::closeTag]
            puts $outFileID "<br>"
        }
    
        #############################
        ## Unique Sources And Sigs ##
        #############################

        set WHERE "timestamp $TIMECONSTR AND status=$status"

        # Chat alerts are done in a seperate table
        if { $status == 15 && $CHAT} {
            set WHERE "$WHERE AND signature NOT LIKE 'CHAT%'"
        }
    
        # Filter out our large sigs
        if { [info exists LARGE_SIGS] } {

            foreach sig $LARGE_SIGS {
                set WHERE "$WHERE AND signature != '$sig'"
            }

        }

        set tmpQuery \
            "SELECT COUNT(signature), INET_NTOA(src_ip), signature_id, signature \
             FROM event \
             WHERE $WHERE \
             GROUP BY signature, src_ip \
             ORDER BY src_ip ASC"
    
        puts $outFileID [::html::openTag table "bgcolor=#a1a1a1 border=0 cellpadding=2 cellspacing=1 width=75%"]

        if { $RESOLVE_DNS } {
            puts $outFileID [::html::paramRow [list "Source And Signatures"] "" "class=title colspan=4"]
            puts $outFileID [::html::paramRow [list Count "Src IP" Hostname Signature] "" "class=sub"]
        } else {
            puts $outFileID [::html::paramRow [list "Source And Signatures"] "" "class=title colspan=3"]
            puts $outFileID [::html::paramRow [list Count "Src IP" Signature] "" "class=sub"]
        }

        set EMPTY_FLAG 1
        if { $VERBOSE } { puts $tmpQuery }
        foreach tmpRow [mysqlsel $dbSocketID $tmpQuery -list] {

            set EMPTY_FLAG 0
            set cnt [lindex $tmpRow 0]
            set sip [lindex $tmpRow 1]
            set sig_id [lindex $tmpRow 2]
            set sig [lindex $tmpRow 3]
            set sigRef [::html::minorMenu [list $sig "http://www.snort.org/pub-bin/sigs.cgi?sid=${sig_id}"]]
            set whoRef [::html::minorMenu [list $sip "http://www.dnsstuff.com/tools/whois.ch?ip=${sip}"]]

            if { $RESOLVE_DNS } {
                set hostname [GetHostbyAddr $sip]
                puts $outFileID [::html::paramRow [list $cnt $whoRef $hostname $sigRef] "" "class=default"]
            } else {
                puts $outFileID [::html::paramRow [list $cnt $whoRef $sigRef] "" "class=default"]
            }

        }

        if { $EMPTY_FLAG } { puts $outFileID [::html::paramRow [list None None None] "" "class=default"] }
        puts $outFileID [::html::closeTag]
        puts $outFileID "<br>"
    
        #################
        ## CHAT Report ##
        #################

        if { $status == 15 && $CHAT } {
            set HOME_NET_CONSTR "src_ip >= INET_ATON('$HOME_NET_START') AND src_ip <= INET_ATON('$HOME_NET_END')"
            set tmpQuery \
                "SELECT COUNT(signature) as sCount, INET_NTOA(src_ip), signature_id, signature \
                 FROM event \
                 WHERE timestamp $TIMECONSTR AND status=15 AND signature LIKE 'CHAT%' AND $HOME_NET_CONSTR \
                 GROUP BY signature, src_ip \
                 ORDER BY sCount DESC LIMIT 20"
    
            puts $outFileID [::html::openTag table "bgcolor=#a1a1a1 border=0 cellpadding=2 cellspacing=1 width=75%"]

            if { $RESOLVE_DNS } {
                puts $outFileID [::html::paramRow [list "Top 20 Chat Users"] "" "class=title colspan=4"]
                puts $outFileID [::html::paramRow [list Count "Src IP" Hostname Signature] "" "class=sub"]
            } else {
                puts $outFileID [::html::paramRow [list "Top 20 Chat Users"] "" "class=title colspan=3"]
                puts $outFileID [::html::paramRow [list Count "Src IP" Signature] "" "class=sub"]
            }

            set EMPTY_FLAG 1

            if { $VERBOSE } { puts $tmpQuery }
            foreach tmpRow [mysqlsel $dbSocketID $tmpQuery -list] {

                set EMPTY_FLAG 0
                set cnt [lindex $tmpRow 0]
                set sip [lindex $tmpRow 1]
                set sig_id [lindex $tmpRow 2]
                set sig [lindex $tmpRow 3]
                set sigRef [::html::minorMenu [list $sig "http://www.snort.org/pub-bin/sigs.cgi?sid=${sig_id}"]]
                set whoRef [::html::minorMenu [list $sip "http://www.dnsstuff.com/tools/whois.ch?ip=${sip}"]]

                if { $RESOLVE_DNS } {
                    set hostname [GetHostbyAddr $sip]
                    puts $outFileID [::html::paramRow [list $cnt $whoRef $hostname $sigRef] "" "class=default"]
                } else {
                    puts $outFileID [::html::paramRow [list $cnt $whoRef $sigRef] "" "class=default"]
                }

            }

            if { $EMPTY_FLAG } { puts $outFileID [::html::paramRow [list None None None] "" "class=default"] }

            puts $outFileID [::html::closeTag]
            puts $outFileID "<br>"
        }

    }

    # Return To Top
    puts $outFileID [::html::openTag table "bgcolor=#FFFFFF border=0 cellpadding=2 cellspacing=1 width=75%"]
    puts $outFileID [::html::paramRow [list $topTag] "" "class=top"]
    puts $outFileID [::html::closeTag]
    puts $outFileID "<br>"

}

puts $outFileID [::html::end]
close $outFileID
