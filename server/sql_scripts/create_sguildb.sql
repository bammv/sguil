-- $Id: create_sguildb.sql,v 1.22 2013/09/05 00:38:45 bamm Exp $
-- Users may want to use a different DB name.
-- CREATE DATABASE IF NOT EXISTS sguildb;
-- USE sguildb;

-- Depreciated for MRG_MyISAM tables
-- CREATE TABLE event
-- (
--   sid			INT UNSIGNED	NOT NULL,
--   cid			INT UNSIGNED	NOT NULL,
--   signature 		VARCHAR(255)	NOT NULL,
--   signature_gen		INT UNSIGNED	NOT NULL,
--   signature_id		INT UNSIGNED	NOT NULL,
--   signature_rev		INT UNSIGNED	NOT NULL,
--   timestamp		DATETIME	NOT NULL,
--   unified_event_id	INT UNSIGNED, 
--   unified_event_ref	INT UNSIGNED,
--   unified_ref_time	DATETIME,
--   priority		INT UNSIGNED,
--   class			VARCHAR(20),
--   status		SMALLINT UNSIGNED DEFAULT 0,
--  src_ip		INT UNSIGNED,
--  dst_ip		INT UNSIGNED,
--  src_port		INT UNSIGNED,
--  dst_port		INT UNSIGNED,
--  icmp_type		TINYINT UNSIGNED,
--  icmp_code		TINYINT UNSIGNED,
--  ip_proto		TINYINT UNSIGNED,
--  ip_ver		TINYINT UNSIGNED,
--  ip_hlen		TINYINT UNSIGNED,
--  ip_tos		TINYINT UNSIGNED,
--  ip_len		SMALLINT UNSIGNED,
--  ip_id 		SMALLINT UNSIGNED,
--  ip_flags		TINYINT UNSIGNED,
--  ip_off		SMALLINT UNSIGNED,
--  ip_ttl		TINYINT UNSIGNED,
--  ip_csum		SMALLINT UNSIGNED,
--  last_modified		DATETIME,
--  last_uid		INT UNSIGNED,
--  abuse_queue		enum('Y','N'),
--  abuse_sent		enum('Y','N'),
--  PRIMARY KEY (sid,cid),
--  INDEX src_ip (src_ip),
--  INDEX dst_ip (dst_ip),
--  INDEX dst_port (dst_port),
--  INDEX src_port (src_port),
--  INDEX icmp_type (icmp_type),
--  INDEX icmp_code (icmp_code),
--  INDEX timestamp (timestamp),
--  INDEX last_modified (last_modified),
--  INDEX signature (signature),
--  INDEX status (status),
--  INDEX abuse_queue (abuse_queue),
--  INDEX abuse_sent (abuse_sent)
-- );

-- CREATE TABLE tcphdr
-- (
--  sid		INT UNSIGNED	NOT NULL,
--  cid		INT UNSIGNED	NOT NULL,
--  tcp_seq	INT UNSIGNED,
--  tcp_ack	INT UNSIGNED,
--  tcp_off	TINYINT UNSIGNED,
--  tcp_res	TINYINT UNSIGNED,
--  tcp_flags	TINYINT UNSIGNED,
--  tcp_win	SMALLINT UNSIGNED,
--  tcp_csum	SMALLINT UNSIGNED,
--  tcp_urp	SMALLINT UNSIGNED,
--  PRIMARY KEY (sid,cid));
--
-- CREATE TABLE udphdr
-- (
--  sid		INT UNSIGNED	NOT NULL,
--  cid		INT UNSIGNED	NOT NULL,
--  udp_len	SMALLINT UNSIGNED,
--  udp_csum	SMALLINT UNSIGNED,
--  PRIMARY KEY (sid,cid));
--
-- CREATE TABLE icmphdr
-- (
--  sid		INT UNSIGNED	NOT NULL,
--  cid		INT UNSIGNED	NOT NULL,
--  icmp_csum	SMALLINT UNSIGNED,
--  icmp_id	SMALLINT UNSIGNED,
--  icmp_seq	SMALLINT UNSIGNED,
--  PRIMARY KEY (sid,cid));
--
-- CREATE TABLE data
-- (
--  sid           INT UNSIGNED    NOT NULL,
--  cid           INT UNSIGNED    NOT NULL,
--  data_payload	TEXT,
--  PRIMARY KEY (sid,cid));

