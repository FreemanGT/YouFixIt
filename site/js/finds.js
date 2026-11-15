// finds section (owner: finds builder).
// The chips are toggle buttons (aria-pressed): hover, tap, Enter or Space picks a thing, and the one docked example row swaps
// to it, written as the app writes it (why lines verbatim from Copy.swift, sizes through the app’s Format.size).
// On first view the pick steps on twice by itself, slowly, to show the words can be pressed; any touch stops that.

const RUN = 'Running now';
const SPACE = 'Taking up space';
// MiB, so size() prints exactly what the app would ("1.3 GB", "14 GB", "240 MB").
const ROWS = {
  apps: { group: RUN, glyph: 'app', name: 'Blender', why: 'Untouched since Wednesday', mib: 1331.2 },
  docker: { group: RUN, glyph: 'cube', name: 'Docker', why: 'No containers running, nothing using it', mib: 3788.8 },
  sims: { group: RUN, glyph: 'phone', name: 'iPhone 17', why: 'iOS 26.1, idle since Wednesday', mib: 1228.8 },
  servers: { group: RUN, glyph: 'server', name: 'node', why: 'Port 3000 in my-app, from a finished coding session', mib: 240 },
  xcode: { group: SPACE, glyph: 'hammer', name: 'Xcode build cache', why: 'Xcode rebuilds this when needed', mib: 14336 },
  caches: { group: SPACE, glyph: 'archive', name: 'npm cache', why: 'Tools refill this as they need it', mib: 2457.6 },
  installers: { group: SPACE, glyph: 'disk', name: 'An old installer', why: 'An installer you already used', mib: 1126.4 },
};
const AUTO_STEPS = ['sims', 'xcode'];
const AUTO_FIRST = 1400;
const AUTO_EVERY = 2600;

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

export default function init({ utils, Component }) {
  const root = document.getElementById('finds');
  const swap = root?.querySelector('.finds__swap');
  if (!swap || !Component?.rowHTML) return;
  const chips = [...root.querySelectorAll('.chip[data-k]')];
  const tray = root.querySelector('.finds__tray');
  const sticky = root.querySelector('.finds__sticky');
  const reduced = () => utils?.reduced ?? Component.motion?.reduced;
  let current = chips.find((c) => c.getAttribute('aria-pressed') === 'true')?.dataset.k || 'docker';
  let intent = 0;

  const show = (k, { quiet = false } = {}) => {
    clearTimeout(intent);
    const r = ROWS[k];
    if (!r || k === current) return;
    current = k;
    for (const c of chips) {
      const on = c.dataset.k === k;
      c.setAttribute('aria-pressed', String(on));
    }
    // The self-running steps change the row without being asked, so they are not announced.
    if (quiet) tray?.setAttribute('aria-live', 'off');
    swap.innerHTML = `<p class="finds__group" data-group>${esc(r.group)}</p>${Component.rowHTML({ id: k, ...r })}`;
    Component.fold(swap, null, true, reduced() ? { ms: 120 } : { scale: 0.97, ms: 220 });
    if (quiet) requestAnimationFrame(() => tray?.setAttribute('aria-live', 'polite'));
  };

  // At 390 the card sits between the sentences: after a tap, bring it into view only if it is off screen.
  const reveal = () => {
    if (!sticky || getComputedStyle(sticky).position === 'sticky') return;
    const b = sticky.getBoundingClientRect();
    if (b.top >= 56 && b.bottom <= innerHeight - 8) return;
    sticky.scrollIntoView({ block: 'nearest', behavior: reduced() ? 'auto' : 'smooth' });
  };

  // ---- first view: step the pick on twice, then stop for good ----
  let autoTimer = 0;
  let autoLeft = reduced() ? 0 : AUTO_STEPS.length;
  let visible = false;
  let io = null;
  const stopAuto = () => {
    autoLeft = 0;
    clearTimeout(autoTimer);
    io?.disconnect();
    io = null;
  };
  const tick = () => {
    if (!autoLeft || !visible) return;
    show(AUTO_STEPS[AUTO_STEPS.length - autoLeft], { quiet: true });
    autoLeft -= 1;
    if (autoLeft) autoTimer = setTimeout(tick, AUTO_EVERY);
    else stopAuto();
  };
  if (autoLeft && 'IntersectionObserver' in window && tray) {
    io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
      clearTimeout(autoTimer);
      if (visible && autoLeft) autoTimer = setTimeout(tick, AUTO_FIRST);
    }, { threshold: 0.9 });
    io.observe(tray);
  }

  const off = [];
  const on = (el, type, fn, opts) => { el.addEventListener(type, fn, opts); off.push(() => el.removeEventListener(type, fn, opts)); };
  // Any touch of the page by the visitor ends the self-running steps.
  for (const type of ['pointerdown', 'keydown']) on(window, type, stopAuto, { capture: true, passive: true });

  for (const c of chips) {
    const k = c.dataset.k;
    // A short intent delay so sweeping the pointer across the sentence does not flick through every row.
    on(c, 'pointerenter', (e) => { if (e.pointerType === 'mouse') { stopAuto(); clearTimeout(intent); intent = setTimeout(() => show(k), 70); } });
    on(c, 'pointerleave', () => clearTimeout(intent));
    on(c, 'click', () => { show(k); reveal(); });
  }
  return () => { clearTimeout(intent); stopAuto(); off.forEach((f) => f()); };
}
