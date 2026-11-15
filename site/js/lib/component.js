// YouFixIt living hero: the pebble, the example panel and the example store, rebuilt from
// Sources/YouFixIt/{StatusIcon,Theme,PopoverView,FindingRow,Copy}.swift. No dependencies (GSAP optional via setTicker).
// Importing this module touches no DOM, so build.mjs can call panelHTML() in Node for the server-rendered heavy state.

// ---------------------------------------------------------------------------------------------------------------
// Theme (Theme.swift, seconds -> ms)
// ---------------------------------------------------------------------------------------------------------------

export const T = {
  feedback: 120, state: 220, overlay: 360, exit: 160, count: 600, stagger: 80, staggerCap: 5,
  blink: 90, smileHold: 1200, undoWindow: 60000, askNote: 6000,
  canvas: 22, pebbleW: 18, pebbleH: 15, pebbleR: 7.5, eye: 1.3, eyeGap: 3,
  faceW: 40, faceH: 32,
};

export const COPY = {
  tipCalm: 'YouFixIt, your Mac feels fine',
  tipWorking: 'YouFixIt, tidying up',
  tipFindings: (n, mib) => `YouFixIt, ${things(n)} to tidy, about ${size(mib)}`,
  tipDone: (mib) => `freed up ${size(mib)}. You can undo for the next minute.`,
  headerHeavy: "Your Mac is working hard. Here’s what you can let go.",
  subHeavy: 'Letting these go helps right away.',
  headerWorking: 'Tidying up…',
  headerDone: (mib) => `Freed up ${size(mib)}`,
  subDone: 'Your Mac has more room to breathe.',
  headerEmpty: 'Nothing to tidy.',
  subEmpty: 'Your Mac is doing great.',
  sectionRunning: 'Running now',
  sectionSpace: 'Taking up space',
  sectionKnow: 'Good to know',
  tidyUp: 'Tidy up',
  nothingSelected: 'Nothing selected',
  undo: 'Undo',
  undoCaption: 'You can undo for the next minute.',
  checked: 'Checked just now',
  askAll: 'Ask Claude',
  askNote: 'On your Mac this opens a new Claude chat with the question already written. Claude only gets the question.',
  again: 'Show the example again',
  label: "Example panel. On your Mac, it lists what’s really there.",
  prefix: 'Example: ',
  a11yInclude: (name, mib) => `Include ${name}, about ${size(mib)}`,
  a11yTidy: (n, mib) => `Tidy up ${things(n)}, frees about ${size(mib)}`,
};

export function things(n) { return n === 1 ? '1 thing' : `${n} things` }

/** Format.size from Copy.swift, taking MiB (the demo’s unit). "690 MB", "5.6 GB", "15 GB", "21 GB". */
export function size(mib) {
  const mb = Math.max(0, mib);
  if (mb < 1000) return `${Math.round(mb)} MB`;
  const gb = mb / 1024;
  const whole = gb >= 10 || Math.abs(gb - Math.round(gb)) < 0.05;
  return whole ? `${Math.round(gb)} GB` : `${gb.toFixed(1)} GB`;
}

/** Copy.frees: "Frees about X of memory and Y of space" (empty when nothing is selected). */
export function frees(memory, space) {
  if (memory > 0 && space > 0) return `Frees about ${size(memory)} of memory and ${size(space)} of space`;
  if (memory > 0) return `Frees about ${size(memory)} of memory`;
  if (space > 0) return `Frees about ${size(space)} of space`;
  return '';
}

// ---------------------------------------------------------------------------------------------------------------
// Easing: Theme.arrive / leave, StatusIcon’s smooth and perk, SwiftUI springs (perk 0.45/0.25, hop 0.5/0.3)
// ---------------------------------------------------------------------------------------------------------------

function bezier(x1, y1, x2, y2) {
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
  const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  const sx = (t) => ((ax * t + bx) * t + cx) * t;
  const sy = (t) => ((ay * t + by) * t + cy) * t;
  const dx = (t) => (3 * ax * t + 2 * bx) * t + cx;
  return (x) => {
    if (x <= 0) return 0; if (x >= 1) return 1;
    let t = x;
    for (let i = 0; i < 8; i++) { const e = sx(t) - x; const d = dx(t); if (Math.abs(e) < 1e-5 || !d) break; t -= e / d; }
    return sy(Math.min(1, Math.max(0, t)));
  };
}

/** SwiftUI .spring(duration:bounce:) as a function of time (ms) and its settle time. */
export function spring(duration, bounce) {
  const w0 = (2 * Math.PI) / (duration / 1000), z = 1 - bounce, wd = w0 * Math.sqrt(1 - z * z);
  const f = (ms) => { const t = ms / 1000; return 1 - Math.exp(-z * w0 * t) * (Math.cos(wd * t) + (z * w0 / wd) * Math.sin(wd * t)); };
  const settle = Math.ceil((Math.log(1000) / (z * w0)) * 1000);
  const linear = (steps = 40) => {
    const pts = [];
    for (let i = 0; i <= steps; i++) pts.push(+f((settle * i) / steps).toFixed(4));
    pts[steps] = 1;
    return `linear(${pts.join(', ')})`;
  };
  return { at: (p) => (p >= 1 ? 1 : f(p * settle)), settle, linear };
}

export const EASE = {
  arrive: bezier(0.16, 1, 0.3, 1),
  leave: bezier(0.42, 0, 1, 1),
  smooth: (t) => t * t * (3 - 2 * t),
  /** StatusIcon.perk: a back-out with c = 1.3, the only bounce in the icon. */
  perk: (t) => { const c = 1.3, x = t - 1; return 1 + x * x * ((c + 1) * x + c); },
  easeOut: bezier(0, 0, 0.58, 1),
};
export const SPRING = { perk: spring(450, 0.25), hop: spring(500, 0.3) };
export const CSS_EASE = {
  arrive: 'cubic-bezier(.16,1,.3,1)', leave: 'cubic-bezier(.42,0,1,1)',
  perk: SPRING.perk.linear(), hop: SPRING.hop.linear(),
};

/** Live reduced-motion flag (false in Node). */
export const motion = { get reduced() { return typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches } };

// ---------------------------------------------------------------------------------------------------------------
// One ticker. setTicker(gsap.ticker.add, gsap.ticker.remove) hands it to GSAP’s; otherwise one rAF loop,
// paused while the document is hidden.
// ---------------------------------------------------------------------------------------------------------------

const subs = new Set();
let raf = 0, external = null;
function loop(now) { raf = 0; for (const fn of [...subs]) fn(now); if (subs.size && !external) raf = requestAnimationFrame(loop); }
function wake() { if (!external && !raf && subs.size && !(typeof document !== 'undefined' && document.hidden)) raf = requestAnimationFrame(loop); }
const extTick = () => { const now = performance.now(); for (const fn of [...subs]) fn(now); };
if (typeof document !== 'undefined') document.addEventListener('visibilitychange', wake);

// The external ticker holds extTick only while something is subscribed, so GSAP’s autoSleep can stop the rAF.
let extOn = false;
function syncExt() {
  if (!external) return;
  if (subs.size && !extOn) { external.add(extTick); extOn = true; }
  else if (!subs.size && extOn) { external.remove(extTick); extOn = false; }
}
export function setTicker(add, remove) {
  if (external && extOn) external.remove(extTick);
  extOn = false;
  external = add ? { add, remove } : null;
  if (external) { if (raf) cancelAnimationFrame(raf); raf = 0; syncExt(); } else wake();
}
export function onTick(fn) {
  subs.add(fn); syncExt(); wake();
  return () => { subs.delete(fn); syncExt(); };
}

