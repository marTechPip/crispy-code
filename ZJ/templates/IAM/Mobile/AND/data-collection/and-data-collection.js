$('.dot').on('click', function() {
  var target = $(this).data('target');
  $('.dot, .slide').removeClass('active');
  $(this).addClass('active');
  $('#' + target).addClass('active');
});

$(function() {
  var xStart = null;

  $('.slideshow').on('touchstart', function(event) {
      const firstTouch = event.originalEvent.touches[0];
      xStart = firstTouch.clientX;
  });

  $('.slideshow').on('touchmove', function(event) {
      if (!xStart) {
          return;
      }

      var xDiff = xStart - event.originalEvent.touches[0].clientX;
      xStart = null;

      var $activeDot = $('.dot.active');
      var $prevDot = $activeDot.prev('.dot');
      var $nextDot = $activeDot.next('.dot');

      if (xDiff > 0 && $nextDot.length > 0) {
          // Left swipe - move to next slide
          changeSlide($nextDot);
      } else if (xDiff < 0 && $prevDot.length > 0) {
          // Right swipe - move to previous slide
          changeSlide($prevDot);
      }
  });

  function changeSlide($dot) {
      $('.dot, .slide').removeClass('active');
      $dot.addClass('active');
      $('#' + $dot.data('target')).addClass('active');
  }
});