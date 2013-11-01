proc InitializeMysqlMergeTables {} {

    global MAIN_DB_SOCKETID mergeTableListArray

    # Make sure the new style (merge) tables are being used and create
    # them if they don't exist
    foreach tableName [list event tcphdr udphdr icmphdr data sancp] {

        set tmpQry "SHOW TABLE STATUS LIKE '$tableName'"
        set tableStatus [mysqlsel $MAIN_DB_SOCKETID $tmpQry -flatlist]

        if { $tableStatus != "" && ![ string equal -nocase [lindex $tableStatus 1] "MRG_MyISAM" ] } {

            # Non MERGE table found.
            set errorMsg "\n*************************************************************\n
                          ERROR: You appear to be using an old version of the\n\
                          sguil database schema that does not support the MERGE tables\n\
                          Please use the migrate_event.tcl script and see the CHANGES \n\
                          document for more information\n\n.\
                          Table $tableName returned status => $tableStatus\n\
                          *************************************************************\n"
            return -code error $errorMsg

        }

        set tmpDBCmd "SHOW TABLES LIKE '${tableName}_%'"
        if [catch {mysqlsel $MAIN_DB_SOCKETID $tmpDBCmd -list} mergeTableListArray($tableName)] {

            # Error getting a list of merged tables
            ErrorMessage "Error trying to get a list of $tableName tables: $mergeTableListArray($tableName)"

        }
 
        if { $mergeTableListArray($tableName) != "" } {

            # Drop and recreate the merge table on init

            switch -exact -- $tableName {

                event        { CreateMysqlMainEventMergeTable }
                tcphdr       { CreateMysqlMainTcpHdrMergeTable }
                udphdr       { CreateMysqlMainUdpHdrMergeTable }
                icmphdr      { CreateMysqlMainIcmpHdrMergeTable }
		data         { CreateMysqlMainDataMergeTable }
                sancp        { CreateSancpMergeTable $MAIN_DB_SOCKETID}
                default      { ErrorMessage "Unknown table type: $tableName" }

            }

        } else {

            # Create empty array var.
            set mergeTableListArray($tableName) ""

        }

    }

}

proc CreateMysqlMainEventMergeTable {} {

    global MAIN_DB_SOCKETID mergeTableListArray

    foreach table $mergeTableListArray(event) {

        lappend tmpTables "`$table`"

    }

    # Drop table if exists first
    mysqlexec $MAIN_DB_SOCKETID "DROP TABLE IF EXISTS event"

    LogMessage "Creating event MERGE table."
    set createQuery "                                           \
        CREATE TABLE event                                      \
        (                                                       \
        sid                   INT UNSIGNED    NOT NULL,         \
        cid                   INT UNSIGNED    NOT NULL,         \
        signature             VARCHAR(255)    NOT NULL,         \
        signature_gen         INT UNSIGNED    NOT NULL,         \
        signature_id          INT UNSIGNED    NOT NULL,         \
        signature_rev         INT UNSIGNED    NOT NULL,         \
        timestamp             DATETIME        NOT NULL,         \
        unified_event_id      INT UNSIGNED,                     \
        unified_event_ref     INT UNSIGNED,                     \
        unified_ref_time      DATETIME,                         \
        priority              INT UNSIGNED,                     \
        class                 VARCHAR(20),                      \
        status                SMALLINT UNSIGNED DEFAULT 0,      \
        src_ip                INT UNSIGNED,                     \
        dst_ip                INT UNSIGNED,                     \
        src_port              INT UNSIGNED,                     \
        dst_port              INT UNSIGNED,                     \
        icmp_type             TINYINT UNSIGNED,                 \
        icmp_code             TINYINT UNSIGNED,                 \
        ip_proto              TINYINT UNSIGNED,                 \
        ip_ver                TINYINT UNSIGNED,                 \
        ip_hlen               TINYINT UNSIGNED,                 \
        ip_tos                TINYINT UNSIGNED,                 \
        ip_len                SMALLINT UNSIGNED,                \
        ip_id                 SMALLINT UNSIGNED,                \
        ip_flags              TINYINT UNSIGNED,                 \
        ip_off                SMALLINT UNSIGNED,                \
        ip_ttl                TINYINT UNSIGNED,                 \
        ip_csum               SMALLINT UNSIGNED,                \
        last_modified         DATETIME,                         \
        last_uid              INT UNSIGNED,                     \
        abuse_queue           enum('Y','N'),                    \
        abuse_sent            enum('Y','N'),                    \
        INDEX event_p_key (sid,cid),                            \
        INDEX sid_time (sid, timestamp),                        \
        INDEX src_ip (src_ip),                                  \
        INDEX dst_ip (dst_ip),                                  \
        INDEX dst_port (dst_port),                              \
        INDEX src_port (src_port),                              \
        INDEX icmp_type (icmp_type),                            \
        INDEX icmp_code (icmp_code),                            \
        INDEX timestamp (timestamp),                            \
        INDEX last_modified (last_modified),                    \
        INDEX signature (signature),                            \
        INDEX status (status)                                   \
        ) ENGINE=MERGE UNION=([join $tmpTables ,])              \
        "
    mysqlexec $MAIN_DB_SOCKETID $createQuery
   
}

