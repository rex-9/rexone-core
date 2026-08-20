(function () {
  function localizeAdminTimes(root) {
    root.querySelectorAll("time.admin-local-time[datetime]").forEach(function (element) {
      var value = element.getAttribute("datetime");
      if (!value) return;

      var date = new Date(value);
      if (Number.isNaN(date.getTime())) return;

      element.textContent = date.toLocaleString();
      element.title = value + " (UTC)";
    });
  }

  function boot() {
    localizeAdminTimes(document);
  }

  document.addEventListener("DOMContentLoaded", boot);
  document.addEventListener("turbo:load", boot);

  if (document.readyState !== "loading") {
    boot();
  }
})();
