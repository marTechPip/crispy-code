drop table if exists adhoc_data.adjust_deterministic

create table adhoc_data.adjust_deterministic as 
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
    att.source,
    NULL as medium,
    att.campaign,
    att.content,
    att.term,
    NULL as first_referer,
    att.first_source,
    NULL as first_medium,
    att.first_campaign,
    att.first_content,
    att.first_term,
    att.fb_install_referrer
FROM preprocess_adjust adj
    LEFT JOIN adhoc_data.attribution_log att ON adj.adid = att.adid AND adj.created_at_dt >= att.created_at_dt AND att.attribution_rank_adid = 1
    left join adhoc_data.adid_uuid_mapping aum on adj.adid = aum.adid AND aum.mapping_rank_adid = 1
WHERE (
        activity_kind = 'install'
        OR (
            activity_kind = 'event'
            AND event_name = 'signup'
        )
    )