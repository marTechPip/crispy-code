CREATE TABLE adhoc_data.adid_uuid_mapping AS 
SELECT distinct adid,
	user_uuid,
	created_at_dt
FROM dds.sd__adjust_data sad
WHERE user_uuid NOTNULL 
-- NULL values are saved AS 'nan' IN the raw Adjust table 
AND user_uuid != 'nan' 
-- One user UUID can be related to multiple ADIDs (Adjust Id), like WHEN the Talent logs IN to their account on a new device. This window function gets the most recent UUID<>ADID association. 
QUALIFY ROW_NUMBER() OVER (
	PARTITION BY adid
	ORDER BY created_at_dt DESC
) = 1
-- Only get records in the last year
AND created_at_dt >= current_date - INTERVAL '365' DAY
