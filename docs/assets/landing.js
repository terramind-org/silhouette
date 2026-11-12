// The landing page loads the way the library does: its copy waits as a skeleton of itself,
// measured from its own markup, then comes in. Skullet (MIT, Lochie Axon) does the web side.
import { Reveal } from "./vendor/skullet/skullet.mjs";

const root = document.documentElement;
const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
// Skullet draws its panes inside the element, so it starts empty and is given the markup.
const parts = still ? [] : [...document.querySelectorAll("[data-loads]")].map((el) => {
  const html = el.innerHTML;
  el.replaceChildren();
  return { el, html, reveal: new Reveal(el, { label: "Loading" }) };
});

// As if the page's own data were on its way: long enough to see the shape, short enough
// not to keep anyone waiting.
const BEAT = 900;

// Fresh nodes each time: Skullet lays them out unseen to measure the skeleton.
const nodes = (html) => document.createRange().createContextualFragment(html);

function play() {
  for (const p of parts) p.reveal.load(nodes(p.html));
  root.classList.remove("landing-wait");
  setTimeout(() => {
    for (const p of parts) {
      p.reveal.show(nodes(p.html));
      window.SilhouetteWireInstall?.(p.el);
    }
  }, BEAT);
}

if (parts.length === 0) {
  root.classList.remove("landing-wait");
} else {
  play();
  // The mark is a skeleton itself: press it to watch the page load again.
  document.querySelector(".top .brand")?.addEventListener("click", (event) => {
    event.preventDefault();
    scrollTo({ top: 0, behavior: "smooth" });
    play();
  });
}
