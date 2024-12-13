
WITH preprocess_skan AS (
    SELECT -- User identifiers will always be NULL. We never get user level data from SKAN
        NULL AS user_uuid,
        NULL AS adid,
        TIMESTAMP 'epoch' + json_extract_path_text(sk_payload, 'timestamp')::INTEGER * interval '1 second' AS created_at,
        'skan' AS data_source,
        -- SKAN data is always iOS
        'ios' AS platform,
        activity_kind,
        sk_network_id,
        json_extract_path_text(sk_payload, 'conversion-value') AS conversion_value,
        json_extract_path_text(sk_payload, 'redownload') AS redownload,
        json_extract_path_text(sk_payload, 'adjust-campaign') AS campaign,
        json_extract_path_text(sk_payload, 'adjust-adgroup') AS adgroup,
        json_extract_path_text(sk_payload, 'adjust-creative') AS creative,
        NULL AS first_referer,
        NULL AS fb_install_referrer
    FROM dds.sd__adjust_data ad
    WHERE activity_kind in ('sk_event', 'sk_install')
        AND CASE
            WHEN json_extract_path_text(sk_payload, 'timestamp') = 'nan' THEN NULL
            ELSE (
                TIMESTAMP 'epoch' + CAST(
                    json_extract_path_text(sk_payload, 'timestamp') AS INTEGER
                ) * interval '1 second'
            )::DATE
        END >= current_date - INTERVAL '180' DAY
)
SELECT user_uuid,
    adid,
    created_at,
    data_source,
    -- At the moment, installs are mapped to conversion value 0, signups are mapped to conversion value 2, and onboardeds to 32
    CASE
        WHEN activity_kind = 'sk_install' THEN 'sk_install'
        WHEN activity_kind = 'sk_event'
        AND conversion_value = 2 THEN 'sk_signup'
        WHEN activity_kind = 'sk_event'
        AND conversion_value = 32 THEN 'sk_onboarded'
        ELSE 'unknown'
    END AS activity_kind,
    -- Unsure how redownloads are tracked, so don't put much faith IN this field being accurate
    CASE
        WHEN redownload = 'true' THEN 'redownload'
        ELSE 'new_install'
    END AS install_type,
    --channel,
    --channel_detail,
    nm.sk_network_name AS source,
    NULL AS medium,
    campaign,
    adgroup,
    creative,
    first_referer,
    -- If the user is NOT redownloading the app ie. is a new user, the current tracker details can also be assigned as the first values. 
    -- If the user is redownloading the app, we must assign the first values as unknown. We cannot know their true first tracker details. 
    -- In any case, the redownload value should be treated with caution, as I'm unsure how Apple assigns it.
    CASE
        WHEN redownload = 'false' THEN nm.sk_network_name
        ELSE 'unknown'
    END AS first_source,
    NULL AS first_medium,
    CASE
        WHEN redownload = 'false' THEN campaign
        ELSE 'unknown'
    END AS first_campaign,
    CASE
        WHEN redownload = 'false' THEN adgroup
        ELSE 'unknown'
    END AS first_content,
    CASE
        WHEN redownload = 'false' THEN creative
        ELSE 'unknown'
    END AS first_term,
    fb_install_referrer
FROM preprocess_skan ps
    LEFT JOIN sd_stage.sd__gsheets__marketing__skan_network_mapping nm ON ps.sk_network_id = nm.sk_network_id
WHERE conversion_value IN (2, 32)