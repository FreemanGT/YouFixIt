// YouFixIt site runtime (architect). Wires motion (WAAPI, one ticker that sleeps when idle), native scroll,
// the reduced-motion switch, the one example store and its global views (menu bar pebble, popover, favicon,
// haze), the email gates and the star count; then mounts each section module present on the page:
//   export default function init({ gsap, lenis, reduced, utils, Component }) → optional cleanup
import * as store from "./lib/store.js";
import * as format from "./lib/format.js";
import * as config from "./lib/config.js";
import motionLib, { motion, onReducedChange, perk, hop, leave, arrive, fold, roll, D } from "./lib/motion.js";
import { renderPebble, breathe, glanceAt, pebbleOf, hydratePebbles } from "./lib/pebble.js";
import * as Component from "./lib/component.js";
import { followFavicon } from "./lib/favicon.js";
import { followMood } from "./lib/haze.js";
import { mountGate, quickDownload, isPhone } from "./lib/signup.js";
import { loadStars } from "./lib/stars.js";

const SECTIONS = ["hero", "finds", "never", "faq", "finale"];
const WITH_JS = ["hero", "finds", "never", "finale"]; // sections that own a js/<id>.js module
const html = document.documentElement;
html.classList.add("js");

// ---- Motion: WAAPI for the verbs; the component’s own rAF ticker for tweens stops when nothing animates. --
html.classList.toggle("reduced", motion.reduced);
onReducedChange((r) => html.classList.toggle("reduced", r));

// ---- Global views of the store -----------------------------------------------------------------------
const bar = {
  el: document.querySelector(".menubar"),
  button: document.querySelector(".menubar__pebble"),
  download: document.querySelector(".menubar__download"),
  popover: document.getElementById("popover"),
  pebble: null,
};
let popoverPanel = null;

if (bar.button) {
  bar.face = Component.mountBarFace(bar.button, { store: store.example }); // pose, count, "Example: " name + title
  bar.pebble = bar.face.pebble;
  followMood(store, bar.button.querySelector(".yf-pb") || bar.button);
  // A real download: the menu bar face hops once (SPEC §I.4).
  store.subscribe((s, p) => { if (s.downloads !== p.downloads) bar.pebble.hop(); });
}
followFavicon(store);
hydratePebbles(document.querySelector("main") || document);

// ---- Popover (the menu bar view of the example) ------------------------------------------------------
const heroPanel = () => document.getElementById("hero-panel");
function openPopover() {
  const pop = bar.popover;
  if (!pop || store.get().popoverOpen) return;
  if (!popoverPanel) {
    popoverPanel = Component.mountPanel(pop.querySelector(".popover__panel") || pop, { store: store.example, mode: "popover", onClose: () => closePopover() });
  }
  pop.hidden = false;
  store.dispatch({ type: "popover", open: true });
  bar.button.setAttribute("aria-expanded", "true");
  fold(pop, bar.button, true);
  requestAnimationFrame(() => (pop.querySelector("button:not([disabled]), [tabindex='0']") || pop).focus({ preventScroll: true }));
}
function closePopover({ returnFocus = true } = {}) {
  const pop = bar.popover;
  if (!pop || !store.get().popoverOpen) return;
  store.dispatch({ type: "popover", open: false });
  bar.button.setAttribute("aria-expanded", "false");
  fold(pop, bar.button, false).then(() => { if (!store.get().popoverOpen) pop.hidden = true; });
  if (returnFocus) bar.button.focus({ preventScroll: true });
}
bar.button?.addEventListener("click", () => {
  if (store.get().popoverOpen) return closePopover();
  const hp = heroPanel();
  if (store.get().heroOpen && hp && hp.getBoundingClientRect().bottom > 0) { // the panel is on screen: point at it
    (hp.querySelector("button:not([disabled])") || hp).focus({ preventScroll: false });
    hp._yfPanel?.perk?.() ?? perk(hp, { from: 0.985 });
    return;
  }
  openPopover();
});
document.addEventListener("keydown", (e) => { if (e.key === "Escape" && store.get().popoverOpen) closePopover(); });
// Non-modal popover: when focus leaves it (Tab past its last control), it folds away instead of covering the page.
bar.popover?.addEventListener("focusout", (e) => {
  const to = e.relatedTarget;
  if (!store.get().popoverOpen || !to) return;
  if (bar.popover.contains(to) || bar.button.contains(to)) return;
  closePopover({ returnFocus: false });
});
document.addEventListener("pointerdown", (e) => {
  if (!store.get().popoverOpen) return;
  if (bar.popover.contains(e.target) || bar.button.contains(e.target)) return;
  closePopover({ returnFocus: false });
});