/** Tween 0..1 over `ms` on the ticker. Resolves true when finished, false when cancelled. */
export function tween(ms, ease, frame) {
  let off, done;
  const p = new Promise((res) => { done = res; });
  const start = performance.now();
  off = onTick((now) => {
    const t = Math.min(1, (now - start) / ms);
    frame(ease(t));
    if (t >= 1) { off(); done(true); }
  });
  return { promise: p, cancel() { off(); done(false); } };
}

/** Animate a number from `from` to `to`, calling `set(value)` each frame (counts, "Freed up"). */
export function roll(from, to, ms, set, ease = EASE.easeOut) {
  if (motion.reduced || ms <= 0) { set(to); return { promise: Promise.resolve(true), cancel() {} }; }
  return tween(ms, ease, (k) => set(from + (to - from) * k));
}

// ---------------------------------------------------------------------------------------------------------------
// Poses (StatusIcon.swift Pose). Every field is a number so poses blend frame by frame; tint flips at t = 0.5.
// ---------------------------------------------------------------------------------------------------------------

const BASE = { eyeDX: 0, eyeDY: 0, eyeScale: 1, eyeOpen: 1, smile: 0, lift: 0, squashX: 1, squashY: 1, alpha: 1, tint: 'bar' };
const pose = (o) => Object.freeze({ ...BASE, ...o });
export const POSES = Object.freeze({
  calm: pose({}),
  blink: pose({ eyeOpen: 0 }),
  light: pose({ tint: 'ok' }),
  glance: pose({ eyeDX: 0.6, eyeDY: -0.4, tint: 'ok' }),
  heavy: pose({ eyeScale: 1.2, lift: 1, tint: 'warn' }),
  working: pose({ eyeDY: 0.7, squashX: 1.05, squashY: 0.95, tint: 'ok' }),
  done: pose({ smile: 1, tint: 'ok' }),
  hop: pose({ smile: 1, lift: 2, tint: 'ok' }),
  paused: pose({ eyeOpen: 0, lift: -1, alpha: 0.55, tint: 'paused' }),
});
const NUM = ['eyeDX', 'eyeDY', 'eyeScale', 'eyeOpen', 'smile', 'lift', 'squashX', 'squashY', 'alpha'];
export function mixPose(a, b, t) {
  const o = { tint: t < 0.5 ? a.tint : b.tint };
  for (const k of NUM) o[k] = a[k] + (b[k] - a[k]) * t;
  return o;
}
const resolvePose = (p) => (typeof p === 'string' ? POSES[p] || POSES.calm : { ...BASE, ...p });

const r2 = (n) => Math.round(n * 1000) / 1000;
/** An arc from 200 to 340 degrees: over the top (the menu bar’s ^ ^) or under the bottom (the panel face’s smile). */
function arc(cx, cy, R, under) {
  const a = (200 * Math.PI) / 180, b = (340 * Math.PI) / 180;
  const x1 = cx + R * Math.cos(a), y1 = cy + R * Math.sin(a), x2 = cx + R * Math.cos(b), y2 = cy + R * Math.sin(b);
  return `M${r2(x1)} ${r2(y1)}A${r2(R)} ${r2(R)} 0 ${under ? '1 0' : '0 1'} ${r2(x2)} ${r2(y2)}`;
}

/**
 * Geometry of one frame. `bar`: the 22 pt menu bar canvas (Pose.image). `face`: the 40 x 32 header face (Welcome.swift
 * Pebble), whose body fills its frame and whose eyes sit 1 unit higher, or 0.7 lower while working.
 */
export function geometry(p, variant = 'bar') {
  if (variant === 'face') {
    const s = T.faceW / T.pebbleW, r = T.eye * s * p.eyeScale;
    const y = T.faceH / 2 + s * (-1 + p.eyeDY * (1.7 / 0.7));
    const open = Math.max(0.22, p.eyeOpen);
    const eyes = [-1, 1].map((d) => ({ cx: T.faceW / 2 + d * T.eyeGap * s + p.eyeDX * s, cy: y, rx: r, ry: r * open }));
    return {
      w: T.faceW, h: T.faceH, tint: p.tint, alpha: p.alpha, eyeAlpha: 1 - p.smile, smileAlpha: p.smile,
      body: { x: 0, y: 0, w: T.faceW, h: T.faceH, rx: Math.min(T.pebbleR * s, T.faceH / 2), ry: Math.min(T.pebbleR * s, T.faceH / 2) },
      transform: `translate(0 ${r2(-p.lift * s)}) translate(20 16) scale(${r2(p.squashX)} ${r2(p.squashY)}) translate(-20 -16)`,
      eyes, arcs: eyes.map((e) => arc(e.cx, e.cy + 0.4 * s, r + 0.4 * s, true)), stroke: 1.1 * s,
    };
  }
  const c = T.canvas / 2, w = T.pebbleW * p.squashX, h = T.pebbleH * p.squashY, cy = c - p.lift;
  const r = T.eye * p.eyeScale, ey = cy - 1 + p.eyeDY, open = Math.max(0.22, p.eyeOpen);
  const eyes = [c - T.eyeGap + p.eyeDX, c + T.eyeGap + p.eyeDX].map((cx) => ({ cx, cy: ey, rx: r, ry: r * open }));
  return {
    w: T.canvas, h: T.canvas, tint: p.tint, alpha: p.alpha, eyeAlpha: 1 - p.smile, smileAlpha: p.smile,
    body: { x: c - w / 2, y: cy - h / 2, w, h, rx: T.pebbleR * p.squashX, ry: T.pebbleR * p.squashY },
    transform: '', eyes, arcs: eyes.map((e) => arc(e.cx, e.cy + 0.4, r + 0.4, false)), stroke: 1.1,
  };
}

let uid = 0;
/**
 * The pebble as an SVG string (Node-safe; the server-rendered hero uses it). Menu bar eyes are holes cut with a mask,
 * so the bar shows through them; the header face draws white eyes, as the app does.
 * opts: { variant: 'bar' | 'face', id: unique id for the mask, ring: true adds the amber legibility ring (CSS shows it in
 * light mode only), className }
 */
export function pebbleSVG(p = 'calm', { variant = 'bar', id, ring = true, className = '' } = {}) {
  const g = geometry(resolvePose(p), variant);
  const m = id || `yfm${++uid}`;
  const b = g.body;
  const eyes = g.eyes.map((e, i) => `<ellipse class="yf-eye" data-i="${i}" cx="${r2(e.cx)}" cy="${r2(e.cy)}" rx="${r2(e.rx)}" ry="${r2(e.ry)}" opacity="${r2(g.eyeAlpha)}"/>`).join('');
  const arcs = g.arcs.map((d, i) => `<path class="yf-smile" data-i="${i}" d="${d}" stroke-width="${r2(g.stroke)}" opacity="${r2(g.smileAlpha)}"/>`).join('');
  const bodyRect = `x="${r2(b.x)}" y="${r2(b.y)}" width="${r2(b.w)}" height="${r2(b.h)}" rx="${r2(b.rx)}" ry="${r2(b.ry)}"`;
  const head = `<svg class="yf-pebble yf-pebble--${variant} ${className}" viewBox="0 0 ${g.w} ${g.h}" data-tint="${g.tint}" aria-hidden="true" focusable="false">`;
  if (variant === 'face') {
    return `${head}<g class="yf-pebble__g" transform="${g.transform}" opacity="${r2(g.alpha)}"><rect class="yf-pebble__body" ${bodyRect}/>`
      + `<g class="yf-pebble__eyes">${eyes}${arcs}</g></g></svg>`;
  }
  return `${head}<defs><mask id="${m}" maskUnits="userSpaceOnUse" x="0" y="-4" width="22" height="30"><rect x="0" y="-4" width="22" height="30" fill="#fff"/>`
    + `<g class="yf-pebble__eyes">${eyes}${arcs}</g></mask></defs>`
    + `<g class="yf-pebble__g" mask="url(#${m})" opacity="${r2(g.alpha)}"><rect class="yf-pebble__body" ${bodyRect}/>`
    + (ring ? `<rect class="yf-pebble__ring" x="${r2(b.x + 0.45)}" y="${r2(b.y + 0.45)}" width="${r2(b.w - 0.9)}" height="${r2(b.h - 0.9)}" rx="${r2(b.rx - 0.45)}" ry="${r2(b.ry - 0.45)}"/>` : '')
    + `</g></svg>`;
}

