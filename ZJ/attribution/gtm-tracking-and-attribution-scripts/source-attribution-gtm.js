(function() {
    var searchEngines = ['https://www.google.com/', 'https://www.google.de/', 'https://www.bing.com/', 'https://www.ecosia.org/', 'https://search.yahoo.com/', 'https://duckduckgo.com/'];     
     
    var location = window.location.href;
     
    if(/gclid/i.test(location) || /google.*uac/i.test(location) || /google.*sem/i.test(location) || /google.*gdn/i.test(location) || /google.*yta/i.test(location)) {
        return 'google_ads';
    } else if(/meta.*pfm/i.test(location) || /meta.*awa/i.test(location)) {
        return 'facebook_ads';
    } else if(/stepstone.*cpad/i.test(location)) {
        return 'stepstone_ads';        
    } else if(/jobsora.*cpc/i.test(location) || /cpc.*jobsora/i.test(location)) {
        return 'jobsora_ads';
    } else if(/instagram.*organic/i.test(location) || /organic.*instagram/i.test(location)) {
        return 'organic_instagram';
    } else if(/tiktok.*organic/i.test(location) || /organic.*tiktok/i.test(location)) {
        return 'organic_tiktok';
    } else if(/youtube.*organic/i.test(location) || /organic.*youtube/i.test(location)) {
        return 'organic_youtube';
    } else if (searchEngines.some(function(se) {
        return document.referrer.startsWith(se);
    })) {
        return 'organic_search';
    } else {
        return 'website_clickout';
    }    
})