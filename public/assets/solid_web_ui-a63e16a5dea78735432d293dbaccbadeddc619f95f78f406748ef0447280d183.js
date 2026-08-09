// Live auto-refresh for the Solid* dashboards.
//
// Self-contained, dependency-free. Drives the controls rendered by
// SolidWebUi::Ui::RefreshControlsComponent: a frequency <select>, a countdown
// and a manual "refresh now" button. On each tick it reloads the dashboard's
// turbo-frame (morph, when Turbo is on the page) or falls back to fetch+replace.
//
// Linked via solid_web_ui_head_tags. The IIFE runs once per Turbo session (the
// asset is data-turbo-track="reload", so Turbo navigations don't re-execute it).
// A single module-level timer ticks for the whole session, re-reading the DOM
// each tick — so it never holds references to elements replaced by a navigation
// and never leaks timers/listeners across pages. Per-panel <select>/button
// handlers are bound once via a data flag.
(function () {
  "use strict";

  var TICK_MS = 250;
  var SELECT = "[data-swui-refresh-select]";
  var STATUS = "[data-swui-refresh-status]";
  var NOW = "[data-swui-refresh-now]";

  // nextAt timestamp per panel element; a WeakMap so detached panels are GC'd.
  var nextAt = new WeakMap();

  function intervalOf(panel) {
    var select = panel.querySelector(SELECT);
    return select ? (parseInt(select.value, 10) || 0) : 0;
  }

  function schedule(panel) {
    var seconds = intervalOf(panel);
    nextAt.set(panel, seconds > 0 ? Date.now() + seconds * 1000 : 0);
  }

  function reloadFrame(frameId) {
    var frame = document.getElementById(frameId);
    if (!frame) return;
    if (typeof frame.reload === "function") {
      // Real <turbo-frame>: reload its OWN current src, which Turbo keeps in sync
      // as the user navigates within the frame (stat cards, filter tabs, pages) —
      // so a refresh re-fetches the view on screen, never snapping back to the
      // page first loaded. Morphs in place when the frame carries refresh="morph".
      // First refresh on a page with no src yet: seed it from the current URL.
      if (frame.getAttribute("src")) {
        frame.reload();
      } else {
        frame.setAttribute("src", window.location.href);
      }
      return;
    }
    // Fallback (no Turbo): frames are inert, so in-frame links navigate the whole
    // page — the frame's current URL is just the document's. Fetch and swap.
    var url = frame.getAttribute("src") || window.location.href;
    fetch(url, { headers: { "X-Requested-With": "XMLHttpRequest" }, credentials: "same-origin" })
      .then(function (r) {
        if (!r.ok) throw new Error("refresh failed: " + r.status);
        return r.text();
      })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, "text/html");
        var incoming = doc.getElementById(frameId);
        if (incoming) frame.innerHTML = incoming.innerHTML;
      })
      .catch(function () { /* transient error — keep the last view, retry next tick */ });
  }

  function refreshNow(panel) {
    reloadFrame(panel.dataset.frame);
    schedule(panel);
  }

  function render(panel) {
    var status = panel.querySelector(STATUS);
    if (!status) return;
    if (intervalOf(panel) <= 0) { status.textContent = "Auto-refresh off"; return; }
    if (document.hidden) { status.textContent = "Paused"; return; }
    var remaining = Math.max(0, Math.ceil(((nextAt.get(panel) || 0) - Date.now()) / 1000));
    status.textContent = "Next refresh in " + remaining + "s";
  }

  // Bind the per-panel handlers exactly once (the flag survives an immediate
  // DOMContentLoaded+turbo:load double-fire on the same element).
  function bind(panel) {
    if (panel.dataset.swuiRefreshReady === "1") return;
    panel.dataset.swuiRefreshReady = "1";

    var select = panel.querySelector(SELECT);
    var storageKey = panel.dataset.storageKey;
    if (select && storageKey) {
      var stored = null;
      try { stored = window.localStorage.getItem(storageKey); } catch (e) { stored = null; }
      var offered = Array.prototype.some.call(select.options, function (o) { return o.value === stored; });
      if (stored !== null && offered) select.value = stored;
      select.addEventListener("change", function () {
        try { window.localStorage.setItem(storageKey, select.value); } catch (e) { /* ignore */ }
        schedule(panel);
        render(panel);
      });
    }
    var nowBtn = panel.querySelector(NOW);
    if (nowBtn) nowBtn.addEventListener("click", function () { refreshNow(panel); render(panel); });

    schedule(panel);
    render(panel);
  }

  function bindAll() {
    Array.prototype.forEach.call(document.querySelectorAll("[data-swui-refresh]"), bind);
  }

  // One timer for the whole session: re-reads the DOM each tick, so it always
  // operates on the panels currently on the page (and does nothing when there
  // are none) without retaining stale element references.
  function tick() {
    Array.prototype.forEach.call(document.querySelectorAll("[data-swui-refresh]"), function (panel) {
      if (!nextAt.has(panel)) schedule(panel);
      if (intervalOf(panel) > 0 && !document.hidden && Date.now() >= nextAt.get(panel)) refreshNow(panel);
      render(panel);
    });
  }

  document.addEventListener("DOMContentLoaded", bindAll);
  document.addEventListener("turbo:load", bindAll);
  window.setInterval(tick, TICK_MS);
})();

// Clickable table rows: a row carrying data-swui-row-href navigates to that URL.
// A single delegated listener (bound once, survives frame morphs). Clicks on an
// inner link/button keep their own behaviour, and modified/middle clicks are left
// to the browser so "open in new tab" still works via the row's ID link.
(function () {
  "use strict";

  document.addEventListener("click", function (event) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey ||
        event.ctrlKey || event.shiftKey || event.altKey) return;
    if (event.target.closest("a, button, input, label, select, textarea")) return;

    var row = event.target.closest("tr[data-swui-row-href]");
    if (!row) return;

    var href = row.getAttribute("data-swui-row-href");
    if (href) window.location.assign(href);
  });
})();
