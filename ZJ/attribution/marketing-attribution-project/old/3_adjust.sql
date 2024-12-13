with mapping as ( --could save this mapping as a temp table to save time
select adid, user_uuid from (
select
	distinct adid,
	user_uuid,
	created_at_dt,
	row_number() over (partition by adid order by created_at_dt desc) as rn
from 
	dds.sd__adjust_data sad
where
	user_uuid notnull
	and user_uuid != 'nan'
) where rn = 1
),
events as (
select
	case
		when user_uuid = 'nan'
			or user_uuid isnull then null
			else user_uuid
		end as user_uuid,
		adid,
		created_at_dt,
		'adjust' as data_source,
		activity_kind,
		'null' as install_type,
		event_name,
		os_name as platform,
		tracker_name,
		'channel' as channel,
		'channel_detail' as channel_detail,
		-- ATTRIBUTION DETAILS TO CONSIDER THE FB INSTALL REFERRER
		case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'publisher_platform') when network_name = 'nan' then null ELSE network_name end as source,
		null as medium,
		case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_group_name')  when campaign_name = 'nan' then null  ELSE TRIM(SPLIT_PART(campaign_name, ' ', 1)) END AS campaign,
		 case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_name')  when adgroup_name = 'nan' then null ELSE TRIM(SPLIT_PART(adgroup_name, ' ', 1)) END AS content,
		case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'adgroup_name')  when creative_name = 'nan' then null ELSE creative_name end as term,
		null as first_referer,
		'first_channel' as first_channel,
		'first_channel_detail' as first_channel_detail,
		case when SPLIT_PART(first_tracker_name , '::', 1) = '' then null else SPLIT_PART(first_tracker_name , '::', 1) end as first_source, 
		null as first_medium,
		case when SPLIT_PART(first_tracker_name , '::', 2) = ''  then null else SPLIT_PART(first_tracker_name , '::', 2) end as first_campaign, 
		case when SPLIT_PART(first_tracker_name , '::', 3) = ''   then null else  SPLIT_PART(first_tracker_name , '::', 3)  end as first_content, 
		case when SPLIT_PART(first_tracker_name , '::', 4) = ''   then null else SPLIT_PART(first_tracker_name , '::', 4) end as first_term
	from
		dds.sd__adjust_data sad
	where
		activity_kind = 'install' or activity_kind = 'reattribution'
		or (activity_kind = 'event'
			and event_name = 'signup')
)
select
	case
		when events.user_uuid != null then events.user_uuid
		else mapping.user_uuid
	end as user_uuid, -- else it will be null anyway 
	events.adid,
	events.created_at_dt,
	events.data_source,
	case when events.activity_kind in ('install','reattribution') then events.activity_kind else event_name end as touchpoint,
	events.platform,
	events.channel,
	events.channel_detail,
	events.source,
	events.medium,
	events.campaign,
	events.content,
	events.term,
	events.first_referer,
	events.first_channel,
	events.first_channel_detail,
	events.first_source,
	events.first_medium,
	events.first_campaign,
	events.first_content,
	events.first_term
from 
	events
left join mapping on
	events.adid = mapping.adid
	where events.created_at_dt::date = '2024-04-12'
