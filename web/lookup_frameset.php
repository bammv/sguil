<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/lookup_frameset.php,v 1.2 2004/04/03 15:50:24 dlowless Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

?><html>
<head>
<title>Lookup Toolbar</title>
<meta name="author" content="Michael Boman">
<meta name="copyright" content="Copyright 2004 Michael Boman <mboman@users.sourceforge.net>. All Rights Reserved.">
<?php include('css.php'); ?>
</head>
<frameset cols="50%,50%">
<frame name="lookup_left" src="hostlookup.php">
<frame name="lookup_right" src="alert_detail.php">
<noframes>

</noframes
</frameset>
</html>
