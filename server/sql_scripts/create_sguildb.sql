CREATE TABLE sensor
(
  sid		INT UNSIGNED NOT NULL AUTO_INCREMENT,
  hostname	VARCHAR(255) NOT NULL,
  agent_type    VARCHAR(40),
  net_name	VARCHAR(40),
  interface	VARCHAR(255),
  description	TEXT,
  bpf_filter	TEXT,
  updated	TIMESTAMP NOT NULL,
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
  src_ip	VARCHAR(16),
  src_port	INT UNSIGNED,
  dst_ip	VARCHAR(16),
  dst_port	INT UNSIGNED,
  data		TEXT,
  INDEX ps_src_ip (src_ip),
  INDEX ps_timestamp (timestamp)
) ENGINE = MYISAM;

CREATE TABLE status
(
  status_id	SMALLINT UNSIGNED NOT NULL,
  description	VARCHAR(255) NOT NULL,
  long_desc     VARCHAR(255),
  PRIMARY KEY (status_id)
) ENGINE = MYISAM;

CREATE TABLE autocat
(
  autoid	INT UNSIGNED NOT NULL AUTO_INCREMENT,
  erase		DATETIME,
  sensorname	VARCHAR(255),
  src_ip	VARCHAR(18),
  src_port	INT UNSIGNED, 
  dst_ip	VARCHAR(18),
  dst_port	INT UNSIGNED, 
  ip_proto	TINYINT UNSIGNED,
  signature	VARCHAR(255),
  status	SMALLINT UNSIGNED NOT NULL,
  active	ENUM('Y','N') DEFAULT 'Y',
  timestamp	DATETIME NOT NULL,
  uid		INT UNSIGNED	NOT NULL,
  comment	VARCHAR(255),
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
  INDEX rid (rid)
) ENGINE = MYISAM;

CREATE TABLE nessus
(
  uid           INT            NOT NULL,
  rid           VARCHAR(40)    NOT NULL,
  ip            VARCHAR(15)    NOT NULL,
  timestart     DATETIME,
  timeend       DATETIME,
  PRIMARY KEY (rid),
  INDEX ip (ip)
) ENGINE = MYISAM;

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
