CREATE TABLE nessus_data
(
  rid           VARCHAR(40)	NOT NULL,
  port          VARCHAR(40),
  nessus_id     INT UNSIGNED,
  level	        VARCHAR(20),
  desc		TEXT,
  INDEX rid (rid));
CREATE TABLE nessus
(
  uid           INT            NOT NULL,
  rid           VARCHAR(40)    NOT NULL,
  ip            VARCHAR(15)    NOT NULL,
  timestart     DATETIME,
  timeend       DATETIME,
  PRIMARY KEY (rid),
  INDEX ip (ip));