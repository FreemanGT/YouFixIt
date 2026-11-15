// The tab icon is the pebble in the example’s pose (SPEC §C, §F): calm grey, amber heavy, green working,
// green smile when done. A data: SVG on the one <link rel="icon" data-live>.
import { svg } from "./pebble-geom.js";

const POSE = { heavy: "heavy", working: "working", done: "done", calm: "calm" };
let link, last;

export function setFavicon(phase) {
  const pose = POSE[phase] || "calm";
  if (pose === last) return;
  last = pose;
  link ||= document.querySelector('link[rel="icon"][data-live]');
  if (!link) {
    link = document.createElement("link");
    link.rel = "icon"; link.type = "image/svg+xml"; link.dataset.live = "";
    document.head.append(link);
  }
  // Flat fills (CSS vars don’t reach a favicon); ring kept for amber so it reads on light tab strips.
  const s = svg(pose, { id: "fv", palette: "flat", ring: true }).replace('class="pebble__svg"', 'xmlns="http://www.w3.org/2000/svg"');
  link.href = "data:image/svg+xml," + encodeURIComponent(s);
}

/** Follow the store. Returns the unsubscribe function. */
export function followFavicon(store) {
  setFavicon(store.get().phase);
  return store.subscribe((s, p) => { if (s.phase !== p.phase) setFavicon(s.phase); });
}
