<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/about.php,v 1.4 2004/04/05 14:29:30 mboman Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

require("std_functions.php");

?><!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>SGUIL Web Console :: About</title>
<meta name="author" content="Michael Boman">
<meta name="copyright" content="Copyright 2004 Michael Boman <mboman@users.sourceforge.net>. All Rights Reserved.">
<?php
	include('css.php');
	jscript_topmenu_head();
?>
</head>
<body>
<?php
	navbar();
?>
<h1>Credits</h1>
<ul>
<li>Initial concept design and code by Michael Boman
&lt;<a href="mailto:mboman@users.sourceforge.net">mboman@users.sourceforge.net</a>&gt;.</li>
<li>CSS Stylesheet and aggregated alerts by David Lowless
&lt;<a href="mailto:dlowless@users.sourceforge.net">dlowless@users.sourceforge.net</a>&gt;.</li>
<li>Category descriptions by Richard Bejtlich
&lt;<a href="mailto:sguil at taosecurity.com">sguil at taosecurity.com</a>&gt;.</li>
<li>This product includes GeoIP data created by MaxMind, available
from <a href="http://maxmind.com/" target="_blank">http://maxmind.com/</a></li>
</ul>
</body>
</html>
