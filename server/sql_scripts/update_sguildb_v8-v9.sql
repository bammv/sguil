ALTER TABLE sessions ADD ip_proto TINYINT UNSIGNED;
UPDATE sessions SET ip_proto=6;
UPDATE version SET version="0.9", installed = now();