// ---- Download pill + gates ---------------------------------------------------------------------------
const onDownload = () => store.dispatch({ type: "download" });
document.querySelectorAll("form.gate").forEach((f) => mountGate(f, { onDownload }));
bar.download?.addEventListener("click", (e) => {
  e.preventDefault();
  if (quickDownload({ onDownload })) return;
  const gates = [...document.querySelectorAll("form.gate")];
  if (!gates.length) return;
  // A gate already on screen (the hero’s, at the top) just takes focus; otherwise go to the nearest one.
  const dist = (g) => { const r = g.getBoundingClientRect(); return r.top < innerHeight && r.bottom > 0 ? -1 : Math.min(Math.abs(r.top), Math.abs(r.bottom - innerHeight)); };
  const gate = gates.reduce((a, b) => (dist(b) < dist(a) ? b : a));
  const input = gate.querySelector('input[type="email"]');
  if (dist(gate) < 0) { input?.focus({ preventScroll: false }); return; }
  gate.scrollIntoView({ block: "center", behavior: motion.reduced ? "auto" : "smooth" });
  input?.focus({ preventScroll: true });
});
loadStars();

// ---- Section registry --------------------------------------------------------------------------------
const utils = {
  store, format, config, motion: motionLib, D,
  perk, hop, leave, arrive, fold, roll,
  renderPebble, breathe, glanceAt, pebbleOf, hydratePebbles,
  menubar: bar, openPopover, closePopover, isPhone, onReducedChange,
  get reduced() { return motion.reduced; },
};
window.__yf = { store, utils }; // QA hook

const fontsReady = Promise.race([document.fonts?.ready ?? Promise.resolve(), new Promise((r) => setTimeout(r, 1500))]);
const cleanups = {};

// Section modules are modulepreloaded and fetched in parallel. The hero mounts at once (hero.js re-measures on
// fonts.ready itself) so Tidy up answers the first tap; the rest wait for fonts so their measurements hold.
const LOADERS = { hero: () => import("./hero.js"), finds: () => import("./finds.js"), never: () => import("./never.js"), finale: () => import("./finale.js") };
async function mount(id, modP) {
  try {
    const mod = await modP;
    const init = mod.default || mod.init;
    if (typeof init === "function") cleanups[id] = await init({ gsap: null, lenis: null, reduced: motion.reduced, utils, Component });
  } catch (e) { console.error(`[${id}] init failed`, e); }
}
async function boot() {
  const ids = SECTIONS.filter((id) => WITH_JS.includes(id) && document.getElementById(id));
  const mods = Object.fromEntries(ids.map((id) => [id, LOADERS[id]().catch((e) => { console.error(`[${id}] load failed`, e); return {}; })]));
  if (mods.hero) await mount("hero", mods.hero);
  await fontsReady;
  await Promise.all(ids.filter((id) => id !== "hero").map((id) => mount(id, mods[id])));
  // Keep the product alive even if hero.js hasn’t mounted it: hydrate the server-rendered hero panel.
  const hp = heroPanel();
  if (hp && !hp.classList.contains("yf-panel-host") && hp.querySelector(".yf-panel")) {
    hp._yfPanel = Component.mountPanel(hp, { store: store.example, mode: "hero", id: "yf-panel-hero" });
  }
  // The menu extra looks pressed while the hero panel hangs open under it (desktop, where the stem shows).
  const hang = heroPanel()?.closest(".hero__hang");
  const syncHang = () => bar.button?.toggleAttribute("data-hanging", !!(store.get().heroOpen && hang?.hasAttribute("data-stem")));
  store.subscribe((s, p) => { if (s.heroOpen !== p.heroOpen) syncHang(); });
  addEventListener("resize", () => requestAnimationFrame(syncHang), { passive: true });
  syncHang();
  html.classList.add("is-ready");
}
boot();
