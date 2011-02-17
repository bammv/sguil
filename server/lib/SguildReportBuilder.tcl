# $Id: SguildReportBuilder.tcl,v 1.5 2011/02/17 03:13:52 bamm Exp $ #

#
# ReportBuilder:  Receive multiple data requests from the client for report building
#
proc ReportBuilder { socketID type sid cid } {
    global REPORT_QRY_LIST
    switch -exact -- $type {
        TCP {
            set query\
                "SELECT tcphdr.tcp_seq, tcphdr.tcp_ack, tcphdr.tcp_off, tcphdr.tcp_res,\
                tcphdr.tcp_flags, tcphdr.tcp_win, tcphdr.tcp_csum, tcphdr.tcp_urp, event.src_port, event.dst_port\
                FROM tcphdr, event\
                WHERE event.sid=tcphdr.sid AND event.cid=tcphdr.cid and event.sid=$sid and event.cid=$cid"
            QueryDB $socketID {REPORT TCP} $query
        }
        UDP {
            set query\
                "select udphdr.udp_len, udphdr.udp_csum, event.src_port, event.dst_port\
                FROM udphdr, event\
                WHERE event.sid = udphdr.sid and event.cid=udphdr.cid and event.sid=$sid and event.cid = $cid"
                                                                                                     
            QueryDB $socketID {REPORT UDP} $query
        }
        ICMP {
            set query\
                "SELECT event.icmp_type, event.icmp_code, icmphdr.icmp_csum, icmphdr.icmp_id, icmphdr.icmp_seq, data.data_payload\
                FROM event, icmphdr, data\
                WHERE event.sid=icmphdr.sid AND event.cid=icmphdr.cid\
                AND event.sid=data.sid AND event.cid=data.cid AND event.sid=$sid AND event.cid=$cid"
                                                                                                     
            QueryDB $socketID {REPORT ICMP} $query
        }
        PAYLOAD {
            set query\
                "SELECT data_payload FROM data WHERE data.sid=$sid and data.cid=$cid"

            QueryDB $socketID {REPORT PAYLOAD} $query
        }
       IP {
            set query\
                "SELECT INET_NTOA(src_ip), INET_NTOA(dst_ip), ip_ver, ip_hlen, ip_tos, ip_len, ip_id,\
                ip_flags, ip_off, ip_ttl, ip_csum\
                FROM event\
                WHERE sid=$sid and cid=$cid"
                                                                                                     
            QueryDB $socketID {REPORT IP} $query
       }
       BUILDER {
            set scanindex 0
            set stop 0
            for {set cIndex 0} { $stop != 1 } {incr cIndex} {
                if { [regexp -start $scanindex {(.*?)\|\|.*?\|\|.*?\|\|(.*?)\|\|.*?\|\|} $REPORT_QRY_LIST match name sql ] } {
                                                                                                     
                    if { $name == $sid } { set stop 1 }
                    regexp -indices -start $scanindex {.*?\|\|.*?\|\|.*?\|\|.*?\|\|.*?\|(\|)} $REPORT_QRY_LIST match endindex
                    set scanindex [expr [lindex $endindex 1] + 1]
                } else {
                    #should never get here, we should find the name before we get to the end of the list
                    set stop 1
                }
            }
            set sensor [lindex $cid 0]
            set timestart [lindex [lindex $cid 1] 0]
            set timeend [lindex [lindex $cid 1] 1]
            if { ![regexp -nocase "^select" $sql] } {
               SendSocket $socketID [list ErrorMessage "Only SELECT queries are valid in the Report Builder"]
               return
            }
            # Macro replacements
            regsub -all "%%STARTTIME%%" $sql "'${timestart}'" sql
            regsub -all "%%ENDTIME%%" $sql "'${timeend}'" sql
                                                                                                     
            set sensormacro "\( sensor.net_name = '[lindex $sensor 0]' "
            for { set i 1 } { $i < [llength $sensor] } { incr i } {
                set sensormacro "${sensormacro} OR sensor.net_name = '[lindex $sensor $i]' "
            }
            set sensormacro "${sensormacro} \)"
            regsub -all "%%SENSORS%%" $sql $sensormacro sql
                                                                                                     
            QueryDB $socketID {REPORT BUILDER} $sql
        }
	NESSUS {
            set ip $sid
	    set query "SELECT * FROM nessus WHERE ip = '$ip'"
            
            QueryDB $socketID {REPORT NESSUS} $query
	}
	NESSUS_DATA {
	    set rid $sid
	    set query "SELECT * FROM nessus_data WHERE rid = '$rid'"

	    QueryDB $socketID {REPORT NESSUS_DATA} $query
	}
    }
}

