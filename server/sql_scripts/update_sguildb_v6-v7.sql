ALTER TABLE event ADD last_uid INT UNSIGNED;
UPDATE version SET version="0.7", installed = now();