proc CreateMysqlMainTcpHdrMergeTable {} {

    global MAIN_DB_SOCKETID mergeTableListArray

    foreach table $mergeTableListArray(tcphdr) {

        lappend tmpTables "`$table`"

    }

    # Drop table if exists first
    mysqlexec $MAIN_DB_SOCKETID "DROP TABLE IF EXISTS tcphdr"

    LogMessage "Creating tcphdr MERGE table."
    set createQuery "                                           \
        CREATE TABLE tcphdr                                     \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        tcp_seq       INT UNSIGNED,                             \
        tcp_ack       INT UNSIGNED,                             \
        tcp_off       TINYINT UNSIGNED,                         \
        tcp_res       TINYINT UNSIGNED,                         \
        tcp_flags     TINYINT UNSIGNED,                         \
        tcp_win       SMALLINT UNSIGNED,                        \
        tcp_csum      SMALLINT UNSIGNED,                        \
        tcp_urp       SMALLINT UNSIGNED,                        \
        INDEX tcphdr_p_key (sid,cid)                            \
        ) ENGINE=MERGE UNION=([join $tmpTables ,])              \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery

}

proc CreateMysqlMainUdpHdrMergeTable {} {

    global MAIN_DB_SOCKETID mergeTableListArray

    foreach table $mergeTableListArray(udphdr) {

        lappend tmpTables "`$table`"

    }

    # Drop table if exists first
    mysqlexec $MAIN_DB_SOCKETID "DROP TABLE IF EXISTS udphdr"

    LogMessage "Creating udphdr MERGE table."
    set createQuery "                                           \
        CREATE TABLE udphdr                                     \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        udp_len       SMALLINT UNSIGNED,                        \
        udp_csum      SMALLINT UNSIGNED,                        \
        INDEX udphdr_p_key (sid,cid)                            \
        ) ENGINE=MERGE UNION=([join $tmpTables ,])              \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery

}

proc CreateMysqlMainIcmpHdrMergeTable {} {

    global MAIN_DB_SOCKETID mergeTableListArray

    foreach table $mergeTableListArray(icmphdr) {

        lappend tmpTables "`$table`"

    }

    # Drop table if exists first
    mysqlexec $MAIN_DB_SOCKETID "DROP TABLE IF EXISTS icmphdr"

    LogMessage "Creating icmphdr MERGE table."
    set createQuery "                                           \
        CREATE TABLE icmphdr                                    \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        icmp_csum     SMALLINT UNSIGNED,                        \
        icmp_id       SMALLINT UNSIGNED,                        \
        icmp_seq      SMALLINT UNSIGNED,                        \
        INDEX icmphdr_p_key (sid,cid)                           \
        ) ENGINE=MERGE UNION=([join $tmpTables ,])              \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery

}

proc CreateMysqlMainDataMergeTable {} {

    global MAIN_DB_SOCKETID mergeTableListArray

    foreach table $mergeTableListArray(data) {

        lappend tmpTables "`$table`"

    }

    # Drop table if exists first
    mysqlexec $MAIN_DB_SOCKETID "DROP TABLE IF EXISTS data"

    LogMessage "Creating data MERGE table."
    set createQuery "                                           \
        CREATE TABLE data                                       \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        data_payload  TEXT,                                     \
        INDEX data_p_key (sid,cid)                              \
        ) ENGINE=MERGE UNION=([join $tmpTables ,])              \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery

}

proc CreateMysqlAlertTables { tablePostfix } {

    global mergeTableListArray

    CreateEventTable event_$tablePostfix
    CreateTcpHdrTable tcphdr_$tablePostfix
    CreateUdpHdrTable udphdr_$tablePostfix
    CreateIcmpHdrTable icmphdr_$tablePostfix
    CreateDataTable data_$tablePostfix

    CreateMysqlMainEventMergeTable
    CreateMysqlMainTcpHdrMergeTable
    CreateMysqlMainUdpHdrMergeTable
    CreateMysqlMainIcmpHdrMergeTable
    CreateMysqlMainDataMergeTable

}

