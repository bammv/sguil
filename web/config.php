<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/config.php,v 1.7 2004/04/06 10:40:40 mboman Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */


$dbhost = "localhost";
$dbuser = "snort";
$dbpass = "snort_password";
$dbname = "sguildb";
$use_sancp = 0;

$whois_command="/usr/bin/jwhois";
$max_sig_length = 50;

$snort_sig_url="http://www.snort.org/snort-db/sid.html?sid=";
$dshield_port_url="http://www.dshield.org/port_report.php?days=70&port=";
$dshield_host_url="http://www.dshield.org/ipinfo.php?ip=";

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


?>