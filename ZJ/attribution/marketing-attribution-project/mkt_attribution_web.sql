WITH preprocess_web AS (
    SELECT user_uuid,
        timestamp 'epoch' + CAST(created_timestamp AS bigint) / 1000 * INTERVAL '1 second' AS created_ts,
        'web'::varchar(128) AS data_source,
        'web_signup'::varchar(128) AS activity_kind,
        signup_metadata AS web_signup_metadata,
        -- utm_* and plain * fields were used randomly by marketing in the past. In the future, we will use only the utm_* variants.
        COALESCE(
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_source'),
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'source')
        ) AS utm_source,
        COALESCE(
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_medium'),
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'medium')
        ) AS utm_medium,
        COALESCE(
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_campaign'),
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'campaign')
        ) AS utm_campaign,
        COALESCE(
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_content'),
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'adgroup')
        ) AS utm_content,
        COALESCE(
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_term'),
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'creative')
        ) AS utm_term,
        JSON_EXTRACT_PATH_TEXT(signup_metadata, 'first_ref') AS first_ref,
        -- for attribution modelling
        JSON_ARRAY_LENGTH(utm_source, TRUE) AS json_array_length_utm_source,
        JSON_ARRAY_LENGTH(utm_medium, TRUE) AS json_array_length_utm_medium,
        JSON_ARRAY_LENGTH(utm_campaign, TRUE) AS json_array_length_utm_campaign,
        JSON_ARRAY_LENGTH(utm_content, TRUE) AS json_array_length_utm_content,
        JSON_ARRAY_LENGTH(utm_term, TRUE) AS json_array_length_utm_term,
        JSON_ARRAY_LENGTH(first_ref, TRUE) AS json_array_length_first_ref
    FROM dl_live_core.etl_live_core_public_employee
    WHERE (
            TIMESTAMP 'epoch' + CAST(created_timestamp AS BIGINT) / 1000 * interval '1 second'
        )::DATE = current_date - interval '1' day
        AND NULLIF(
            JSON_EXTRACT_PATH_TEXT(signup_metadata, 'Signup Channel'),
            ''
        ) = 'WEB' -- exclude Zenjob internal testers
        AND test_account = false
)
SELECT user_uuid,
    NULL AS adid,
    created_ts AS created_at,
    data_source,
    activity_kind,
    data_source AS platform,
    --web_signup_metadata,
    --utm_channel,
    --channel,
    --channel_detail,                        
    CASE
        WHEN NVL(json_array_length_utm_source, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_source, json_array_length_utm_source - 1)
        ELSE utm_source
    END AS source,
    CASE
        WHEN NVL(json_array_length_utm_medium, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_medium, json_array_length_utm_medium - 1)
        ELSE utm_medium
    END AS medium,
    CASE
        WHEN NVL(json_array_length_utm_campaign, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_campaign, json_array_length_utm_campaign - 1)
        ELSE utm_campaign
    END AS campaign,
    CASE
        WHEN NVL(json_array_length_utm_content, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_content, json_array_length_utm_content - 1)
        ELSE utm_content
    END AS content,
    CASE
        WHEN NVL(json_array_length_utm_term, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_term, json_array_length_utm_term - 1)
        ELSE utm_term
    END AS term,
    CASE
        WHEN NVL(json_array_length_first_ref, 0) > 1 THEN NULLIF(
            JSON_EXTRACT_ARRAY_ELEMENT_TEXT(first_ref, json_array_length_first_ref -1),
            'null'
        )
        ELSE first_ref
    END AS first_referer,
    -- Web is a first access point (Talents signing up on web have not engaged with our product before), so 'first' values are equal to last attribution details
    CASE
        WHEN NVL(json_array_length_utm_source, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_source, json_array_length_utm_source - 1)
        ELSE utm_source
    END AS first_source,
    CASE
        WHEN NVL(json_array_length_utm_medium, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_medium, json_array_length_utm_medium - 1)
        ELSE utm_medium
    END AS first_medium,
    CASE
        WHEN NVL(json_array_length_utm_campaign, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_campaign, json_array_length_utm_campaign - 1)
        ELSE utm_campaign
    END AS first_campaign,
    CASE
        WHEN NVL(json_array_length_utm_content, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_content, json_array_length_utm_content - 1)
        ELSE utm_content
    END AS first_content,
    CASE
        WHEN NVL(json_array_length_utm_term, 0) > 1 THEN JSON_EXTRACT_ARRAY_ELEMENT_TEXT(utm_term, json_array_length_utm_term - 1)
        ELSE utm_term
    END AS first_term,
    NULL AS fb_install_referrer
FROM preprocess_web