CREATE TABLE sensor
(
  sid		INT UNSIGNED	NOT NULL AUTO_INCREMENT,
  hostname	VARCHAR(255)	NOT NULL,
  agent_type    VARCHAR(40),
  net_name	VARCHAR(40),
  interface	VARCHAR(255),
  description	TEXT,
  bpf_filter	TEXT,
  updated	TIMESTAMP(14) NOT NULL,
  active	ENUM('Y','N') DEFAULT 'Y',
  ip		VARCHAR(15) DEFAULT NULL,
  public_key	VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (sid),
  INDEX hostname_idx (hostname)
) ENGINE = MYISAM;

CREATE TABLE portscan
(
  hostname	VARCHAR(255),
  timestamp	DATETIME,
  src_ip	varchar(16),
  src_port	INT UNSIGNED,
  dst_ip	varchar(16),
  dst_port	INT UNSIGNED,
  data		TEXT,
  INDEX ps_src_ip (src_ip),
  INDEX ps_timestamp (timestamp)) ENGINE = MYISAM;

-- Depreciated
-- CREATE TABLE sessions ( 
--  sid		INT UNSIGNED NOT NULL, 
--  xid		BIGINT UNSIGNED NOT NULL, 
--  start_time	datetime NOT NULL, 
--  end_time	datetime NOT NULL, 
--  src_ip	INT UNSIGNED NOT NULL, 
--  dst_ip	INT UNSIGNED NOT NULL, 
--  src_port	INT UNSIGNED NOT NULL, 
--  dst_port	INT UNSIGNED NOT NULL, 
--  ip_proto	TINYINT UNSIGNED NOT NULL,
--  src_pckts	BIGINT UNSIGNED NOT NULL, 
--  dst_pckts	BIGINT UNSIGNED NOT NULL, 
--  src_bytes	BIGINT UNSIGNED NOT NULL, 
--  dst_bytes	BIGINT UNSIGNED NOT NULL, 
--  PRIMARY KEY (sid,xid), 
--  INDEX begin (start_time), 
--  INDEX end (end_time), 
--  INDEX server (src_ip), 
--  INDEX client (dst_ip), 
--  INDEX sport (src_port), 
--  INDEX cport (dst_port)); 

CREATE TABLE status
(
  status_id	SMALLINT UNSIGNED NOT NULL,
  description	VARCHAR(255) NOT NULL,
  long_desc     VARCHAR(255),
  PRIMARY KEY (status_id)
) ENGINE = MYISAM;

CREATE TABLE autocat
(
  autoid	INT UNSIGNED		NOT NULL AUTO_INCREMENT,
  erase		DATETIME,
  sensorname	VARCHAR(255),
  src_ip	VARCHAR(18),
  src_port	INT UNSIGNED, 
  dst_ip	VARCHAR(18),
  dst_port	INT UNSIGNED, 
  ip_proto	TINYINT UNSIGNED,
  signature	VARCHAR(255),
  status	SMALLINT UNSIGNED	NOT NULL,
  active	ENUM('Y','N') DEFAULT 'Y',
  timestamp	DATETIME NOT NULL,
  uid		INT UNSIGNED	NOT NULL,
  PRIMARY KEY (autoid)
) ENGINE = MYISAM;

CREATE TABLE history
(
  sid		INT UNSIGNED	NOT NULL,
  cid		INT UNSIGNED	NOT NULL,
  uid		INT UNSIGNED	NOT NULL,
  timestamp	DATETIME	NOT NULL,
  status	SMALLINT UNSIGNED	NOT NULL,
  comment	VARCHAR(255),
  INDEX log_time (timestamp)
) ENGINE = MYISAM;

CREATE TABLE user_info
(
  uid		INT UNSIGNED	NOT NULL AUTO_INCREMENT,
  username	VARCHAR(16)	NOT NULL,
  last_login	DATETIME,
  password	VARCHAR(42),
  PRIMARY KEY (uid)
) ENGINE = MYISAM;

