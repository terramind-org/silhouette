// Silhouette docs: Swift highlighting, copy buttons, the contents menu and recordings.
// No dependencies, no build step.
(function () {
  "use strict";

  // ---------- Swift highlighting ----------

  var KEYWORDS = new Set((
    "import struct class enum protocol extension func var let static private public internal fileprivate " +
    "open final some any return if else guard switch case default for in while repeat break continue " +
    "where throws throw try await async do catch init self Self super nil true false inout mutating " +
    "nonmutating typealias associatedtype is as weak unowned lazy get set willSet didSet defer " +
    "operator subscript convenience required override indirect fallthrough"
  ).split(" "));

  var TOKEN = /(\$\d+)|(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|("(?:\\.|[^"\\\n])*")|(@[A-Za-z_]\w*)|(#[A-Za-z_]\w*)|(\b\d[\d_]*(?:\.\d+)?\b)|([A-Za-z_]\w*)/g;

  function escapeHTML(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function span(cls, text) {
    return '<span class="tok-' + cls + '">' + escapeHTML(text) + "</span>";
  }

  function highlightSwift(src) {
    var out = "";
    var last = 0;
    var m;
    TOKEN.lastIndex = 0;
    while ((m = TOKEN.exec(src))) {
      out += escapeHTML(src.slice(last, m.index));
      var t = m[0];
      if (m[1]) out += escapeHTML(t);
      else if (m[2]) out += span("com", t);
      else if (m[3]) out += span("str", t);
      else if (m[4] || m[5]) out += span("attr", t);
      else if (m[6]) out += span("num", t);
      else {
        var prev = src.charAt(m.index - 1);
        if (KEYWORDS.has(t) && prev !== ".") out += span("kw", t);
        else if (/^[A-Z]/.test(t)) out += span("type", t);
        else if (prev === ".") out += span("mem", t);
        else out += escapeHTML(t);
      }
      last = TOKEN.lastIndex;
    }
    return out + escapeHTML(src.slice(last));
  }

  window.SilhouetteHighlight = highlightSwift;

  function addCopyButton(container, getText) {
    var button = document.createElement("button");
    button.type = "button";
    button.className = "copy";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy code");
    button.addEventListener("click", function () {
      var text = getText();
      var done = function () {
        button.textContent = "Copied";
        button.classList.add("done");
        setTimeout(function () {
          button.textContent = "Copy";
          button.classList.remove("done");
        }, 1400);
      };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
      } else {
        fallbackCopy(text);
        done();
      }
    });
    container.appendChild(button);
    return button;
  }

  function fallbackCopy(text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(area);
  }

  window.SilhouetteCopy = addCopyButton;

  document.querySelectorAll(".code pre code").forEach(function (code) {
    var raw = code.textContent.replace(/^\n/, "").replace(/\s+$/, "");
    if (code.classList.contains("swift")) code.innerHTML = highlightSwift(raw);
    else code.textContent = raw;
    var box = code.closest(".code");
    if (!box.hasAttribute("data-no-copy")) addCopyButton(box, function () { return code.textContent; });
  });

  document.querySelectorAll(".install").forEach(function (box) {
    var code = box.querySelector("code");
    var button = addCopyButton(box, function () { return code.textContent; });
    button.setAttribute("aria-label", "Copy the package line");
  });

  // ---------- Heading anchors ----------

  document.querySelectorAll("section[id] > h2, h3[id]").forEach(function (h) {
    var id = h.id || h.parentElement.id;
    var a = document.createElement("a");
    a.className = "anchor";
    a.href = "#" + id;
    a.textContent = "#";
    a.setAttribute("aria-label", "Link to this section");
    h.appendChild(a);
  });

  // ---------- Contents: current section and the mobile menu ----------

  var mobileMenu = document.querySelector(".mobile-menu");
  var sideToc = document.querySelector(".sidebar .toc");
  if (mobileMenu && sideToc && !mobileMenu.children.length) {
    var copy = sideToc.cloneNode(true);
    copy.removeAttribute("aria-label");
    mobileMenu.appendChild(copy);
  }

  var links = Array.prototype.slice.call(document.querySelectorAll(".toc a[href^='#']"));
  if (links.length) {
    var ids = [];
    links.forEach(function (a) {
      var id = a.getAttribute("href").slice(1);
      if (ids.indexOf(id) < 0) ids.push(id);
    });
    var targets = ids.map(function (id) { return document.getElementById(id); }).filter(Boolean);
    var sidebar = document.querySelector(".sidebar");
    var current = null;

    var update = function () {
      var line = Math.min(160, window.innerHeight * 0.3);
      var active = targets[0];
      for (var i = 0; i < targets.length; i++) {
        if (targets[i].getBoundingClientRect().top - line <= 0) active = targets[i];
        else break;
      }
      if ((window.innerHeight + window.scrollY) >= document.documentElement.scrollHeight - 4) {
        active = targets[targets.length - 1];
      }
      if (!active || active === current) return;
      current = active;
      links.forEach(function (a) {
        var on = a.getAttribute("href") === "#" + active.id;
        a.classList.toggle("active", on);
        if (on) a.setAttribute("aria-current", "location");
        else a.removeAttribute("aria-current");
        if (on && sidebar && sidebar.contains(a)) {
          var top = a.offsetTop, bottom = top + a.offsetHeight;
          if (top < sidebar.scrollTop + 60 || bottom > sidebar.scrollTop + sidebar.clientHeight - 60) {
            sidebar.scrollTop = top - sidebar.clientHeight / 3;
          }
        }
      });
    };

    var queued = false;
    window.addEventListener("scroll", function () {
      if (queued) return;
      queued = true;
      requestAnimationFrame(function () { queued = false; update(); });
    }, { passive: true });
    window.addEventListener("resize", update);
    update();
  }

  var toggle = document.querySelector(".menu-toggle");
  var menu = document.querySelector(".mobile-menu");
  if (toggle && menu) {
    var setOpen = function (open) {
      menu.classList.toggle("open", open);
      toggle.setAttribute("aria-expanded", String(open));
      toggle.textContent = open ? "Close" : "Contents";
      document.body.style.overflow = open ? "hidden" : "";
    };
    toggle.addEventListener("click", function () { setOpen(!menu.classList.contains("open")); });
    menu.addEventListener("click", function (e) { if (e.target.closest("a")) setOpen(false); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") setOpen(false); });
  }

  // ---------- Recordings ----------

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  var videos = Array.prototype.slice.call(document.querySelectorAll(".clip video"));
  videos.forEach(function (v) {
    v.muted = true;
    // Once a recording is there, the waiting shimmer behind it can stop.
    v.addEventListener("loadeddata", function () { v.parentElement.classList.add("ready"); });
    if (reduce.matches) {
      v.removeAttribute("autoplay");
      v.controls = true;
      v.pause();
    }
  });
  if ("IntersectionObserver" in window && !reduce.matches) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var v = entry.target;
        if (entry.isIntersecting) {
          var p = v.play();
          if (p && p.catch) p.catch(function () {});
        } else {
          v.pause();
        }
      });
    }, { rootMargin: "200px 0px" });
    videos.forEach(function (v) { io.observe(v); });
  }
})();

// Live panels: segmented controls choose between pre-recorded clips.
(function () {
  document.querySelectorAll("[data-clips]").forEach(function (panel) {
    var video = panel.querySelector("video");
    var choice = {};
    panel.querySelectorAll(".segmented").forEach(function (group) {
      var pressed = group.querySelector('[aria-pressed="true"]');
      choice[group.dataset.key] = pressed ? pressed.dataset.value : "";
      group.addEventListener("click", function (event) {
        var button = event.target.closest("button");
        if (!button) return;
        group.querySelectorAll("button").forEach(function (b) { b.setAttribute("aria-pressed", String(b === button)); });
        choice[group.dataset.key] = button.dataset.value;
        var src = panel.dataset.clips.replace(/\{(\w+)\}/g, function (_, key) { return choice[key]; });
        video.src = src;
        video.play().catch(function () {});
      });
    });
  });
})();
