CREATE TABLE sessions_tmp (
  sid           INT UNSIGNED NOT NULL,
  xid           BIGINT UNSIGNED NOT NULL,
  start_time    datetime NOT NULL,
  end_time      datetime NOT NULL,
  src_ip        INT UNSIGNED NOT NULL,
  dst_ip        INT UNSIGNED NOT NULL,
  src_port      INT UNSIGNED NOT NULL,
  dst_port      INT UNSIGNED NOT NULL,
  ip_proto      TINYINT UNSIGNED NOT NULL,
  src_pckts     BIGINT UNSIGNED NOT NULL,
  dst_pckts     BIGINT UNSIGNED NOT NULL,
  src_bytes     BIGINT UNSIGNED NOT NULL,
  dst_bytes     BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (sid,xid),
  INDEX begin (start_time),
  INDEX end (end_time),
  INDEX server (src_ip),
  INDEX client (dst_ip),
  INDEX sport (src_port),
  INDEX cport (dst_port));
INSERT INTO sessions_tmp SELECT sid, xid, start_time, end_time, src_ip, dst_ip, src_port, dst_port, 6, src_pckts, dst_pckts, src_bytes, dst_bytes FROM sessions;
DROP TABLE sessions;
RENAME TABLE sessions_tmp TO sessions;
UPDATE version SET version="0.9", installed = now();
