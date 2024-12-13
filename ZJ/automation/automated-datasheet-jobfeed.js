/**
 * @OnlyCurrentDoc
 */

/* Create menu to manually trigger cache */

function onOpen() {
    var spreadsheet = SpreadsheetApp.getActive();
    var menuItems = [
        { name: 'Manual refresh job feed cache', functionName: 'createXML' }
    ];
    spreadsheet.addMenu('Job feed', menuItems);
}

/* START - ADD NEW JOB FUNCTION */
/* The POST request and addRow function processes add job requests from the AM holding sheet */
/* Note: not refactored */

function doPost(e) {
    var callback;
    /* Trigger add row function and return error message in case of failure */
    try {
        callback = addRow(e);
    } catch (err) {
        callback = '<error>' + (err.message || err) + '</error>';
    }
    /* return success/fail status message to endpoint */
    return ContentService.createTextOutput(JSON.stringify(callback))
}

function addRow(e) {

    var statusColumn = 'A';
    var referenceNumberColumn = 'B';
    var titleColumn = 'C';
    var startDateColumn = 'D';
    var cityColumn = 'E';
    var salaryColumn = 'F';
    var urlColumn = 'G'
    var jobTypeColumn = 'H';
    var descriptionColumn = 'I';
    /* CHANGE */
    var endDateColumn = 'P';
    var languageColumn = 'J'
    var ss = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("data");
    var lastRow = ss.getLastRow();
    var nextRow = lastRow + 1;
    var postContents = JSON.parse(e.postData.contents);
    var dd = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("dropdowns")
    var ddRange = dd.getRange('A1:A3');
    var ddIndeed = ss.getRange(statusColumn + nextRow)
    var rule = SpreadsheetApp.newDataValidation().requireValueInRange(ddRange).build();
    ddIndeed.setDataValidation(rule);
    ss.getRange(statusColumn + nextRow).setValue('DRAFT')
    ss.getRange(referenceNumberColumn + nextRow).setValue(postContents.referenceNumber)
    ss.getRange(titleColumn + nextRow).setValue(postContents.jobTitle)
    ss.getRange(startDateColumn + nextRow).setValue(postContents.date)
    ss.getRange(cityColumn + nextRow).setValue(postContents.city)
    ss.getRange(salaryColumn + nextRow).setValue(postContents.salary)
    ss.getRange(urlColumn + nextRow).setValue(postContents.url)
    ss.getRange(jobTypeColumn + nextRow).setValue(postContents.jobType)
    ss.getRange(descriptionColumn + nextRow).setValue(postContents.description)
    ss.getRange(endDateColumn + nextRow).setValue(postContents.endDate)
    ss.getRange(languageColumn + nextRow).setValue(postContents.language)
    return 'success'
}

/* END - ADD NEW JOB FUNCTION */
/* START - RETURN JOB(S) ON GET REQUEST */
/* The GET request processes incoming requests from either an individual job listing page (in which case, one row is returned), or from the job overview page or from Stepstone's bot (in which case, the entire sheet is returned) */

function doGet(e) {
    var feedType;
    var jobIdParameter = e.parameter.jobId
    var rowIdParameter = e.parameter.dav
    if (jobIdParameter != '' && jobIdParameter != null && jobIdParameter != undefined) {
        feedType = 'specific'
    } else {
        feedType = 'generic'
    }
    var content;
    try {
        if (feedType == 'specific') {
            content = createXMLspecific(e, jobIdParameter, rowIdParameter);
        } else {
            content = new ChunkyCache().get('key');
            if (content == null) {
                content = createXML('returnOverview');
            } else {
                Logger.log("cache")
            }
        }
    } catch (err) {
        content = '<error>' + (err.message || err) + '</error>';
    }
    return ContentService.createTextOutput(content)
        .setMimeType(ContentService.MimeType.XML);
}

/* Return one job detail for the individual job listing pages */

