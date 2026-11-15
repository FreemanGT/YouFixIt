// The face, page-wide. One implementation: the product component’s Pebble (lib/component.js, a port of
// StatusIcon.swift), so the menu bar, the panel header, the finds pebbles, the gate error and the finale
// period are the same object. This module is the architect’s small API over it (SPEC §F):
//   renderPebble(el, {pose, count, size, ring, variant}) → controller · breathe(el) · glanceAt(el, x, y)
// Build-rendered pebbles (<!-- @pebble ... --> in any HTML) are hydrated in place, no repaint.
import { Pebble } from "./component.js";

/** The live Pebble of an element (or undefined). */
export const pebbleOf = (el) => el?._yfPebble;

/**
 * renderPebble(el, opts) — draw (or hydrate) a pebble in `el` and return its controller (a component Pebble):
 *   pose: calm | blink | glance | light | heavy | working | done | hop | paused   (default el.dataset.pebble or calm)
 *   count: number | null (menu bar variant only: Geist Mono beside the face)
 *   size: css px width of the svg (sets --pebble-size; default 24)
 *   ring: amber legibility ring in light mode (default true)
 *   variant: "bar" (menu bar fills, eyes cut out) | "face" (the panel header face, white eyes)
 * Controller: p.to(pose) tweens · await p.show(mood) perks into a mood · p.hop() · p.perk() · p.blink()
 *   · p.glance(dir ±1) · p.setCount(n) · p.breathe(true|false) · p.destroy() · p.poseName
 */
export function renderPebble(el, { pose, count, size, ring, variant } = {}) {
  if (!el) return null;
  if (size) el.style.setProperty("--pebble-size", `${size}px`);
  const existing = pebbleOf(el);
  if (existing) { if (pose) existing.to(pose); if (count !== undefined) existing.setCount(count); return existing; }
  return new Pebble(el, {
    variant: variant || el.dataset.variant || "bar",
    pose: pose || el.dataset.pebble || "calm",
    count: count !== undefined ? count : el.dataset.count ? +el.dataset.count : null,
    ring: ring ?? el.dataset.ring !== "off",
  });
}

/** Idle life: blink every 4 to 7 s, a glance every third or fourth blink, on screen only (component scheduler). */
export function breathe(el, on = true) {
  const p = pebbleOf(el) || renderPebble(el);
  p.breathe(on);
  return () => p.breathe(false);
}

/** Eyes toward a page point (client px), e.g. the finale’s period glancing at the gate. */
export function glanceAt(el, x) {
  const p = pebbleOf(el);
  if (!p) return;
  const r = el.getBoundingClientRect();
  p.glance(x < r.left + r.width / 2 ? -1 : 1);
}

/** Hydrate every build-rendered [data-pebble] inside root (idempotent). Returns the controllers. */
export const hydratePebbles = (root = document) => [...root.querySelectorAll("[data-pebble]")].map((el) => renderPebble(el));

export default { renderPebble, breathe, glanceAt, pebbleOf, hydratePebbles };
