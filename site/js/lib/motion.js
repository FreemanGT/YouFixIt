// The four verbs (SPEC §E): breathe (pebble.js) · perk · leave · fold. Durations and eases come from
// tokens.css custom properties; springs are SwiftUI’s spring(duration, bounce) solved exactly and exposed as
// CSS linear() strings (--spring-perk, --spring-hop on :root). Every verb runs on the Web Animations API (no
// library, no ticker that never sleeps) and animates transform-family properties and opacity only.
// Every verb has a reduced variant: short crossfades, nothing hidden, nothing waits to animate.
import { tween } from "./component.js";

const mq = matchMedia("(prefers-reduced-motion: reduce)");

/** Live reduced-motion flag. `motion.reduced` is always current. */
export const motion = { reduced: mq.matches };
const listeners = new Set();
mq.addEventListener?.("change", (e) => { motion.reduced = e.matches; listeners.forEach((fn) => fn(e.matches)); });
export const onReducedChange = (fn) => (listeners.add(fn), () => listeners.delete(fn));

const css = getComputedStyle(document.documentElement);
/** ms from a CSS custom property like --d-state: "220ms" → 220. */
export function dur(name, fallback = 220) {
  const v = css.getPropertyValue(name).trim();
  if (!v) return fallback;
  return v.endsWith("ms") ? parseFloat(v) : v.endsWith("s") ? parseFloat(v) * 1000 : parseFloat(v) || fallback;
}
export const D = {
  feedback: dur("--d-feedback", 120), state: dur("--d-state", 220), overlay: dur("--d-overlay", 360),
  exit: dur("--d-exit", 160), count: dur("--d-count", 600), stagger: dur("--d-stagger", 80),
  blink: dur("--d-blink", 90), smile: dur("--d-smile", 1200), haze: dur("--d-haze", 600),
};

/** SwiftUI spring(duration, bounce) as a progress function over its settle time. */
function spring(duration, bounce) {
  const w0 = (2 * Math.PI) / duration, z = 1 - bounce, wd = w0 * Math.sqrt(1 - z * z);
  const x = (t) => 1 - Math.exp(-z * w0 * t) * (Math.cos(wd * t) + ((z * w0) / wd) * Math.sin(wd * t));
  let settle = duration; // first time after which it stays within 0.2 % of 1
  for (let t = duration * 3; t > 0; t -= 0.005) if (Math.abs(x(t) - 1) > 0.002) { settle = t + 0.005; break; }
  const ease = (p) => (p >= 1 ? 1 : x(p * settle));
  const pts = Array.from({ length: 41 }, (_, i) => +ease(i / 40).toFixed(4));
  return { ease, settle, linear: `linear(${pts.join(", ")})` };
}
export const SPRINGS = { perk: spring(0.45, 0.25), hop: spring(0.5, 0.3) };
const root = document.documentElement.style;
root.setProperty("--spring-perk", SPRINGS.perk.linear);
root.setProperty("--spring-hop", SPRINGS.hop.linear);
root.setProperty("--spring-perk-dur", `${Math.round(SPRINGS.perk.settle * 1000)}ms`);
root.setProperty("--spring-hop-dur", `${Math.round(SPRINGS.hop.settle * 1000)}ms`);

/** CSS easing strings for element.animate(). */
export const EASE = {
  arrive: "cubic-bezier(.16, 1, .3, 1)", leave: "cubic-bezier(.42, 0, 1, 1)", out: "cubic-bezier(.33, 1, .68, 1)",
  perk: SPRINGS.perk.linear, hop: SPRINGS.hop.linear,
};
const arriveFn = (t) => 1 - (1 - t) ** 4; // close to the arrive curve, for number rolls

const list = (els) => (els ? (els.length !== undefined && typeof els !== "string" ? [...els] : [els]) : []).filter((e) => e?.animate);
const done = (anims) => Promise.all(anims.map((a) => a.finished.catch(() => {}))).then(() => {});
const stop = (el, tag) => el.getAnimations?.().forEach((a) => { if (a.id === tag) a.cancel(); });
const run = (el, frames, opts, tag) => { stop(el, tag); const a = el.animate(frames, opts); a.id = tag; return a; };

/** perk · a state change lands: scale .9 → 1 on the perk spring (one ~6 % overshoot). Reduced: 120 ms fade. */
export function perk(el, { from = 0.9 } = {}) {
  const els = list(el);
  if (motion.reduced) return done(els.map((e) => run(e, [{ opacity: 0.6 }, { opacity: 1 }], { duration: D.feedback }, "yf-perk")));
  return done(els.map((e) => run(e, [{ scale: from }, { scale: 1 }], { duration: SPRINGS.perk.settle * 1000, easing: EASE.perk }, "yf-perk")));
}

