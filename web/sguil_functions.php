<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/sguil_functions.php,v 1.1 2004/03/30 23:24:08 mboman Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */
 
require("config.php");

function DBOpen() {
	$dbhost = "localhost";
	$dbuser = "snort";
	$dbpass = "snort_password";
	$dbname = "sguildb";

	$conn = mysql_connect($dbhost, $dbuser, $dbpass);

	if (!$conn) {
	   echo "Unable to connect to DB: " . mysql_error();
	   exit;
	}
  
	if (!mysql_select_db($dbname)) {
	   echo "Unable to select $dbname: " . mysql_error();
	   exit;
	}

}


function DBClose($result) {
	mysql_free_result($result);
}


function show_alerts( $where_query ) {

	DBOpen();

	$alert_query = "SELECT
			event.status,
			event.priority,
			event.class,
			sensor.hostname,
			event.timestamp,
			event.sid,
			event.cid,
			event.signature,
			INET_NTOA(event.src_ip) as src_ip,
			INET_NTOA(event.dst_ip) as dst_ip,
			event.ip_proto,
			event.src_port,
			event.dst_port
			FROM
			event,
			sensor";

	if ( $where_query == "" ) {
		$where_query = "WHERE event.sid=sensor.sid AND event.status=0 ORDER BY event.timestamp ASC LIMIT 50";
	}

	$sql = $alert_query . " " . $where_query;

	$result = mysql_query($sql);

	if (!$result) {
   	echo "Could not successfully run query ($sql) from DB: " . mysql_error();
   	exit;
	}

	// print the header
	print("<form action=\"" . $_SERVER['PHP_SELF'] . "\" method=\"POST\">\n");
	print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
	print("<tr><td colspan=\"11\">Query: " .
		"<input type=\"text\" name=\"query\" size=\"100\" value=\"" . $where_query . "\"> " .
		"<input name=\"submit\" value=\"Submit\" type=\"submit\"></td></tr>\n");
	print("</table>\n");
	print("</form>\n");
	print("<hr>\n");	

	print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"1\" width=\"100%\">\n");
	print("<tr bgcolor=\"#000000\">\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;ST&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;CNT&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;Sensor&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;sid.cid&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;Date/Time&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;Src IP&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;SPort&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;Dst IP&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;DPort&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;Pr&nbsp;</strong></font></td>\n");
	print("	<td><font color=\"#FFFFFF\"><strong>&nbsp;Event Message&nbsp;</strong></font></td>\n");
	print("</tr>\n");

	$colours = array("#A8A8A8","#FFFFFF","#D2D2D2");
	
	$status_desc = array(
							"0"  => "RT",
							"1"  => "NA",
							"2"  => "ES",
							"11" => "C1",
							"12" => "C2",
							"13" => "C3",
							"14" => "C4",
							"15" => "C5",
							"16" => "C6",
							"17" => "C7"
							);
							
	$status_colour = array(
							"0"  => "#FF0000",
							"1"  => "#ADD7E6",
							"2"  => "#FFBFCA",
							"11" => "#CC0000",
							"12" => "#FF6600",
							"13" => "#FF9800",
							"14" => "#CC9800",
							"15" => "#9898CC",
							"16" => "#FFCC00",
							"17" => "#CC66FF"
							);

	$i = 0;

	if (mysql_num_rows($result) > 0) {
		while ($row = mysql_fetch_assoc($result)) {
		
			$lookup_url="hostlookup.php?src_ip=" . $row['src_ip'] . "&dst_ip=" . $row['dst_ip'];
			$detail_url="alert_detail.php?sid=" . $row['sid'] . "&cid=" . $row['cid'];
			
			print("<tr bgcolor=\"" . $colours[$i] . "\">\n");
			print("	<td bgcolor=\"" . $status_colour[$row['status']] . "\">" . $status_desc[$row['status']] . "</td>\n");
			print("	<td>[cnt]</td>\n");
			print("	<td>" . $row['hostname'] . "</td>\n");
			print("	<td><a href=\"$detail_url\" target=\"lookup_right\">" . $row['sid'] . "." . $row['cid'] . "</a></td>\n");
			print("	<td>" . $row['timestamp'] . "</td>\n");
			print("	<td><a href=\"$lookup_url\" target=\"lookup_left\">" . $row['src_ip'] . "</a></td>\n");
			print("	<td>" . $row['src_port'] . "</td>\n");
			print("	<td><a href=\"$lookup_url\" target=\"lookup_left\">" . $row['dst_ip'] . "</a></td>\n");
			print("	<td>" . $row['dst_port'] . "</td>\n");
			print("	<td>" . $row['ip_proto'] . "</td>\n");
			print("	<td>" . $row['signature'] . "</td>\n");
			print("</tr>\n");
			


			if( $i++ >= count($colours) ) {
				$i = 0;
			}
		}
	}	
	print("</table>\n");
	print("<p>Query returned " . mysql_num_rows($result) . " rows</p>\n");

	DBClose($result);
}


