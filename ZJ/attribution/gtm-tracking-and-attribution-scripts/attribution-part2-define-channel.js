function() {
  var channelDetail = {{ALL | Source attribution - Part 1 - Define channel detail}};
  var channel;

  if (channelDetail === 'Awin') {
    channel = 'Affiliate';
  } else if (channelDetail === 'Braze') {
    channel = 'CRM';
  } else if (/Facebook Organic|Instagram Organic|Tiktok Organic|Linkedin Organic/i.test(channelDetail)) {
    channel = 'Organic Social';
  } else if (/Meta Paid|Linkedin Paid/i.test(channelDetail)) {
    channel = 'Paid Social';
  } else if (/Google Ads Performance Max|Google Search/i.test(channelDetail)) {
    channel = 'Paid Search';
  } else if (/Google Organic Search|Misc. Organic Search/i.test(channelDetail)) {
    channel = 'Organic Search';
  } else if (/Jobsora|Stepstone/i.test(channelDetail)) {
    channel = 'Job boards';
  } else if (channelDetail === 'Growth Testing') {
    channel = 'Misc. Testing';
  } else if (/Misc. Traffic|Misc. Refferal Traffic|Unknown/i.test(channelDetail)) {
    channel = 'Unknown/organic';
  }

  return channel;
}