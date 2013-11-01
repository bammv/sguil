# $Id: SguildLoaderd.tcl,v 1.30 2011/02/17 03:15:42 bamm Exp $ #

proc ForkLoader {} {

    global sguildReadPipe sguildWritePipe
    global loaderdReadPipe loaderdWritePipe 

    # Prep things for the fork
    InitLoaderd

    # First create some pipes to communicate thru
    pipe loaderdReadPipe sguildWritePipe
    pipe sguildReadPipe loaderdWritePipe

    # Fork the child
    if {[set childPid [fork]] == 0 } {

        # We are the child now (loaderd).

        # Close the unneeded pipe fileIDs
        catch {close $sguildWritePipe}
        catch {close $sguildReadPipe}

        # Cmd received via pipe
        proc SguildCmdRcvd { pipeID } {

            fconfigure $pipeID -buffering line
            # Set up our comms cmds here
            if { [eof $pipeID] || [catch {gets $pipeID data}] } {
  
                # Pipe died
                exit

            } else {

                InfoMessage "loaderd: Received: $data"
                set cmd [lindex $data 0]
                # Here the cmds the loaderd knows
                switch -exact -- $cmd {
  
                    LoadSancpFile  { LoadSancpFile [lindex $data 1] [lindex $data 2] [lindex $data 3] }
                    default        { LogMessage "Unknown command received from sguild: $cmd" }

                }
  
            }

        }

        fileevent $loaderdReadPipe readable [list SguildCmdRcvd $loaderdReadPipe]
        LogMessage "Loaderd Forked"
        CheckLoaderDir

    } else {

        # We are the parent (sguild)

        # Close the unneeded pipe fileIDs
        catch {close $loaderdWritePipe}
        catch {close $loaderdReadPipe}

        # Proc to read msgs from loaderd.
        proc LoaderdCmdRcvd { pipeID } {

            fconfigure $pipeID -buffering line
            # Set up our comms cmds here
            if { [eof $pipeID] || [catch {gets $pipeID data}] } {
  
                # Pipe died
                catch {close $pipeID}
                # For now we just die.
                ErrorMessage "Lost communications with loaderd."

            } else {

                InfoMessage "sguild: Received from loaderd: $data"
                set cmd [lindex $data 0]
                # Here the cmds the sguild gets from loaderd
                switch -exact -- $cmd {
  
                    ConfirmSancpFile    { ConfirmSancpFile [lindex $data 1] [lindex $data 2] }
                    default             { LogMessage "Unknown command received from loaderd: $cmd" }

                }

            }
        }

        # Call LoaderdCmdRcvd when we get a msg from loaderd
        fileevent $sguildReadPipe readable [list LoaderdCmdRcvd $sguildReadPipe]

    }

    return $childPid
}

proc CreateNewSancpTable { tableName } {

    global LOADERD_DB_ID mergeTableListArray

    LogMessage "loaderd: Creating sancp table: $tableName."
    set createQuery "                                      \
        CREATE TABLE `$tableName`                          \
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
        ) ENGINE=MyISAM                                    \
        "

    # Create the table
    mysqlexec $LOADERD_DB_ID $createQuery
    # Add the new table to our list
    lappend mergeTableListArray(sancp) "$tableName"

    # If the sancp table exists, then DROP it
    #if { [mysqlsel $LOADERD_DB_ID {SHOW TABLES LIKE 'sancp'} -list] != "" } {
    #    mysqlexec $LOADERD_DB_ID {DROP TABLE sancp}
    #}
    CreateSancpMergeTable $LOADERD_DB_ID
}

proc CreateSancpMergeTable { dbSocketID } {

    global mergeTableListArray

    # Drop table if exists first
    mysqlexec $dbSocketID "DROP TABLE IF EXISTS sancp"
    
    # Clean up our list for the query
    foreach table $mergeTableListArray(sancp) {
        lappend tmpTables "`$table`"
    }

    LogMessage "loaderd: Creating sancp MERGE table."
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
        ) ENGINE=MERGE UNION=([join $tmpTables ,])      \
        "
    # Create our MERGE sancp table
    mysqlexec $dbSocketID $createQuery

}

