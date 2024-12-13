
WITH preprocess_adjust AS (
    SELECT NULLIF(user_uuid, 'nan') AS user_uuid,
        adid,
        created_at_dt,
        activity_kind,
        event_name,
        os_name AS platform
    FROM dds.sd__adjust_data
    WHERE created_at_dt::DATE >= current_date - interval '180' day
)
SELECT 
	aum.user_uuid,
    adj.adid,
    adj.created_at_dt as created_at,
    'adjust' AS data_source,
    CASE
		WHEN adj.activity_kind IN ('install', 'reattribution') THEN adj.activity_kind
		ELSE event_name
		END AS touchpoint,
    NULL AS install_type,
    adj.platform,
    log.source,
    NULL as medium,
    log.campaign,
    log.content,
    log.term,
    NULL as first_referer,
    log.first_source,
    NULL as first_medium,
    log.first_campaign,
    log.first_content,
    log.first_term,
    log.fb_install_referrer
FROM preprocess_adjust adj
    --map attribution details to the most recent ones in the log table, which were logged AT or BEFORE the touchpoint
    LEFT JOIN adhoc_data.mkt_attribution_log log ON adj.adid = log.adid AND adj.created_at_dt >= log.created_at_dt AND log.attribution_rank_adid = 1
    left join adhoc_data.mkt_attribution_adid_uuid_mapping aum on adj.adid = aum.adid AND aum.mapping_rank_adid = 1
WHERE (
        activity_kind = 'install'
        OR (
            activity_kind = 'event'
            AND event_name = 'signup'
        )
    )