/** Write one frame into an existing pebble SVG (no allocation of new nodes). */
export function paintPebble(svg, p, variant) {
  const g = geometry(p, variant);
  const b = g.body;
  if (svg.dataset.tint !== g.tint) svg.dataset.tint = g.tint;
  const grp = svg.querySelector('.yf-pebble__g');
  grp.setAttribute('opacity', r2(g.alpha));
  if (variant === 'face') grp.setAttribute('transform', g.transform);
  const set = (el, o) => { for (const k in o) el.setAttribute(k, r2(o[k])); };
  set(svg.querySelector('.yf-pebble__body'), { x: b.x, y: b.y, width: b.w, height: b.h, rx: b.rx, ry: b.ry });
  const ring = svg.querySelector('.yf-pebble__ring');
  if (ring) set(ring, { x: b.x + 0.45, y: b.y + 0.45, width: b.w - 0.9, height: b.h - 0.9, rx: b.rx - 0.45, ry: b.ry - 0.45 });
  svg.querySelectorAll('.yf-eye').forEach((el, i) => { const e = g.eyes[i]; set(el, { cx: e.cx, cy: e.cy, rx: e.rx, ry: e.ry, opacity: g.eyeAlpha }); });
  svg.querySelectorAll('.yf-smile').forEach((el, i) => { el.setAttribute('d', g.arcs[i]); el.setAttribute('opacity', r2(g.smileAlpha)); });
}

// ---------------------------------------------------------------------------------------------------------------
// Breathe: one scheduler for every idle pebble on screen. Blink every 4 to 7 s, a glance every third or fourth
// blink, never two pebbles within 400 ms of each other. Reduced motion stops idle blinks (every face a still poster).
// ---------------------------------------------------------------------------------------------------------------

const breathers = new Set();
let lastBlink = 0, io = null;
function scheduleBlink(pb) {
  clearTimeout(pb._blinkT);
  if (!pb._breathing || !pb._visible || motion.reduced) return; // reduced motion: every face is a still poster
  pb._blinkT = setTimeout(() => {
    const now = performance.now();
    if (now - lastBlink < 400 || (typeof document !== 'undefined' && document.hidden)) { pb._blinkT = setTimeout(() => scheduleBlink(pb), 400); return; }
    lastBlink = now;
    pb._blinks = (pb._blinks || 0) + 1;
    if (pb._blinks >= pb._glanceEvery && !motion.reduced && pb._name !== 'working') { pb._blinks = 0; pb._glanceEvery = 3 + Math.round(Math.random()); pb.glance(); }
    else pb.blink();
    scheduleBlink(pb);
  }, 4000 + Math.random() * 3000);
}
function observe(pb) {
  if (typeof IntersectionObserver !== 'function') { pb._visible = true; scheduleBlink(pb); return; }
  io ||= new IntersectionObserver((entries) => {
    for (const e of entries) { const p = e.target._yfPebble; if (!p) continue; p._visible = e.isIntersecting; scheduleBlink(p); }
  });
  io.observe(pb.el);
}
// Reduced motion switched live: stop every idle blink, or start them again.
if (typeof matchMedia === 'function') {
  matchMedia('(prefers-reduced-motion: reduce)').addEventListener?.('change', () => { for (const pb of breathers) scheduleBlink(pb); });
}

/**
 * A live pebble. `el` is any element (a span); the pebble draws an SVG into it, plus the count for the bar variant.
 *   const p = new Pebble(span, { variant: 'bar', pose: 'heavy', count: 5 });
 *   await p.show('done'); p.hop(); p.setCount(3); p.breathe(true);
 */
export class Pebble {
  constructor(el, { variant = 'bar', pose: start = 'calm', count = null, ring = true, breathe = false } = {}) {
    this.el = el; this.variant = variant;
    el.classList.add('yf-pb', `yf-pb--${variant}`);
    el._yfPebble = this;
    const existing = el.querySelector('svg.yf-pebble');
    if (!existing) el.insertAdjacentHTML('afterbegin', pebbleSVG(start, { variant, ring }));
    this.svg = el.querySelector('svg.yf-pebble');
    if (variant === 'bar') {
      this.countEl = el.querySelector('.yf-pb__count') || el.appendChild(Object.assign(document.createElement('span'), { className: 'yf-pb__count' }));
      this.countEl.setAttribute('aria-hidden', 'true');
    }
    this._name = typeof start === 'string' ? start : 'custom';
    this.target = resolvePose(start);
    this.base = this.target;
    this.over = { eyeOpen: null, eyeDX: 0 };
    this._glanceEvery = 3 + Math.round(Math.random());
    this._count = null;
    this._seq = 0;
    this.setCount(count, { roll: false });
    this._paint();
    this._syncSweep();
    if (breathe) this.breathe(true);
  }

  get poseName() { return this._name }

  _paint() {
    const p = { ...this.base };
    if (this.over.eyeOpen != null) p.eyeOpen = Math.min(p.eyeOpen, this.over.eyeOpen);
    p.eyeDX += this.over.eyeDX;
    paintPebble(this.svg, p, this.variant);
  }

  /** Low-level: tween to a pose (name or Pose) with ease 'smooth' | 'perk' | 'arrive' | 'none'. Resolves when done. */
  to(target, { ease = 'smooth', duration = T.state } = {}) {
    this._tw?.cancel();
    const next = resolvePose(target);
    if (typeof target === 'string') this._name = target;
    this.target = next;
    this._syncSweep();
    if (ease === 'none' || duration <= 0 || motion.reduced) {
      this.base = next; this._paint();
      if (motion.reduced && ease !== 'none' && this.svg.animate) this.svg.animate([{ opacity: 0.35 }, { opacity: 1 }], { duration: T.feedback, easing: 'ease-out' });
      return Promise.resolve(true);
    }
    const from = this.base, fn = EASE[ease] || EASE.smooth;
    this._tw = tween(duration, fn, (k) => { this.base = mixPose(from, next, k); this._paint(); });
    return this._tw.promise;
  }

  /** The app’s own entrance for a mood (StatusIcon.show). 'done' smiles, holds, hops once and stays done (SPEC H). */
  async show(mood, { thenCalm = false } = {}) {
    const seq = ++this._seq;
    const live = () => seq === this._seq;
    switch (mood) {
      case 'heavy': return this.to('heavy', { ease: 'perk', duration: 450 });
      case 'light':
        if (this._name === 'calm' && !motion.reduced) { await this.to('glance', { ease: 'perk' }); if (!live()) return false; }
        return this.to('light');
      case 'done': {
        if (!(await this.to('hop', { ease: 'perk', duration: 250 })) || !live()) return false;
        if (!(await this.to('done', { duration: 250 })) || !live()) return false;
        await wait(T.smileHold); if (!live()) return false;
        if (thenCalm) return this.to('calm', { duration: T.overlay });
        return this.hop();
      }
      case 'paused': return this.to('paused', { duration: T.overlay });
      default: return this.to(mood);
    }
  }

  /** One hop: lift 2 with the perk overshoot, then settle back to the current pose. */
  async hop() {
    if (motion.reduced) return true;
    const back = this._name, rest = this.target;
    const up = { ...rest, lift: rest.lift + 2, smile: rest.smile };
    if (!(await this.to(up, { ease: 'perk', duration: 250 }))) return false;
    this._name = back;
    return this.to(rest, { duration: 250 }).then((ok) => { this._name = back; return ok; });
  }

