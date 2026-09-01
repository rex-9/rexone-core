(function () {
  var FORMAT = {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  };
  var UTC_CLOCK = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})(?:\.\d+)?(?:Z)?$/;

  function formatLocal(date) {
    return date.toLocaleString(undefined, FORMAT);
  }

  function localizeTimeElement(element, value) {
    if (!value) return;

    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return;

    element.textContent = formatLocal(date);
    element.title = value + " (UTC)";
    element.dataset.localized = "true";
  }

  function localizeUtcClockText(root) {
    var scope = root.querySelector(".solid-web-ui") || root;
    if (!scope.querySelectorAll) return;

    scope.querySelectorAll("td, dd, li, p, span, div").forEach(function (element) {
      if (element.dataset.localized === "true") return;
      if (element.closest("script, style, textarea, pre, code, a")) return;
      if (element.querySelector("a, time, table, ul, ol, pre, code")) return;

      var text = "";
      for (var i = 0; i < element.childNodes.length; i++) {
        if (element.childNodes[i].nodeType === 3) text += element.childNodes[i].nodeValue;
      }
      text = text.trim();
      if (!UTC_CLOCK.test(text)) return;

      var date = new Date(text.replace(" ", "T") + "Z");
      if (Number.isNaN(date.getTime())) return;

      element.textContent = formatLocal(date);
      element.title = text + " (UTC)";
      element.dataset.localized = "true";
    });
  }

  function localizeAdminTimes(root) {
    root.querySelectorAll("time.admin-local-time[datetime]").forEach(function (element) {
      localizeTimeElement(element, element.getAttribute("datetime"));
    });

    root.querySelectorAll(".local-time[data-utc]").forEach(function (element) {
      localizeTimeElement(element, element.getAttribute("data-utc"));
    });

    localizeUtcClockText(root);
  }

  function boot(event) {
    var root = document;
    if (event && event.target && event.target.querySelectorAll && event.target !== document) {
      root = event.target;
    }
    localizeAdminTimes(root);
  }

  document.addEventListener("DOMContentLoaded", boot);
  document.addEventListener("turbo:load", boot);
  document.addEventListener("turbo:frame-load", boot);
  document.addEventListener("turbo:render", boot);

  if (document.readyState !== "loading") {
    boot();
  }
})();
