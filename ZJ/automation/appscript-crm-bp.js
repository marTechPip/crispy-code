/**
* @OnlyCurrentDoc
*/

/* START - RETURN BONUS PARAMETER(S) ON GET REQUEST */
/* The GET request processes incoming requests from an individual bonus listing page (one row is returned). */

function doGet(e) {

  var bonusIdParameter = e.parameter.bonusId
  var content;
 
  try {       
    content = createXMLspecific(bonusIdParameter);  
  } catch (err) {
    console.error('<error>' + (err.message || err) + '</error>');
  }
  
  var output = ContentService.createTextOutput(content)
  .setMimeType(ContentService.MimeType.XML);
    
  return output       
}

/* Return one bonus program for the individual bonus program landing pages */

function createXMLspecific(referenceId) {
  var bonusColumn = 'B';
  var shiftColumn = 'C';
  var startColumn = 'D';
  var endColumn = 'E';
  var cityColumn = 'F';
  var jobColumn = 'G';
  var termsColumn = 'H';
  var referenceIdColumn = 'A';
  var root = XmlService.createElement('source');    
  var ss = SpreadsheetApp.getActiveSheet();
  var specificRow; 
  var lastRow = ss.getLastRow();
  var data = ss.getRange(referenceIdColumn + "1:" + referenceIdColumn + lastRow).getValues();
  //specificRow = 2;
  for (var i = 0; i < data.length; i++) {
      if (data[i] == referenceId) {
          specificRow = i + 1;
      }
  }    

  try {
    var rowData = ss.getRange('A' + specificRow + ":H" + specificRow).getValues();
  }
  catch {
    return ['bonusNotFound', 'bonusId error code 1']
  }

  var bonusCampaign = XmlService.createElement('bonusCampaign')
  root.addContent(bonusCampaign);

  var idRow = rowData[0][0];
  var id_cData = XmlService.createCdata(idRow);
  var id = XmlService.createElement('id').addContent(id_cData);
  bonusCampaign.addContent(id);

  var bonusRow = rowData[0][1];
  var bonus_cData = XmlService.createCdata(bonusRow);
  var bonus = XmlService.createElement('bonus').addContent(bonus_cData);
  bonusCampaign.addContent(bonus);
  
  var shiftsRow = rowData[0][2]
  var shifts_cData = XmlService.createCdata(shiftsRow);
  var shifts = XmlService.createElement('shifts').addContent(shifts_cData);
  bonusCampaign.addContent(shifts);

  var start_dateRow = rowData[0][3];
  var start_date_cData = XmlService.createCdata(start_dateRow);
  var start_date = XmlService.createElement('start_date').addContent(start_date_cData);
  bonusCampaign.addContent(start_date);

  var end_dateRow = rowData[0][4];
  var end_date_cData = XmlService.createCdata(end_dateRow);
  var end_date = XmlService.createElement('end_date').addContent(end_date_cData);
  bonusCampaign.addContent(end_date);

  var cityRow = rowData[0][5];
  var city_cData = XmlService.createCdata(cityRow);
  var city = XmlService.createElement('city').addContent(city_cData);
  bonusCampaign.addContent(city);

  var jobRow = rowData[0][6];
  var job_cData = XmlService.createCdata(jobRow);
  var job = XmlService.createElement('job').addContent(job_cData);
  bonusCampaign.addContent(job);

  var termsRow = rowData[0][7];
  var terms_cData = XmlService.createCdata(termsRow);
  var terms = XmlService.createElement('terms').addContent(terms_cData);
  bonusCampaign.addContent(terms);

  let document = XmlService.createDocument(root);
  let xml = XmlService.getPrettyFormat().format(document);
  
  return xml  
}
