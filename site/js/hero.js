// hero (owner: hero builder). SPEC §J hero: the example panel hanging from the menu bar pebble.
// Mounts the live panel on the one example store, holds its heavy height through done (a full payoff frame),
// centres the face’s light on the panel’s head, links its face to the menu bar face, perks Tidy up once,
// and folds the panel into the pebble while it is still in full view (state re-derived on every scroll frame).
export default function init({ utils, Component }) {
  const hero = document.getElementById("hero");
  const host = document.getElementById("hero-panel");
  const hang = hero?.querySelector(".hero__hang");
  const col = hero?.querySelector(".hero__panel-col");
  if (!hero || !host || !hang || !col) return;

  const { store } = utils;
  const offs = [];
  const reduced = () => utils.reduced;
  const isBig = (p) => p === "done" || p === "calm";

  // ---- Before the panel renders a new phase (subscribed first, so the old DOM is still there):
  //      hold the heavy height when it leaves heavy, drop the hold when it comes back, FLIP the face. -------
  let panel = null, heavyH = 0;
  offs.push(store.example.subscribe((s) => {
    const el = panel?.el;
    if (!el || el.dataset.phase === s.phase) return;
    if (s.phase === "heavy") el.style.removeProperty("--yf-hold");
    else if (el.dataset.phase === "heavy") {
      const h = store.get().knowOpen ? heavyH : el.offsetHeight;
      if (h) el.style.setProperty("--yf-hold", `${h}px`);
    }
    if (reduced() || isBig(el.dataset.phase) === isBig(s.phase)) return;
    const face = el.querySelector(".yf-panel__face");
    const a = face.getBoundingClientRect();
    queueMicrotask(() => {
      const b = face.getBoundingClientRect();
      if (!b.width) return;
      const k = a.width / b.width;
      face.animate([
        { transformOrigin: "0 0", transform: `translate(${a.left - b.left}px, ${a.top - b.top}px) scale(${k})` },
        { transformOrigin: "0 0", transform: "none" },
      ], { duration: 520, easing: "cubic-bezier(.16, 1, .3, 1)" });
    });
  }));

  panel = Component.mountPanel(host, { store: store.example, mode: "hero", id: "yf-panel-hero" });
  host._yfPanel = panel; // main.js perks it when the menu bar pebble is pressed while it is on screen
  const barBtn = utils.menubar?.button;
  const barPebble = utils.menubar?.pebble;
  const barEl = document.querySelector(".menubar");

  // ---- Measure: the heavy height (for a hold taken with Good to know open), the stem, the light ---------
  const measure = (resized) => {
    const s = store.get();
    if (s.phase === "heavy" && !s.knowOpen) heavyH = panel.el.offsetHeight;
    // a new width means a new heavy height: let the hold go; the next heavy → working takes it again
    if (resized && s.phase !== "heavy") panel.el.style.removeProperty("--yf-hold");
    if (barBtn) {
      const b = barBtn.getBoundingClientRect(), hr = hang.getBoundingClientRect();
      const x = Math.round(b.left + b.width / 2 - hr.left);
      hang.style.setProperty("--stem-x", `${Math.max(24, Math.min(hr.width - 24, x))}px`);
      hang.toggleAttribute("data-stem", innerWidth > 720 && x > 12 && x < hr.width - 12);
    }
    const h = hero.getBoundingClientRect(), p = panel.el.getBoundingClientRect();
    if (p.width) {
      hero.style.setProperty("--haze-x", `${Math.round(p.left - h.left + p.width * 0.4)}px`);
      hero.style.setProperty("--haze-y", `${Math.round(p.top - h.top + 60)}px`);
    }
  };
  measure(false);
  // First load, desktop: the panel opens out of the menu bar pebble once (the fold verb, 360 ms); the page under
  // it is already complete. Skipped under reduced motion, at phone width, or when the page loads scrolled.
  if (barBtn && !reduced() && hang.hasAttribute("data-stem") && scrollY < 40 && matchMedia("(min-width: 721px)").matches) {
    hang.style.opacity = "0";
    requestAnimationFrame(() => utils.fold(hang, barBtn, true).then(() => { hang.style.opacity = ""; }));
  }
  document.fonts?.ready.then(() => measure(false));

  // ---- Once, after load + 1.2 s idle: the two faces perk together and Tidy up perks with them (the cue that
  //      the panel is pressable, on the button itself); then the header face breathes ---------------------
  let perkT = 0;
  const linkFaces = () => {
    perkT = setTimeout(() => {
      const s = store.get();
      if (hero.getBoundingClientRect().bottom > 0 && s.heroOpen) {
        barPebble?.perk(); panel.perk();
        const pill = panel.el.querySelector('.yf-pill[data-act="tidy"]');
        if (pill && s.phase === "heavy" && !s.touched && !reduced()) utils.perk(pill, { from: 0.94 });
      }
      panel.face?.breathe?.(true);
    }, 1200);
  };
  if (document.readyState === "complete") linkFaces();
  else addEventListener("load", linkFaces, { once: true });

  // ---- Scroll away: fold into the pebble, open again on the way back (never scrubbed) ------------------
  // Re-derived from geometry on every scroll frame, so a jump (Home, #top, a flick) always lands right.
  // Desktop: it folds once less than 15 % of the panel is still below the menu bar; phone (where the panel is
  // most of a screen tall): only once it is wholly under the bar. Either way folding never leaves a hole of
  // blank paper where the panel was, and scrolling back it opens again as it comes into view. The column's
  // bottom is the panel's bottom (no travel spacer), and it ignores the fold's own transforms.
  const phone = matchMedia("(max-width: 720px)");
  const isAway = () => {
    const c = col.getBoundingClientRect(), H = hang.offsetHeight, bar = barEl?.getBoundingClientRect().bottom ?? 0;
    return c.bottom - H * (phone.matches ? 0 : 0.15) < bar;
  };
  let first = true;
  const setOpen = (open, animate) => {
    if (store.get().heroOpen === open) return;
    // never pull the floor from under a keyboard or screen-reader user: focus moves to the pebble the panel
    // folds into (it stands for the panel now) before the panel goes inert
    if (!open && hang.contains(document.activeElement)) barBtn?.focus({ preventScroll: true });
    store.dispatch({ type: "hero", open });
    hang.setAttribute("aria-hidden", String(!open));
    hang.inert = !open;
    if (!animate) { hang.style.visibility = open ? "" : "hidden"; hang.style.opacity = open ? "" : "0"; return; }
    hang.style.visibility = ""; hang.style.opacity = "";
    utils.fold(hang, barBtn, open);
    if (!open) barPebble?.perk();
  };
  let sraf = 0;
  const sync = () => { sraf = 0; if (!barBtn) return; setOpen(!isAway(), !first); first = false; };
  const onScroll = () => { if (!sraf) sraf = requestAnimationFrame(sync); };
  const onHash = () => { if (location.hash === "#top" || location.hash === "") setOpen(true, true); onScroll(); };
  addEventListener("scroll", onScroll, { passive: true });
  addEventListener("hashchange", onHash);
  sync();

  let raf = 0;
  const onResize = () => { cancelAnimationFrame(raf); raf = requestAnimationFrame(() => { measure(true); sync(); }); };
  addEventListener("resize", onResize, { passive: true });

  // ---- While the hero gate is on screen it is the page's one ask: the nav Download steps back ----------
  const gate = hero.querySelector(".gate");
  const root = document.documentElement;
  let gio = null;
  if (gate && "IntersectionObserver" in window) {
    gio = new IntersectionObserver(([e]) => root.toggleAttribute("data-hero-gate", e.isIntersecting), { rootMargin: "-48px 0px 0px 0px" });
    gio.observe(gate);
  }

  return () => {
    clearTimeout(perkT);
    cancelAnimationFrame(raf);
    cancelAnimationFrame(sraf);
    removeEventListener("resize", onResize);
    removeEventListener("scroll", onScroll);
    removeEventListener("hashchange", onHash);
    offs.forEach((f) => f());
    gio?.disconnect();
    root.removeAttribute("data-hero-gate");
    panel.destroy();
  };
}
