// The face’s light (SPEC §I.2). Sets html[data-mood] = heavy | working | done | calm from the store;
// CSS (base.css .haze) crossfades two radial layers by opacity over --d-haze. Also keeps --pebble-x
// (the menu bar pebble’s centre, px from the viewport’s left) current so the light sits around it.
export function followMood(store, pebbleEl) {
  const html = document.documentElement;
  const set = (s) => { html.dataset.mood = store.mood(s); };
  set(store.get());
  const off = store.subscribe((s, p) => { if (s.phase !== p.phase) set(s); });

  const measure = () => {
    if (!pebbleEl) return;
    const r = pebbleEl.getBoundingClientRect();
    if (r.width) html.style.setProperty("--pebble-x", `${Math.round(r.left + r.width / 2)}px`);
  };
  measure();
  let raf = 0;
  const onResize = () => { cancelAnimationFrame(raf); raf = requestAnimationFrame(measure); };
  addEventListener("resize", onResize, { passive: true });
  document.fonts?.ready.then(measure);
  return () => { off(); removeEventListener("resize", onResize); };
}
