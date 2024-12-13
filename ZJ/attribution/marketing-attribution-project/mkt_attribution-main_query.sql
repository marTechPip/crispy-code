-- separate id mapping: uuid_adid_mapping
-- separate adjust_deterministic
-- Add SKAN mappings ad-network ids to the mapping gsheet and join - skan_mapping
-- put skan data in it's own query
-- remove the unnecessary NULLIF
-- full reload. Changes date logic
-- can we merge adjust_deterministic and the last attribution details
-- make web its separate table and copy the existing touchpoints_web
-- onlz thing left in main table is the funnel_events

-- use chatgpt for the dbt docs
-- copy andreas stuff




-- Mkt_attribution table. Important note: SKAN data may duplicate data obtained from the Adjust table. 
-- De-duplicate attribution data on iOS by selecting only one data source for iOS self-attributing networks
-- This id_mapping can be saved as a separate table to make the main query more efficient
with id_mapping AS (
	SELECT distinct adid,
		user_uuid,
		created_at_dt
	FROM dds.sd__adjust_data sad
	WHERE user_uuid notnull -- NULL values are saved AS 'nan' IN the raw Adjust table 
		AND user_uuid != 'nan' -- One user UUID can be related to multiple ADIDs (Adjust Id), like WHEN the Talent logs IN to their account on a new device. This window function gets the most recent UUID<>ADID association. 
		QUALIFY ROW_NUMBER() OVER (
			PARTITION BY adid
			ORDER BY created_at_dt DESC
		) = 1
),
adjust_deterministic AS (
	SELECT CASE
			WHEN user_uuid = 'nan'
			OR user_uuid isnull THEN NULL
			ELSE user_uuid
		END AS user_uuid,
		adid,
		created_at_dt,
		'adjust' AS data_source,
		activity_kind,
		NULL AS install_type,
		event_name,
		os_name AS platform,
		tracker_name,
		fb_install_referrer,
		network_name,
		NULLIF(JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'publisher_platform'),'') AS fb_publisher_platform,
		-- Facebook attribution details come in the fb_install_referrer field. Only available for Android. 
		CASE
			WHEN network_name ILIKE 'unattributed'
			AND os_name = 'android'
			AND fb_install_referrer IS NOT NULL
			AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'publisher_platform')
			WHEN network_name = 'nan' THEN NULL
			ELSE network_name
		END AS source,
		NULL AS medium,
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
		END AS first_term
	FROM dds.sd__adjust_data
	WHERE (
			activity_kind = 'install'
			OR activity_kind = 'reattribution'
			OR (
				activity_kind = 'event'
				AND event_name = 'signup'
			)
		) -- the whole query gets rows from the last calendar day
		AND created_at_dt::DATE = current_date - interval '1' day
),
skan AS (
	SELECT -- User identifiers will always be NULL. We never get user level data from SKAN
		NULL AS user_uuid,
		NULL AS adid,
		TIMESTAMP 'epoch' + json_extract_path_text(sk_payload, 'timestamp')::INTEGER * interval '1 second' AS created_at,
		'skan' AS data_source,
		-- At the moment, installs are mapped to conversion value 0, signups are mapped to conversion value 2, and onboardeds to 32
		CASE
			WHEN activity_kind = 'sk_install' THEN 'sk_install'
			WHEN activity_kind = 'sk_event' THEN CASE
				WHEN NULLIF(json_extract_path_text(sk_payload,'conversion-value'),'') = 2 THEN 'sk_signup'
				WHEN NULLIF(json_extract_path_text(sk_payload,'conversion-value'),'') = 32 THEN 'sk_onboarded'
				ELSE 'unknown'
			END
		END AS activity_kind,
		-- Unsure how redownloads are tracked, so don't put much faith IN this field being accurate
		CASE
			WHEN NULLIF(
				json_extract_path_text(sk_payload, 'redownload'),
				''
			) = 'true' THEN 'redownload'
			ELSE 'new_install'
		END AS install_type,
		-- SKAN data is always iOS
		'ios' AS platform,
		-- IMPORTANT: Need to update these network names/IDs if we add more channels and update the mapping table. Also update the network names 27 lines down. 
		CASE
			WHEN sk_network_id = 'mj797d8u6f.skadnetwork' THEN 'tiktok ads'
			WHEN sk_network_id = 'eqhxz8m8av.skadnetwork' THEN 'google ads aci'
			WHEN sk_network_id = 'facebook.skadnetwork' THEN 'facebook ads'
		END AS source,
		NULL AS medium,
		NULLIF(
			json_extract_path_text(sk_payload, 'adjust-campaign'),
			''
		) AS campaign,
		NULLIF(
			json_extract_path_text(sk_payload, 'adjust-adgroup'),
			''
		) AS adgroup,
		NULLIF(
			json_extract_path_text(sk_payload, 'adjust-creative'),
			''
		) AS creative,
		NULL AS first_referer,
		-- If the user is NOT redownloading the app ie. is a new user, the current tracker details can also be assigned as the first values. 
		-- If the user is redownloading the app, we must assign the first values as unknown. We cannot know their true first tracker details. 
		-- In any case, the redownload value should be treated with caution, as I'm unsure how Apple assigns it.
		CASE
			WHEN NULLIF(
				json_extract_path_text(sk_payload, 'redownload'),
				''
			) = 'false' THEN CASE
				WHEN sk_network_id = 'mj797d8u6f.skadnetwork' THEN 'tiktok ads'
				WHEN sk_network_id = 'eqhxz8m8av.skadnetwork' THEN 'google ads aci'
				WHEN sk_network_id = 'facebook.skadnetwork' THEN 'facebook ads'
				ELSE 'unknown'
			END
			ELSE 'unknown'
		END AS first_source,
		NULL AS first_medium,
		CASE
			WHEN NULLIF(
				json_extract_path_text(sk_payload, 'redownload'),
				''
			) = 'false' THEN NULLIF(
				json_extract_path_text(sk_payload, 'adjust-campaign'),
				''
			)
			ELSE 'unknown'
		END AS first_campaign,
		CASE
			WHEN NULLIF(
				json_extract_path_text(sk_payload, 'redownload'),
				''
			) = 'false' THEN NULLIF(
				json_extract_path_text(sk_payload, 'adjust-adgroup'),
				''
			)
			ELSE 'unknown'
		END AS first_content,
		CASE
			WHEN NULLIF(
				json_extract_path_text(sk_payload, 'redownload'),
				''
			) = 'false' THEN NULLIF(
				json_extract_path_text(sk_payload, 'adjust-creative'),
				''
			)
			ELSE 'unknown'
		END AS first_term,
		NULL AS fb_install_referrer
	FROM dds.sd__adjust_data
	WHERE (
			(
				activity_kind = 'sk_event'
				AND NULLIF(json_extract_path_text(sk_payload,'conversion-value'),'') IN (2, 32)
			)
			OR (
				activity_kind = 'sk_install'
				AND NULLIF(json_extract_path_text(sk_payload,'conversion-value'),'') = 0
			)
		) 
		AND (
			TIMESTAMP 'epoch' + CAST(
				json_extract_path_text(sk_payload, 'timestamp') AS INTEGER
			) * interval '1 second'
		)::DATE = current_date - interval '1' day
),
funnel_events AS (
	SELECT talent_id,
		'onboarded' AS activity_kind,
		onboarded_dt AS created_at
	FROM cds.fact_talent_funnel
	WHERE onboarded_dt = current_date - interval '1' day
	UNION ALL
	SELECT talent_id,
		'first_shift_worked' AS activity_kind,
		first_worked_shift_dt AS created_at
	FROM cds.fact_talent_funnel
	WHERE first_worked_shift_dt = current_date - interval '1' day
),
attribution_details AS (
	-- Get most recent attribution details from raw Adjust table and map those to the user_uuid
	SELECT user_uuid,
		adid,
		created_at_dt,
		os_name,
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
			ELSE TRIM(SPLIT_PART(campaign_name, ' ', 1))
		END AS campaign,
		CASE
			WHEN network_name ILIKE 'unattributed'
			AND os_name = 'android'
			AND fb_install_referrer IS NOT NULL
			AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_name')
			WHEN adgroup_name = 'nan' THEN NULL
			ELSE TRIM(SPLIT_PART(adgroup_name, ' ', 1))
		END AS content,
		CASE
			WHEN network_name ILIKE 'unattributed'
			AND os_name = 'android'
			AND fb_install_referrer IS NOT NULL
			AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'adgroup_name')
			WHEN creative_name = 'nan' THEN NULL
			ELSE creative_name
		END AS term,
		fb_install_referrer,
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
		END AS first_term
	FROM dds.sd__adjust_data 
	WHERE user_uuid notnull
		AND user_uuid != 'nan'
		QUALIFY ROW_NUMBER() OVER (
			PARTITION BY user_uuid
			ORDER BY created_at_dt DESC
		) = 1
),
web AS (
	SELECT distinct user_uuid,
		NULL AS adid,
		TIMESTAMP 'epoch' + CAST(created_timestamp AS BIGINT) / 1000 * interval '1 second' AS created_ts,
		'web' AS data_source,
		'web_signup' AS activity_kind,
		NULL AS install_type,
		'web' AS platform,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_source'),
			''
		) AS source,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_medium'),
			''
		) AS medium,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_campaign'),
			''
		) AS campaign,
		NULLIF(
			jSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_content'),
			''
		) AS content,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_term'),
			''
		) AS term,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'first_ref'),
			''
		) AS first_referer,
		-- As web signup is a talent entry point, the 'first_' values are the same as the current ones
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_source'),
			''
		) AS first_source,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_medium'),
			''
		) AS first_medium,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_campaign'),
			''
		) AS first_campaign,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_content'),
			''
		) AS first_content,
		NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'utm_term'),
			''
		) AS first_term,
		NULL AS fb_install_referrer
	FROM dl_live_core.etl_live_core_public_employee
	WHERE (
			TIMESTAMP 'epoch' + CAST(created_timestamp AS BIGINT) / 1000 * interval '1 second'
		)::DATE = current_date - interval '1' day
		AND NULLIF(
			JSON_EXTRACT_PATH_TEXT(signup_metadata, 'Signup Channel'),
			''
		) not IN ('IOS', 'ANDROID')
		-- exclude Zenjob internal testers
		AND test_account = false
),
main_table AS (
	SELECT CASE
			WHEN adjust_deterministic.user_uuid != NULL THEN adjust_deterministic.user_uuid
			ELSE id_mapping.user_uuid
		END AS user_uuid,
		adjust_deterministic.adid,
		adjust_deterministic.created_at_dt,
		adjust_deterministic.data_source,
		CASE
			WHEN adjust_deterministic.activity_kind IN ('install', 'reattribution') THEN adjust_deterministic.activity_kind
			ELSE event_name
		END AS touchpoint,
		adjust_deterministic.install_type,
		adjust_deterministic.platform,
		adjust_deterministic.source,
		adjust_deterministic.medium,
		adjust_deterministic.campaign,
		adjust_deterministic.content,
		adjust_deterministic.term,
		adjust_deterministic.first_referer,
		adjust_deterministic.first_source,
		adjust_deterministic.first_medium,
		adjust_deterministic.first_campaign,
		adjust_deterministic.first_content,
		adjust_deterministic.first_term,
		adjust_deterministic.fb_install_referrer
	FROM adjust_deterministic
		LEFT JOIN id_mapping on adjust_deterministic.adid = id_mapping.adid
	UNION ALL
	SELECT skan.user_uuid,
		skan.adid,
		skan.created_at,
		skan.data_source,
		skan.activity_kind,
		skan.install_type,
		skan.platform,
		skan.source,
		skan.medium,
		skan.campaign,
		skan.adgroup,
		skan.creative,
		skan.first_referer,
		skan.first_source,
		skan.first_medium,
		skan.first_campaign,
		skan.first_content,
		skan.first_term,
		skan.fb_install_referrer
	FROM skan
	UNION ALL
	SELECT talent.user_uuid,
		attribution_details.adid,
		funnel_events.created_at::TIMESTAMP,
		'talent_funnel' AS data_source,
		funnel_events.activity_kind,
		NULL AS install_type,
		attribution_details.os_name AS platform,
		attribution_details.source,
		NULL AS medium,
		attribution_details.campaign,
		attribution_details.content,
		attribution_details.term,
		NULL AS first_referer,
		attribution_details.first_source,
		NULL AS first_medium,
		attribution_details.first_campaign,
		attribution_details.first_content,
		attribution_details.first_term,
		fb_install_referrer
	FROM funnel_events
		JOIN cds.dim_talent talent on funnel_events.talent_id = talent.talent_id
		JOIN attribution_details on talent.user_uuid = attribution_details.user_uuid
	UNION ALL
	SELECT web.user_uuid,
		web.adid,
		web.created_ts,
		web.data_source,
		web.activity_kind,
		web.install_type,
		web.platform,
		web.source,
		web.medium,
		web.campaign,
		web.content,
		web.term,
		web.first_referer,
		web.first_source,
		web.first_medium,
		web.first_campaign,
		web.first_content,
		web.first_term,
		web.fb_install_referrer
	FROM web
)
SELECT distinct main_table.user_uuid,
	main_table.adid,
	main_table.created_at_dt,
	main_table.data_source,
	main_table.touchpoint,
	main_table.install_type,
	main_table.platform,
	NVL(channel_map.channel, 'Unknown/organic') as channel,
	NVL(channel_map.channel_detail, 'Unknown/organic') as channel_detail,
	main_table.source,
	main_table.medium,
	main_table.campaign,
	main_table.content,
	main_table.term,
	NVL(first_channel_map.channel, 'Unknown/organic') as first_channel,
	NVL(first_channel_map.channel_detail,'Unknown/organic') as first_channel_detail,
	main_table.first_source,
	main_table.first_medium,
	main_table.first_campaign,
	main_table.first_content,
	main_table.first_term,
	main_table.first_referer,
	main_table.fb_install_referrer
