CREATE TABLE IF NOT EXISTS `pads` (
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
);

ALTER TABLE sensor ADD COLUMN (
  agent_type    VARCHAR(40),
  net_name      VARCHAR(40)
);

ALTER TABLE history ADD INDEX (sid), ADD INDEX (cid);

UPDATE version SET version="0.12", installed = now();