function createXMLspecific(e, referenceId, rowIdParameter) {
    var importStatusColumn = 'A'
    var referenceIdColumn = 'B'
    var endColumn = 'J'
    var root = XmlService.createElement('source');
    var publisher = XmlService.createElement('publisher')
        .setText('Zenjob GmbH');
    var publisherurl = XmlService.createElement('publisherurl')
        .setText('https://zenjob.com');
    const now = new Date();
    var nowFormatted = Utilities.formatDate(now, 'Etc/GMT', 'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
    var lastBuildDate = XmlService.createElement('lastbuilddate')
        .setText(nowFormatted);
    root.addContent(publisher);
    root.addContent(publisherurl);
    root.addContent(lastBuildDate);
    var ss = SpreadsheetApp.getActiveSheet();

    var specificRow;

    /* Set specific row variable to dav (rowId) parameter */
    const regex = /\d/;
    const rowIdTest = regex.test(rowIdParameter);

    if (rowIdTest == true) {
        specificRow = rowIdParameter
    } else {
        /* Row lookup in case of missing dav parameter */
        var lastRow = ss.getLastRow();
        var data = ss.getRange(referenceIdColumn + "1:" + referenceIdColumn + lastRow).getValues();
        //specificRow = 2;
        for (var i = 0; i < data.length; i++) {
            if (data[i] == referenceId) {
                specificRow = i + 1;
            }
        }
    }

    try {
        var rowData = ss.getRange(importStatusColumn + specificRow + ":" + endColumn + specificRow).getValues();
    }
    catch {
        Logger.log('jobNotFound')
        return 'jobNotFound'
    }

    var importStatus = rowData[0][0]
    if (importStatus == 'LIVE') {
        var referencenumberRow = rowData[0][1]
        var referencenumberRow_cData = XmlService.createCdata(referencenumberRow);
        var jobTitleRow = rowData[0][2]
        var jobTitleRow_cData = XmlService.createCdata(jobTitleRow);
        var cityRow = rowData[0][4]
        var cityRow_cData = XmlService.createCdata(cityRow);
        var salaryRow = rowData[0][5]
        var salaryRow_cData = XmlService.createCdata(salaryRow);
        var jobtypeRow = rowData[0][7]
        var jobtypeRow_cData = XmlService.createCdata(jobtypeRow);
        var languageRow = rowData[0][9]
        var languageRow_cData = XmlService.createCdata(languageRow);
        var descriptionRow = rowData[0][8]
        var descriptionRow_cData;
        if (languageRow == 'en') {
            descriptionRow_cData = XmlService.createCdata(descriptionRow + "<div id='hiddenPara'><br><em>An application is only possible via our app. Due to legal requirements and technical peculiarities of our digital business model, an application is currently only possible for students and people with a main employment subject to social security contributions.</em></div>")
        } else {
            descriptionRow_cData = XmlService.createCdata(descriptionRow + "<div id='hiddenPara'><br><em>Eine Bewerbung ist nur über unsere App möglich. Aufgrund von gesetzlichen Vorgaben und technischen Besonderheiten unseres digitalen Geschäftsmodells, ist eine Bewerbung derzeit nur für Studierende sowie Menschen mit einer sozialversicherungspflichtigen Hauptbeschäftigung möglich.</em></div>")
        }
        var joblisting = XmlService.createElement('job')
        root.addContent(joblisting);
        var jobTitle = XmlService.createElement('title').addContent(jobTitleRow_cData)
        joblisting.addContent(jobTitle);
        var referencenumber = XmlService.createElement('referencenumber').addContent(referencenumberRow_cData)
        joblisting.addContent(referencenumber);
        var city = XmlService.createElement('city').addContent(cityRow_cData)
        joblisting.addContent(city);
        var salary = XmlService.createElement('salary').addContent(salaryRow_cData)
        joblisting.addContent(salary);
        var jobtype = XmlService.createElement('jobtype').addContent(jobtypeRow_cData)
        joblisting.addContent(jobtype);
        var language = XmlService.createElement('language').addContent(languageRow_cData)
        joblisting.addContent(language);
        var description = XmlService.createElement('description').addContent(descriptionRow_cData)
        joblisting.addContent(description);
        let document = XmlService.createDocument(root);
        let xml = XmlService.getPrettyFormat().format(document);
        return xml
    } else {

        return 'jobInactive'
    }
}

/* Return all job details from the sheet for bot or overview request*/

function createXML(requestType) {
    var importStatusColumn = 'A'
    /* CHANGE */
    var endColumn = 'Q'

    /* define array conditions from gSheet and create parent node*/
    var root = XmlService.createElement('source');
    var publisher = XmlService.createElement('publisher')
        .setText('Zenjob GmbH');
    var publisherurl = XmlService.createElement('publisherurl')
        .setText('https://zenjob.com');
    const now = new Date();
    var nowFormatted = Utilities.formatDate(now, 'Etc/GMT', 'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
    var lastBuildDate = XmlService.createElement('lastbuilddate')
        .setText(nowFormatted);
    root.addContent(publisher);
    root.addContent(publisherurl);
    root.addContent(lastBuildDate);
    var ss = SpreadsheetApp.getActiveSheet();
    var lastRow = ss.getLastRow();
    var data = ss.getRange(importStatusColumn + '2:' + endColumn + lastRow).getValues();

    // var header = data.shift();
    data.forEach((value, index) => {

        var importStatus = value[0]

        if (importStatus == 'LIVE') {


            /* create and add joblisting node*/
            var joblisting = XmlService.createElement('job')
            root.addContent(joblisting);

            var referencenumber_data = value[1]
            var referencenumber_CData = XmlService.createCdata(referencenumber_data);
            var referencenumber_child = XmlService.createElement('referencenumber').addContent(referencenumber_CData)
            joblisting.addContent(referencenumber_child);

            var title_data = value[2]
            var title_CData = XmlService.createCdata(title_data);
            var title_child = XmlService.createElement('title').addContent(title_CData)
            joblisting.addContent(title_child);

            var date_data = value[3]
            var date_CData = XmlService.createCdata(date_data);
            var date_child = XmlService.createElement('date').addContent(date_CData)
            joblisting.addContent(date_child);

            var city_data = value[4]
            var city_CData = XmlService.createCdata(city_data);
            var city_child = XmlService.createElement('city').addContent(city_CData)
            joblisting.addContent(city_child);

            var salary_data = value[5]
            var salary_CData = XmlService.createCdata(salary_data);
            var salary_child = XmlService.createElement('salary').addContent(salary_CData)
            joblisting.addContent(salary_child);

            var url_data = value[6]
            var url_CData = XmlService.createCdata(url_data);
            var url_child = XmlService.createElement('url').addContent(url_CData)
            joblisting.addContent(url_child);

            var jobtype_data = value[7]
            var jobtype_CData = XmlService.createCdata(jobtype_data);
            var jobtype_child = XmlService.createElement('jobtype').addContent(jobtype_CData)
            joblisting.addContent(jobtype_child);

            var language_data = value[9]
            var language_CData = XmlService.createCdata(language_data);
            var language_child = XmlService.createElement('language').addContent(language_CData)
            joblisting.addContent(language_child);

            /* CHANGE */
            var category_data = value[16]
            var category_CData = XmlService.createCdata(category_data);
            var category_child = XmlService.createElement('category').addContent(category_CData)
            joblisting.addContent(category_child);

            var description_data = value[8]
            var descriptionComplete = description_data + "<div><br><em>Eine Bewerbung ist nur über unsere App möglich. Aufgrund von gesetzlichen Vorgaben und technischen Besonderheiten unseres digitalen Geschäftsmodells, ist eine Bewerbung derzeit nur für Studierende sowie Menschen mit einer sozialversicherungspflichtigen Hauptbeschäftigung möglich.</em></div>"
            var descriptionComplete_CData = XmlService.createCdata(descriptionComplete);
            var description_child = XmlService.createElement('description').addContent(descriptionComplete_CData)
            joblisting.addContent(description_child);


            var countrycData = XmlService.createCdata('Deutschland');
            var companycData = XmlService.createCdata('Zenjob GmbH');
            var sourcenamecData = XmlService.createCdata('Zenjob GmbH');
            var country = XmlService.createElement('country').addContent(countrycData)
            var company = XmlService.createElement('company').addContent(companycData)
            var sourcename = XmlService.createElement('sourcename').addContent(sourcenamecData)
            joblisting.addContent(country);
            joblisting.addContent(company);
            joblisting.addContent(sourcename);
        }

    })

    let document = XmlService.createDocument(root);
    let xml = XmlService.getPrettyFormat().format(document);
    if (requestType == 'returnOverview') {
        console.log('overview')
        return xml
    } else {
        console.log('caching')
        new ChunkyCache().remove('key');
        new ChunkyCache().put('key', xml);
    }
}


class ChunkyCache {
    /**
     *
     * @param {GoogleAppsScript.Cache.Cache} cache
     */
    constructor(cache) {
        this.cache = cache || CacheService.getScriptCache();
        this.chunkSize = 100 * 1024;
    }
    /**
     * Gets the cached value for the given key, or null if none is found.
     * https://developers.google.com/apps-script/reference/cache/cache#getkey
     *
     * @param {string} key
     * @returns {any} A JSON.parse result
     */
    get(key) {
        const superKeyjson = this.cache.get(key);
        if (superKeyjson === null) return null;
        const superKey = JSON.parse(superKeyjson);
        const cache = this.cache.getAll(superKey.chunks);
        const chunks = superKey.chunks.map((key) => cache[key]);
        if (
            chunks.every(function (c) {
                return c !== undefined;
            })
        ) {
            return JSON.parse(chunks.join(''));
        }
    }
    /**
     * Adds a key/value pair to the cache.
     * https://developers.google.com/apps-script/reference/cache/cache#putkey,-value
     *
     * @param {string} key
     * @param {string} value
     * @param {number} expirationInSeconds
     */
    put(key, value, expirationInSeconds = 18000) {
        const json = JSON.stringify(value);
        const chunks = [];
        const chunkValues = {};
        let index = 0;
        while (index < json.length) {
            const chunkKey = key + '_' + index;
            chunks.push(chunkKey);
            chunkValues[chunkKey] = json.substr(index, this.chunkSize);
            index += this.chunkSize;
        }
        const superKey = {
            chunkSize: this.chunkSize,
            chunks: chunks,
            length: json.length,
        };
        chunkValues[key] = JSON.stringify(superKey);
        this.cache.putAll(chunkValues, expirationInSeconds);
    }
    /**
     * Removes an entry from the cache using the given key.
     *
     * @returns {null}
     */
    remove(key) {
        const superKeyjson = this.cache.get(key);
        if (superKeyjson !== null) {
            const superKey = JSON.parse(superKeyjson);
            this.cache.removeAll([...superKey.chunks, key]);
        }
        return null;
    }
}
