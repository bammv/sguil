<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/alerts.php,v 1.3 2004/04/01 15:35:01 mboman Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

	require("sguil_functions.php");
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
	<title>Alert Listing</title>
	<meta name="author" content="Michael Boman">
	<meta name="copyright" content="Copyright 2004 Michael Boman <mboman@users.sourceforge.net>. All Rights Reserved.">
<?php
	if( $_REQUEST['auto_refresh'] == 1 ) {
		$url=$_SERVER['PHP_SELF'] .
			"?query=" . $_REQUEST['query'] .
			"&auto_refresh=" . $_REQUEST['auto_refresh'] .
			"&autorefresh_interval=" . $_REQUEST['autorefresh_interval'];
			
			printf("	<meta http-equiv=\"refresh\" content=\"" . $_REQUEST['autorefresh_interval'] . "; URL=" . $url ."\">\n");
	}
?>
</head>
<body>

<?php
	show_alerts($_REQUEST["query"]);
?>

</body>
</html>