// The landing page is a wall of things loading: every piece waits as a skeleton of itself,
// measured from its own markup, and the whole wall comes in under one sweep. Now and then it
// all loads again, the way an app refreshes. Skullet (MIT, Lochie Axon) does the web side;
// Silhouette does the same in SwiftUI.
import { Reveal, applyTheme, forgetShapes } from "./vendor/skullet/skullet.mjs";

const root = document.documentElement;
// ?static shows the page as it is and ?hold keeps it loading: for checking that every skeleton
// sits exactly on what it stands for.
const params = new URLSearchParams(location.search);
const still = params.has("static") || matchMedia("(prefers-reduced-motion: reduce)").matches;
const hold = params.has("hold");
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
// Fresh nodes each time: Skullet lays them out unseen to measure the skeleton.
const nodes = (html) => document.createRange().createContextualFragment(html);

// Skullet remembers each skeleton's shape. Without an id it keys the shape off the markup's
// structure, and two cards built alike (a picture beside a few lines) would share one: each
// card keys its own. Shapes from earlier visits are dropped, so a changed page never starts
// from an old one.
forgetShapes();
// Each line's bar runs from the cap height to the baseline: it covers the letters, not the
// air above and below them.
applyTheme({ text: { top: "cap-height", bottom: "baseline" } }, "dark");

function take(el, key) {
  const html = `<div class="in">${el.innerHTML}</div>`;
  el.replaceChildren();
  return { el, html, reveal: new Reveal(el, { id: `landing-${key}`, reveal: "sweep", label: "Loading" }) };
}

function wireCopy(scope) {
  const button = scope.querySelector(".copy");
  const code = scope.querySelector(".install code");
  if (!button || !code) return;
  button.addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(`https://${code.textContent}`); } catch {}
    button.textContent = "Copied";
    button.classList.add("done");
    setTimeout(() => { button.textContent = "Copy"; button.classList.remove("done"); }, 1400);
  });
}

if (still) {
  for (const el of document.querySelectorAll("[data-piece], [data-loads]")) el.innerHTML = `<div class="in">${el.innerHTML}</div>`;
  root.classList.remove("waiting");
  wireCopy(document);
} else {
  const lead = take(document.querySelector("[data-loads]"), "lead");
  const pieces = [...document.querySelectorAll("[data-piece]")].map((el, i) => take(el, i));
  let run = 0;

  // Everything shown in one go lands in one sweep across the page.
  const load = (all) => all.forEach((p) => p.reveal.load(nodes(p.html)));
  const show = (all) => all.forEach((p) => p.reveal.show(nodes(p.html)));

  async function play() {
    const id = ++run;
    load([lead, ...pieces]);
    root.classList.remove("waiting");
    if (hold) return;
    await wait(1200);
    if (id !== run) return;
    show([lead, ...pieces]);
    wireCopy(lead.el);
    while (id === run) {
      await wait(7000);
      if (id !== run) return;
      load(pieces);
      await wait(1600);
      if (id !== run) return;
      show(pieces);
    }
  }

  // A skeleton is measured from the text as it will be set: wait for the page's own fonts (never
  // longer than a moment), or the bars would be laid out in a fallback face and miss the words.
  Promise.race([
    Promise.all([document.fonts.load('300 40px "Geist"'), document.fonts.load('400 15px "Geist"'), document.fonts.load('400 14px "Geist Mono"')]),
    wait(1200),
  ]).then(play);
  // The mark is a skeleton itself: press it to load the whole page again.
  document.querySelector(".brand")?.addEventListener("click", (event) => {
    event.preventDefault();
    scrollTo({ top: 0, behavior: "smooth" });
    play();
  });
}
