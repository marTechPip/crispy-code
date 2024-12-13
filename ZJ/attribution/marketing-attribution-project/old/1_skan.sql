-- GET SKAN INSTALLS, SIGNUPS AND ONBOARDINGS
-- INSTALL
select activity_kind, source, count(*) from (
select 
	null as user_uuid, 
	null as adid,
	TIMESTAMP 'epoch' + json_extract_path_text(sk_payload,'timestamp')::integer * INTERVAL '1 second' as created_at,
	'skan' as data_source,
	'install' as activity_kind,
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'true' then 'redownload' else 'new_install' end as install_type,
	'ios' as platform,
	'channel'as channel,
	'channel_detail' as channel_detail,
	case when sk_network_id = 'mj797d8u6f.skadnetwork' then 'tiktok ads' when sk_network_id = 'eqhxz8m8av.skadnetwork' then 'google ads aci' when sk_network_id = 'facebook.skadnetwork' then 'facebook ads' end as source, 
	null as medium,
	nullif(json_extract_path_text(sk_payload, 'adjust-campaign'), '') as campaign,
	nullif(json_extract_path_text(sk_payload, 'adjust-adgroup'), '') as adgroup,
	nullif(json_extract_path_text(sk_payload, 'adjust-creative'), '') as creative,
	null as first_referer,
		'first_channel' as first_channel,
			'first_channel_detail' as first_channel_detail,
	-- IF NOT REDOWNLOAD THEN USE CURRENT TRACKERS FOR FIRST VALUES. OTHERWISE UNKNOWN
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then 
		case when sk_network_id = 'mj797d8u6f.skadnetwork' then 'tiktok ads' when sk_network_id = 'eqhxz8m8av.skadnetwork' then 'google ads aci' when sk_network_id = 'facebook.skadnetwork' then 'facebook ads' else 'unknown' end
		else 'unknown' end 
		as first_source, 
	null as first_medium,
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then nullif(json_extract_path_text(sk_payload, 'adjust-campaign'), '')  else 'unknown' end as first_campaign, 
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then nullif(json_extract_path_text(sk_payload, 'adjust-adgroup'), '') else 'unknown' end as first_content, 
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then nullif(json_extract_path_text(sk_payload, 'adjust-creative'), '') else 'unknown' end as first_term
from 
	dds.sd__adjust_data sad
where
	activity_kind = 'sk_install'
	--MAYBE REPLACE THIS WITH DATE_ON_FILE FOR THE PROD VERSION?
	and json_extract_path_text(sk_payload,'timestamp') >= 1704063600--2024-01-01 
	and json_extract_path_text(sk_payload,'timestamp') <= 1711839600--2024-03-31
union all 
-- SIGNUP AND ONBOARDED (union installs)
select 
	null as user_uuid, 
	null as adid,
	TIMESTAMP 'epoch' + json_extract_path_text(sk_payload,'timestamp')::integer * INTERVAL '1 second' as created_at,
	'skan' as data_source,
	case when nullif(json_extract_path_text(sk_payload, 'conversion-value'), '') = 2 then 'sk_signup' when nullif(json_extract_path_text(sk_payload, 'conversion-value'), '') = 32 then 'sk_onboarded' else 'unknown' end as activity_kind,  
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'true' then 'redownload' else 'new_install' end as install_type,
	'ios' as platform,
	'channel'as channel,
	'channel_detail' as channel_detail,
	case when sk_network_id = 'mj797d8u6f.skadnetwork' then 'tiktok ads' when sk_network_id = 'eqhxz8m8av.skadnetwork' then 'google ads aci' when sk_network_id = 'facebook.skadnetwork' then 'facebook ads' end as source, 
	null as medium,
	nullif(json_extract_path_text(sk_payload, 'adjust-campaign'), '') as campaign,
	nullif(json_extract_path_text(sk_payload, 'adjust-adgroup'), '') as adgroup,
	nullif(json_extract_path_text(sk_payload, 'adjust-creative'), '') as creative,
	null as first_referer,
		'first_channel' as first_channel,
			'first_channel_detail' as first_channel_detail,
	-- IF NOT REDOWNLOAD THEN USE CURRENT TRACKERS FOR FIRST VALUES. OTHERWISE UNKNOWN
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then 
		case when sk_network_id = 'mj797d8u6f.skadnetwork' then 'tiktok ads' when sk_network_id = 'eqhxz8m8av.skadnetwork' then 'google ads aci' when sk_network_id = 'facebook.skadnetwork' then 'facebook ads' else 'unknown' end
		else 'unknown' end 
		as first_source, 
	null as first_medium,
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then nullif(json_extract_path_text(sk_payload, 'adjust-campaign'), '')  else 'unknown' end as first_campaign, 
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then nullif(json_extract_path_text(sk_payload, 'adjust-adgroup'), '') else 'unknown' end as first_content, 
	case when nullif(json_extract_path_text(sk_payload, 'redownload'), '') = 'false' then nullif(json_extract_path_text(sk_payload, 'adjust-creative'), '') else 'unknown' end as first_term
from 
	dds.sd__adjust_data sad
where
	activity_kind = 'sk_event'
	--MAYBE REPLACE THIS WITH DATE_ON_FILE FOR THE PROD VERSION?
	and json_extract_path_text(sk_payload,'timestamp') >= 1704063600--2024-01-01 
	and json_extract_path_text(sk_payload,'timestamp') <= 1711839600--2024-03-31
	and nullif(json_extract_path_text(sk_payload, 'conversion-value'), '') in (2, 32) 
	) group by 1,2
	
	