  /** The perk on a state change without one: drop a unit and spring back up (the heavy lift on load). */
  perk() {
    if (motion.reduced) return Promise.resolve(true);
    const rest = this.target, name = this._name;
    this.base = { ...rest, lift: rest.lift - 1, eyeScale: 1 };
    this._paint();
    return this.to(rest, { ease: 'perk', duration: 450 }).then((ok) => { this._name = name; return ok; });
  }

  /** Eyes to slits for 90 ms. */
  blink() {
    this.over.eyeOpen = 0; this._paint();
    clearTimeout(this._blinkOff);
    this._blinkOff = setTimeout(() => { this.over.eyeOpen = null; this._paint(); }, T.blink);
  }

  /** Eyes one unit aside for 600 ms (dir -1 left, 1 right). */
  glance(dir = Math.random() < 0.5 ? -1 : 1) {
    if (motion.reduced) return;
    this._gl?.cancel();
    const start = performance.now();
    this._gl = { cancel: onTick((now) => {
      const t = (now - start) / 600;
      const k = t < 0.25 ? EASE.smooth(t / 0.25) : t < 0.75 ? 1 : t < 1 ? 1 - EASE.smooth((t - 0.75) / 0.25) : 0;
      this.over.eyeDX = dir * k; this._paint();
      if (t >= 1) { this._gl.cancel(); this._gl = null; }
    }) };
  }

  /** StatusIcon.sweepLoop: while working the eyes sweep side to side, 0.7 units, 1.2 s a cycle. */
  _syncSweep() {
    const on = this._name === 'working' && !motion.reduced && typeof performance !== 'undefined';
    if (on && !this._sweep) {
      const t0 = performance.now();
      this._sweep = onTick((now) => { this.over.eyeDX = 0.7 * Math.sin(((now - t0) / 1200) * 2 * Math.PI); this._paint(); });
    } else if (!on && this._sweep) { this._sweep(); this._sweep = null; this.over.eyeDX = 0; }
  }

  /** The number beside the bar face. null hides it. Rolls one step at a time over 600 ms. */
  setCount(n, { roll: animate = true } = {}) {
    if (!this.countEl) return;
    this._cr?.cancel();
    const from = this._count;
    this._count = n;
    if (n == null || n <= 0) { this.countEl.textContent = ''; this.countEl.hidden = true; return; }
    this.countEl.hidden = false;
    if (!animate || from == null || from === n) { this.countEl.textContent = String(n); return; }
    this._cr = roll(from, n, T.count, (v) => { this.countEl.textContent = String(Math.round(v)); }, EASE.easeOut);
  }

  /** Idle blinks and glances while on screen. */
  breathe(on = true) {
    this._breathing = on;
    if (on) { breathers.add(this); observe(this); } else { breathers.delete(this); clearTimeout(this._blinkT); io?.unobserve(this.el); }
  }

  destroy() { this.breathe(false); this._tw?.cancel(); this._gl?.cancel(); this._sweep?.(); this._cr?.cancel(); clearTimeout(this._blinkOff); }
}

export const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------------------------------------------
// Glyphs: drawn strokes on a 16 unit grid, shown at 14 px (Theme.symbol). Never SF Symbols files.
// ---------------------------------------------------------------------------------------------------------------

function cog() {
  const pts = [];
  for (let i = 0; i < 16; i++) {
    const a = (i * Math.PI) / 8 - Math.PI / 16, r = i % 2 ? 4.9 : 6.4;
    pts.push(`${r2(8 + r * Math.cos(a))} ${r2(8 + r * Math.sin(a))}`);
  }
  return `<path d="M${pts.join('L')}Z" stroke-linejoin="round"/><circle cx="8" cy="8" r="2"/>`;
}
export const GLYPHS = {
  phone: '<rect x="4.5" y="1.5" width="7" height="13" rx="1.8"/><path d="M7 12.2h2"/>',
  cube: '<path d="M8 1.6 14 4.8v6.4L8 14.4 2 11.2V4.8z"/><path d="M2 4.8 8 8l6-3.2M8 8v6.4"/>',
  server: '<rect x="2" y="2.5" width="12" height="4.6" rx="1.2"/><rect x="2" y="8.9" width="12" height="4.6" rx="1.2"/><path d="M4.6 4.8h.01M4.6 11.2h.01M7 4.8h4.4M7 11.2h4.4"/>',
  hammer: '<path d="M8.4 7.6 2.5 13.5a1.1 1.1 0 0 0 1.6 1.6L10 9.2"/><path d="M6.2 5 9 2.2c1.5-.8 3-.4 4 .6l1.4 1.4-1.3 1.3-.9-.3-2.6 2.6z"/>',
  disk: '<rect x="1.5" y="4" width="13" height="8" rx="2"/><path d="M1.6 9.2h12.8M11.4 10.7h.01"/>',
  app: '<rect x="1.5" y="2.5" width="13" height="11" rx="2"/><path d="M1.5 5.6h13M3.8 4h.01M5.6 4h.01"/>',
  terminal: '<rect x="1.5" y="2.5" width="13" height="11" rx="2"/><path d="m4.6 6.2 1.9 1.8-1.9 1.8M8.4 10h3"/>',
  database: '<ellipse cx="8" cy="3.8" rx="5.5" ry="2"/><path d="M2.5 3.8v8.4c0 1.1 2.5 2 5.5 2s5.5-.9 5.5-2V3.8M2.5 8c0 1.1 2.5 2 5.5 2s5.5-.9 5.5-2"/>',
  gear: cog(),
  bolt: '<path d="M9 1.5 3.5 9h4L7 14.5 12.5 7h-4z" stroke-linejoin="round"/>',
  folder: '<path d="M1.5 4.2c0-.9.7-1.7 1.6-1.7h3l1.5 1.7h5.3c.9 0 1.6.7 1.6 1.6v6.4c0 .9-.7 1.6-1.6 1.6H3.1c-.9 0-1.6-.7-1.6-1.6z"/>',
  archive: '<rect x="1.5" y="2.5" width="13" height="3.5" rx="1"/><path d="M2.5 6v6.5c0 .6.4 1 1 1h9c.6 0 1-.4 1-1V6M6.5 8.8h3"/>',
  film: '<rect x="2" y="2" width="12" height="12" rx="2"/><path d="M5 2v12M11 2v12M2 5.5h3M2 10.5h3M11 5.5h3M11 10.5h3"/>',
  search: '<circle cx="7" cy="7" r="4.5"/><path d="m10.4 10.4 3.8 3.8"/>',
  photo: '<rect x="1.5" y="2.5" width="13" height="11" rx="2"/><circle cx="5.5" cy="6.2" r="1.2"/><path d="m1.8 12 4-3.8 3 2.6 2.4-2 3 2.8"/>',
  sparkles: '<path d="M6.2 1.8 7.3 5l3.2 1.2-3.2 1.1-1.1 3.3-1.1-3.3L1.9 6.2 5.1 5z" stroke-linejoin="round"/><path d="m12 9.4.6 1.5 1.5.6-1.5.6-.6 1.6-.6-1.6-1.5-.6 1.5-.6z" stroke-linejoin="round"/>',
  pause: '<circle cx="8" cy="8" r="6.6"/><path d="M6.5 5.6v4.8M9.5 5.6v4.8"/>',
  return: '<path d="M11.8 4.2v3.4c0 .8-.6 1.4-1.4 1.4H4.4M6.6 6.6 4.2 9l2.4 2.4"/>',
  tick: '<path d="m4.9 8.3 2.1 2.1 4.1-4.5"/>',
  chevron: '<path d="m6 3.8 4.2 4.2L6 12.2"/>',
  arrow: '<path d="M8 2.5v9M4.2 8 8 11.8 11.8 8M3 14h10"/>',
};
export function glyph(name, cls = 'yf-glyph') {
  return `<svg class="${cls}" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" aria-hidden="true" focusable="false">${GLYPHS[name] || GLYPHS.app}</svg>`;
}

