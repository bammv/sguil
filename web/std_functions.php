<?php

require("jscript_functions.php");

function navbar() {
	print("<br><br>");
	print("	<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">\n");
	print("		<tr>\n");
	print("			<td width=\"20%\" colspan=\"0\" rowspan=\"0\" align=\"center\" valign=\"middle\">\n");
	print("				<form action=\"alerts.php\" method=\"POST\" target=\"alerts\">\n");
	print("					<input type=\"hidden\" name=\"query\" value=\"WHERE event.sid=sensor.sid AND event.status=0 GROUP BY src_ip,signature ORDER BY event.timestamp DESC LIMIT 50\">\n");
	print("					<input type=\"hidden\" name=\"aggregate\" value=\"1\">\n");
	print("					<input value=\"RealTime Events\" type=\"submit\">		\n");
	print("				</form>\n");
	print("			</td>\n");
	print("			<td width=\"20%\" colspan=\"0\" rowspan=\"0\" align=\"center\" valign=\"middle\">\n");
	print("				<form action=\"alerts.php\" method=\"POST\" target=\"alerts\">\n");
	print("					<input type=\"hidden\" name=\"query\" value=\"WHERE event.sid=sensor.sid AND event.status=2 GROUP BY src_ip,signature ORDER BY event.timestamp DESC LIMIT 50\">\n");
	print("					<input type=\"hidden\" name=\"aggregate\" value=\"1\">\n");
	print("					<input value=\"Escalated Events\" type=\"submit\">\n");
	print("				</form>\n");
	print("			</td>\n");
	print("			<td width=\"20%\" colspan=\"0\" rowspan=\"0\" align=\"center\" valign=\"middle\">\n");
	print("				<form action=\"sessions.php\" method=\"POST\" target=\"alerts\">\n");
	print("					<input type=\"hidden\" name=\"query\" value=\"\">\n");
	print("					<input value=\"Session Query\" type=\"submit\">\n");
	print("				</form>\n");
	print("			</td>\n");
	/*
	print("			<td width=\"20%\" colspan=\"0\" rowspan=\"0\" align=\"center\" valign=\"middle\">\n");
	print("				Query Builder\n");
	print("			</td>\n");
	print("			<td width=\"20%\" colspan=\"0\" rowspan=\"0\" align=\"center\" valign=\"middle\">\n");
	print("				<a href=\"about.php\" target=\"alerts\">About</a>\n");
	print("			</td>\n");
	*/
	print("		</tr>\n");
	print("	</table>\n");
	
	jscript_topmenu_body();
}

?>