CREATE TABLE nessus_data
(
  rid           VARCHAR(40)	NOT NULL,
  port          VARCHAR(40),
  nessus_id     INT UNSIGNED,
  level	        VARCHAR(20),
  description		TEXT,
  INDEX rid (rid)) ENGINE = MYISAM;

CREATE TABLE nessus
(
  uid           INT            NOT NULL,
  rid           VARCHAR(40)    NOT NULL,
  ip            VARCHAR(15)    NOT NULL,
  timestart     DATETIME,
  timeend       DATETIME,
  PRIMARY KEY (rid),
  INDEX ip (ip)) ENGINE = MYISAM;

CREATE TABLE IF NOT EXISTS `pads`
(
  hostname              VARCHAR(255)     NOT NULL,
  sid                   INT UNSIGNED     NOT NULL,
  asset_id              INT UNSIGNED     NOT NULL,
  timestamp             DATETIME         NOT NULL,
  ip                    INT UNSIGNED     NOT NULL,
  service               VARCHAR(40)      NOT NULL,
  port                  INT UNSIGNED     NOT NULL,
  ip_proto              TINYINT UNSIGNED NOT NULL,
  application           VARCHAR(255)     NOT NULL,
  hex_payload           VARCHAR(255),
  PRIMARY KEY (sid,asset_id)
) ENGINE = MYISAM;

--
-- Depreciated for MERGE tables
-- CREATE TABLE sancp
-- (
--  sid		INT UNSIGNED	NOT NULL,
--  sancpid	BIGINT UNSIGNED	NOT NULL,
--  start_time	DATETIME	NOT NULL,
--  end_time	DATETIME	NOT NULL,
--  duration	INT UNSIGNED	NOT NULL,
--  ip_proto	TINYINT UNSIGNED	NOT NULL,
--  src_ip	INT UNSIGNED,
--  src_port	SMALLINT UNSIGNED,
--  dst_ip	INT UNSIGNED,
--  dst_port	SMALLINT UNSIGNED,
--  src_pkts	INT UNSIGNED	NOT NULL,
--  src_bytes	INT UNSIGNED	NOT NULL,
--  dst_pkts	INT UNSIGNED	NOT NULL,
--  dst_bytes	INT UNSIGNED	NOT NULL,
--  src_flags	TINYINT UNSIGNED	NOT NULL,
--  dst_flags	TINYINT UNSIGNED	NOT NULL,
--  PRIMARY KEY (sid,sancpid),
--  INDEX src_ip (src_ip),
--  INDEX dst_ip (dst_ip),
--  INDEX dst_port (dst_port),
--  INDEX src_port (src_port),
--  INDEX start_time (start_time)
-- );
--

INSERT INTO status (status_id, description, long_desc) VALUES (0, "New", "Real Time Event");
INSERT INTO status (status_id, description, long_desc) VALUES (1, "No Further Action Required", "No Further Action Required");
INSERT INTO status (status_id, description, long_desc) VALUES (2, "Escalated", "Escalated");
INSERT INTO status (status_id, description, long_desc) VALUES (11, "Category I", "Unauthorized Root Access");
INSERT INTO status (status_id, description, long_desc) VALUES (12, "Category II", "Unauthorized User Access");
INSERT INTO status (status_id, description, long_desc) VALUES (13, "Category III", "Attempted Unauthorized Access");
INSERT INTO status (status_id, description, long_desc) VALUES (14, "Category IV", "Successful Denial of Service Attack");
INSERT INTO status (status_id, description, long_desc) VALUES (15, "Category V", "Poor Security Practice or Policy Violation");
INSERT INTO status (status_id, description, long_desc) VALUES (16, "Category VI", "Reconnaissance/Probes/Scans");
INSERT INTO status (status_id, description, long_desc) VALUES (17, "Category VII", "Virus Infection");


CREATE TABLE version
(
  version	VARCHAR(32),
  installed	DATETIME
) ENGINE = MYISAM;

INSERT INTO version (version, installed) VALUES ("0.14", now());

