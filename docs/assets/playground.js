// The theme playground: draws a card's skeleton on a canvas the way Silhouette does, and
// prints the SkeletonTheme that matches the controls.
(function () {
  "use strict";

  var root = document.getElementById("playground");
  if (!root) return;

  var canvas = root.querySelector("canvas");
  var stage = root.querySelector(".pg-stage");
  var codeEl = root.querySelector(".pg-code code");
  var ctx = canvas.getContext("2d");

  var FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif';
  // San Francisco's vertical metrics, as fractions of the point size.
  var METRICS = { ascender: 0.952, capHeight: 0.705, xHeight: 0.528, descender: 0.241, baseline: 0 };
  var LINE = METRICS.ascender + METRICS.descender; // SwiftUI sets lines with no extra leading.

  var DEFAULTS = {
    preview: window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light",
    light: { mode: "neutral", tint: "#5145d6", base: 7, highlight: 60 },
    dark: { mode: "neutral", tint: "#9d95ff", base: 8, highlight: 10 },
    animation: "shimmer",
    speed: "slow",
    angle: 20,
    radius: "auto",
    points: 4,
    top: "capHeight",
    bottom: "descender",
    xray: false
  };
  var BASELINE = { light: { base: 7, highlight: 60 }, dark: { base: 8, highlight: 10 } };

  var state = clone(DEFAULTS);

  function clone(o) { return JSON.parse(JSON.stringify(o)); }

  // ---------- Controls ----------

  function bindSegments() {
    root.querySelectorAll(".seg[data-key]").forEach(function (seg) {
      seg.addEventListener("click", function (e) {
        var b = e.target.closest("button");
        if (!b) return;
        var key = seg.getAttribute("data-key");
        if (key === "mode") {
          var sc = scheme();
          if (sc.mode !== b.value) {
            sc.mode = b.value;
            // A tint reads best a little stronger than neutral ink; neutral goes back to the defaults.
            var d = BASELINE[state.preview];
            sc.base = b.value === "tint" ? 12 : d.base;
            sc.highlight = b.value === "tint" ? (state.preview === "dark" ? 16 : 20) : d.highlight;
          }
        }
        else state[key] = b.value;
        sync();
      });
    });
    root.querySelectorAll("input[data-key]").forEach(function (input) {
      input.addEventListener("input", function () {
        var key = input.getAttribute("data-key");
        if (key === "base" || key === "highlight") scheme()[key] = Number(input.value);
        else if (key === "tint") scheme().tint = input.value;
        else if (key === "xray") state.xray = input.checked;
        else state[key] = Number(input.value);
        sync();
      });
    });
    root.querySelector(".pg-reset").addEventListener("click", function () {
      var preview = state.preview;
      state = clone(DEFAULTS);
      state.preview = preview;
      sync();
    });
  }

  function scheme() { return state[state.preview]; }

  function sync() {
    root.querySelectorAll(".seg[data-key]").forEach(function (seg) {
      var key = seg.getAttribute("data-key");
      var value = key === "mode" ? scheme().mode : state[key];
      seg.querySelectorAll("button").forEach(function (b) {
        b.setAttribute("aria-pressed", String(b.value === value));
      });
    });
    var s = scheme();
    setInput("base", s.base, s.base + "%");
    setInput("highlight", s.highlight, s.highlight + "%");
    setInput("angle", state.angle, state.angle + "°");
    setInput("points", state.points, state.points + " pt");
    root.querySelector("input[data-key='tint']").value = s.tint;
    root.querySelector("input[data-key='tint']").disabled = s.mode !== "tint";
    root.querySelector(".pg-points").hidden = state.radius !== "points";
    root.querySelector("input[data-key='xray']").checked = state.xray;
    stage.className = "pg-stage " + state.preview;
    printCode();
  }

  function setInput(key, value, label) {
    var input = root.querySelector("input[data-key='" + key + "']");
    if (input) input.value = value;
    var out = root.querySelector("output[data-for='" + key + "']");
    if (out) out.textContent = label;
  }

  // ---------- Swift ----------

  function swiftColour(hex) {
    var r = parseInt(hex.slice(1, 3), 16) / 255;
    var g = parseInt(hex.slice(3, 5), 16) / 255;
    var b = parseInt(hex.slice(5, 7), 16) / 255;
    return "Color(red: " + r.toFixed(2) + ", green: " + g.toFixed(2) + ", blue: " + b.toFixed(2) + ")";
  }

  function pct(n) { return String(+(n / 100).toFixed(2)); }

  function coloursCode(name) {
    var s = state[name];
    var d = BASELINE[name];
    if (s.mode === "tint") {
      return name + ": .tinted(" + swiftColour(s.tint) + ", base: " + pct(s.base) + ", highlight: " + pct(s.highlight) + ")";
    }
    if (s.base === d.base && s.highlight === d.highlight) return null;
    var ink = name === "light" ? ".black" : ".white";
    return name + ": .init(base: " + ink + ".opacity(" + pct(s.base) + "), highlight: .white.opacity(" + pct(s.highlight) + "))";
  }

  function printCode() {
    var args = [];
    var light = coloursCode("light");
    var dark = coloursCode("dark");
    if (light) args.push(light);
    if (dark) args.push(dark);
    if (state.animation !== "shimmer") args.push("animation: ." + state.animation);
    if (state.speed !== "slow") args.push("speed: ." + state.speed);
    if (state.angle !== 20) {
      var dir = state.angle === 0 ? ".leadingToTrailing" : state.angle === 90 ? ".topToBottom" : ".angle(.degrees(" + state.angle + "))";
      args.push("direction: " + dir);
    }
    if (state.radius === "pill") args.push("radius: .pill");
    if (state.radius === "points") args.push("radius: .points(" + state.points + ")");
    var text = [];
    if (state.top !== "capHeight") text.push("top: ." + state.top);
    if (state.bottom !== "descender") text.push("bottom: ." + state.bottom);
    if (text.length) args.push("text: SkeletonTextMetrics(" + text.join(", ") + ")");

    var src;
    if (!args.length) {
      src = "ContentView()\n    .skeletonTheme(SkeletonTheme())   // every option at its default";
    } else {
      src = "ContentView()\n    .skeletonTheme(SkeletonTheme(\n        " + args.join(",\n        ") + "\n    ))";
    }
    codeEl.innerHTML = window.SilhouetteHighlight ? window.SilhouetteHighlight(src) : src;
    codeEl.setAttribute("data-src", src);
  }

  // ---------- Drawing ----------

  var W = 400;
  var H = 334;

  var card = {
    avatar: { x: 20, y: 20, w: 44, h: 44 },
    name: { text: "Ada Lovelace", size: 17, weight: 600, x: 76, top: 21 },
    handle: { text: "@ada · Analyst · 2h", size: 13, weight: 400, x: 76, top: 44 },
    body: [
      "Wrote the first published program, for",
      "a machine that was never built, and saw",
      "it could do more than arithmetic."
    ],
    bodySize: 15,
    bodyTop: 82,
    image: { x: 20, y: 150, w: 360, h: 120, r: 12 },
    chips: ["Mathematics", "Engines"],
    chipTop: 286,
    box: { w: 72, h: 28 }
  };

  function radiusFor(h) {
    if (state.radius === "pill") return h / 2;
    if (state.radius === "points") return Math.min(h / 2, Math.max(0, state.points));
    return Math.min(h / 2, Math.max(2, h * 0.28));
  }

  function textBar(line, size, weight, x, lineTop) {
    ctx.font = weight + " " + size + "px " + FONT;
    var width = ctx.measureText(line).width;
    var baseline = lineTop + METRICS.ascender * size;
    var top = baseline - METRICS[state.top] * size;
    var bottom = baseline + METRICS[state.bottom] * size;
    return { x: x, y: top, w: width, h: bottom - top, text: line, size: size, weight: weight, baseline: baseline };
  }

  function pieces() {
    var list = [];
    var a = card.avatar;
    list.push({ kind: "circle", x: a.x, y: a.y, w: a.w, h: a.h });
    [card.name, card.handle].forEach(function (t) {
      var bar = textBar(t.text, t.size, t.weight, t.x, t.top);
      bar.kind = "text";
      list.push(bar);
    });
    card.body.forEach(function (line, i) {
      var bar = textBar(line, card.bodySize, 400, 20, card.bodyTop + i * LINE * card.bodySize);
      bar.kind = "text";
      list.push(bar);
    });
    var im = card.image;
    list.push({ kind: "rect", x: im.x, y: im.y, w: im.w, h: im.h, r: im.r });
    var x = 20;
    ctx.font = "500 13px " + FONT;
    card.chips.forEach(function (label) {
      var w = Math.round(ctx.measureText(label).width + 24);
      list.push({ kind: "rect", x: x, y: card.chipTop, w: w, h: 28, r: 14, label: label });
      x += w + 8;
    });
    // A SkeletonBox: it takes the theme's radius, like a line of text.
    list.push({ kind: "box", x: W - 20 - card.box.w, y: card.chipTop, w: card.box.w, h: card.box.h });
    return list;
  }

  function roundRect(x, y, w, h, r) {
    r = Math.max(0, Math.min(r, h / 2, w / 2));
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function rgba(hex, alpha) {
    var r = parseInt(hex.slice(1, 3), 16);
    var g = parseInt(hex.slice(3, 5), 16);
    var b = parseInt(hex.slice(5, 7), 16);
    return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
  }

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  function draw(now) {
    var dpr = window.devicePixelRatio || 1;
    if (canvas.width !== W * dpr) {
      canvas.width = W * dpr;
      canvas.height = H * dpr;
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    var dark = state.preview === "dark";
    ctx.fillStyle = dark ? "#000" : "#fff";
    ctx.fillRect(0, 0, W, H);

    var s = scheme();
    var ink = s.mode === "tint" ? s.tint : (dark ? "#ffffff" : "#000000");
    var shine = s.mode === "tint" ? s.tint : "#ffffff";
    var list = pieces();

    if (state.xray) {
      ctx.fillStyle = dark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)";
      list.forEach(function (p) {
        if (p.kind === "text") {
          ctx.font = p.weight + " " + p.size + "px " + FONT;
          ctx.fillText(p.text, p.x, p.baseline);
        }
      });
    }

    ctx.save();
    ctx.beginPath();
    list.forEach(function (p) {
      if (p.kind === "circle") {
        ctx.moveTo(p.x + p.w, p.y + p.h / 2);
        ctx.arc(p.x + p.w / 2, p.y + p.h / 2, p.w / 2, 0, Math.PI * 2);
      } else if (p.kind === "text" || p.kind === "box") {
        roundRect(p.x, p.y, p.w, p.h, radiusFor(p.h));
      } else {
        roundRect(p.x, p.y, p.w, p.h, p.r);
      }
    });
    ctx.clip();
    ctx.globalAlpha = state.xray ? 0.75 : 1;
    ctx.fillStyle = rgba(ink, s.base / 100);
    ctx.fillRect(0, 0, W, H);

    var highlight = s.highlight / 100;
    var animation = state.animation;
    if (reduceMotion.matches && (animation === "shimmer" || animation === "groupShimmer")) animation = "pulse";
    var t = now / 1000;

    if (animation === "pulse") {
      var period = { slow: 2.4, normal: 1.8, fast: 1.2 }[state.speed] * (reduceMotion.matches ? 1.5 : 1);
      var amount = (0.5 - 0.5 * Math.cos(2 * Math.PI * ((t % period) / period))) * (reduceMotion.matches ? 0.7 : 1);
      ctx.fillStyle = rgba(shine, highlight * amount);
      ctx.fillRect(0, 0, W, H);
    } else if (animation !== "none") {
      var loop = { slow: 4, normal: 3, fast: 2 }[state.speed];
      var pace = 1280 / (0.7 * loop);
      var band = Math.min(Math.max(W * 0.4, 80), 320);
      var rad = state.angle * Math.PI / 180;
      var ax = Math.cos(rad), ay = Math.sin(rad);
      var extent = Math.abs(W * ax) + Math.abs(H * ay);
      var group = animation === "groupShimmer";
      var span = group ? extent + band * 2 : band * 2.5;
      var phase = (t % (span / pace)) / (span / pace);
      var start = group ? Math.min(0, W * ax) + Math.min(0, H * ay) - band : 0;
      var head = start + phase * span;
      var along = [0, W * ax, H * ay, W * ax + H * ay];
      var low = Math.min.apply(null, along), high = Math.max.apply(null, along);
      var ramp = [[0, 0], [0.18, 0.12], [0.34, 0.45], [0.5, 1], [0.66, 0.45], [0.82, 0.12], [1, 0]];
      for (var k = Math.floor((low - band - head) / span); head + k * span <= high + band; k++) {
        var c = head + k * span;
        var from = c - band / 2, to = c + band / 2;
        var g = ctx.createLinearGradient(from * ax, from * ay, to * ax, to * ay);
        ramp.forEach(function (r) { g.addColorStop(r[0], rgba(shine, highlight * r[1])); });
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, W, H);
      }
    }
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  var visible = true;
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (entries) { visible = entries[0].isIntersecting; }).observe(canvas);
  }
  function frame(now) {
    if (visible) draw(Date.now());
    requestAnimationFrame(frame);
  }

  bindSegments();
  sync();
  canvas.style.aspectRatio = W + " / " + H;
  requestAnimationFrame(frame);
})();
