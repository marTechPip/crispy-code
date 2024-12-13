-- Mkt_attribution table. Important note: SKAN data may duplicate data obtained from the Adjust table. 
-- De-duplicate attribution data on iOS by selecting only one data source for iOS self-attributing networks
-- There are 4 data sources considered: Adjust raw table for deterministic data, Adjust raw table for SKAN, web signup form, and funnel events
-- ADID and UUID mappings and the log of attributions are saved AS separate tables
-- All data sources consider data from the lASt 6 months. If you want to change this, you must change in the individual data source table queries
WITH mkt_attribution_funnel_events AS (
	SELECT
		talent_id,
		'onboarded' AS activity_kind,
		onboarded_dt AS created_at
	FROM
		cds.fact_talent_funnel
	WHERE
		onboarded_dt = current_date - interval '180' day
	UNION
	ALL
	SELECT
		talent_id,
		'first_shift_worked' AS activity_kind,
		first_worked_shift_dt AS created_at
	FROM
		cds.fact_talent_funnel
	WHERE
		first_worked_shift_dt = current_date - interval '180' day
),
mkt_attribution_main AS (
	SELECT
		det.user_uuid,
		det.adid,
		det.created_at,
		det.data_source,
		det.touchpoint,
		det.install_type,
		det.platform,
		det.source,
		det.medium,
		det.campaign,
		det.content,
		det.term,
		det.first_referer,
		det.first_source,
		det.first_medium,
		det.first_campaign,
		det.first_content,
		det.first_term,
		det.fb_install_referrer
	FROM
		adhoc_data.mkt_attribution_deterministic det --Change this table in production
	UNION
	ALL
	SELECT
		skan.user_uuid,
		skan.adid,
		skan.created_at,
		skan.data_source,
		skan.activity_kind,
		skan.install_type,
		'ios' AS platform,
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
	FROM
		adhoc_data.mkt_attribution_skan skan --Change this table in production
	UNION
	ALL
	SELECT
		web.user_uuid,
		web.adid,
		web.created_at,
		web.data_source,
		web.activity_kind,
		NULL AS install_type,
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
	FROM
		adhoc_data.mkt_attribution_web web --Change this table in production
	UNION
	ALL
	SELECT
		tal.user_uuid,
		log.adid,
		fun.created_at :: TIMESTAMP,
		'talent_funnel' AS data_source,
		fun.activity_kind,
		NULL AS install_type,
		log.platform,
		log.source,
		NULL AS medium,
		log.campaign,
		log.content,
		log.term,
		NULL AS first_referer,
		log.first_source,
		NULL AS first_medium,
		log.first_campaign,
		log.first_content,
		log.first_term,
		log.fb_install_referrer
	FROM
		mkt_attribution_funnel_events fun
		JOIN cds.dim_talent tal ON fun.talent_id = tal.talent_id -- Must get most recent UUID -> ADID mapping, hence the mapping_rank_uuid condition
		LEFT JOIN adhoc_data.mkt_attribution_adid_uuid_mapping aum ON tal.user_uuid = aum.user_uuid
		AND aum.mapping_rank_uuid = 1 -- IN this case, we are mapping ADID to UUID, so we need to use attribution_rank_adid to get most recent mapping
		LEFT JOIN adhoc_data.mkt_attribution_log log ON aum.adid = log.adid
		AND fun.created_at :: TIMESTAMP >= log.created_at_dt
		AND log.attribution_rank_adid = 1
)
SELECT
	distinct mt.user_uuid,
	mt.adid,
	mt.created_at,
	mt.data_source,
	mt.touchpoint,
	mt.install_type,
	mt.platform,
	NVL(channel_map.channel, 'Unknown/organic') AS channel,
	NVL(channel_map.channel_detail, 'Unknown/organic') AS channel_detail,
	mt.source,
	mt.medium,
	mt.campaign,
	mt.content,
	mt.term,
	NVL(first_channel_map.channel, 'Unknown/organic') AS first_channel,
	NVL(first_channel_map.channel_detail,'Unknown/organic') AS first_channel_detail,
	mt.first_source,
	mt.first_medium,
	mt.first_campaign,
	mt.first_content,
	mt.first_term,
	mt.first_referer,
	mt.fb_install_referrer
