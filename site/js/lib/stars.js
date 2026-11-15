// Live GitHub stars (FACTS): one fetch after load, at idle; sessionStorage for 10 min; shown in every
// [data-stars] only when stargazers_count >= 25, rolled in once over --d-count. Otherwise (or on any
// failure) nothing is shown and the element stays empty (CSS: [data-stars]:empty {display:none}).
import { API_URL, STAR_MIN } from "./config.js";
import { roll } from "./motion.js";

const KEY = "yf-stars", TTL = 10 * 60 * 1000;
const fmt = (n) => Math.round(n).toLocaleString("en-US");

async function count() {
  try {
    const c = JSON.parse(sessionStorage.getItem(KEY) || "null");
    if (c && Date.now() - c.t < TTL) return c.n;
  } catch {}
  try {
    const r = await fetch(API_URL, { headers: { Accept: "application/vnd.github+json" } });
    if (!r.ok) return null;
    const n = (await r.json()).stargazers_count;
    if (typeof n !== "number") return null;
    try { sessionStorage.setItem(KEY, JSON.stringify({ n, t: Date.now() })); } catch {}
    return n;
  } catch { return null; }
}

export function loadStars() {
  const run = async () => {
    const n = await count();
    if (n == null || n < STAR_MIN) return;
    document.querySelectorAll("[data-stars]").forEach((el) => {
      el.setAttribute("aria-label", `${fmt(n)} stars`);
      roll(el, Math.max(0, n - Math.min(n, 40)), n, fmt);
    });
  };
  const idle = window.requestIdleCallback || ((fn) => setTimeout(fn, 1200));
  if (document.readyState === "complete") idle(run); else addEventListener("load", () => idle(run), { once: true });
}
