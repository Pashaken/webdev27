(function () {
  var elements = document.querySelectorAll(".clock.is-running[data-seconds]");
  if (!elements.length) return;

  var startedAt = Date.now();
  var reloading = false;
  var timers = Array.prototype.map.call(elements, function (element) {
    return { element: element, seconds: parseInt(element.dataset.seconds, 10) };
  });

  function format(total) {
    var minutes = String(Math.floor(total / 60)).padStart(2, "0");
    var seconds = String(total % 60).padStart(2, "0");
    return minutes + ":" + seconds;
  }

  function tick() {
    var elapsed = Math.floor((Date.now() - startedAt) / 1000);

    timers.forEach(function (timer) {
      var left = Math.max(timer.seconds - elapsed, 0);
      timer.element.textContent = format(left);
      timer.element.classList.toggle("is-low", left < 30);

      if (left === 0 && !reloading) {
        reloading = true;
        setTimeout(function () { location.reload(); }, 1000);
      }
    });
  }

  setInterval(tick, 250);
})();
