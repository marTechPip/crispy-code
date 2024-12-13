-- mkt attribution adid AND uuid mapping
WITH ranked_mapping AS (
	SELECT
		adid,
		user_uuid,
		created_at_dt
	FROM
		dds.sd__adjust_data sad
	WHERE
		user_uuid notnull -- NULL values are saved AS 'nan' IN the raw Adjust table 
		AND user_uuid != 'nan' -- One user UUID can be related to multiple ADIDs (Adjust Id), like WHEN the Talent logs IN to their account on a new device. 
		-- This window function gets the most recent UUID<>ADID ASsociation. 
		QUALIFY ROW_NUMBER() OVER (
			PARTITION_BY user_uuid,
			adid
			ORDER BY
				created_at_dt desc
		) = 1 -- Only get records in the lASt year
		AND created_at_dt >= current_date - interval '1' year
)
SELECT
	adid,
	user_uuid,
	created_at_dt,
	-- AS both uuid AND adid can be mapped to multiple values, we need to rank the instances to get the most recent one
	ROW_NUMBER() OVER (
		PARTITION_BY adid
		ORDER BY
			created_at_dt desc
	) AS mapping_rank_adid,
	ROW_NUMBER() OVER (
		PARTITION_BY user_uuid
		ORDER BY
			created_at_dt desc
	) AS mapping_rank_uuid
FROM
	ranked_mapping