-- $Id: create_sancp_table.sql,v 1.1 2004/03/19 20:33:59 bamm Exp $

CREATE TABLE sancp
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

