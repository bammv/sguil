<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/Attic/tabs.php,v 1.4 2004/04/03 15:50:24 dlowless Exp $
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
			<td width="25%" colspan="0" rowspan="0" align="center" valign="middle">
				<form action="alerts.php" method="POST" target="alerts">
					<input type="hidden" name="query" value="WHERE event.sid=sensor.sid AND event.status=0 ORDER BY event.timestamp ASC LIMIT 50">
					<input value="RealTime Events" type="submit">		
				</form>
			</td>
			<td width="25%" colspan="0" rowspan="0" align="center" valign="middle">
				<form action="alerts.php" method="POST" target="alerts">
					<input type="hidden" name="query" value="WHERE event.sid=sensor.sid AND event.status=2 ORDER BY event.timestamp ASC LIMIT 50">
					<input value="Escalated Events" type="submit">
				</form>
			</td>
			<td width="25%" colspan="0" rowspan="0" align="center" valign="middle">
				<form action="sessions.php" method="POST" target="alerts">
					<input type="hidden" name="query" value="">
					<input value="Session Query" type="submit">
				</form>
			</td>
			<td width="25%" colspan="0" rowspan="0" align="center" valign="middle">
				Query Builder
			</td>
		</tr>
	</table>
</body>
</html>
