# $Id: SguildLoaderd.tcl,v 1.4 2005/01/27 19:25:26 bamm Exp $ #

proc ForkLoader {} {

    global loaderWritePipe DBNAME DBUSER DBPASS DBPORT DBHOST LOADERD_DB_ID

    # First create some pipes to communicate thru
    pipe loaderReadPipe loaderWritePipe

    # Fork the child
    if {[set childPid [fork]] == 0 } {

        # We are the child now.

        # Open a cnx to the DB
        if { $DBPASS == "" } {
            set LOADERD_DB_ID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT]
        } else {
            set LOADERD_DB_ID [mysqlconnect -host $DBHOST -db $DBNAME -user $DBUSER -port $DBPORT -password $DBPASS]
        }

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
                    default    { LogMessage "Unknown command recieved from sguild: $cmd" }

                }
  
            }

        }

        fileevent $loaderReadPipe readable [list ParentCmdRcvd $loaderReadPipe]
        LogMessage "Loader Forked"
    }
    return $childPid
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