// ---------------------------------------------------------------------------------------------------------------
// The example (SPEC G.2). Sizes in MiB so every number goes through size(). Why lines verbatim from Copy.swift.
// ---------------------------------------------------------------------------------------------------------------

export const EXAMPLE = {
  rows: [
    { id: 'sim', section: 'running', kind: 'memory', glyph: 'phone', name: 'iPhone 17', why: 'iOS 26.1, idle since Wednesday', mib: 1228.8 },
    { id: 'docker', section: 'running', kind: 'memory', glyph: 'cube', name: 'Docker', why: 'No containers running, nothing using it', mib: 3788.8 },
    { id: 'servers', section: 'running', kind: 'memory', glyph: 'server', name: '3 leftover servers', why: 'Ports 3000 to 5173, from finished coding sessions', mib: 690 },
    { id: 'xcode', section: 'space', kind: 'space', glyph: 'hammer', name: 'Xcode build cache', why: 'Xcode rebuilds this when needed', mib: 14336 },
    { id: 'installer', section: 'space', kind: 'space', glyph: 'disk', name: 'An old installer', why: 'An installer you already used', mib: 1126.4 },
  ],
  know: [
    { id: 'spotlight', glyph: 'search', name: 'Spotlight', why: 'Spotlight is building its search index. It finishes on its own.' },
    { id: 'photos', glyph: 'photo', name: 'Photos', why: 'Photos is looking through your library. It finishes on its own, mostly while charging.' },
  ],
};

/** Timings of a tidy, shared by the panel, the bar count and anyone who wants to move in step. */
export const timing = {
  beat: 260, // the spinners show before the first row leaves
  leaveDelay: (i) => timing.beat + Math.min(i, T.staggerCap) * T.stagger,
  working: (n) => (motion.reduced ? timing.beat + T.state + 120 : timing.leaveDelay(Math.max(0, n - 1)) + T.exit + 160),
  returnDelay: (i) => Math.min(i, T.staggerCap) * T.stagger,
};

/** Totals and strings for any state (pure). */
export function derive(s) {
  const sel = s.rows.filter((r) => s.selected.includes(r.id) && !s.gone.includes(r.id));
  const memory = sel.filter((r) => r.kind === 'memory').reduce((a, r) => a + r.mib, 0);
  const space = sel.filter((r) => r.kind === 'space').reduce((a, r) => a + r.mib, 0);
  const left = s.rows.filter((r) => !s.gone.includes(r.id));
  const tip = s.phase === 'heavy' ? COPY.tipFindings(sel.length, memory + space)
    : s.phase === 'working' ? COPY.tipWorking : s.phase === 'done' ? COPY.tipDone(s.freed) : COPY.tipCalm;
  return {
    count: s.phase === 'heavy' ? sel.length : 0, memory, space, total: memory + space,
    caption: frees(memory, space), left,
    running: left.filter((r) => r.section === 'running'), space_: left.filter((r) => r.section === 'space'),
    tip: COPY.prefix + tip,
    mood: s.phase === 'heavy' ? 'heavy' : s.phase === 'working' ? 'working' : s.phase === 'done' ? 'done' : 'calm',
  };
}

/**
 * The example state machine (SPEC H): heavy -> working -> done -> (60 s) calm; Undo: done -> heavy;
 * reset: calm -> heavy. get() / subscribe(fn) / dispatch(action), the same shape as store.js.
 * Actions: toggle {id} · tidy · undo · reset · know {open?} · ask · touch · phase {phase} (tests and the lab)
 */
export function createExampleStore({ rows = EXAMPLE.rows, know = EXAMPLE.know, undoWindow = T.undoWindow, phase = 'heavy' } = {}) {
  let s = { phase, rows, know, selected: rows.map((r) => r.id), gone: [], freed: 0, knowOpen: false, ask: false, touched: false, prev: null };
  const fns = new Set();
  const timers = {};
  const set = (patch, action) => { s = { ...s, ...patch }; for (const fn of [...fns]) fn(s, action); };
  const clear = (k) => { clearTimeout(timers[k]); timers[k] = 0; };
  const toDone = () => { set({ phase: 'done' }, { type: 'done' }); timers.calm = setTimeout(() => set({ phase: 'calm' }, { type: 'calm' }), undoWindow); };
  const dispatch = (a) => {
    const act = typeof a === 'string' ? { type: a } : a;
    switch (act.type) {
      case 'toggle':
        if (s.phase !== 'heavy') return;
        set({ touched: true, selected: s.selected.includes(act.id) ? s.selected.filter((x) => x !== act.id) : [...s.selected, act.id] }, act);
        return;
      case 'tidy': {
        if (s.phase !== 'heavy') return;
        const d = derive(s);
        const ids = d.left.filter((r) => s.selected.includes(r.id)).map((r) => r.id);
        if (!ids.length) return;
        set({ phase: 'working', touched: true, ask: false, gone: ids, freed: d.total, prev: s.selected }, { ...act, ids });
        clear('done'); timers.done = setTimeout(toDone, timing.working(ids.length));
        return;
      }
      case 'undo':
        if (s.phase !== 'done') return;
        clear('calm');
        set({ phase: 'heavy', gone: [], selected: s.prev || s.rows.map((r) => r.id), freed: 0 }, act);
        return;
      case 'reset':
        clear('calm'); clear('done');
        set({ phase: 'heavy', gone: [], selected: s.rows.map((r) => r.id), freed: 0, ask: false }, act);
        return;
      case 'know': set({ touched: true, knowOpen: act.open ?? !s.knowOpen }, act); return;
      case 'ask':
        clear('ask'); set({ touched: true, ask: true }, act);
        timers.ask = setTimeout(() => set({ ask: false }, { type: 'askEnd' }), T.askNote);
        return;
      case 'touch': if (!s.touched) set({ touched: true }, act); return;
      case 'phase': {
        clear('calm'); clear('done');
        const p = act.phase;
        const gone = p === 'heavy' ? [] : s.rows.map((r) => r.id);
        const freed = p === 'heavy' ? 0 : s.rows.reduce((a, r) => a + r.mib, 0);
        set({ phase: p, gone, freed, selected: s.rows.map((r) => r.id) }, act);
        if (p === 'done') timers.calm = setTimeout(() => set({ phase: 'calm' }, { type: 'calm' }), undoWindow);
        return;
      }
    }
  };
  return { get: () => s, subscribe(fn) { fns.add(fn); return () => fns.delete(fn); }, dispatch, derive: () => derive(s) };
}

// ---------------------------------------------------------------------------------------------------------------
// Markup (Node-safe strings). The panel’s heavy state is pasted into index.html by build.mjs and hydrated.
// ---------------------------------------------------------------------------------------------------------------

const esc = (t) => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/**
 * One app row (FindingRow): check, icon well, name, why line, size pill. Reused by finds and never.
 * opts: { check: true | false | 'off', size: true, well: 'tint' | 'grey', tag: 'div', attrs: '' }
 */
export function rowHTML(r, { check = false, size: showSize = true, well = 'tint', tag = 'div', attrs = '' } = {}) {
  const on = check === true;
  const chk = check === false ? ''
    : `<button type="button" class="yf-check" aria-pressed="${on}" aria-label="${esc(COPY.a11yInclude(r.name, r.mib))}">`
      + `<span class="yf-check__ring"></span>${glyph('tick', 'yf-check__tick')}<span class="yf-spin" aria-hidden="true"></span></button>`;
  const pill = showSize && r.mib ? `<span class="yf-row__size">${size(r.mib)}</span>` : '';
  return `<${tag} class="yf-row${check === 'off' ? ' is-off' : ''}" data-id="${esc(r.id || '')}" ${attrs}>${chk}`
    + `<span class="yf-row__well yf-row__well--${well}">${glyph(r.glyph)}</span>`
    + `<span class="yf-row__text"><span class="yf-row__name">${esc(r.name)}</span><span class="yf-row__why">${esc(r.why)}</span></span>${pill}</${tag}>`;
}

