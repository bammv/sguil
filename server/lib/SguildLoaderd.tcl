# $Id: SguildLoaderd.tcl,v 1.6 2005/01/28 00:07:40 bamm Exp $ #

proc ForkLoader {} {

    global loaderWritePipe DBNAME DBUSER DBPASS DBPORT DBHOST LOADERD_DB_ID

    # Prep things for the fork
    InitLoaderd

    # First create some pipes to communicate thru
    pipe loaderReadPipe loaderWritePipe

    # Fork the child
    if {[set childPid [fork]] == 0 } {

        # We are the child now.

        # Cmd recieved via pipe
        proc ParentCmdRcvd { pipeID } {

            fconfigure $pipeID -buffering line
            # Set up our comms cmds here
            if { [eof $pipeID] || [catch {gets $pipeID data}] } {
  
                # Pipe died
                exit

            } else {

                InfoMessage "loaderd: Recieved: $data"
                set cmd [lindex $data 0]
                # Here the cmds the loaderd knows
                switch -exact -- $cmd {
  
                    LoadPSFile { LoadFile [lindex $data 1] portscan }
                    LoadSsnFile { LoadSsnFile [lindex $data 1] [lindex $data 2] }
                    LoadSancpFile { LoadSancpFile [lindex $data 1] [lindex $data 2] }
                    default    { LogMessage "Unknown command recieved from sguild: $cmd" }

                }
  
            }

        }

        fileevent $loaderReadPipe readable [list ParentCmdRcvd $loaderReadPipe]
        LogMessage "Loader Forked"
    }
    return $childPid
}

proc CreateNewSancpTable { date } {

    global LOADERD_DB_ID SANCP_TBL_LIST

    InfoMessage "loaderd: Creating sancp table: sancp_$date."
    set createQuery "                                      \
        CREATE TABLE sancp_$date                           \
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
        PRIMARY KEY (sid,sancpid),                         \
        INDEX src_ip (src_ip),                             \
        INDEX dst_ip (dst_ip),                             \
        INDEX dst_port (dst_port),                         \
        INDEX src_port (src_port),                         \
        INDEX start_time (start_time)                      \
        )                                                  \
        "

    # Create the table
    mysqlexec $LOADERD_DB_ID $createQuery
    # Add the new table to our list
    lappend SANCP_TBL_LIST "sancp_$date"

    # If the sancp table exists, then DROP it
    if { [mysqlsel $LOADERD_DB_ID {SHOW TABLES LIKE 'sancp'} -list] != "" } {
        mysqlexec $LOADERD_DB_ID {DROP TABLE sancp}
    }
    CreateSancpMergeTable
}

proc CreateSancpMergeTable {} {

    global LOADERD_DB_ID SANCP_TBL_LIST
    
    InfoMessage "loaderd: Creating sancp MERGE table."
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
        INDEX src_ip (src_ip),                             \
        INDEX dst_ip (dst_ip),                             \
        INDEX dst_port (dst_port),                         \
        INDEX src_port (src_port),                         \
        INDEX start_time (start_time)                      \
        ) TYPE=MERGE UNION=([join $SANCP_TBL_LIST ,])      \
        "
    # Create our MERGE sancp table
    mysqlexec $LOADERD_DB_ID $createQuery

}

proc InitLoaderd {} {

    global DBNAME DBUSER DBPASS DBPORT DBHOST LOADERD_DB_ID SANCP_TBL_LIST

    # Open a cnx to the DB
    if { $DBPASS == "" } {
        set LOADERD_DB_ID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
    } else {
        set LOADERD_DB_ID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
    }

    # Get a list of current sancp tables
    set SANCP_TBL_LIST [mysqlsel $LOADERD_DB_ID {SHOW TABLES LIKE 'sancp_%'} -list]
    InfoMessage "loaderd: sancp tables: $SANCP_TBL_LIST"
    set todaysDate [clock format [clock scan today] -gmt true -format "%Y%m%d"]
    # Check to see if we have a sancp table for today
    if { [lsearch -exact $SANCP_TBL_LIST "sancp_$todaysDate"] < 0 } {
        CreateNewSancpTable $todaysDate
    }
    
    # Check to see if sancp table exist
    if { [mysqlsel $LOADERD_DB_ID {SHOW TABLES LIKE 'sancp'} -list] == "" } {
        # Create sancp merge table.
        CreateSancpMergeTable
    } else {
        # Make sure its a MERGE table and not the old monser
        set tableStatus [mysqlsel $LOADERD_DB_ID {SHOW TABLE STATUS LIKE 'sancp'} -list]
        if { [lindex $tableStatus 1] != "MRG_MyISAM" } {
            ErrorMessage "ERROR: loaderd: You appear to be using an old version of the\n\
                          sguil database schema that does not support the MERGE sancp\n\
                          table. Please see the CHANGES document for more information\n."
            CleanExit
        }
    }

}

proc LoadFile { fileName table } {

    global  LOADERD_DB_ID

    set dbCmd "LOAD DATA CONCURRENT LOCAL INFILE '$fileName' INTO TABLE $table\
               FIELDS TERMINATED BY '|'"

    if [catch {mysqlexec $LOADERD_DB_ID $dbCmd} execResults] {
        ErrorMessage "ERROR: loaderd: $execResults"
    }

    # Delete the tmpfile
    if [catch {file delete $fileName} tmpError] {
        ErrorMessage "ERROR: loaderd: $tmpError"
    }

    InfoMessage "loaderd: Loaded $fileName into the portscan table."

}

proc LoadSsnFile { filename date } {

    # Not doing anything with the date yet
    LoadFile $filename sessions

}

proc LoadSancpFile { filename date } {

    global SANCP_TBL_LIST

    set tableName "sancp_$date"
    # Make sure our table exists
    if { [lsearch -exact $SANCP_TBL_LIST $tableName] < 0 } {
        CreateNewSancpTable $date
    }

    # Not doing anything with the date yet
    LoadFile $filename $tableName 

}
