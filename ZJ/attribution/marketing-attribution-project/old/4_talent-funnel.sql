with funnel_events as (
select
	talent_id,
	'onboarded' as activity_kind,
	onboarded_dt as created_at
from
	cds.fact_talent_funnel
where
	onboarded_dt = '2024-04-01'
union all
select
	talent_id,
	'first_shift_worked' as activity_kind,
	first_worked_shift_dt as created_at
from
	cds.fact_talent_funnel
where
	first_worked_shift_dt = '2024-04-01'
union all
select
	talent_id,
	'first_shift_worked' as activity_kind,
	third_worked_shift_dt as created_at
from
	cds.fact_talent_funnel
where
	third_worked_shift_dt = '2024-04-01'
), attribution_details as (-- create user uuid mapping table to get last and first attribution details from Adjust table - get latest attribution details
select user_uuid, adid, os_name, source, campaign, content, term, first_source, first_campaign, first_content, first_term from (
select user_uuid, 
adid, 
created_at_dt,
os_name, 
case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'publisher_platform') when network_name = 'nan' then null ELSE network_name end as source,
case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_group_name')  when campaign_name = 'nan' then null  ELSE TRIM(SPLIT_PART(campaign_name, ' ', 1)) END AS campaign,
 case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'campaign_name')  when adgroup_name = 'nan' then null ELSE TRIM(SPLIT_PART(adgroup_name, ' ', 1)) END AS content,
case WHEN network_name ILIKE 'unattributed' AND os_name = 'android' and fb_install_referrer IS NOT NULL AND fb_install_referrer != 'nan' THEN JSON_EXTRACT_PATH_TEXT(fb_install_referrer, 'adgroup_name')  when creative_name = 'nan' then null ELSE creative_name end as term,
case when SPLIT_PART(first_tracker_name , '::', 1) = '' then null else SPLIT_PART(first_tracker_name , '::', 1) end as first_source, 
case when SPLIT_PART(first_tracker_name , '::', 2) = ''  then null else SPLIT_PART(first_tracker_name , '::', 2) end as first_campaign, 
case when SPLIT_PART(first_tracker_name , '::', 3) = ''   then null else  SPLIT_PART(first_tracker_name , '::', 3)  end as first_content, 
case when SPLIT_PART(first_tracker_name , '::', 4) = ''   then null else SPLIT_PART(first_tracker_name , '::', 4) end as first_term,
row_number() over (partition by user_uuid order by created_at_dt desc) as rn
from dds.sd__adjust_data sad 
where user_uuid notnull and user_uuid != 'nan'
) where rn = 1
)
select 
talent.user_uuid,
attribution_details.adid,
funnel_events.created_at::timestamp,
'talent_funnel' as data_source,
funnel_events.activity_kind,
null as install_type,
attribution_details.os_name as platform, 
'channel' as channel,
'channel_detail' as channel_detail, 
attribution_details.source,
attribution_details.campaign,
attribution_details.content,
attribution_details.term,
null as first_referer,
'first_channel' as first_channel,
'first_channel_detail' as first_channel_detail, 
attribution_details.first_source,
attribution_details.first_campaign,
attribution_details.first_content,
attribution_details.first_term
from funnel_events
join cds.dim_talent talent on funnel_events.talent_id=talent.talent_id
join attribution_details on talent.user_uuid=attribution_details.user_uuid

	
	


