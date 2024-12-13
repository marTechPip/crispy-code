// Add this function to open the iOS settings
function openIosSettings() {
  // Replace the following URL with the appropriate URL scheme for opening the iOS settings
  const iosSettingsURL = "app-settings:NOTIFICATIONS";
  window.location.href = iosSettingsURL;
}

const iosCtaButton = document.getElementById("ios-cta");
iosCtaButton.addEventListener("click", openIosSettings);

const carousel = document.querySelector(".carousel");
const slides = document.querySelectorAll(".slide");
const slideCount = slides.length;
let activeSlide = 0;

function showSlide(index) {
  slides.forEach((slide, i) => {
    slide.style.display = i === index ? "block" : "none";
  });
}

function nextSlide() {
  activeSlide = (activeSlide + 1) % slideCount;
  showSlide(activeSlide);
}

function prevSlide() {
  activeSlide = (activeSlide - 1 + slideCount) % slideCount;
  showSlide(activeSlide);
}

carousel.addEventListener("click", (event) => {
  const target = event.target;
  if (target.classList.contains("next")) {
    nextSlide();
  } else if (target.classList.contains("prev")) {
    prevSlide();
  }
});

showSlide(activeSlide);
