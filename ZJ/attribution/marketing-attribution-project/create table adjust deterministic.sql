CREATE TABLE adhoc_data.adjust_deterministic AS
WITH preprocess_adjust AS (
    SELECT NULLIF(user_uuid, 'nan') AS user_uuid,
        adid,
        created_at_dt,
        activity_kind,
        event_name,
        os_name AS platform,
        tracker_name,
        fb_install_referrer,
        network_name,
        campaign_name,
        adgroup_name,
        creative_name,
        first_tracker_name
        FROM dds.sd__adjust_data
    WHERE created_at_dt::DATE >= current_date - interval '180' DAY
)
SELECT user_uuid,
    adid,
    created_at_dt as created_at,
    'adjust' AS data_source,
    activity_kind,
    NULL AS install_type,
    platform,
    --channel,
    --channel_detail,
    -- Facebook attribution details come in the fb_install_referrer field. Only available for Android. 
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND platform = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'publisher_platform')
        WHEN network_name = 'nan' THEN NULL
        ELSE network_name
    END AS source,
    NULL AS medium,
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND platform = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_group_name')
        WHEN campaign_name = 'nan' THEN NULL
        ELSE campaign_name
    END AS campaign,
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND platform = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_name')
        WHEN adgroup_name = 'nan' THEN NULL
        ELSE adgroup_name
    END AS content,
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND platform = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'adgroup_name')
        WHEN creative_name = 'nan' THEN NULL
        ELSE creative_name
    END AS term,
    NULL AS first_referer,
    --get first tracker values from first_tracker_name field. Delimited by ::
    CASE
        WHEN SPLIT_PART(first_tracker_name, '::', 1) = '' THEN NULL
        ELSE SPLIT_PART(first_tracker_name, '::', 1)
    END AS first_source,
    NULL AS first_medium,
    CASE
        WHEN SPLIT_PART(first_tracker_name, '::', 2) = '' THEN NULL
        ELSE SPLIT_PART(first_tracker_name, '::', 2)
    END AS first_campaign,
    CASE
        WHEN SPLIT_PART(first_tracker_name, '::', 3) = '' THEN NULL
        ELSE SPLIT_PART(first_tracker_name, '::', 3)
    END AS first_content,
    CASE
        WHEN SPLIT_PART(first_tracker_name, '::', 4) = '' THEN NULL
        ELSE SPLIT_PART(first_tracker_name, '::', 4)
    END AS first_term,
    fb_install_referrer
FROM preprocess_adjust
WHERE (
        activity_kind IN ('install', 'reattribution')
        OR (
            activity_kind = 'event'
            AND event_name = 'signup'
        )
    )

