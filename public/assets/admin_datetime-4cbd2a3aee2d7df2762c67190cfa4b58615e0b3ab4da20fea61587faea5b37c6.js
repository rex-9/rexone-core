(function () {
  var FORMAT = {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  };

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

  function localizeAdminTimes(root) {
    root.querySelectorAll("time.admin-local-time[datetime]").forEach(function (element) {
      localizeTimeElement(element, element.getAttribute("datetime"));
    });

    root.querySelectorAll(".local-time[data-utc]").forEach(function (element) {
      localizeTimeElement(element, element.getAttribute("data-utc"));
    });
  }

  function boot(event) {
    var root = event && event.target && event.target.querySelectorAll ? event.target : document;
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
