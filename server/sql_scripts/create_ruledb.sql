-- $Id

CREATE DATABASE IF NOT EXISTS sguildb;

USE sguildb;

CREATE TABLE `rman_sensor_status` (
  `sid` int(11) NOT NULL default '0',
  `statusflag` int(11) default NULL,
  `lastlog` text,
  `lastcheck` timestamp(14) NOT NULL,
  `lastupdate` timestamp(14) NOT NULL,
  PRIMARY KEY  (`sid`)
) TYPE=MyISAM;

CREATE TABLE `rman_rgroup` (
  `rgid` int(11) NOT NULL auto_increment,
  `name` varchar(30) default NULL,
  `description` varchar(255) default NULL,
  `updated` timestamp(14) NOT NULL,
  PRIMARY KEY  (`rgid`)
) TYPE=MyISAM;

CREATE TABLE `rman_rules` (
  `rid` int(11) NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `active` enum('Y','N','P') default NULL,
  `rev` int(11) default NULL,
  `updated` timestamp(14) NOT NULL,
  `created` timestamp(14) NOT NULL,
  `action` varchar(30) default NULL,
  `proto` varchar(30) default NULL,
  `s_ip` varchar(255) default NULL,
  `s_port` varchar(30) default NULL,
  `dir` enum('->','<>') default NULL,
  `d_ip` varchar(255) default NULL,
  `d_port` varchar(30) default NULL,
  `options` blob,
  PRIMARY KEY  (`rid`)
) TYPE=MyISAM; 

ALTER TABLE rman_rules AUTO_INCREMENT=1000000;

CREATE TABLE `rman_rule_description` (
  `rid` int(11) NOT NULL,
  `Summary` varchar(255) default NULL,
  `Impact` text default NULL,
  `DetailedInformation` text default NULL,
  `AttackScenarios` text default NULL,
  `EaseOfAttack` text default NULL,
  `FalsePositives` text default NULL,
  `FalseNegatives` text default NULL,
  `CorrectiveAction` text default NULL,
  `References` text default NULL,
  `Contributors` text default NULL,
  `Comments` text default NULL,
  PRIMARY KEY (`rid`)
) TYPE=MyISAM;

CREATE TABLE `rman_rrgid` (
  `rid` int(11) default NULL,
  `rgid` int(11) default NULL,
  KEY `idx_rid` (`rid`)
) TYPE=MyISAM;

CREATE TABLE `rman_senrgrp` (
  `sid` int(11) default NULL,
  `rgid` int(11) default NULL
) TYPE=MyISAM;

CREATE TABLE `rman_vars` (
  `vid` int(11) NOT NULL auto_increment,
  `vname` varchar(30) default NULL,
  PRIMARY KEY  (`vid`)
) TYPE=MyISAM;

INSERT INTO rman_vars (vid, vname) VALUES (1, 'HOME_NET');
INSERT INTO rman_vars (vid, vname) VALUES (2, 'EXTERNAL_NET');
INSERT INTO rman_vars (vid, vname) VALUES (3, 'HTTP_SERVERS');
INSERT INTO rman_vars (vid, vname) VALUES (4, 'SQL_SERVERS');
INSERT INTO rman_vars (vid, vname) VALUES (5, 'SMTP');
INSERT INTO rman_vars (vid, vname) VALUES (6, 'DNS_SERVERS');
INSERT INTO rman_vars (vid, vname) VALUES (7, 'SHELLCODE_PORTS');
INSERT INTO rman_vars (vid, vname) VALUES (8, 'HTTP_PORTS');
INSERT INTO rman_vars (vid, vname) VALUES (9, 'ORACLE_PORTS');
INSERT INTO rman_vars (vid, vname) VALUES (10, 'TELNET_SERVERS');
INSERT INTO rman_vars (vid, vname) VALUES (11, 'AIM_SERVERS');

ALTER TABLE rman_vars AUTO_INCREMENT=100;

CREATE TABLE `rman_varvals` (
  `vid` int(11) NOT NULL,
  `sid` int(11) NOT NULL,
  `value` varchar(255) NOT NULL,
  `comment` varchar(255) default NULL,
  `updated` timestamp(14) NOT NULL
) TYPE=MyISAM;

