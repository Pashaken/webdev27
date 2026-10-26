(function () {
  var interval = null;

  function format(total) {
    var minutes = String(Math.floor(total / 60)).padStart(2, "0");
    var seconds = String(total % 60).padStart(2, "0");
    return minutes + ":" + seconds;
  }

  function refresh() {
    if (window.refreshGame) {
      window.refreshGame();
    } else {
      location.reload();
    }
  }

  function start() {
    if (interval) clearInterval(interval);
    interval = null;

    var elements = document.querySelectorAll(".clock.is-running[data-seconds]");
    if (!elements.length) return;

    var startedAt = Date.now();
    var expired = false;
    var timers = Array.prototype.map.call(elements, function (element) {
      return { element: element, seconds: parseInt(element.dataset.seconds, 10) };
    });

    interval = setInterval(function () {
      var elapsed = Math.floor((Date.now() - startedAt) / 1000);

      timers.forEach(function (timer) {
        var left = Math.max(timer.seconds - elapsed, 0);
        timer.element.textContent = format(left);
        timer.element.classList.toggle("is-low", left < 30);

        if (left === 0 && !expired) {
          expired = true;
          setTimeout(refresh, 1000);
        }
      });
    }, 250);
  }

  window.startClocks = start;
  start();
})();
