document.getElementById("submit-button").addEventListener("click", function (event) {
  // Collect form data
  var formData = new FormData(document.getElementById("zapier-form"));

  // Validate form fields
  if (!validateForm()) {
      // If validation fails, prevent the form from submitting
      event.preventDefault();
      return;
  }

  // Send data to Zapier asynchronously using fetch
  fetch("REQUEST-URL", {
      method: "POST",
      body: formData
  })
  .then(response => {
      if (response.ok) {
          // Redirect user to thank-you page on successful submission
          window.location.href = "https://www.exampleurl.com";
      } else {
          // Handle error if needed
          console.error("Form submission to Zapier failed");
      }
  })
  .catch(error => {
      // Handle fetch error if needed
      console.error("Error during form submission:", error);
  });
});

function validateForm() {

  addDatetime();    
  console.log(document.getElementById("datetime").value);
  // Perform custom validation here
  // Check if required fields are filled out
  var requiredFields = ["first_name", "last_name", "email", "phone", "company"];
  var emptyFields = [];
  var invalidEmailField = [];
  var invalidZipField = [];

  for (var field of requiredFields) {
      var element = document.getElementById(field);
      var value = element.value.trim();

      // Check email format
      if (field === "email" && !isValidEmail(value)) {
          invalidEmailField.push(field);
      }
  }

  if (emptyFields.length > 0) {
      alert("Bitte füllen Sie alle Felder aus.");
      return false;
  }

  if (invalidEmailField.length > 0) {
      alert("Bitte hinterlegen Sie eine gültige Email-Adresse.")
      return false;
  }

  return true;
}

function isValidEmail(email) {
  // Regular expression for basic email format validation
  var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function addDatetime() {
  //Get datetime as ISO string
  const datetime = new Date().toISOString();

  //Set datetime to field value
  document.getElementById('datetime').value = datetime;
        }