function headHTML(s, d, faceId) {
  const words = {
    heavy: `<p class="yf-panel__title">${esc(COPY.headerHeavy)}</p><p class="yf-panel__sub">${esc(COPY.subHeavy)}</p>`,
    working: `<p class="yf-panel__title">${esc(COPY.headerWorking)}</p>`,
    done: `<p class="yf-panel__title yf-panel__title--hero"><span class="yf-freed">${esc(COPY.headerDone(s.freed))}</span></p><p class="yf-panel__sub">${esc(COPY.subDone)}</p>`,
    calm: `<p class="yf-panel__title">${esc(COPY.headerEmpty)}</p><p class="yf-panel__sub">${esc(COPY.subEmpty)}</p>`,
  }[s.phase];
  return `<span class="yf-panel__face">${pebbleSVG(d.mood, { variant: 'face', id: faceId })}</span><div class="yf-panel__words">${words}</div>`;
}

const key = (tonal) => `<span class="yf-key${tonal ? ' yf-key--tonal' : ''}" aria-hidden="true">${glyph('return', 'yf-key__glyph')}</span>`;

function primaryHTML(s, d) {
  if (s.phase === 'calm') return `<button type="button" class="yf-again" data-act="reset">${esc(COPY.again)}</button>`;
  if (s.phase === 'done') {
    return `<button type="button" class="yf-pill yf-pill--tonal" data-act="undo"><span class="yf-pill__label">${esc(COPY.undo)}</span>${key(true)}</button>`
      + `<p class="yf-panel__caption">${esc(COPY.undoCaption)}</p>`;
  }
  const none = s.phase === 'heavy' && d.count === 0;
  const busy = s.phase === 'working';
  const label = busy ? COPY.headerWorking : none ? COPY.nothingSelected : COPY.tidyUp;
  const aria = busy || none ? '' : ` aria-label="${esc(COPY.a11yTidy(d.count, d.total))}"`;
  return `<button type="button" class="yf-pill" data-act="tidy"${busy || none ? ' aria-disabled="true"' : ''}${aria}><span class="yf-pill__label">${esc(label)}</span>${busy || none ? '' : key(false)}</button>`
    + `<p class="yf-panel__caption">${esc(busy ? '' : d.caption) || '&nbsp;'}</p>`;
}

function badge(n) { return `<span class="yf-badge" aria-hidden="false">${n}</span>` }

/** The whole panel plus its example label, for any state. opts: { mode: 'hero' | 'popover', label: true, id } */
export function panelHTML(s, { mode = 'hero', label = true, id = 'yf-panel' } = {}) {
  const d = derive(s);
  const all = (sec) => s.rows.filter((r) => r.section === sec);
  const fold = (inner, gone, extra = '') => `<div class="yf-fold${gone ? ' is-gone' : ''}" ${extra}><div class="yf-fold__in">${inner}</div></div>`;
  const section = (sec, title, left) => fold(
    `<div class="yf-sec"><div class="yf-sec__head"><span>${esc(title)}</span>${badge(left.length)}</div><div class="yf-sec__rows">`
    + all(sec).map((r) => fold(rowHTML(r, { check: s.selected.includes(r.id) ? true : 'off' }), s.gone.includes(r.id), `data-row="${r.id}"`)).join('')
    + `</div></div>`, left.length === 0, `data-sec="${sec}"`);
  const knowRows = s.know.map((k) => `<div class="yf-know__row">${rowHTML(k, { size: false, well: 'grey', tag: 'div' })}</div>`).join('');
  const knowBox = fold(
    `<div class="yf-know"><button type="button" class="yf-know__toggle" aria-expanded="${s.knowOpen}" aria-controls="${id}-know">`
    + `${glyph('chevron', 'yf-know__chev')}<span class="yf-know__title">${esc(COPY.sectionKnow)}</span>${badge(s.know.length)}</button>`
    + `<div class="yf-fold${s.knowOpen ? '' : ' is-gone'} yf-know__body" id="${id}-know">`
    + `<div class="yf-fold__in"><div class="yf-know__list">${knowRows}</div></div></div></div>`, s.phase === 'calm', 'data-sec="know"');
  const listGone = s.phase === 'calm';
  const role = mode === 'popover' ? 'role="dialog" aria-label="YouFixIt, example panel"' : 'role="group" aria-label="Example YouFixIt panel"';
  return `<div class="yf-p yf-panel yf-panel--${mode}" id="${id}" ${role} tabindex="-1" data-phase="${s.phase}">`
    + `<div class="yf-panel__head">${headHTML(s, d, `${id}-face`)}</div>`
    + fold(`<div class="yf-panel__list"><div class="yf-panel__scroll">`
      + section('running', COPY.sectionRunning, d.running) + section('space', COPY.sectionSpace, d.space_) + knowBox
      + `</div></div>`, listGone, 'data-part="list"')
    + fold(`<p class="yf-panel__note" role="note">${esc(COPY.askNote)}</p>`, !s.ask, 'data-part="note"')
    + `<div class="yf-panel__primary">${primaryHTML(s, d)}</div>`
    + `<div class="yf-panel__foot"><span class="yf-panel__checked">${esc(COPY.checked)}</span>`
    + `<button type="button" class="yf-ask" data-act="ask"${s.phase === 'heavy' ? '' : ' hidden'}>${glyph('sparkles', 'yf-ask__glyph')}<span>${esc(COPY.askAll)}</span></button>`
    + `<span class="yf-panel__icons" aria-hidden="true">${glyph('pause', 'yf-icon')}${glyph('gear', 'yf-icon')}</span></div>`
    + `<p class="yf-sr" aria-live="polite" data-part="live"></p></div>`
    + (label ? `<p class="yf-panel__label">${esc(COPY.label)}</p>` : '');
}

// ---------------------------------------------------------------------------------------------------------------
// Live views
// ---------------------------------------------------------------------------------------------------------------

/** Collapse or open one .yf-fold. how: { ms, ease: 'arrive' | 'leave', delay, lift } */
function setFold(el, open, { ms = T.state, ease = 'arrive', delay = 0, lift = 8 } = {}) {
  if (!el) return;
  el.style.setProperty('--yf-fd', `${motion.reduced ? Math.min(ms, T.state) : ms}ms`);
  el.style.setProperty('--yf-fe', CSS_EASE[ease] || ease);
  el.style.setProperty('--yf-fdl', `${delay}ms`);
  el.style.setProperty('--yf-lift', `${motion.reduced ? 0 : -lift}px`);
  el.classList.toggle('is-gone', !open);
}

/** Bring words in with the perk spring (a 120 ms crossfade under reduced motion). */
export function perkIn(el, { y = 4 } = {}) {
  if (!el?.animate) return;
  if (motion.reduced) { el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: T.feedback, easing: 'ease-out' }); return; }
  el.animate([{ opacity: 0, transform: `translateY(${y}px)` }, { opacity: 1, transform: 'none' }], { duration: SPRING.perk.settle, easing: CSS_EASE.perk });
}

/**
 * Popover fold (SPEC E.4): open 360 ms arrive from scale .94 at the origin’s centre; close 160 ms leave.
 * Reduced motion: a 160 ms opacity change. Resolves when finished.
 */