proc CreateEventTable { tableName } {

    global MAIN_DB_SOCKETID mergeTableListArray

    LogMessage "Creating event table $tableName."

    set createQuery "                                           \
        CREATE TABLE IF NOT EXISTS `$tableName`                 \
        (                                                       \
        sid                   INT UNSIGNED    NOT NULL,         \
        cid                   INT UNSIGNED    NOT NULL,         \
        signature             VARCHAR(255)    NOT NULL,         \
        signature_gen         INT UNSIGNED    NOT NULL,         \
        signature_id          INT UNSIGNED    NOT NULL,         \
        signature_rev         INT UNSIGNED    NOT NULL,         \
        timestamp             DATETIME        NOT NULL,         \
        unified_event_id      INT UNSIGNED,                     \
        unified_event_ref     INT UNSIGNED,                     \
        unified_ref_time      DATETIME,                         \
        priority              INT UNSIGNED,                     \
        class                 VARCHAR(20),                      \
        status                SMALLINT UNSIGNED DEFAULT 0,      \
        src_ip                INT UNSIGNED,                     \
        dst_ip                INT UNSIGNED,                     \
        src_port              INT UNSIGNED,                     \
        dst_port              INT UNSIGNED,                     \
        icmp_type             TINYINT UNSIGNED,                 \
        icmp_code             TINYINT UNSIGNED,                 \
        ip_proto              TINYINT UNSIGNED,                 \
        ip_ver                TINYINT UNSIGNED,                 \
        ip_hlen               TINYINT UNSIGNED,                 \
        ip_tos                TINYINT UNSIGNED,                 \
        ip_len                SMALLINT UNSIGNED,                \
        ip_id                 SMALLINT UNSIGNED,                \
        ip_flags              TINYINT UNSIGNED,                 \
        ip_off                SMALLINT UNSIGNED,                \
        ip_ttl                TINYINT UNSIGNED,                 \
        ip_csum               SMALLINT UNSIGNED,                \
        last_modified         DATETIME,                         \
        last_uid              INT UNSIGNED,                     \
        abuse_queue           enum('Y','N'),                    \
        abuse_sent            enum('Y','N'),                    \
        PRIMARY KEY (sid,cid),                                  \
        INDEX sid_time (sid, timestamp),                        \
        INDEX src_ip (src_ip),                                  \
        INDEX dst_ip (dst_ip),                                  \
        INDEX dst_port (dst_port),                              \
        INDEX src_port (src_port),                              \
        INDEX icmp_type (icmp_type),                            \
        INDEX icmp_code (icmp_code),                            \
        INDEX timestamp (timestamp),                            \
        INDEX last_modified (last_modified),                    \
        INDEX signature (signature),                            \
        INDEX status (status)                                   \
        ) ENGINE=MyISAM                                         \
        "
    mysqlexec $MAIN_DB_SOCKETID $createQuery
    lappend mergeTableListArray(event) $tableName 

}

proc CreateTcpHdrTable { tableName } {

    global MAIN_DB_SOCKETID mergeTableListArray

    LogMessage "Creating tcphdr table $tableName."
    set createQuery "                                           \
        CREATE TABLE IF NOT EXISTS `$tableName`                 \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        tcp_seq       INT UNSIGNED,                             \
        tcp_ack       INT UNSIGNED,                             \
        tcp_off       TINYINT UNSIGNED,                         \
        tcp_res       TINYINT UNSIGNED,                         \
        tcp_flags     TINYINT UNSIGNED,                         \
        tcp_win       SMALLINT UNSIGNED,                        \
        tcp_csum      SMALLINT UNSIGNED,                        \
        tcp_urp       SMALLINT UNSIGNED,                        \
        PRIMARY KEY   (sid,cid)                                 \
        ) ENGINE=MyISAM                                         \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery
    lappend mergeTableListArray(tcphdr) $tableName 

}

proc CreateUdpHdrTable { tableName } {

    global MAIN_DB_SOCKETID mergeTableListArray

    LogMessage "Creating udphdr table $tableName."
    set createQuery "                                           \
        CREATE TABLE IF NOT EXISTS `$tableName`                 \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        udp_len       SMALLINT UNSIGNED,                        \
        udp_csum      SMALLINT UNSIGNED,                        \
        PRIMARY KEY   (sid,cid)                                 \
        ) ENGINE=MyISAM                                         \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery
    lappend mergeTableListArray(udphdr) $tableName 

}

proc CreateIcmpHdrTable { tableName } {

    global MAIN_DB_SOCKETID mergeTableListArray

    LogMessage "Creating icmphdr table $tableName."
    set createQuery "                                           \
        CREATE TABLE IF NOT EXISTS `$tableName`                 \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        icmp_csum     SMALLINT UNSIGNED,                        \
        icmp_id       SMALLINT UNSIGNED,                        \
        icmp_seq      SMALLINT UNSIGNED,                        \
        PRIMARY KEY   (sid,cid)                                 \
        ) ENGINE=MyISAM                                         \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery
    lappend mergeTableListArray(icmphdr) $tableName 

}

proc CreateDataTable { tableName } {

    global MAIN_DB_SOCKETID mergeTableListArray

    LogMessage "Creating data table $tableName."
    set createQuery "                                           \
        CREATE TABLE IF NOT EXISTS `$tableName`                 \
        (                                                       \
        sid           INT UNSIGNED    NOT NULL,                 \
        cid           INT UNSIGNED    NOT NULL,                 \
        data_payload  TEXT,                                     \
        PRIMARY KEY   (sid,cid)                                 \
        ) ENGINE=MyISAM                                         \
        "

    mysqlexec $MAIN_DB_SOCKETID $createQuery
    lappend mergeTableListArray(data) $tableName 

}
