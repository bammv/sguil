ALTER TABLE event ADD signature_gen INT UNSIGNED NOT NULL;
UPDATE version SET version="0.8", installed = now();
