-- Users may want to use a different DB name.
-- CREATE DATABASE IF NOT EXISTS sguildb;
-- USE sguildb;

CREATE TABLE event
(
  sid		INT UNSIGNED	NOT NULL,
  cid		INT UNSIGNED	NOT NULL,
  signature 	VARCHAR(255)	NOT NULL,
  signature_id	INT UNSIGNED	NOT NULL,
  signature_rev	INT UNSIGNED	NOT NULL,
  timestamp	DATETIME	NOT NULL,
  priority	INT UNSIGNED,
  class		VARCHAR(20),
  status	SMALLINT UNSIGNED DEFAULT 0,
  src_ip	INT UNSIGNED,
  dst_ip	INT UNSIGNED,
  src_port	INT UNSIGNED,
  dst_port	INT UNSIGNED,
  icmp_type	TINYINT UNSIGNED,
  icmp_code	TINYINT UNSIGNED,
  ip_proto	TINYINT UNSIGNED,
  ip_ver	TINYINT UNSIGNED,
  ip_hlen	TINYINT UNSIGNED,
  ip_tos	TINYINT UNSIGNED,
  ip_len	SMALLINT UNSIGNED,
  ip_id 	SMALLINT UNSIGNED,
  ip_flags	TINYINT UNSIGNED,
  ip_off	SMALLINT UNSIGNED,
  ip_ttl	TINYINT UNSIGNED,
  ip_csum	SMALLINT UNSIGNED,
  last_modified	DATETIME,
  serverity_criticality	TINYINT UNSIGNED,
  serverity_lethality	TINYINT UNSIGNED,
  serverity_system_cm	TINYINT	UNSIGNED,
  serverity_network_cm	TINYINT UNSIGNED,
  src_abuse_record_id	BIGINT UNSIGNED,
  dst_abuse_record_id	BIGINT UNSIGNED,
  abuse_queue		enum('Y','N'),
  abuse_sent		enum('Y','N'),
  PRIMARY KEY (sid,cid),
  INDEX src_ip (src_ip),
  INDEX dst_ip (dst_ip),
  INDEX dst_port (dst_port),
  INDEX src_port (src_port),
  INDEX icmp_type (icmp_type),
  INDEX icmp_code (icmp_code),
  INDEX timestamp (timestamp),
  INDEX signature (signature),
  INDEX status (status),
  INDEX src_abuse_record_id (src_abuse_record_id),
  INDEX dst_abuse_record_id (dst_abuse_record_id),
  INDEX abuse_queue (abuse_queue),
  INDEX abuse_sent (abuse_sent)
);

CREATE TABLE tcphdr
(
  sid		INT UNSIGNED	NOT NULL,
  cid		INT UNSIGNED	NOT NULL,
  tcp_seq	INT UNSIGNED,
  tcp_ack	INT UNSIGNED,
  tcp_off	TINYINT UNSIGNED,
  tcp_res	TINYINT UNSIGNED,
  tcp_flags	TINYINT UNSIGNED,
  tcp_win	SMALLINT UNSIGNED,
  tcp_csum	SMALLINT UNSIGNED,
  tcp_urp	SMALLINT UNSIGNED,
  PRIMARY KEY (sid,cid));

CREATE TABLE udphdr
(
  sid		INT UNSIGNED	NOT NULL,
  cid		INT UNSIGNED	NOT NULL,
  udp_len	SMALLINT UNSIGNED,
  udp_csum	SMALLINT UNSIGNED,
  PRIMARY KEY (sid,cid));

CREATE TABLE icmphdr
(
  sid		INT UNSIGNED	NOT NULL,
  cid		INT UNSIGNED	NOT NULL,
  icmp_csum	SMALLINT UNSIGNED,
  icmp_id	SMALLINT UNSIGNED,
  icmp_seq	SMALLINT UNSIGNED,
  PRIMARY KEY (sid,cid));

CREATE TABLE data
(
  sid           INT UNSIGNED    NOT NULL,
  cid           INT UNSIGNED    NOT NULL,
  data_payload	TEXT,
  PRIMARY KEY (sid,cid));

CREATE TABLE sensor
(
  sid		INT UNSIGNED	NOT NULL AUTO_INCREMENT,
  hostname	VARCHAR(255)	NOT NULL,
  interface	VARCHAR(255),
  description	TEXT,
  bpf_filter	TEXT,
  updated	TIMESTAMP(14) NOT NULL,
  active	ENUM('Y','N') DEFAULT 'Y',
  ip		VARCHAR(15) DEFAULT NULL,
  public_key	VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (sid),
  INDEX hostname_idx (hostname)
);

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
  INDEX ps_timestamp (timestamp));

CREATE TABLE sessions ( 
  sid		INT UNSIGNED NOT NULL, 
  xid		BIGINT UNSIGNED NOT NULL, 
  start_time	datetime NOT NULL, 
  end_time	datetime NOT NULL, 
  src_ip	INT UNSIGNED NOT NULL, 
  dst_ip	INT UNSIGNED NOT NULL, 
  src_port	INT UNSIGNED NOT NULL, 
  dst_port	INT UNSIGNED NOT NULL, 
  src_pckts	BIGINT UNSIGNED NOT NULL, 
  dst_pckts	BIGINT UNSIGNED NOT NULL, 
  src_bytes	BIGINT UNSIGNED NOT NULL, 
  dst_bytes	BIGINT UNSIGNED NOT NULL, 
  PRIMARY KEY (sid,xid), 
  INDEX begin (start_time), 
  INDEX end (end_time), 
  INDEX server (src_ip), 
  INDEX client (dst_ip), 
  INDEX sport (src_port), 
  INDEX cport (dst_port)); 

CREATE TABLE status
(
  status_id	SMALLINT UNSIGNED NOT NULL,
  description	VARCHAR(255) NOT NULL,
  PRIMARY KEY (status_id)
);

INSERT INTO status (status_id, description) VALUES (0, "New");
INSERT INTO status (status_id, description) VALUES (1, "No Further Action Required");
INSERT INTO status (status_id, description) VALUES (2, "Escalated");
INSERT INTO status (status_id, description) VALUES (11, "Category I");
INSERT INTO status (status_id, description) VALUES (12, "Category II");
INSERT INTO status (status_id, description) VALUES (13, "Category III");
INSERT INTO status (status_id, description) VALUES (14, "Category IV");
INSERT INTO status (status_id, description) VALUES (15, "Category V");
INSERT INTO status (status_id, description) VALUES (16, "Category VI");
INSERT INTO status (status_id, description) VALUES (17, "Category VII");


CREATE TABLE version
(
  version	VARCHAR(32),
  installed	DATETIME
);

INSERT INTO version (version, installed) VALUES ("0.5", now());
