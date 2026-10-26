(function () {
  var timer = null;
  var busy = false;

  function current() {
    return document.querySelector(".game");
  }

  function refresh() {
    if (busy) return Promise.resolve();
    busy = true;

    return fetch(location.href, { credentials: "same-origin", headers: { Accept: "text/html" } })
      .then(function (response) { return response.ok ? response.text() : null; })
      .then(function (html) {
        var next = html && new DOMParser().parseFromString(html, "text/html").querySelector(".game");
        if (!next) {
          location.reload();
          return;
        }

        current().replaceWith(next);
        start();
        if (window.startClocks) window.startClocks();
      })
      .catch(function () {})
      .then(function () { busy = false; });
  }

  function check() {
    var game = current();
    if (!game || !game.dataset.pollUrl) return;

    fetch(game.dataset.pollUrl, { credentials: "same-origin", headers: { Accept: "application/json" } })
      .then(function (response) { return response.ok ? response.json() : null; })
      .then(function (data) {
        var latest = current();
        if (data && latest && data.version !== latest.dataset.version) return refresh();
      })
      .catch(function () {});
  }

  function start() {
    if (timer) clearInterval(timer);

    var game = current();
    timer = game && game.dataset.pollUrl ? setInterval(check, 2000) : null;
  }

  window.refreshGame = refresh;
  start();
})();
