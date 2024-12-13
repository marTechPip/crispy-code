-- mkt_attribution_log gets all attribution details in the last year logged under install, reattribution and events. 
-- Although attribution details only change on install and reattributions, I also need events as otherwise there are too many gaps when mapping later funnel events to attribution details
SELECT 
    user_uuid,
    adid,
    created_at_dt,
    os_name as platform,
    -- Facebook attribution details come in the fb_install_referrer field. Only available for Android. 
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND os_name = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'publisher_platform')
        WHEN network_name = 'nan' THEN NULL
        ELSE network_name
    END AS source,
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND os_name = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_group_name')
        WHEN campaign_name = 'nan' THEN NULL
        ELSE campaign_name
    END AS campaign,
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND os_name = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_name')
        WHEN adgroup_name = 'nan' THEN NULL
        ELSE adgroup_name
    END AS content,
    CASE
        WHEN network_name ILIKE 'unattributed'
        AND os_name = 'android'
        AND fb_install_referrer IS NOT NULL
        AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'adgroup_name')
        WHEN creative_name = 'nan' THEN NULL
        ELSE creative_name
    END AS term,
    --get first tracker values from first_tracker_name field. Delimited by ::
    CASE
        WHEN SPLIT_PART(first_tracker_name, '::', 1) = '' THEN NULL
        ELSE SPLIT_PART(first_tracker_name, '::', 1)
    END AS first_source,
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
    fb_install_referrer,
    --get the attribution rank by both adid and uuid separately as later tables need to map variously on each identifier
    ROW_NUMBER() OVER (PARTITION BY adid ORDER BY created_at_dt DESC) AS attribution_rank_adid,
    ROW_NUMBER() OVER (PARTITION BY user_uuid, adid ORDER BY created_at_dt DESC) AS attribution_rank_uuid
FROM dds.sd__adjust_data
WHERE activity_kind IN ('install', 'reattribution', 'event')
    AND created_at_dt >= current_date - interval '1' year
    
    
    