# Insert defaults for sensor '0' i.e. default sensor
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (1,0,'any','Default definition for HOME_NET');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (2,0,'any','Default definition for EXTERNAL_NET');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (3,0,'$HOME_NET','Default definition for HTTP_SERVERS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (4,0,'$HOME_NET','Default definition for SQL_SERVERS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (5,0,'$HOME_NET','Default definition for SMTP');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (6,0,'$HOME_NET','Default definition for DNS_SERVERS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (7,0,'!80','Default definition for SHELLCODE_PORTS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (8,0,'80','Default definition for HTTP_PORTS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (9,0,'1521','Default definition for ORACLE_PORTS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (10,0,'$HOME_NET','Default definition for TELNET_SERVERS');
INSERT INTO rman_varvals (vid, sid, value, comment) VALUES (11,0,'[64.12.24.0/24,64.12.25.0/24,64.12.26.14/24,64.12.28.0/24,64.12.29.0/24,64.12.161.0/24,64.12.163.0/24,205.188.5.0/24,205.188.9.0/24]','Default definition for AIM_SERVERS');

CREATE TABLE `rman_tag` (
  rid int NOT NULL,
  sid int NOT NULL DEFAULT 0,
  tag_type enum('session','host') NOT NULL DEFAULT 'session',
  tag_count int NOT NULL DEFAULT 300,
  tag_metric enum('packets','seconds') NOT NULL DEFAULT 'seconds',
  PRIMARY KEY (rid,sid),
  INDEX rid (rid),
  INDEX sid (sid)
);

CREATE TABLE `rman_snortsam` (
  rid INT NOT NULL,
  sid INT NOT NULL DEFAULT 0,
  ss_who enum('source','destination') NOT NULL DEFAULT 'source',
  ss_how enum('in','out','src','dest','either','both','this') NOT NULL DEFAULT 'this',
  ss_time_count int NOT NULL DEFAULT 5,
  ss_time_metric enum ('seconds','minutes','hours','days','weeks','months','years','permanent') NOT NULL DEFAULT 'minutes',
  PRIMARY KEY (rid,sid),
  INDEX rid (rid),
  INDEX sid (sid)
);

CREATE TABLE `rman_response` (
  rid INT NOT NULL,
  sid INT NOT NULL DEFAULT 0,
  response enum('rst_snd','rst_rcv','rst_all','icmp_net','icmp_host','icmp_port','icmp_all') NOT NULL DEFAULT 'rst_all',
  PRIMARY KEY (rid,sid),
  INDEX rid (rid),
  INDEX sid (sid)
);

CREATE TABLE `rman_classification` (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(255) NOT NULL,
  priority INT NOT NULL,
  PRIMARY KEY (id)
);

INSERT INTO rman_classification (name, description, priority) VALUES ("not-suspicious","Not Suspicious Traffic","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("unknown","Unknown Traffic","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("bad-unknown","Potentially Bad Traffic"," 2");
INSERT INTO rman_classification (name, description, priority) VALUES ("attempted-recon","Attempted Information Leak","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("successful-recon-limited","Information Leak","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("successful-recon-largescale","Large Scale Information Leak","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("attempted-dos","Attempted Denial of Service","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("successful-dos","Denial of Service","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("attempted-user","Attempted User Privilege Gain","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("unsuccessful-user","Unsuccessful User Privilege Gain","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("successful-user","Successful User Privilege Gain","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("attempted-admin","Attempted Administrator Privilege Gain","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("successful-admin","Successful Administrator Privilege Gain","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("rpc-portmap-decode","Decode of an RPC Query","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("shellcode-detect","Executable code was detected","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("string-detect","A suspicious string was detected","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("suspicious-filename-detect","A suspicious filename was detected","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("suspicious-login","An attempted login using a suspicious username was detected","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("system-call-detect","A system call was detected","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("tcp-connection","A TCP connection was detected","4");
INSERT INTO rman_classification (name, description, priority) VALUES ("trojan-activity","A Network Trojan was detected"," 1");
INSERT INTO rman_classification (name, description, priority) VALUES ("unusual-client-port-connection","A client was using an unusual port","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("network-scan","Detection of a Network Scan","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("denial-of-service","Detection of a Denial of Service Attack","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("non-standard-protocol","Detection of a non-standard protocol or event","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("protocol-command-decode","Generic Protocol Command Decode","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("web-application-activity","access to a potentially vulnerable web application","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("web-application-attack","Web Application Attack","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("misc-activity","Misc activity","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("misc-attack","Misc Attack","2");
INSERT INTO rman_classification (name, description, priority) VALUES ("icmp-event","Generic ICMP event","3");
INSERT INTO rman_classification (name, description, priority) VALUES ("kickass-porn","SCORE! Get the lotion!","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("policy-violation","Potential Corporate Privacy Violation","1");
INSERT INTO rman_classification (name, description, priority) VALUES ("default-login-attempt","Attempt to login by a default username and password","2");

CREATE TABLE `rman_config` (
  `sid` int(11) NOT NULL default '0',
  `option` VARCHAR(255) NOT NULL,
  `value` VARCHAR(255),
  PRIMARY KEY (`sid`,`option`)
);


