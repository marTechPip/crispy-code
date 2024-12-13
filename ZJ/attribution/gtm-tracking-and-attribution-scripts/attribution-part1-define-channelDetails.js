function() {
  var utmSource = {{ALL | utm_source (url)}};
  var utmCampaign = {{ALL | utm_campaign (url)}};
  
  var firstReferrer = sessionStorage.getItem('first_referrer');
  var channelDetail;

  if (utmSource === 'awin') {
    channelDetail = 'Awin';
  } else if (utmSource === 'braze') {
    channelDetail = 'Braze';
  } else if ((utmSource === 'meta' || utmSource === 'facebook') && !/meta_/i.test(utmCampaign)) {
    channelDetail = 'Facebook Organic';
  } else if (utmSource === 'meta' && /meta/i.test(utmCampaign)) {
    channelDetail = 'Meta Paid';
  } else if (utmSource === 'linkedin' && /linkedin/i.test(utmCampaign)) {
    channelDetail = 'Linkedin Paid';
  } else if (utmSource === 'linkedin' || (/linkedin/i.test(firstReferrer) && utmSource === undefined)) {
    channelDetail = 'Linkedin Organic';
  } else if (utmSource === 'google-search' && /pmax/i.test(utmCampaign)) {
    channelDetail = 'Google Ads Performance Max';
  } else if (utmSource === undefined && /google/i.test(firstReferrer)) {
    channelDetail = 'Google Organic Search';
  } else if (utmSource === 'google-search' && !/pmax/i.test(utmCampaign)) {
    channelDetail = 'Google Search Ads';
  } else if (utmSource === 'instagram') {
    channelDetail = 'Instagram Organic';
  } else if (utmSource === 'jobsora') {
    channelDetail = 'Jobsora Ads';
  } else if (utmSource === undefined && !/google/i.test(firstReferrer)) {
    channelDetail = 'Misc. Organic Search';
  } else if (utmSource === 'stepstone') {
    channelDetail = 'Stepstone Ads';
  } else if (utmSource === 'tiktok' && !/tiktok_/i.test(utmCampaign)) {
    channelDetail = 'Tiktok Organic';
  } else if (utmSource === undefined && /zenjob.com/i.test(firstReferrer)) {
    channelDetail = 'Self Referring';
  } else if (/test_/i.test(utmSource)) {
    channelDetail = 'Growth Testing';
  } else if (utmSource != undefined) {
    channelDetail = 'Misc. Traffic';
  } else if (utmSource === undefined && !/(google|bing|ecosia)/i.test(firstReferrer)) {
    channelDetail = 'Misc. Referral Traffic';
  } else {
    channelDetail = 'Unknown';
  }
  return channelDetail;
}