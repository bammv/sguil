ALTER TABLE user_info ADD COLUMN (
  password      VARCHAR(42)
);

ALTER TABLE user_info MODIFY COLUMN last_login datetime;

UPDATE version SET version="0.13", installed = now();
