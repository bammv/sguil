CREATE TABLE IF NOT EXISTS `autocat`
(
  autoid        INT UNSIGNED            NOT NULL AUTO_INCREMENT,
  erase         DATETIME,
  sensorname    VARCHAR(255),
  src_ip        VARCHAR(18),
  src_port      INT UNSIGNED,
  dst_ip        VARCHAR(18),
  dst_port      INT UNSIGNED,  
  ip_proto      TINYINT UNSIGNED,
  signature     VARCHAR(255),  
  status        SMALLINT UNSIGNED       NOT NULL,
  active        ENUM('Y','N') DEFAULT 'Y',
  timestamp     DATETIME NOT NULL,
  uid           INT UNSIGNED    NOT NULL,
  comment       VARCHAR(255),
  PRIMARY KEY (autoid)
) ENGINE = MYISAM;

UPDATE version SET version="0.14", installed = now();
