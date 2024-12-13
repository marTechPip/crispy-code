with web_channel_detail as (
select
	case
		when lower(utm_source) = 'awin' then 'Awin'
		when lower(utm_source) = 'braze' then 'Braze'
		when (lower(utm_source) = 'meta'
		or lower(utm_source) = 'facebook')
		and lower(utm_campaign) not ilike '%meta_%' then 'Facebook Organic'
		when lower(utm_source) = 'meta'
		and lower(utm_campaign) ilike '%meta_%' then 'Meta Paid'
		when lower(utm_source) = 'google-display' then 'Google GDN'
		when lower(utm_source) = 'google-search'
		and lower(utm_campaign) ilike '%pmax%' then 'Google Ads Performance Max'
		when lower(utm_source) = 'google-search'
		and lower(utm_campaign) not ilike '%pmax%' then 'Google Search'
		when lower(utm_source) = 'heyjobs' then 'Heyjobs' 
		when lower(utm_source) = 'instagram' then 'Instagram Organic'
		when lower(utm_source) = 'jobsora' then 'Jobsora'
		when lower(utm_source) = 'linkedin' and lower(utm_campaign) ilike 'linkedin' then 'Linkedin Paid'
		when lower(utm_source) = 'linkedin' and lower(utm_campaign) isnull then 'Linkedin Organic'
		when lower(utm_source) = 'stepstone' then 'Stepstone'
		when lower(utm_source) = 'tiktok' and lower(utm_campaign) not ilike '%tiktok_b%' then 'Tiktok Organic'
		when lower(utm_source) = 'tiktok' and lower(utm_campaign) ilike '%tiktok_b%' then 'Tiktok Paid'
		when lower(utm_source) isnull and first_referer like '%google%' then 'Google Organic Search' -- can't use this until get referer sent with signup form data
		when lower(utm_source) isnull and first_referer not like '%google%' then 'Misc. Organic Search' -- can't use this until get referer sent with signup form data
		when lower(utm_source) isnull and first_referer not ilike '%google%' and first_referer not ilike '%ecosia%' and referer not ilike '%bing%' then 'Misc. referral traffic'
		when lower(utm_source) isnull and first_referer ilike '%zenjob.com%' then 'Self referrering'
		when lower(utm_source) notnull then 'Misc. traffic'
		else 'unknown/organic'
	end as channel_detail,
	utm_source as network_name,
	utm_campaign as campaign_name,
	utm_content as adgroup_name,
	utm_term as creative_name,
	'web' as platform
from cds.fact_talent_mkt_touchpoints
where
	created_ts >= '2023-06-01 00:00:00' and created_ts <= '2023-10-31 23:59:59' 
	and utm_channel = 'WEB' and activity_kind = 'web_signup'
), mobile_channel_detail as (
select
	case
	when lower(network_name) = 'apple search ads' then 'Apple Search Ads'
	when lower(network_name) ilike '%braze%' then 'Braze'
	when lower(network_name) ilike '%facebook ads%' or (lower(network_name) ilike '%unattr%' and (lower(fb_install_referrer_publisher_platform) = 'facebook' or lower(fb_install_referrer_publisher_platform) = 'instagram')) then 'Meta Paid'
    when lower(network_name) ilike '%facebook organic%' then 'Facebook Organic'
	when lower(network_name) = 'google ads ace' then 'Google Ads ACE'
	when lower(network_name) = 'google ads performance max' then 'Google Ads Performance Max'
	when lower(network_name) ilike '%google organic search%' or (lower(network_name) ilike '%organic search%' and lower(adgroup_name) ilike '%google%') then 'Google Organic Search'
	when lower(network_name) ilike 'google ads search' or lower(network_name) ilike '%google ads -%' or lower(network_name) ilike 'google ads (unknown)' or lower(network_name) ilike '%google search ads%' then 'Google Search'
	when lower(network_name) ilike '%google ads aci%' then 'Google UAC'
	when lower(network_name) ilike '%heyjobs%' then 'Heyjobs'
	when lower(network_name) ilike '%instagram organic%' or lower(network_name) ilike '%instagram stories%' then 'Instagram Organic'
	when lower(network_name) ilike '%jobsora ads%' then 'Jobsora'
	when lower(network_name) ilike '%organic search%' and lower(adgroup_name) not ilike '%google%' then 'Misc. Organic Search'
	when lower(network_name) ilike '%referral%' then 'Referral'
	when lower(network_name) ilike '%stepstone%' then 'Stepstone'
	when lower(network_name) ilike '%tiktok organic%'  then 'Tiktok Organic'
	when lower(network_name) in ('tiktok', 'tiktok ads', 'tiktok installs', 'tiktok san') or lower(network_name) ilike '%tiktok ads - %' then 'Tiktok Paid'
	when lower(network_name) in ('organic - app store') then 'Organic App Store'
	when lower(network_name) = 'growth testing' then 'Growth testing'
	-- Includes unattributed things we know come from facebook/instagram. And unknown things from the app download buttons (website_clickout)
	when (lower(network_name) notnull and lower(network_name) != 'nan') and lower(network_name) != 'organic' then 'Misc. traffic'
	else 'Unknown/organic'
end as channel_detail,
case
	when lower(network_name) = 'unattributed' and ((fb_install_referrer notnull and fb_install_referrer != 'nan')) then json_extract_path_text(fb_install_referrer,'publisher_platform')
	else network_name
end as network_name,
case
	when lower(network_name) = 'unattributed' and ((fb_install_referrer notnull and fb_install_referrer != 'nan')) then json_extract_path_text(fb_install_referrer,'campaign_group_name')
	when lower(network_name) = 'growth testing' then split_part(creative_name , '::', 1) 
	else campaign_name
end as campaign_name,
case
	when lower(network_name) = 'unattributed' and ((fb_install_referrer notnull and fb_install_referrer != 'nan')) then json_extract_path_text(fb_install_referrer,'campaign_name')
	when lower(network_name) = 'growth testing' then split_part(creative_name , '::', 2) 
	else adgroup_name
end as adgroup_name,
	case
	when lower(network_name) = 'unattributed' and ((fb_install_referrer notnull and fb_install_referrer != 'nan')) then json_extract_path_text(fb_install_referrer,'adgroup_name')
	when lower(network_name) = 'growth testing' then split_part(creative_name , '::', 3) 
	else creative_name
end as creative_name,
'mobile' as platform
from
dwh_db.dds.sd__adjust_data ad
where created_at_dt >= '2023-06-01 00:00:00' and created_at_dt <= '2023-10-31 23:59:59'  and event_name = 'signup'
), channel as (
select 'Apple Search Ads' as channel_detail, 'Apple Search' as channel UNION
select 'Awin' as channel_detail, 'Affiliate' as channel UNION
select 'Braze' as channel_detail, 'CRM' as channel UNION
select 'Facebook Organic' as channel_detail, 'Organic Social' as channel UNION
select 'Meta Paid' as channel_detail, 'Paid Social' as channel UNION
select 'Google Ads ACE' as channel_detail, 'Retargeting' as channel UNION
select 'Google Ads Performance Max' as channel_detail, 'Display' as channel UNION
select 'Google Organic Search' as channel_detail, 'Organic Search' as channel UNION
select 'Google Search' as channel_detail, 'Paid Search' as channel UNION
select 'Google UAC' as channel_detail, 'UAC' as channel UNION
select 'Google GDN' as channel_detail, 'Display' as channel UNION
select 'Heyjobs' as channel_detail, 'Job boards' as channel UNION
select 'Instagram Organic' as channel_detail, 'Organic Social' as channel UNION
select 'Jobsora' as channel_detail, 'Job boards' as channel UNION
select 'Linkedin Organic' as channel_detail, 'Organic social' as channel UNION
select 'Linkedin Paid' as channel_detail, 'Paid social' as channel UNION
select 'Misc. Organic Search' as channel_detail, 'Organic Search' as channel UNION
select 'Referral' as channel_detail, 'Referral' as channel UNION
select 'Stepstone' as channel_detail, 'Job boards' as channel UNION
select 'Tiktok Organic' as channel_detail, 'Organic Social' as channel UNION
select 'Tiktok Paid' as channel_detail, 'Paid Social' as channel UNION
select 'Organic App Store' as channel_detail, 'Organic' as channel UNION
select 'Growth testing' as channel_detail, 'Misc. testing' as channel UNION
select 'Self Referring' as channel_detail, 'Internal' as channel UNION
select 'Misc. traffic' as channel_detail, 'Unknown/organic' as channel UNION
select 'Misc. referral traffic' as channel_detail, 'Unknown/organic' as channel UNION
select 'Unknown/organic' as channel_detail, 'Unknown/organic' as channel
)
select channel, channel_detail, count(*) from (
select
channel.channel, 
mobile_channel_detail.channel_detail,
mobile_channel_detail.network_name,
mobile_channel_detail.campaign_name,
mobile_channel_detail.adgroup_name,
mobile_channel_detail.creative_name,
mobile_channel_detail.platform
from mobile_channel_detail
join channel on mobile_channel_detail.channel_detail=channel.channel_detail
union all
select 
channel.channel, 
web_channel_detail.channel_detail,
web_channel_detail.network_name,
web_channel_detail.campaign_name,
web_channel_detail.adgroup_name,
web_channel_detail.creative_name,
web_channel_detail.platform
from web_channel_detail
join channel on web_channel_detail.channel_detail=channel.channel_detail
)
group by 1,2
