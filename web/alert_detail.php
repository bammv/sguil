<?php
/*
 * Copyright (C) 2004 Michael Boman <mboman@users.sourceforge.net>
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/alert_detail.php,v 1.4 2004/04/04 17:01:42 mboman Exp $
 *
 * This program is distributed under the terms of version 1.0 of the
 * Q Public License.  See LICENSE.QPL for further details.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

require("sguil_functions.php");

?><!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta name="author" content="Michael Boman">
<meta name="copyright" content="Copyright 2004 Michael Boman <mboman@users.sourceforge.net>. All Rights Reserved.">
<title>Alert Details</title>
<?php include('css.php'); ?>
</head>
<body>

<?php
	if( ($_REQUEST['sid'] != "" ) && ( $_REQUEST['cid'] != "") ) {
?>

<table cellpadding="0" cellspacing="0" border="1" width="100%">
	<tr><td colspan="2">&nbsp;Displaying alert <?php print($_REQUEST['sid'] . "." . $_REQUEST['cid']); ?></td></tr>
	<tr><td bgcolor="#00BFFF" align="center"><font color="#FFFFFF"><strong>&nbsp;IP&nbsp;</strong></font></td><td bgcolor="#ADD7E6"><?php
		$proto = alert_details_ip($_REQUEST['sid'],$_REQUEST['cid']);
	?></td></tr>
	
	<?php
	
	if( $proto == 1 ) {
		?>
	   <tr><td bgcolor="#0000FF" align="center"><font color="#FFFFFF"><strong>&nbsp;ICMP&nbsp;</strong></font></td><td bgcolor="#ADD7E6">
		<?php
		alert_details_icmp($_REQUEST['sid'],$_REQUEST['cid']);
 		?>
 		</td></tr>
 		<?php
	} else if ( $proto == 6 ) {
	   ?>
	   <tr><td bgcolor="#0000FF" align="center"><font color="#FFFFFF"><strong>&nbsp;TCP&nbsp;</strong></font></td><td bgcolor="#ADD7E6">
	   <?php
		alert_details_tcp($_REQUEST['sid'],$_REQUEST['cid']);
		?>
		</td></tr>
		<?php
	} else if ( $proto == 17 ) {
		?>
	   <tr><td bgcolor="#0000FF" align="cente"><font color="#FFFFFF"><strong>&nbsp;UDP&nbsp;</strong></font></td><td bgcolor="#ADD7E6">
	   <?php
		alert_details_udp($_REQUEST['sid'],$_REQUEST['cid']);
		?>
		</td></tr>
		<?php
	}
	
	?>
	<tr><td bgcolor="#00007F" align="center"><font color="#FFFFFF"><strong>&nbsp;DATA&nbsp;</strong></font></td><td bgcolor="#ADD7E6"><?php
	
	alert_details_payload($_REQUEST['sid'],$_REQUEST['cid']);
	
	
	?></td></tr>
</table>

<?php
 } else {
?>

No event selected. Click on the alert's sid.cid value to show it's details.


<?php
}
?>
</body>
</html>
