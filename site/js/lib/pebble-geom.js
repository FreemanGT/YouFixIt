// The face, ported from StatusIcon.swift: pure geometry, no DOM, so build.mjs can pre-render pebbles into the
// HTML (first paint complete) and pebble.js can animate the same numbers. Canvas 22 x 22, y down.
// Body 18 x 15, radius 7.5, centred, raised by `lift`. Eyes: holes r 1.3 * eyeScale at x 11 ± 3 (+ eyeDX),
// y 10 (+ eyeDY), squashed to `eyeOpen` (min .22). Smile: arcs r + .4 from 200° to 340° (the ^ ^ eyes).
export const CANVAS = 22;
const W = 18, H = 15, R = 7.5, EYE = 1.3, GAP = 3;

const base = { eyeDX: 0, eyeDY: 0, eyeScale: 1, eyeOpen: 1, smile: 0, lift: 0, squashX: 1, squashY: 1, alpha: 1, tint: "bar" };
/** StatusIcon.Pose, verbatim values. tint: bar (ink) · ok (green) · warn (amber) · paused (grey). */
export const POSES = {
  calm: { ...base },
  blink: { ...base, eyeOpen: 0 },
  glance: { ...base, eyeDX: 0.6, eyeDY: -0.4, tint: "ok" },
  light: { ...base, tint: "ok" },
  heavy: { ...base, eyeScale: 1.2, lift: 1, tint: "warn" },
  working: { ...base, eyeDY: 0.7, squashX: 1.05, squashY: 0.95, tint: "ok" },
  done: { ...base, smile: 1, tint: "ok" },
  hop: { ...base, smile: 1, lift: 2, tint: "ok" },
  paused: { ...base, eyeOpen: 0, lift: -1, alpha: 0.55, tint: "paused" },
};
export const NUMERIC = ["eyeDX", "eyeDY", "eyeScale", "eyeOpen", "smile", "lift", "squashX", "squashY", "alpha"];

/** Fills per palette. "bar" = the menu bar (site tokens); "app" = inside the panel (Theme.swift fills). */
export const FILLS = {
  bar: { bar: "var(--face-calm, currentColor)", ok: "var(--face-green, #259E80)", warn: "var(--face-amber, #EDA833)", paused: "var(--face-paused, #8A8F8C)" },
  app: { bar: "var(--p-text, currentColor)", ok: "var(--p-tint, #177D66)", warn: "var(--p-amber, #D99A2B)", paused: "var(--face-paused, #8A8F8C)" },
  flat: { bar: "#8A8F8C", ok: "#259E80", warn: "#EDA833", paused: "#8A8F8C" }, // favicon (no CSS vars)
};
export const RING = "#A8721A"; // light-mode inner ring on the amber body (SPEC §A.4)

const f = (n) => +n.toFixed(3);

/** Everything needed to draw one pose. */
export function geometry(p) {
  const w = W * p.squashX, h = H * p.squashY, cx = CANVAS / 2;
  const cy = CANVAS / 2 - p.lift + (H - h) / 2; // squash from the bottom
  const r = EYE * p.eyeScale, ey = cy - 1 + p.eyeDY, open = Math.max(0.22, p.eyeOpen);
  const eyes = [cx - GAP + p.eyeDX, cx + GAP + p.eyeDX].map((ex) => {
    const ar = r + 0.4, ay = ey + 0.4, a1 = (200 * Math.PI) / 180, a2 = (340 * Math.PI) / 180;
    return {
      cx: f(ex), cy: f(ey), rx: f(r), ry: f(r * open),
      arc: `M${f(ex + ar * Math.cos(a1))} ${f(ay + ar * Math.sin(a1))}A${f(ar)} ${f(ar)} 0 0 1 ${f(ex + ar * Math.cos(a2))} ${f(ay + ar * Math.sin(a2))}`,
    };
  });
  return { x: f(cx - w / 2), y: f(cy - h / 2), w: f(w), h: f(h), rx: f(R * p.squashX), ry: f(R * p.squashY), eyes, smile: p.smile, alpha: p.alpha };
}

/**
 * A complete <svg> string for a pose. opts: {id (unique mask id), palette: bar|app|flat, ring: bool, title}.
 * Structure (pebble.js relies on it): g.pb-body[mask] > rect.pb-fill + rect.pb-ring; mask > rect + ellipse.pb-eye x2 + path.pb-smile x2.
 */
export function svg(poseName = "calm", { id = "pb", palette = "bar", ring = true } = {}) {
  const p = typeof poseName === "string" ? POSES[poseName] || POSES.calm : poseName;
  const g = geometry(p), fill = (FILLS[palette] || FILLS.bar)[p.tint];
  const eyes = g.eyes.map((e) => `<ellipse class="pb-eye" cx="${e.cx}" cy="${e.cy}" rx="${e.rx}" ry="${e.ry}" fill="#000" opacity="${f(1 - g.smile)}"/>`).join("");
  const arcs = g.eyes.map((e) => `<path class="pb-smile" d="${e.arc}" fill="none" stroke="#000" stroke-width="1.1" stroke-linecap="round" opacity="${f(g.smile)}"/>`).join("");
  const ringEl = ring ? `<rect class="pb-ring" x="${g.x}" y="${g.y}" width="${g.w}" height="${g.h}" rx="${g.rx}" ry="${g.ry}" fill="none" stroke="${RING}" stroke-width="2" vector-effect="non-scaling-stroke" clip-path="url(#${id}c)" opacity="${p.tint === "warn" ? 1 : 0}"/>` : "";
  return `<svg class="pebble__svg" viewBox="0 0 ${CANVAS} ${CANVAS}" width="${CANVAS}" height="${CANVAS}" aria-hidden="true" focusable="false">` +
    `<defs><mask id="${id}m" maskUnits="userSpaceOnUse" x="0" y="0" width="${CANVAS}" height="${CANVAS}"><rect width="${CANVAS}" height="${CANVAS}" fill="#fff"/>${eyes}${arcs}</mask>` +
    `<clipPath id="${id}c"><rect class="pb-clip" x="${g.x}" y="${g.y}" width="${g.w}" height="${g.h}" rx="${g.rx}" ry="${g.ry}"/></clipPath></defs>` +
    `<g class="pb-body" mask="url(#${id}m)" opacity="${f(g.alpha)}"><rect class="pb-fill" x="${g.x}" y="${g.y}" width="${g.w}" height="${g.h}" rx="${g.rx}" ry="${g.ry}" fill="${fill}"/>${ringEl}</g></svg>`;
}

/** The whole static pebble element (what build.mjs writes for <!-- @pebble ... -->). */
export function html(poseName, { id = "pb", palette = "bar", ring = true, count = null, cls = "", size = null } = {}) {
  const style = size ? ` style="--pebble-size:${size}px"` : "";
  const countEl = count != null ? `<span class="pebble__count">${count}</span>` : "";
  return `<span class="pebble${cls ? " " + cls : ""}" data-pebble="${poseName}" data-palette="${palette}"${ring ? "" : ' data-ring="off"'}${count != null ? ` data-count="${count}"` : ""}${style} aria-hidden="true">${svg(poseName, { id, palette, ring })}${countEl}</span>`;
}
