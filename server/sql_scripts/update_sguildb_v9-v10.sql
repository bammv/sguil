CREATE TABLE IF NOT EXISTS nessus_data 
(
  rid           VARCHAR(40)	NOT NULL,
  port          VARCHAR(40),
  nessus_id     INT UNSIGNED,
  level	        VARCHAR(20),
  description		TEXT,
  INDEX rid (rid));

CREATE TABLE IF NOT EXISTS nessus 
(
  uid           INT            NOT NULL,
  rid           VARCHAR(40)    NOT NULL,
  ip            VARCHAR(15)    NOT NULL,
  timestart     DATETIME,
  timeend       DATETIME,
  PRIMARY KEY (rid),
  INDEX ip (ip));

CREATE TABLE IF NOT EXISTS sancp 
(
  sid		INT UNSIGNED	NOT NULL,
  sancpid	BIGINT UNSIGNED	NOT NULL,
  start_time	DATETIME	NOT NULL,
  end_time	DATETIME	NOT NULL,
  duration	INT UNSIGNED	NOT NULL,
  ip_proto	TINYINT UNSIGNED	NOT NULL,
  src_ip	INT UNSIGNED,
  src_port	SMALLINT UNSIGNED,
  dst_ip	INT UNSIGNED,
  dst_port	SMALLINT UNSIGNED,
  src_pkts	INT UNSIGNED	NOT NULL,
  src_bytes	INT UNSIGNED	NOT NULL,
  dst_pkts	INT UNSIGNED	NOT NULL,
  dst_bytes	INT UNSIGNED	NOT NULL,
  src_flags	TINYINT UNSIGNED	NOT NULL,
  dst_flags	TINYINT UNSIGNED	NOT NULL,
  PRIMARY KEY (sid,sancpid),
  INDEX src_ip (src_ip),
  INDEX dst_ip (dst_ip),
  INDEX dst_port (dst_port),
  INDEX src_port (src_port),
  INDEX start_time (start_time)
);

ALTER TABLE status ADD long_desc VARCHAR(255);

UPDATE status set long_desc="Real Time Event" WHERE status_id=0;
UPDATE status set long_desc="No Further Action Required" WHERE status_id=1;
UPDATE status set long_desc="Escalated" WHERE status_id=2;
UPDATE status set long_desc="Unauthorized Root Access" WHERE status_id=11;
UPDATE status set long_desc="Unauthorized User Access" WHERE status_id=12;
UPDATE status set long_desc="Attempted Unauthorized Access" WHERE status_id=13;
UPDATE status set long_desc="Successful Denial of Service Attack" WHERE status_id=14;
UPDATE status set long_desc="Poor Security Practice or Policy Violation" WHERE status_id=15;
UPDATE status set long_desc="Reconnaissance/Probes/Scans" WHERE status_id=16;
UPDATE status set long_desc="Virus Infection" WHERE status_id=17;

UPDATE version SET version="0.10", installed = now();
