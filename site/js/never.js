// never · one motion: each refusal row arrives (the panel's own `arrive`) as its Never rule scrolls in, once.
// Only rows still below the fold wait; reduced motion, no IntersectionObserver or no JS leave every row in place.
export default function init({ utils }) {
  const section = document.getElementById("never");
  const pairs = [...(section?.querySelectorAll(".never__pair") || [])];
  if (!pairs.length || utils.reduced || !("IntersectionObserver" in window)) return;

  const line = () => innerHeight * 0.8;
  const rowOf = (pair) => pair.querySelector(".never__tray .yf-row");
  const waiting = pairs.filter((p) => p.getBoundingClientRect().top > line() && rowOf(p));
  if (!waiting.length) return;

  const show = (pair, animate) => {
    const row = rowOf(pair);
    if (!row?.classList.contains("is-waiting")) return;
    row.classList.remove("is-waiting");
    if (animate) utils.arrive(row);
  };
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { io.unobserve(e.target); show(e.target, true); } });
  }, { rootMargin: "0px 0px -20% 0px" });

  waiting.forEach((p) => { rowOf(p).classList.add("is-waiting"); io.observe(p); });
  const off = utils.onReducedChange?.((r) => { if (r) { io.disconnect(); waiting.forEach((p) => show(p, false)); } });

  return () => { io.disconnect(); waiting.forEach((p) => show(p, false)); if (typeof off === "function") off(); };
}