function alert_details_ip($sid,$cid) {

	DBOpen();

   $sql = "SELECT INET_NTOA(src_ip) AS src_ip, INET_NTOA(dst_ip) AS dst_ip, " .
   		"ip_ver, ip_hlen, ip_tos, ip_len, ip_id, ip_flags, ip_off, ip_ttl, ip_csum, ip_proto " .
   		"FROM event " .
			"WHERE sid=" . $sid . " and cid=" . $cid;

	$result = mysql_query($sql);

	if (!$result) {
   	echo "Could not successfully run query ($sql) from DB: " . mysql_error();
   	exit;
	}

	if (mysql_num_rows($result) > 0) {

		$row = mysql_fetch_assoc($result);
	
		print("<form action=\"" . $_SERVER['PHP_SELF'] . "\" method=\"POST\">\n");
		print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
		print("	<tr>\n");
		print("		<td bgcolor=\"#ADD7E6\">Source IP</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">Dest IP</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">Ver</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">HL</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">TOS</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">len</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">ID</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">Flags</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">Offset</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">TTL</td>\n");
		print("		<td bgcolor=\"#ADD7E6\">Checksum</td>\n");
		print("	</tr>\n");
		print("	<tr>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"src_ip\" value=\"" . $row['src_ip'] . "\" size=\"16\" maxlength=\"16\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"dst_ip\" value=\"" . $row['dst_ip'] . "\" size=\"16\" maxlength=\"16\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"ver\" value=\"" . $row['ip_ver'] . "\" size=\"2\" maxlength=\"2\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"hl\" value=\"" . $row['ip_hlen'] . "\" size=\"2\" maxlength=\"2\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"tos\" value=\"" . $row['ip_tos'] . "\" size=\"3\" maxlength=\"3\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"len\" value=\"" . $row['ip_len'] . "\" size=\"5\" maxlength=\"5\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"id\" value=\"" . $row['ip_id'] . "\" size=\"5\" maxlength=\"5\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"flags\" value=\"" . $row['ip_flags'] . "\" size=\"4\" maxlength=\"4\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"offset\" value=\"" . $row['ip_off'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"ttl\" value=\"" . $row['ip_ttl'] . "\" size=\"4\" maxlength=\"4\"></td>\n");
		print("		<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"checksum\" value=\"" . $row['ip_csum'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("	</tr>\n");
		print("</table>\n");
		print("</form>\n");
	}
	
	DBClose($result);
	return($row['ip_proto']);
}

function alert_details_tcp($sid,$cid) {

	DBOpen();

   $sql = "SELECT src_port, dst_port, tcp_seq, tcp_ack, tcp_off, tcp_res, tcp_flags, tcp_win, tcp_csum, tcp_urp " .
   "FROM event, tcphdr " .
   "WHERE event.sid = tcphdr.sid and event.cid = tcphdr.cid and event.sid=" . $sid . " and event.cid =" . $cid;

	$result = mysql_query($sql);

	if (!$result) {
   	echo "Could not successfully run query ($sql) from DB: " . mysql_error();
   	exit;
	}

	if (mysql_num_rows($result) > 0) {

		$row = mysql_fetch_assoc($result);

		print("<form action=\"" . $_SERVER['PHP_SELF'] . "\" method=\"POST\">\n");
		print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\">Source<br>Port</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Dest<br>Port</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">R<br>1</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">R<br>0</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">U<br>R<br>G</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">A<br>C<br>K</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">P<br>S<br>H</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">R<br>S<br>T</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">S<br>Y<br>N</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">F<br>I<br>N</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Seq #</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Ack #</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Offset</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Res</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Window</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Urp</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">ChkSum</td>\n");
		print("</tr>\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"sport\" value=\"" . $row['src_port'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"dport\" value=\"" . $row['dst_port'] . "\" size=\"6\" maxlength=\"6\"></td>\n");

		$ipFlags = $row['tcp_flags'];
		
		if ( $ipFlags != "" ) {
			if ( 128 & $ipFlags ) {
				$r1Flag = "checked";
				$ipFlags = $ipFlags - 128;
			}

			if ( 64 & $ipFlags ) {
				$r0Flag = "checked";
				$ipFlags = $ipFlags - 64;
			}

			if ( 32 & $ipFlags ) {
				$urgFlag = "checked";
				$ipFlags = $ipFlags - 32;
			}

			if ( 16 & $ipFlags ) {
				$ackFlag = "checked";
				$ipFlags = $ipFlags - 16;
			}

			if ( 8 & $ipFlags ) {
				$pshFlag = "checked";
				$ipFlags = $ipFlags - 8;
			}

			if ( 4 & $ipFlags ) {
				$rstFlag = "checked";
				$ipFlags = $ipFlags - 4;
			}
			
			if ( 2 & $ipFlags ) {
				$synFlag = "checked";
				$ipFlags = $ipFlags - 2;
			}

			if ( 1 & $ipFlags ) {
				$finFlag = "checked";
				$ipFlags = $ipFlags - 1;
			}
		}

		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"r1\" " . $r1Flag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"r0\" " . $r0Flag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"urg\" " . $urgFlag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"ack\" " . $ackFlag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"psh\" " . $pshFlag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"rst\" " . $rstFlag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"syn\" " . $synFlag . "></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"checkbox\" name=\"fin\" " . $finFlag . "></td>\n");

		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"seq\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_seq'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"ack\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_ack'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"offset\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_off'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"res\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_res'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"window\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_win'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"urp\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_urp'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"csum\" size=\"6\" maxlength=\"6\" value=\"" . $row['tcp_csum'] . "\"></td>\n");
		print("</tr>\n");
		print("</table>\n");
		print("</form>\n");
	}
	
	DBClose($result);
}


function alert_details_icmp($sid,$cid) {

	DBOpen();

   $sql = "SELECT event.icmp_type, event.icmp_code, icmphdr.icmp_csum, icmphdr.icmp_id, icmphdr.icmp_seq " .
		"FROM event, icmphdr " .
		"WHERE event.sid=icmphdr.sid AND event.cid=icmphdr.cid AND event.sid=" . $sid . " AND event.cid=" . $cid;

	$result = mysql_query($sql);

	if (!$result) {
   	echo "Could not successfully run query ($sql) from DB: " . mysql_error();
   	exit;
	}

	if (mysql_num_rows($result) > 0) {

		$row = mysql_fetch_assoc($result);

		print("<form action=\"" . $_SERVER['PHP_SELF'] . "\" method=\"POST\">\n");
		print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\">Type</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Code</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">ChkSum</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">ID</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Seq#</td>\n");
		print("</tr>\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"type\" value=\"" . $row['icmp_type'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"code\" value=\"" . $row['icmp_code'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"chksum\" size=\"6\" maxlength=\"6\" value=\"" . $row['icmp_csum'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"id\" size=\"6\" maxlength=\"6\" value=\"" . $row['icmp_id'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"seq\" size=\"6\" maxlength=\"6\" value=\"" . $row['icmp_seq'] . "\"></td>\n");
		print("</tr>\n");
		print("</table>\n");
		print("</form>\n");
	}
	
	DBClose($result);
}
	

function alert_details_udp($sid,$cid) {

	DBOpen();

   $sql = "SELECT src_port, dst_port, udp_len, udp_csum FROM event, udphdr WHERE event.sid=udphdr.sid and event.cid=udphdr.cid and event.sid=" . $sid . " and event.cid=" . $cid;

	$result = mysql_query($sql);

	if (!$result) {
   	echo "Could not successfully run query ($sql) from DB: " . mysql_error();
   	exit;
	}

	if (mysql_num_rows($result) > 0) {

		$row = mysql_fetch_assoc($result);

		print("<form action=\"" . $_SERVER['PHP_SELF'] . "\" method=\"POST\">\n");
		print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\">Source Port</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Destination Port</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">Length</td>\n");
		print("	<td bgcolor=\"#ADD7E6\">ChkSum</td>\n");
		print("</tr>\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"type\" value=\"" . $row['src_port'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"code\" value=\"" . $row['dst_port'] . "\" size=\"6\" maxlength=\"6\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"chksum\" size=\"6\" maxlength=\"6\" value=\"" . $row['udp_len'] . "\"></td>\n");
		print("	<td bgcolor=\"#ADD7E6\"><input type=\"text\" name=\"id\" size=\"6\" maxlength=\"6\" value=\"" . $row['udp_csum'] . "\"></td>\n");
		print("</tr>\n");
		print("</table>\n");
		print("</form>\n");
	}
	
	DBClose($result);
}

	
function alert_details_payload($sid, $cid) {	
	DBOpen();

   $sql = "SELECT data_payload " .
   	"FROM data " .
		"WHERE sid=" . $sid . " and cid=" . $cid;

	$result = mysql_query($sql);

	if (!$result) {
   	echo "Could not successfully run query ($sql) from DB: " . mysql_error();
   	exit;
	}

		$row = mysql_fetch_assoc($result);

		print("<form action=\"" . $_SERVER['PHP_SELF'] . "\" method=\"POST\">\n");
		print("<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
		print("<tr>\n");
		print("	<td bgcolor=\"#ADD7E6\"><textarea name=\"payload\" rows=\"10\" cols=\"80\">\n");
		
		if ( $row['data_payload'] == "" ) {
			print("None.");
		} else {
			$payload = $row['data_payload'];
			
			$datalen = strlen($payload);		
			$asciiStr = "";
			$counter = 2;

			for( $i = 1; $i < $datalen; $i = $i+2 ) {
				$currentByte = $payload[$i-1];
				$currentByte = $currentByte . $payload[$i];
				
		    	$hexStr = $hexStr . $currentByte . " ";
		    	$intValue = hexdec($currentByte);
		    	
				if ( ($intValue < 32) || ($intValue > 126) ) {
					// Non printable char
					$currentChar = ".";
      		} else {
      			// printable char
					$currentChar = chr($intValue);
		      }		    
				
		      $asciiStr = $asciiStr . $currentChar;

				if ( $counter == 32 ) {
					$dataText = $dataText . $hexStr . "  " . $asciiStr . "\n";
					$hexStr = "";
					$asciiStr = "";
					$counter = 2;
      		} else {
					$counter = $counter + 2;
      		}
    		}
    		
    		// Last line.. Need to put in spaces for the char's the doesn't exist.
    		
    		for(; $counter < 32; $counter = $counter + 2 ) {
	    		$hexStr = $hexStr . "   ";
		      $asciiStr = $asciiStr . " ";
    		}
    		
    		$dataText = $dataText . $hexStr . "     " . $asciiStr . "\n";
    		
    		sprintf($dataText, "%-47s %s\n", $hexStr, $asciiStr);
		}

		print("$dataText");
		
		print("\n</textarea></td>\n");
		print("</tr>\n");
		print("</table>\n");
		print("</form>\n");
	
	DBClose($result);
}

?>