FROM
	mkt_attribution_main mt -- With the first join, we map the *current* attribution details to a channel/channel_detail
	LEFT JOIN sd_stage.sd__gsheets__marketing__attribution_channel_mapping channel_map on CASE
		-- Separate mappings for web and app
		WHEN mt.platform = 'web' THEN CASE
			-- exception for Organic Search
			WHEN mt.source is NULL
			AND mt.first_referer notNULL THEN mt.platform = channel_map.platform
			AND mt.first_referer ILIKE channel_map.first_referer -- exception for Google Paid search 
			WHEN mt.source = 'google-search' THEN mt.platform = channel_map.platform
			AND mt.source = channel_map.network_name_pattern
			AND mt.campaign ILIKE ('%' + channel_map.campaign_name_pattern + '%') -- exception for Meta/Tiktok paid and organic campaigns 
			WHEN mt.source IN ('meta', 'tiktok') THEN mt.platform = channel_map.platform
			AND mt.source = channel_map.network_name_pattern
			AND mt.medium = channel_map.medium_name_pattern -- Everything else matches on network name. For future channel mappings, we should ensure that network names are distinct, so we can use them. 
			ELSE lower(mt.platform) = lower(channel_map.platform)
			AND lower(mt.source) = lower(channel_map.network_name_pattern)
		END -- Mobile mappings
		ELSE -- Exception for Facebook and Instagram
		CASE
			WHEN (
				lower(mt.source) ILIKE 'unattributed'
				AND mt.fb_install_referrer IS NOT NULL
				AND mt.fb_install_referrer != 'nan'
			) THEN mt.platform = channel_map.platform
			AND lower(mt.source) ILIKE lower(
				channel_map.fb_install_referrer_publisher_platform_pattern
			) -- Exception for Google Organic Search
			WHEN (
				lower(mt.source) ILIKE '%organic search%'
				AND lower(mt.content) ILIKE '%google%'
			) THEN mt.platform = channel_map.platform
			AND lower(mt.source) ILIKE lower('%' + channel_map.network_name_pattern + '%')
			AND lower(mt.content) ILIKE lower('%' + channel_map.adgroup_name_pattern + '%') -- Everything else matches on network name
			-- Match platform on *mobile* string. Dynamic platform values are either ios or android, and so don't match with the mapping table
			ELSE 'mobile' = lower(channel_map.platform)
			AND lower(mt.source) ILIKE lower(channel_map.network_name_pattern)
		END
	END -- With the second join, we map the *first* attribution details to a channel/channel_detail
	LEFT JOIN sd_stage.sd__gsheets__marketing__attribution_channel_mapping first_channel_map on CASE
		WHEN mt.platform = 'web' THEN CASE
			-- exception for Organic Search
			WHEN mt.first_source is NULL
			AND mt.first_referer notNULL THEN mt.platform = first_channel_map.platform
			AND mt.first_referer ILIKE first_channel_map.first_referer -- exception for Google Paid search 
			WHEN mt.first_source = 'google-search' THEN mt.platform = first_channel_map.platform
			AND mt.first_source = first_channel_map.network_name_pattern
			AND mt.first_campaign ILIKE (
				'%' + first_channel_map.campaign_name_pattern + '%'
			) -- exception for Meta/Tiktok paid and organic campaigns 
			WHEN mt.first_source IN ('meta', 'tiktok') THEN mt.platform = first_channel_map.platform
			AND mt.first_source = first_channel_map.network_name_pattern
			AND mt.first_medium = first_channel_map.medium_name_pattern
			ELSE mt.platform = first_channel_map.platform
			AND mt.first_source = first_channel_map.network_name_pattern
		END -- Mobile mappings
		ELSE -- Exception for Facebook and Instagram
		CASE
			WHEN (
				lower(mt.first_source) ILIKE 'unattributed'
				AND mt.fb_install_referrer IS NOT NULL
				AND mt.fb_install_referrer != 'nan'
			) THEN mt.platform = first_channel_map.platform
			AND lower(mt.first_source) ILIKE lower(
				first_channel_map.fb_install_referrer_publisher_platform_pattern
			) -- Exception for Google Organic Search
			WHEN (
				lower(mt.first_source) ILIKE '%organic search%'
				AND lower(mt.first_content) ILIKE '%google%'
			) THEN mt.platform = first_channel_map.platform
			AND lower(mt.first_source) ILIKE lower(
				'%' + first_channel_map.network_name_pattern + '%'
			)
			AND lower(mt.first_content) ILIKE lower(
				'%' + first_channel_map.adgroup_name_pattern + '%'
			) -- everything else matches on network name
			ELSE 'mobile' = first_channel_map.platform
			AND lower(mt.first_source) ILIKE lower(first_channel_map.network_name_pattern)
		END
	END
ORDER BY
	mt.created_at DESC