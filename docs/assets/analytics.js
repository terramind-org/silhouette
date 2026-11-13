// Silhouette's analytics: Tag Manager GTM-WWGHW69G (Google Analytics G-FKDMZXW8MH), Consent Mode v2.
// The head of each page sets the consent defaults before Tag Manager loads (denied in the EEA,
// Iceland, Liechtenstein, Norway, the UK and Switzerland; granted elsewhere) and applies a stored
// choice. This file shows the cookie banner to visitors in those countries (by time zone) until they
// choose, and sends cta_click {placement, destination} for every tracked link.
(function () {
  var KEY = "sil:consent";
  var ZONES = ["Europe/Vienna","Europe/Brussels","Europe/Sofia","Europe/Zagreb","Asia/Nicosia","Asia/Famagusta","Europe/Nicosia","Europe/Prague","Europe/Copenhagen","Europe/Tallinn","Europe/Helsinki","Europe/Mariehamn","Europe/Paris","Europe/Berlin","Europe/Busingen","Europe/Athens","Europe/Budapest","Europe/Dublin","Eire","Europe/Rome","Europe/Riga","Europe/Vilnius","Europe/Luxembourg","Europe/Malta","Europe/Amsterdam","Europe/Warsaw","Poland","Europe/Lisbon","Portugal","Atlantic/Madeira","Atlantic/Azores","Europe/Bucharest","Europe/Bratislava","Europe/Ljubljana","Europe/Madrid","Africa/Ceuta","Atlantic/Canary","Europe/Stockholm","Atlantic/Reykjavik","Iceland","Europe/Vaduz","Europe/Oslo","Arctic/Longyearbyen","Atlantic/Jan_Mayen","Europe/London","Europe/Belfast","GB","GB-Eire","Europe/Zurich"];
  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }

  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[data-placement]");
    if (a) window.dataLayer.push({ event: "cta_click", placement: a.dataset.placement, destination: a.dataset.destination || null });
  });

  var stored = null;
  try { stored = localStorage.getItem(KEY); } catch (e) {}
  var tz = "";
  try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone; } catch (e) {}
  var force = /[?&]consent=show\b/.test(location.search);
  if (!force && (stored || ZONES.indexOf(tz) < 0)) return;

  function choose(granted) {
    var v = granted ? "granted" : "denied";
    try { localStorage.setItem(KEY, v); } catch (e) {}
    gtag("consent", "update", { analytics_storage: v, ad_storage: v, ad_user_data: v, ad_personalization: v });
    bar.remove();
  }
  var bar = document.createElement("div");
  bar.className = "consent";
  bar.setAttribute("role", "dialog");
  bar.setAttribute("aria-label", "Cookies");
  bar.innerHTML = '<p>Cookies count visits, so we know what to build next. Your call.</p><div><button type="button" data-c="0">Reject all</button><button type="button" data-c="1">Accept all</button></div>';
  bar.addEventListener("click", function (e) { var b = e.target.closest("button"); if (b) choose(b.dataset.c === "1"); });
  function show() { document.body.appendChild(bar); }
  if (document.body) show(); else document.addEventListener("DOMContentLoaded", show);
})();
