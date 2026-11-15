// finale · the pebble is the full stop of "Free forever", and it remembers what you did (SPEC §finale).
// Not a control: no button, no click. Untouched it is the calm green face and glances once toward the gate
// (never the amber alarm on the gift moment);
// after a tidy it is green with the smile, hops once on entry and shows the caption; a download hops it.
export default function init({ utils }) {
  const section = document.getElementById("finale");
  const el = section?.querySelector(".finale__period");
  if (!el) return;
  const { store } = utils;
  const gate = section.querySelector(".gate__capsule") || section.querySelector(".gate");

  let smiled = false;            // a download started: the period keeps the smile
  const tidied = (s) => store.tidied(s);
  const mood = (s) => (tidied(s) || smiled ? "done" : "light");

  const p = utils.renderPebble(el, { variant: "bar", pose: mood(store.get()) });
  p.breathe(true);               // the face’s own blink, on screen only

  let seen = false, visible = false, glanced = false, hopPending = false;

  const paint = (s, animate) => {
    const m = mood(s);
    section.dataset.state = tidied(s) ? "done" : "idle";
    section.dataset.mood = m;
    if (p.poseName === m) return;
    if (animate && visible) p.show(m);   // the app’s own entrance: done hops in, smiles, hops once
    else p.to(m, { ease: "none" });
  };

  // Called once per entry into view (40 %).
  const onEnter = () => {
    const s = store.get();
    if (utils.reduced) return;
    if (tidied(s) || smiled) {
      if (hopPending || !seen) { hopPending = false; p.hop(); }
    } else if (!glanced) {
      glanced = true;
      const r = gate?.getBoundingClientRect();
      setTimeout(() => { if (visible) (r ? utils.glanceAt(el, r.left + r.width / 2) : p.glance(-1)); }, 420);
    }
  };

  paint(store.get(), false);

  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      const was = visible;
      visible = e.isIntersecting;
      if (visible && !was) { onEnter(); seen = true; }
    }
  }, { threshold: 0.4 });
  io.observe(el.closest(".finale__stop") || el);

  const off = store.subscribe((s, prev) => {
    if (!prev) return;
    if (tidied(s) !== tidied(prev)) {
      paint(s, true);
      // Tidied off screen (the menu bar’s popover, or the hero): hop the next time the period comes into view.
      hopPending = tidied(s) && !visible;
    }
    if (s.downloads !== prev.downloads) {
      const first = !smiled;
      smiled = true;
      section.dataset.mood = "done";
      if (first && p.poseName !== "done") {
        if (visible) p.to("done", { ease: "perk", duration: 450 }).then((ok) => ok && p.hop());
        else p.to("done", { ease: "none" });
      } else if (visible) p.hop();
    }
  });

  return () => { off(); io.disconnect(); p.breathe(false); };
}
