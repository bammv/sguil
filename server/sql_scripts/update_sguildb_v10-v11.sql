ALTER TABLE event ADD COLUMN 
(
  unified_event_id 	INT UNSIGNED,
  unified_event_ref	INT UNSIGNED,
  unified_ref_time	DATETIME
);
UPDATE version SET version="0.11", installed = now();
