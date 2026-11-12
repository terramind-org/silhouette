// The landing page is a wall of things loading: every piece waits as a skeleton of itself,
// measured from its own markup, and the whole wall comes in under one sweep. Now and then it
// all loads again, the way an app refreshes. Skullet (MIT, Lochie Axon) does the web side;
// Silhouette does the same in SwiftUI.
import { Reveal } from "./vendor/skullet/skullet.mjs";

const root = document.documentElement;
const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
// Fresh nodes each time: Skullet lays them out unseen to measure the skeleton.
const nodes = (html) => document.createRange().createContextualFragment(html);

function take(el) {
  const html = `<div class="in">${el.innerHTML}</div>`;
  el.replaceChildren();
  return { el, html, reveal: new Reveal(el, { reveal: "sweep", label: "Loading" }) };
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
  const lead = take(document.querySelector("[data-loads]"));
  const pieces = [...document.querySelectorAll("[data-piece]")].map(take);
  let run = 0;

  // Everything shown in one go lands in one sweep across the page.
  const load = (all) => all.forEach((p) => p.reveal.load(nodes(p.html)));
  const show = (all) => all.forEach((p) => p.reveal.show(nodes(p.html)));

  async function play() {
    const id = ++run;
    load([lead, ...pieces]);
    root.classList.remove("waiting");
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

  play();
  // The mark is a skeleton itself: press it to load the whole page again.
  document.querySelector(".brand")?.addEventListener("click", (event) => {
    event.preventDefault();
    scrollTo({ top: 0, behavior: "smooth" });
    play();
  });
}