export function fold(el, originEl, open, { scale = 0.94, ms } = {}) {
  if (!el?.animate) return Promise.resolve();
  if (originEl) {
    const a = el.getBoundingClientRect(), o = originEl.getBoundingClientRect();
    el.style.transformOrigin = `${o.left + o.width / 2 - a.left}px ${o.top + o.height / 2 - a.top}px`;
  }
  const dur = ms ?? (motion.reduced ? T.exit : open ? T.overlay : T.exit);
  const from = motion.reduced ? { opacity: 0 } : { opacity: 0, transform: `scale(${scale})` };
  const to = motion.reduced ? { opacity: 1 } : { opacity: 1, transform: 'none' };
  const anim = el.animate(open ? [from, to] : [to, from], { duration: dur, easing: open ? CSS_EASE.arrive : CSS_EASE.leave, fill: 'both' });
  return anim.finished.then(() => { if (open) anim.cancel(); }).catch(() => {});
}

/**
 * Mount (or hydrate) the example panel. Two views of one store can live on a page (hero and popover).
 *   const store = createExampleStore();
 *   const panel = mountPanel(document.querySelector('#hero-panel'), { store, mode: 'hero' });
 * opts: { store, mode: 'hero' | 'popover', onClose() (popover: Escape), label: true, id }
 * Returns { el, face, focus(), perk(), destroy() }.
 */
export function mountPanel(root, { store = createExampleStore(), mode = 'hero', onClose, label = true, id = `yf-panel-${++uid}` } = {}) {
  if (!root.querySelector('.yf-panel')) root.innerHTML = panelHTML(store.get(), { mode, label, id });
  root.classList.add('yf-panel-host');
  const el = root.querySelector('.yf-panel');
  const q = (s) => el.querySelector(s);
  const head = q('.yf-panel__head');
  const face = new Pebble(q('.yf-panel__face'), { variant: 'face', pose: derive(store.get()).mood });
  const live = q('[data-part="live"]');
  // MeasuredScroll: the list scrolls inside past its cap, with a 28 px fade that says "there is more".
  const list = q('.yf-panel__list'), scroller = q('.yf-panel__scroll');
  const fade = () => { list.dataset.overflow = String(scroller.scrollHeight - scroller.clientHeight - scroller.scrollTop > 2); };
  const ro = typeof ResizeObserver === 'function' ? new ResizeObserver(fade) : null;
  ro?.observe(scroller); if (scroller.firstElementChild) ro?.observe(scroller.firstElementChild);
  scroller.querySelectorAll('.yf-fold').forEach((f) => ro?.observe(f));
  scroller.addEventListener('scroll', fade, { passive: true });
  fade();
  const rowFold = (rid) => el.querySelector(`.yf-fold[data-row="${rid}"]`);
  const secFold = (sec) => el.querySelector(`.yf-fold[data-sec="${sec}"]`);
  const badgeOf = (sec) => secFold(sec)?.querySelector('.yf-badge');
  let prev = store.get();
  let lastInside = false;
  const timers = new Set();
  const later = (fn, ms) => { const t = setTimeout(() => { timers.delete(t); fn(); }, ms); timers.add(t); };
  const clearLater = () => { for (const t of timers) clearTimeout(t); timers.clear(); };

  const onClick = (e) => {
    lastInside = true;
    const t = e.target.closest('button, .yf-row');
    if (!t || !el.contains(t)) return;
    if (t.matches('.yf-check')) { store.dispatch({ type: 'toggle', id: t.closest('.yf-row').dataset.id }); return; }
    if (t.matches('.yf-know__toggle')) { store.dispatch({ type: 'know' }); return; }
    if (t.dataset.act) { if (t.getAttribute('aria-disabled') !== 'true') store.dispatch(t.dataset.act); return; }
    if (t.matches('.yf-sec .yf-row') && store.get().phase === 'heavy') store.dispatch({ type: 'toggle', id: t.dataset.id });
  };
  const runPrimary = () => { const s = store.get(); if (s.phase === 'heavy') store.dispatch('tidy'); else if (s.phase === 'done') store.dispatch('undo'); };
  const onKey = (e) => {
    if (e.key === 'Escape' && mode === 'popover') { e.preventDefault(); onClose?.(); return; }
    if (e.key === 'Enter' && !e.repeat && e.target === el && !e.isComposing) { e.preventDefault(); runPrimary(); }
  };
  // Input modality: a pointer press never shows a focus ring when focus moves to Undo / Again for the next step.
  const onPtr = () => { el.dataset.input = 'pointer'; };
  const onAnyKey = (e) => { if (!e.metaKey && !e.ctrlKey) el.dataset.input = 'key'; };
  el.addEventListener('pointerdown', onPtr);
  document.addEventListener('keydown', onAnyKey, true);
  el.addEventListener('click', onClick);
  el.addEventListener('keydown', onKey);
  el.addEventListener('focusin', () => { lastInside = true; });

  function setBadge(sec, n, animate) {
    const b = badgeOf(sec); if (!b) return;
    const from = +b.textContent;
    if (!animate || from === n) { b.textContent = n; return; }
    b.textContent = n; perkIn(b, { y: n < from ? -3 : 3 });
  }

  function syncRows(s, animate) {
    for (const r of s.rows) {
      const f = rowFold(r.id); if (!f) continue;
      const row = f.querySelector('.yf-row'), chk = row.querySelector('.yf-check');
      const on = s.selected.includes(r.id);
      row.classList.toggle('is-off', !on);
      chk?.setAttribute('aria-pressed', String(on));
      if (!animate) { setFold(f, !s.gone.includes(r.id), { ms: 0 }); row.classList.remove('is-busy'); }
    }
  }

  function renderPrimary(s, d) {
    const box = q('.yf-panel__primary');
    const had = box.contains(document.activeElement);
    const pill = box.querySelector('.yf-pill');
    const kind = s.phase === 'heavy' || s.phase === 'working' ? 'tidy' : s.phase;
    if (pill && pill.dataset.act === 'tidy' && kind === 'tidy') {
      // In place, so focus and the pressed state survive a check or a caption change.
      const tmp = document.createElement('div'); tmp.innerHTML = primaryHTML(s, d);
      const np = tmp.querySelector('.yf-pill');
      for (const a of ['aria-disabled', 'aria-label']) { const v = np.getAttribute(a); v == null ? pill.removeAttribute(a) : pill.setAttribute(a, v); }
      pill.innerHTML = np.innerHTML;
      const cap = box.querySelector('.yf-panel__caption'), ncap = tmp.querySelector('.yf-panel__caption');
      if (cap.textContent !== ncap.textContent) cap.innerHTML = ncap.innerHTML;
      return;
    }
    box.innerHTML = primaryHTML(s, d);
    perkIn(box.firstElementChild);
    if (had || (s.phase === 'done' && lastInside)) box.querySelector('button')?.focus({ preventScroll: true });
  }

  function renderHead(s, d) {
    const words = head.querySelector('.yf-panel__words');
    const tmp = document.createElement('div'); tmp.innerHTML = headHTML(s, d, 'x');
    words.innerHTML = tmp.querySelector('.yf-panel__words').innerHTML;
    perkIn(words);
    face.to(d.mood, { ease: s.phase === 'calm' ? 'smooth' : 'perk', duration: s.phase === 'calm' ? T.state : 450 });
    if (s.phase === 'done') {
      const span = words.querySelector('.yf-freed');
      roll(0, s.freed, T.count, (v) => { span.textContent = COPY.headerDone(v); });
    }
  }

  function render(s, action = {}) {
    const d = derive(s);
    const jump = action.type === 'phase' || action.type === 'sync';
    // FLIP: a phase change re-lays the panel (the head grows for done); what sits below glides there with a
    // transform instead of jumping, so nothing shifts in layout terms long after the press.
    const flip = s.phase !== prev.phase && !jump && !motion.reduced
      ? [q('[data-part="list"]'), q('.yf-panel__primary'), q('.yf-panel__foot')].filter(Boolean).map((e) => [e, e.getBoundingClientRect().top]) : [];
    el.dataset.phase = s.phase;
    syncRows(s, !jump);
    setFold(q('[data-part="note"]'), s.ask, { ms: T.state });
    const kb = q('.yf-know__body');
    if (kb.classList.contains('is-gone') === s.knowOpen) setFold(kb, s.knowOpen, { ms: s.knowOpen ? T.state : T.exit, ease: s.knowOpen ? 'arrive' : 'leave', lift: 0 });
    q('.yf-know__toggle').setAttribute('aria-expanded', String(s.knowOpen));
    q('.yf-ask').hidden = s.phase !== 'heavy';

    if (s.phase !== prev.phase || jump) {
      clearLater();
      renderHead(s, d);
      if (jump) {
        unfade();
        for (const sec of ['running', 'space']) { setFold(secFold(sec), (sec === 'running' ? d.running : d.space_).length > 0, { ms: 0 }); setBadge(sec, (sec === 'running' ? d.running : d.space_).length, false); }
        setFold(secFold('know'), s.phase !== 'calm', { ms: 0 });
        setFold(q('[data-part="list"]'), s.phase !== 'calm', { ms: 0 });
      } else if (s.phase === 'working') leaveRows(s, action.ids || s.gone);
      else if (s.phase === 'heavy') { unfade(); returnRows(s, prev); }
      else if (s.phase === 'done') collapseGone(s);
      else if (s.phase === 'calm') { setFold(q('[data-part="list"]'), false, { ms: T.state, ease: 'leave' }); }
      live.textContent = d.tip;
    }
    if (s.phase === 'heavy' && !jump) {
      for (const sec of ['running', 'space']) if (prev.phase === 'heavy') setBadge(sec, (sec === 'running' ? d.running : d.space_).length, false);
    }
    renderPrimary(s, d);
    for (const [e, top] of flip) {
      const dy = top - e.getBoundingClientRect().top;
      if (Math.abs(dy) > 0.5 && e.animate) e.animate([{ transform: `translateY(${dy}px)` }, { transform: 'none' }], { duration: T.state, easing: CSS_EASE.arrive });
    }
    prev = s;
  }

  // Rows leave with opacity and transform only (no re-layout per frame); once the last one has faded, every gone
  // row and emptied section collapses in one step and what sat below glides up with a transform (FLIP).
  const fades = new Set();
  function unfade() { for (const a of fades) a.cancel(); fades.clear(); }
  function leaveRows(s, ids) {
    const order = s.rows.filter((r) => ids.includes(r.id)).reverse(); // nearest the pill first
    const left = { running: s.rows.filter((r) => r.section === 'running').length, space: s.rows.filter((r) => r.section === 'space').length };
    let end = 0;
    order.forEach((r, i) => {
      const f = rowFold(r.id);
      f.querySelector('.yf-row').classList.add('is-busy');
      const at = motion.reduced ? timing.beat : timing.leaveDelay(i);
      const ms = motion.reduced ? T.state : T.exit;
      const inner = f.firstElementChild;
      if (inner?.animate) {
        fades.add(inner.animate([{ opacity: 1, transform: 'none' }, { opacity: 0, transform: `translateY(${motion.reduced ? 0 : -8}px)` }],
          { duration: ms, delay: at, easing: CSS_EASE.leave, fill: 'forwards' }));
      }
      end = Math.max(end, at + ms);
      later(() => { left[r.section]--; setBadge(r.section, left[r.section], true); }, at);
    });
    later(() => collapseGone(store.get()), end);
  }

  function collapseGone(s) {
    const gone = s.rows.filter((r) => s.gone.includes(r.id)).map((r) => rowFold(r.id)).filter((f) => f && !f.classList.contains('is-gone'));
    if (!gone.length) return;
    const below = [secFold('know'), q('.yf-panel__primary')].filter(Boolean);
    const before = below.map((b) => b.getBoundingClientRect().top);
    gone.forEach((f) => setFold(f, false, { ms: 0 }));
    for (const sec of ['running', 'space']) {
      if (!s.rows.some((r) => r.section === sec && !s.gone.includes(r.id))) setFold(secFold(sec), false, { ms: 0 });
    }
    unfade();
    if (motion.reduced) return;
    below.forEach((b, i) => {
      const dy = before[i] - b.getBoundingClientRect().top;
      if (Math.abs(dy) > 0.5 && b.animate) b.animate([{ transform: `translateY(${dy}px)` }, { transform: 'none' }], { duration: T.state, easing: CSS_EASE.arrive });
    });
  }

  function returnRows(s, before) {
    setFold(q('[data-part="list"]'), true, { ms: T.overlay });
    setFold(secFold('know'), true, { ms: 0 });
    const back = s.rows.filter((r) => before.gone.includes(r.id) || before.phase === 'calm');
    for (const sec of ['running', 'space']) setFold(secFold(sec), true, { ms: T.state });
    back.forEach((r, i) => {
      const f = rowFold(r.id);
      f.querySelector('.yf-row').classList.remove('is-busy');
      setFold(f, true, { ms: T.state, ease: 'arrive', delay: motion.reduced ? 0 : timing.returnDelay(i) });
    });
    for (const sec of ['running', 'space']) setBadge(sec, s.rows.filter((r) => r.section === sec).length, true);
  }

  const off = store.subscribe((s, a) => render(s, a));
  if (store.get().phase !== 'heavy') render(store.get(), { type: 'sync' });
  else { syncRows(store.get(), false); renderPrimary(store.get(), derive(store.get())); }

  return {
    el, face,
    focus() { el.focus({ preventScroll: true }); },
    perk() { face.perk(); perkIn(head.querySelector('.yf-panel__words'), { y: 2 }); },
    destroy() { off(); clearLater(); face.destroy(); ro?.disconnect(); scroller.removeEventListener('scroll', fade); el.removeEventListener('click', onClick); el.removeEventListener('keydown', onKey); el.removeEventListener('pointerdown', onPtr); document.removeEventListener('keydown', onAnyKey, true); },
  };
}

