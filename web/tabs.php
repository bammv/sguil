<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/Attic/tabs.php,v 1.9 2004/04/04 17:12:49 dlowless Exp $
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
	<title>Tab-bar</title>
	<meta name="author" content="Michael Boman">
	<meta name="copyright" content="Copyright 2004 Michael Boman <mboman@users.sourceforge.net>. All Rights Reserved.">
	<?php include('css.php'); ?>
</head>
<body>
	<table cellpadding="0" cellspacing="0" border="0" width="100%">
		<tr>
			<td width="20%" colspan="0" rowspan="0" align="center" valign="middle">
				<form action="alerts.php" method="POST" target="alerts">
					<input type="hidden" name="query" value="WHERE event.sid=sensor.sid AND event.status=0 GROUP BY src_ip,signature ORDER BY event.timestamp DESC LIMIT 50">
					<input type="hidden" name="aggregate" value="1">
					<input value="RealTime Events" type="submit">		
				</form>
			</td>
			<td width="20%" colspan="0" rowspan="0" align="center" valign="middle">
				<form action="alerts.php" method="POST" target="alerts">
					<input type="hidden" name="query" value="WHERE event.sid=sensor.sid AND event.status=2 GROUP BY src_ip,signature ORDER BY event.timestamp DESC LIMIT 50">
					<input type="hidden" name="aggregate" value="1">
					<input value="Escalated Events" type="submit">
				</form>
			</td>
			<td width="20%" colspan="0" rowspan="0" align="center" valign="middle">
				<form action="sessions.php" method="POST" target="alerts">
					<input type="hidden" name="query" value="">
					<input value="Session Query" type="submit">
				</form>
			</td>
			<td width="20%" colspan="0" rowspan="0" align="center" valign="middle">
				Query Builder
			</td>
			<td width="20%" colspan="0" rowspan="0" align="center" valign="middle">
				<a href="about.php" target="alerts">About</a>
			</td>
		</tr>
	</table>
</body>
</html>