proc InitLoaderd {} {

    global DBNAME DBUSER DBPASS DBPORT DBHOST LOADERD_DB_ID mergeTableListArray
    global mysqltclVersion

    # Open a cnx to the DB
    if { $DBPASS == "" } {
        set SWITCHES "-host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT"
    } else {
        set SWITCHES "-host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS"
    }

    if { $mysqltclVersion >= 3 } {
        set SWITCHES "$SWITCHES -localfiles 1"
    }
    set LOADERD_DB_ID [eval mysqlconnect $SWITCHES]

    # Get a list of current sancp tables
    set mergeTableListArray(sancp) [mysqlsel $LOADERD_DB_ID {SHOW TABLES LIKE 'sancp_%'} -list]
    
    #LogMessage "loaderd: sancp tables: $mergeTableListArray(sancp)"
    #set todaysDate [clock format [clock scan today] -gmt true -format "%Y%m%d"]
    # Check to see if we have a sancp table for today
    #if { [lsearch -exact $mergeTableListArray(sancp) "sancp_$todaysDate"] < 0 } {
    #    CreateNewSancpTable $todaysDate
    #}
    
    # Check to see if sancp table exist
    if { [mysqlsel $LOADERD_DB_ID {SHOW TABLES LIKE 'sancp'} -list] == "" } {
        # Create sancp merge table if we have a list of sancp tables.
        if { [info exists mergeTableListArray(sancp)] && $mergeTableListArray(sancp) != "" } {
            CreateSancpMergeTable $LOADERD_DB_ID
        }
    } else {
        # Make sure its a MERGE table and not the old monster
        set tableStatus [mysqlsel $LOADERD_DB_ID {SHOW TABLE STATUS LIKE 'sancp'} -flatlist]
        if { $tableStatus != "" && ![ string equal -nocase [lindex $tableStatus 1] "MRG_MyISAM" ] } {

            ErrorMessage "ERROR: loaderd: You appear to be using an old version of the\n\
                          sguil database schema that does not support the MERGE sancp\n\
                          table. Please see the CHANGES document for more information\n."
            CleanExit
        }
    }

}

proc LoadFile { fileName table } {

    global LOADERD_DB_ID DBHOST TMP_LOAD_DIR

    if { ![file exists $fileName] || ![file readable $fileName] } {
        LogMessage "Non-fatal error: File $fileName does not exist or is not readable."
        return
    }

    if { $DBHOST != "localhost" && $DBHOST != "127.0.0.1" } {
        set dbCmd "LOAD DATA CONCURRENT LOCAL INFILE '$fileName' INTO TABLE `$table`\
                   FIELDS TERMINATED BY '|'"
    } else {
        #set dbCmd "LOAD DATA CONCURRENT INFILE '$fileName' INTO TABLE `$table`
        set dbCmd "LOAD DATA CONCURRENT LOCAL INFILE '$fileName' INTO TABLE `$table`\
                   FIELDS TERMINATED BY '|'"
    }

    if [catch {mysqlexec $LOADERD_DB_ID $dbCmd} execResults] {

        LogMessage "ERROR: loaderd: $execResults"

        if { ![file exists ${TMP_LOAD_DIR}/failed] } { 

            # Attempt to create it
            if { [catch {file mkdir ${TMP_LOAD_DIR}/failed} err] } {

                LogMessage "Unable to create failed directory: $err"

            }

        }

        set fName [file tail $fileName]
        set fDir [file dirname $fileName]
        if [catch {file copy -force $fileName ${fDir}/failed/${fName}} tmpError] {
            LogMessage "ERROR: loaderd: $tmpError"
        } else {
            LogMessage "ERROR: loaderd: $fName moved to failed directory."
        }

    }

    # Delete the tmpfile
    if [catch {file delete $fileName} tmpError] {
        LogMessage "ERROR: loaderd: $tmpError"
    }

    InfoMessage "loaderd: Loaded $fileName into the table $table."

}

proc LoadSancpFile { sensor filename date } {

    global mergeTableListArray loaderdWritePipe

    set tableName "sancp_${sensor}_${date}"
    # Make sure our table exists
    if { [lsearch -exact $mergeTableListArray(sancp) $tableName] < 0 } {
        CreateNewSancpTable $tableName
    }

    LoadFile $filename $tableName 
    file delete $filename

    if [catch {flush $loaderdWritePipe} tmpError] {
        LogMessage "ERROR: $tmpError"
    }

}

proc CheckLoaderDir {} {

    global TMP_LOAD_DIR

    if { ![file exists $TMP_LOAD_DIR] } { 

        # Attempt to create it
        if { [catch {file mkdir $TMP_LOAD_DIR} err] } {

            ErrorMessage "Unable to create load directory: $err"

        }

    }

    # Load SANCP files
    foreach fileName [glob -nocomplain $TMP_LOAD_DIR/parsed.*] {

        set splitFile [split [file tail $fileName] .]
        set sensorName [lindex $splitFile 1]
        set date [lindex $splitFile 5]
        LoadSancpFile $sensorName $fileName $date

    }

    after 5000 CheckLoaderDir
 
}
