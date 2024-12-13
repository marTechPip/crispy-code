function addRows(groups) {
  var $row = $('.testGroupClone').clone();
  var $tasksList = $('.testGroupContainer');
  var $resultRow = $('.testGroupResults').clone();
  var $resultsList = $('.testGroupResultsContainer')
  for (p = 2; p <= groups; p++) {

    // add groups section
    var newRow = $row.clone()
    $(".groupName", newRow).text("Test group " + p); //test # increment
    $("#testGroupSize", newRow).attr('id', 'testGroupSize_' + p).val('0');
    $("#testGroupSubject", newRow).attr('id', 'testGroupSubject_' + p);
    newRow.appendTo($tasksList);

    // add results section
    var newResults = $resultRow.clone();
    $("label[for='testGroupResultSize']", newResults).html("Number of users in <strong>test group " + p + "</strong>");
    //$("label[for='testGroupResultConversions']", newResults).text("Number of primary conversions in test group " + additionalGroup);
    $("#testGroupResultSize", newResults).attr('id', 'testGroupResultSize_' + p);
    $("#testGroupResultConversions", newResults).attr('id', 'testGroupResultConversions_' + p);
    $("#testGroupConversionRate", newResults).attr('id', 'testGroupConversionRate_' + p);
    $("#testGroupStatisticalSignificance", newResults).attr('id', 'testGroupStatisticalSignificance_' + p);
    newResults.appendTo($resultsList)
  }
}