CREATE TABLE history
(
  sid		INT UNSIGNED	NOT NULL,
  cid		INT UNSIGNED	NOT NULL,
  uid		INT UNSIGNED	NOT NULL,
  timestamp	DATETIME	NOT NULL,
  status	SMALLINT UNSIGNED	NOT NULL,
  comment	VARCHAR(255),
  INDEX log_time (timestamp)
);

CREATE TABLE user_info
(
  uid		INT UNSIGNED	NOT NULL AUTO_INCREMENT,
  username	VARCHAR(16)	NOT NULL,
  last_login	DATETIME	NOT NULL,
  PRIMARY KEY (uid)
);

ALTER TABLE event DROP INDEX src_abuse_record_id, DROP INDEX dst_abuse_record_id, DROP src_abuse_record_id, DROP dst_abuse_record_id;
UPDATE version SET version="0.6", installed = now();
