<?php
/*
 * Copyright (C) 2003,2004 Richard Bejtlich (sguil at taosecurity.com, http://www.taosecurity.com). All Rights Reserved.
 * $Header: /usr/local/src/sguil_bak/sguil/sguil/web/incident_categories.php,v 1.2 2004/04/05 14:29:30 mboman Exp $
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
<h2>Category I: Root/Administrator Account Compromise</h2>
<p>A category I event occurs when an unauthorized party gains 'root' or 'administrator' control of a client computer.  Unauthorized parties include human adversaries and automated malicious code, such as a worm.  On UNIX-like systems, the 'root' account is the 'super-user,' generally capable of taking any action desired by the unauthorized party.  (Note that so-called 'Trusted' operating systems (OS), like Sun Microsystem's 'Trusted Solaris,' divide the powers of the root account among various operators.  Compromise of any one of these accounts on a 'Trusted' OS constitutes a category I incident.)  On Windows systems, the 'administrator' has near complete control of the computer, although some powers remain with the 'SYSTEM' account used internally by the OS itself.  (Compromise of the SYSTEM account is considered a category I event as well.)  Category I incidents are potentially the most damaging type of event.</p>

<h2>Category II: User Account Compromise</h2>
<p>A category II event occurs when an unauthorized party gains control of any non-root or non-administrator account on a client computer.  User accounts include those held by people as well as applications.  For example, services may be configured to run or interact with various non-root or non-administrator accounts, such as 'apache' for the Apache web server or 'IUSR_machinename' for Microsoft's Internet Information Services (IIS).  Category II incidents are treated as though they will quickly escalate to Category I events.  Skilled attackers will elevate their privileges once they acquire user status on the victim machine.</p>

<h2>Category III: Attempted Account Compromise</h2>
<p>A category III event occurs when an unauthorized party attempts to gain root/administrator or user level access on a client computer.  The exploitation attempt fails for one of several reasons.  First, the target may be properly patched to reject the attack.  Second, the attacker may find a vulnerable machine, but he may not be sufficiently skilled to execute the attack.  Third, the target may be vulnerable to the attack, but its configuration prevents compromise.  (For example, an IIS web server may be vulnerable to an exploit employed by a worm, but the default locations of critical files have been altered.)</p>

<h2>Category IV: Denial of Service</h2>
<p>A category IV event occurs when an adversary takes damaging action against the resources or processes of a target machine or network.  Denial of service attacks may consume CPU cycles, bandwidth, hard drive space, user's time, and many other resources.</p>

<h2>Category V: Poor Security Practice or Policy Violation</h2>  A category V event occurs when the MNSS operation detects a condition which exposes the client to unnecessary risk of exploitation.  For example, should a MNSS analyst discover that a client domain name system server allows zone transfers to all Internet users, she will report the incident as a category V event.  (Zone transfers provide complete information on the host names and IP addresses of client machines.)  Violations of a client's security policy also constitutes a category V incident.  Should a client forbid the use of peer-to-peer file sharing applications, detections of  Napster or Gnutella traffic will be reported as category V events.</p>

<h2>Category VI: Reconnaissance</h2>  
<p>A category VI event occurs when an adversary attempts to learn about a target system or network, with the presumed intent to later compromise that system or network.  Reconnaissance events include port scans, enumeration of NetBIOS shares on Windows systems, inquiries concerning the version of applications on servers, unauthorized zone transfers, and similar activity.  Category VI activity also includes limited attempts to guess user names and passwords.  Sustained, intense guessing of user names and passwords would be considered category III events if unsuccessful.</p>

<h2>Category VII: Virus Activity</h2>
<p>A category VII event occurs when a client system becomes infected by a virus.  Note the emphasis here is on the term virus, as opposed to a worm.  Viruses depend on one or both of the following conditions: (1) human interaction is required to propagate the virus; (2) the virus must attach itself to a 'host' file, such as an email message, Word document, or web page.  Worms, on the other hand, are capable of propagating themselves without human interaction or host files.  A compromise caused by a worm would qualify as a category I or II event.</p>
</body>
</html>
