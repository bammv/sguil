<?php
function jscript_newwindow() {
	print("<SCRIPT LANGUAGE=\"JavaScript\">\n");
	print("	<!-- Begin\n");
	print("	function NewWindow(mypage, myname, w, h, scroll) {\n");
	print("		var winl = (screen.width - w) / 2;\n");
	print("		var wint = (screen.height - h) / 2;\n");
	print("		winprops = 'height='+h+',width='+w+',top='+wint+',left='+winl+',scrollbars='+scroll+',resizable'\n");
	print("		win = window.open(mypage, myname, winprops)\n");
	print("		if (parseInt(navigator.appVersion) >= 4) { win.window.focus(); }\n");
	print("	}\n");
	print("	//  End -->\n");
	print("</SCRIPT>\n");
}

function jscript_overlib_head() {
	print("<script type=\"text/javascript\" src=\"overlib.js\"><!-- overLIB (c) Erik Bosrup --></script>\n");
}

function jscript_overlib_body() {
	print("<div id=\"overDiv\" style=\"position:absolute; visibility:hidden; z-index:1000;\"></div>\n");
}
function jscript_topmenu_head() {
	print("<script language=\"javascript\" src=\"config.js\"></script>\n");
	print("<script language=\"javascript\" src=\"menu.js\"></script>\n");
}

function jscript_topmenu_body() {
	print("<SCRIPT LANGUAGE=\"JavaScript\">\n");
	print("   <!--\n");
	print("   AddMenu(\"1\" , \"1\" , \"File\" ,  \"\"  ,  \"\"  , \"\");\n");
	print("     AddMenu(\"2\" , \"1\" , \"Show Incident Cat's\" ,  \"\"  ,  \"\"  , \"incident_categories.php\");   \n");
	print("     AddMenu(\"3\" , \"1\" , \"About\" , \"\"  ,  \"\"  , \"about.php\");\n");

	print("   AddMenu(\"4\" , \"4\" , \"Query\" ,  \"\" , \"\" , \"\");\n");
	print("     AddMenu(\"5\" , \"4\" , \"Query Event Table\" ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("     AddMenu(\"6\" , \"4\" , \"Query Session Table\" , \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("     AddMenu(\"7\" , \"4\" , \"Standard Queries\" , \"\" , \"\" , \"http://www.javascriptsource.com\");  \n");
	print("     AddMenu(\"8\" , \"4\" , \"Query Builder\"   ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");  \n");
	print("     AddMenu(\"9\" , \"4\" , \"Query By Category >>\"    ,  \"\"  ,  \"\"  , \"\");  \n");
	print("       AddMenu(\"10\", \"9\" , \"Cat I:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("       AddMenu(\"11\", \"9\" , \"Cat II:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("       AddMenu(\"12\", \"9\" , \"Cat III:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("       AddMenu(\"13\", \"9\" , \"Cat IV:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("       AddMenu(\"14\", \"9\" , \"Cat V:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("       AddMenu(\"15\", \"9\" , \"Cat VI:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("       AddMenu(\"16\", \"9\" , \"Cat VII:\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");    \n");
	print("   AddMenu(\"17\", \"4\" , \"Show Database Tables\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");

	print("   AddMenu(\"18\", \"18\" , \"Reports\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("     AddMenu(\"19\", \"18\" , \"Export to CSV >>\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("       AddMenu(\"20\", \"19\" , \"Summary >>\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("         AddMenu(\"21\", \"20\" , \"Normal\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("         AddMenu(\"22\", \"20\" , \"Santanized\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("       AddMenu(\"23\", \"19\" , \"Details >>\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("         AddMenu(\"24\", \"23\" , \"Normal\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("         AddMenu(\"25\", \"23\" , \"Santanized\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("     AddMenu(\"26\", \"18\" , \"Email Events >>\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("       AddMenu(\"27\", \"26\" , \"Summary >>\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("         AddMenu(\"28\", \"27\" , \"Normal\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("         AddMenu(\"29\", \"27\" , \"Santanized\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("       AddMenu(\"30\", \"26\" , \"Details >>\"     ,  \"\"  ,  \"\"  , \"\");\n");
	print("         AddMenu(\"31\", \"30\" , \"Normal\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("         AddMenu(\"32\", \"30\" , \"Santanized\"     ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");

	print("   AddMenu(\"33\" , \"33\" , \"Database\"       ,  \"\"  ,  \"\"  , \"\");\n");
	print("     AddMenu(\"34\" , \"33\" , \"Purge Session Data\"       ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");
	print("     AddMenu(\"35\" , \"33\" , \"Optimize Tables\"      ,  \"\"  ,  \"\"  , \"http://www.javascriptsource.com\");\n");

	print("   Build();\n");
	print("   --> \n");
	print("</SCRIPT>\n");
}
