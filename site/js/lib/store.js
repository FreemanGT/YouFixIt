// The one example state (SPEC §H). The state machine itself is the product component’s
// (lib/component.js createExampleStore: heavy → working → done → 60 s → calm; Undo; reset), so the panel,
// the popover and the menu bar face run on exactly what the app does. This module holds the ONE instance and
// adds what the site needs around it: page UI flags (heroOpen, popoverOpen, downloads) and helpers.
//   get() → {phase, rows, selected, gone, freed, knowOpen, ask, touched, heroOpen, popoverOpen, downloads}
//   subscribe(fn(state, prev, action)) → off · dispatch(action)
//   Example actions: toggle {id} · tidy · undo · reset (alias: again) · know {open?} · ask · touch
//   Page actions:    hero {open} · popover {open} · download
import { createExampleStore, derive, EXAMPLE } from "./component.js";

/** The raw component store. Pass THIS to Component.mountPanel / mountBarFace (their subscribers get (s, action)). */
// On the page Undo stays for 3 minutes (the app gives a minute; a slow reader of a demo should not lose the control).
export const example = createExampleStore({ undoWindow: 180000 });

let ui = { heroOpen: true, popoverOpen: false, downloads: 0 };
let state = { ...example.get(), ...ui };
const subs = new Set();
const emit = (prev, action) => subs.forEach((fn) => { try { fn(state, prev, action); } catch (e) { console.error(e); } });

example.subscribe((s, action) => { const prev = state; state = { ...s, ...ui }; emit(prev, action); });

export function dispatch(action) {
  const a = typeof action === "string" ? { type: action } : action;
  const page = (patch) => {
    const prev = state;
    ui = { ...ui, ...patch };
    state = { ...state, ...ui };
    emit(prev, a);
  };
  switch (a.type) {
    case "hero": if (state.heroOpen !== !!a.open) page({ heroOpen: !!a.open }); return;
    case "popover": if (state.popoverOpen !== !!a.open) page({ popoverOpen: !!a.open }); return;
    case "download": page({ downloads: ui.downloads + 1 }); return;
    case "again": example.dispatch({ type: "reset" }); return;
    default: example.dispatch(a);
  }
}

export const get = () => state;
export function subscribe(fn) { subs.add(fn); return () => subs.delete(fn); }

/** Totals and strings for a state (component derive): {count, memory, space, total, caption, left, running, space_, tip, mood}. */
export const totals = (s = state) => derive(s);
/** "Example: …" tooltip string (SPEC §G.3). */
export const tooltip = (s = state) => derive(s).tip;
/** html[data-mood]: heavy | working | done | calm. */
export const mood = (s = state) => derive(s).mood;
/** Did the visitor tidy the example (finale period)? */
export const tidied = (s = state) => s.phase === "done" || s.phase === "calm";
export const ROWS = EXAMPLE.rows;
export const KNOW = EXAMPLE.know;

export const store = { get, subscribe, dispatch, example, totals, tooltip, mood, tidied, ROWS, KNOW };
export default store;