FROM main_table 
	-- With the first join, we map the *current* attribution details to a channel/channel_detail
	LEFT JOIN channel_mapping channel_map on CASE
		-- Separate mappings for web and app
		WHEN main_table.platform = 'web' THEN CASE
			-- exception for Organic Search
			WHEN main_table.source is NULL
			AND main_table.first_referer notnull THEN main_table.platform = channel_map.platform
			AND main_table.first_referer ILIKE channel_map.first_referer 
			-- exception for Google Paid search 
			WHEN main_table.source = 'google-search' THEN main_table.platform = channel_map.platform
			AND main_table.source = channel_map.network_name_pattern
			AND main_table.campaign ILIKE ('%' + channel_map.campaign_name_pattern + '%') 
			-- exception for Meta/Tiktok paid and organic campaigns 
			WHEN main_table.source IN ('meta', 'tiktok') THEN main_table.platform = channel_map.platform
			AND main_table.source = channel_map.network_name_pattern
			AND main_table.medium = channel_map.medium_name_pattern 
			-- Everything else matches on network name. For future channel mappings, we should ensure that network names are distinct, so we can use them. 
			ELSE lower(main_table.platform) = lower(channel_map.platform)
			AND lower(main_table.source) = lower(channel_map.network_name_pattern)
		END
		-- Mobile mappings
		ELSE 
		-- Exception for Facebook and Instagram
		CASE
			WHEN (
				lower(main_table.source) ILIKE 'unattributed'
				AND main_table.fb_install_referrer IS NOT NULL
				AND main_table.fb_install_referrer != 'nan'
			) THEN main_table.platform = channel_map.platform
			AND lower(main_table.source) ILIKE lower(
				channel_map.fb_install_referrer_publisher_platform_pattern
			) 
			-- Exception for Google Organic Search
			WHEN (
				lower(main_table.source) ILIKE '%organic search%'
				AND lower(main_table.content) ILIKE '%google%'
			) THEN main_table.platform = channel_map.platform
			AND lower(main_table.source) ILIKE lower('%' + channel_map.network_name_pattern + '%')
			AND lower(main_table.content) ILIKE lower('%' + channel_map.adgroup_name_pattern + '%') 
			-- Everything else matches on network name
			-- Match platform on *mobile* string. Dynamic platform values are either ios or android, and so don't match with the mapping table
			ELSE 'mobile' = lower(channel_map.platform) 
			AND lower(main_table.source) ILIKE lower(channel_map.network_name_pattern)
		END
	END 
	-- With the second join, we map the *first* attribution details to a channel/channel_detail
	LEFT JOIN channel_mapping first_channel_map on CASE
		WHEN main_table.platform = 'web' THEN CASE
			-- exception for Organic Search
			WHEN main_table.first_source is NULL
			AND main_table.first_referer notnull THEN main_table.platform = first_channel_map.platform
			AND main_table.first_referer ILIKE first_channel_map.first_referer 
			-- exception for Google Paid search 
			WHEN main_table.first_source = 'google-search' THEN main_table.platform = first_channel_map.platform
			AND main_table.first_source = first_channel_map.network_name_pattern
			AND main_table.first_campaign ILIKE (
				'%' + first_channel_map.campaign_name_pattern + '%'
			) -- exception for Meta/Tiktok paid and organic campaigns 
			WHEN main_table.first_source IN ('meta', 'tiktok') THEN main_table.platform = first_channel_map.platform
			AND main_table.first_source = first_channel_map.network_name_pattern
			AND main_table.first_medium = first_channel_map.medium_name_pattern
			ELSE main_table.platform = first_channel_map.platform
			AND main_table.first_source = first_channel_map.network_name_pattern
		END
		-- Mobile mappings
		ELSE 
		-- Exception for Facebook and Instagram
		CASE
			WHEN (
				lower(main_table.first_source) ILIKE 'unattributed'
				AND main_table.fb_install_referrer IS NOT NULL
				AND main_table.fb_install_referrer != 'nan'
			) THEN main_table.platform = first_channel_map.platform
			AND lower(main_table.first_source) ILIKE lower(
				first_channel_map.fb_install_referrer_publisher_platform_pattern
			) 
			-- Exception for Google Organic Search
			WHEN (
				lower(main_table.first_source) ILIKE '%organic search%'
				AND lower(main_table.first_content) ILIKE '%google%'
			) THEN main_table.platform = first_channel_map.platform
			AND lower(main_table.first_source) ILIKE lower(
				'%' + first_channel_map.network_name_pattern + '%'
			)
			AND lower(main_table.first_content) ILIKE lower(
				'%' + first_channel_map.adgroup_name_pattern + '%'
			) 
			-- everything else matches on network name
			ELSE 'mobile' = first_channel_map.platform 
			AND lower(main_table.first_source) ILIKE lower(first_channel_map.network_name_pattern)
		END
	END
ORDER BY main_table.created_at_dt DESC