/**
 * The menu bar face bound to the store (SPEC H, I.1). `button` is the <button> in the bar; the pebble and count are
 * drawn inside it, and its accessible name and title follow the store’s "Example: " tooltip.
 *   mountBarFace(document.querySelector('.menubar__face'), { store });
 */
export function mountBarFace(button, { store, breathe = true } = {}) {
  let host = button.querySelector('.yf-pb');
  if (!host) { host = document.createElement('span'); button.prepend(host); }
  const s0 = store.get(), d0 = derive(s0);
  const pebble = new Pebble(host, { variant: 'bar', pose: d0.mood, count: d0.count || null, breathe });
  let prev = s0;
  const tip = (d) => { button.setAttribute('aria-label', d.tip); button.title = d.tip; };
  tip(d0);
  const timers = [];
  const off = store.subscribe((s, a) => {
    const d = derive(s);
    tip(d);
    if (s.phase !== prev.phase) {
      timers.splice(0).forEach(clearTimeout);
      if (s.phase === 'working') {
        pebble.to('working');
        let n = derive(prev).count;
        (a?.ids || s.gone).forEach((_, i) => timers.push(setTimeout(() => pebble.setCount(--n || null), motion.reduced ? timing.beat : timing.leaveDelay(i))));
      } else if (s.phase === 'done') { pebble.setCount(null); pebble.show('done'); }
      else if (s.phase === 'heavy') { pebble.show('heavy'); pebble.setCount(d.count || null); }
      else pebble.to('calm', { duration: T.overlay }), pebble.setCount(null);
    } else if (s.phase === 'heavy') pebble.setCount(d.count || null);
    prev = s;
  });
  return { pebble, destroy() { off(); timers.forEach(clearTimeout); pebble.destroy(); } };
}
