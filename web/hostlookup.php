<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/hostlookup.php,v 1.1 2004/03/30 23:24:08 mboman Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

?><!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Host Lookup</title>
<meta name="author" content="Michael Boman">
<meta name="copyright" content="Copyright 2004 Michael Boman <mboman@users.sourceforge.net>. All Rights Reserved.">
</head>
<body>

<form action="<?php print($_SERVER['PHP_SELF']); ?>" method="GET">
<table cellpadding="0" cellspacing="0" border="0" width="350">
	<tr>
		<td>
			<table cellpadding="0" cellspacing="0" border="1" width="100%">
				<tr>
					<td>
						<table cellpadding="0" cellspacing="3" border="0" width="100%">
							<tr>
								<td>Src IP:</td><td><input type="text" name="src_ip" size="20" value="<?php
									print($_REQUEST['src_ip']);
								?>"></td>
							</tr>
							<tr>
								<td>Src Name:</td><td><input type="text" name="src_name" size="20" value="<?php
									if (preg_match("/^[\d\.]+$/", $_REQUEST['src_ip'])) {
										$hostname = gethostbyaddr($_REQUEST['src_ip']);
										print($hostname);
									}
								?>"></td>
							</tr>
							<tr>
								<td colspan="2"><hr></td>
							</tr>
							<tr>
								<td>Dst IP:</td><td><input type="text" name="dst_ip" size="20" value="<?php
									print($_REQUEST['dst_ip']);
								?>"></td>
							</tr>
							<tr>
								<td>Dst Name:</td><td><input type="text" name="dst_name" size="20" value="<?php
									if (preg_match("/^[\d\.]+$/", $_REQUEST['dst_ip'])) {
										$hostname = gethostbyaddr($_REQUEST['dst_ip']);
										print($hostname);
									}
								?>"></td>
							</tr>
						</table>
					</td>
				</tr>
			</table>
		</td>
	</tr>
	<tr>
		<td>
			<p>WHOIS Information:</p>
			<optgroup label="whois">
				<input type="radio" name="whois_lookup" value="src"> Src IP
				<input type="radio" name="whois_lookup" value="dst"> Dst IP
				<input type="radio" name="whois_lookup" value="none" checked> None
			</optgroup>
			<input value="Whois lookup" type="submit">
			<textarea name="whois" rows="6" cols="60">
<?php



$whois_command="/usr/bin/jwhois";

if ( $_REQUEST['whois_lookup'] == "src" ) {
	if (preg_match("/^[\d\.]+$/", $_REQUEST['src_ip'])) {
		$command = $whois_command . " " . $_REQUEST['src_ip'];
		//print("Executing: $command\n\n");
		system("$command");
	} else {
		print("What in the hell do you think you're doing?!\n");	
	}
} else if ( $_REQUEST['whois_lookup'] == "dst" ) {
	if (preg_match("/^[\d\.]+$/", $_REQUEST['src_ip'])) {
		$command = $whois_command . " " . $_REQUEST['dst_ip'];
		//print("Executing: $command\n\n");
		system("$command");
	} else {
		print("What in the hell do you think you're doing?!\n");	
	}
}
			?></textarea>
		</td>
	</tr>
</table>
</form>




</body>
</html>