/** hop · one small jump (a done face, a download). Reduced: nothing (the pose still changes). */
export function hop(el, { height = 3 } = {}) {
  const els = list(el);
  if (!els.length || motion.reduced) return Promise.resolve();
  const up = 160, back = SPRINGS.hop.settle * 1000, total = up + back;
  return done(els.map((e) => run(e, [
    { translate: "0 0", easing: EASE.out },
    { translate: `0 ${-height}px`, offset: up / total, easing: EASE.hop },
    { translate: "0 0" },
  ], { duration: total }, "yf-hop")));
}

/** Order elements by distance from an origin element’s centre, nearest first. */
export function byDistance(els, originEl) {
  if (!originEl) return list(els);
  const o = originEl.getBoundingClientRect(), ox = o.left + o.width / 2, oy = o.top + o.height / 2;
  const d = (el) => { const r = el.getBoundingClientRect(); return Math.hypot(r.left + r.width / 2 - ox, r.top + r.height / 2 - oy); };
  return list(els).sort((a, b) => d(a) - d(b));
}

/**
 * leave · rows exit: fade + 8 px up (transform and opacity only), nearest originEl first, 80 ms steps capped
 * at 5; then every `.collapse` wrapper closes in one step, so layout changes once. `stagger: false` when the
 * caller already times each row. Reduced: all crossfade together over 220 ms.
 */
export function leave(els, originEl, { stagger = true } = {}) {
  const items = byDistance(els, originEl);
  if (!items.length) return Promise.resolve();
  const d = motion.reduced ? D.state : D.exit;
  const anims = items.map((el, i) => run(el, [{ opacity: 1, translate: "0 0" }, { opacity: 0, translate: `0 ${motion.reduced ? 0 : -8}px` }],
    { duration: d, delay: motion.reduced || !stagger ? 0 : Math.min(i, 5) * D.stagger, easing: EASE.leave, fill: "forwards" }, "yf-leave"));
  return done(anims).then(() => items.forEach((el) => el.closest(".collapse")?.classList.add("is-gone")));
}

/** arrive · Undo plays leave back: wrappers open in one step, then rows fade in top-down (80 ms steps, cap 5). */
export function arrive(els) {
  const items = list(els);
  if (!items.length) return Promise.resolve();
  items.forEach((el) => el.closest(".collapse")?.classList.remove("is-gone"));
  return done(items.map((el, i) => run(el, [{ opacity: 0, translate: `0 ${motion.reduced ? 0 : -8}px` }, { opacity: 1, translate: "0 0" }],
    { duration: D.state, delay: motion.reduced ? 0 : Math.min(i, 5) * D.stagger, easing: EASE.arrive }, "yf-leave")));
}

/**
 * fold · a popover opens out of / folds back into its origin (the pebble). Origin = originEl’s centre.
 * open: scale .94 → 1 + opacity, 360 ms arrive. close: 160 ms leave. Sets `visibility` at the ends
 * (the element keeps its layout box: zero CLS). Reduced: a 160 ms opacity change.
 */
export function fold(el, originEl, open, { scale = 0.94, duration } = {}) {
  if (!el?.animate) return Promise.resolve();
  if (originEl) {
    const o = originEl.getBoundingClientRect(), r = el.getBoundingClientRect();
    if (r.width && r.height) el.style.transformOrigin = `${o.left + o.width / 2 - r.left}px ${o.top + o.height / 2 - r.top}px`;
  }
  if (open) el.style.visibility = "visible";
  const shown = { opacity: 1, scale: 1 }, hidden = motion.reduced ? { opacity: 0, scale: 1 } : { opacity: 0, scale };
  const ms = motion.reduced ? D.exit : duration ?? (open ? D.overlay : D.exit);
  const a = run(el, open ? [hidden, shown] : [shown, hidden], { duration: ms, easing: motion.reduced ? "linear" : open ? EASE.arrive : EASE.leave, fill: open ? "none" : "forwards" }, "yf-fold");
  return a.finished.then(() => {
    if (!open) { el.style.visibility = "hidden"; a.cancel(); el.style.opacity = "0"; }
    else el.style.opacity = "";
  }).catch(() => {});
}

/** Roll a number from → to over --d-count (tabular digits) on the shared ticker. fmt formats each frame. Reduced: swap. */
export function roll(el, from, to, fmt = (n) => String(Math.round(n))) {
  if (!el) return Promise.resolve();
  if (motion.reduced || from === to) { el.textContent = fmt(to); return Promise.resolve(); }
  return tween(D.count, arriveFn, (k) => { el.textContent = fmt(from + (to - from) * k); }).promise.then(() => {});
}

export default { motion, D, SPRINGS, EASE, perk, hop, leave, arrive, fold, roll, byDistance, dur, onReducedChange };
