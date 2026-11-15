// The email gate (SPEC §I.4). Markup comes from build.mjs (<!-- @gate <id> -->), styles in base.css.
// Valid email → beacon to the Apps Script sheet (once per email) → DMG navigation, all in the same task:
// the download never waits on the network. Phones send the beacon but get the "Mac app" line instead.
import { DMG_URL, SIGNUP_URL } from "./config.js";
import { renderPebble } from "./pebble.js";
import { perk } from "./motion.js";

const RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const MSG = {
  empty: "Add your email first, then the download starts.",
  incomplete: "That email looks incomplete. Add the part after the @.",
  note: "Your email goes to a Google Sheet the maker reads, and nowhere else. The app itself never goes online.",
  phone: "YouFixIt is a Mac app. Open this page on your Mac to install it.",
  phoneLink: "Download the disk image",
  started: "Open the disk image and drag YouFixIt to Applications.",
  startedLink: "If it didn’t start, download it directly.",
};
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch {} },
};

/** Coarse platform string: "Mac Apple silicon" | "Mac Intel" | "Mac" | "iPhone" | "Android" | "Other". */
export function platformString() {
  const ua = navigator.userAgent || "";
  const d = navigator.userAgentData;
  if (/iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) return "iPhone";
  if (/Android/.test(ua) || d?.platform === "Android") return "Android";
  if (d?.platform === "macOS" || /Macintosh|Mac OS X/.test(ua)) {
    try { // WebGL renderer names the GPU: "Apple M…" means Apple silicon
      const gl = document.createElement("canvas").getContext("webgl");
      const ext = gl?.getExtension("WEBGL_debug_renderer_info");
      const gpu = ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : "";
      if (/Apple M\d|Apple GPU/.test(gpu)) return "Mac Apple silicon";
      if (/Intel|AMD|Radeon/.test(gpu)) return "Mac Intel";
    } catch {}
    return "Mac";
  }
  return "Other";
}
export const isPhone = () => ["iPhone", "Android"].includes(platformString());

function send(email, company) {
  if (!SIGNUP_URL) return;
  const body = new URLSearchParams({ type: "mac", email, name: "", platform: "YouFixIt · " + platformString(), ref: document.referrer || "", company: company || "" });
  let ok = false;
  try { ok = navigator.sendBeacon?.(SIGNUP_URL, body); } catch {}
  if (!ok) { try { fetch(SIGNUP_URL, { method: "POST", mode: "no-cors", keepalive: true, body }).catch(() => {}); } catch {} }
}

/**
 * mountGate(formEl, {onDownload}) wires one gate. onDownload() runs after a Mac download starts
 * (main.js uses it to dispatch {type:"download"} so the pebbles hop). Returns a cleanup function.
 */
export function mountGate(form, { onDownload } = {}) {
  const input = form.querySelector('input[type="email"]');
  const hp = form.querySelector('input[name="company"]');
  const err = form.querySelector(".gate__error");
  const errText = form.querySelector(".gate__error-text");
  const note = form.querySelector(".gate__note");
  const btn = form.querySelector(".gate__btn");
  const btnText = form.querySelector(".gate__btn-text");
  const face = form.querySelector(".gate__error .yf-pb");
  if (!input || !btn) return () => {};
  if (face) renderPebble(face, { pose: "heavy" });
  const remembered = store.get("yf-email");
  if (remembered && !input.value) input.value = remembered;
  const describedBase = input.getAttribute("aria-describedby") || "";
  let resetT = 0;

  const showError = (msg) => {
    errText.textContent = msg;
    err.hidden = false;
    input.setAttribute("aria-invalid", "true");
    input.setAttribute("aria-describedby", `${err.id} ${describedBase}`.trim());
    perk(err, { from: 0.96 });
  };
  const clearError = () => {
    if (err.hidden) return;
    err.hidden = true; errText.textContent = "";
    input.removeAttribute("aria-invalid");
    input.setAttribute("aria-describedby", describedBase);
  };
  const setNote = (text, linkText) => {
    note.textContent = text + (linkText ? " " : "");
    if (linkText) { const a = document.createElement("a"); a.href = DMG_URL; a.textContent = linkText; note.append(a); }
  };

  const onSubmit = (e) => {
    e.preventDefault();
    const email = input.value.trim();
    if (!email) { showError(MSG.empty); input.focus(); return; }
    if (!RE.test(email)) { showError(MSG.incomplete); input.focus(); return; }
    clearError();
    if (hp?.value) return; // a bot filled the honeypot: do nothing at all
    const sentKey = "yf-sent:" + email.toLowerCase();
    if (!store.get(sentKey)) { send(email, hp?.value); store.set(sentKey, "1"); }
    store.set("yf-email", email);
    if (isPhone()) { setNote(MSG.phone, MSG.phoneLink); return; }
    location.href = DMG_URL;
    btnText.textContent = "Downloading";
    btn.classList.add("is-downloading");
    perk(btn, { from: 0.96 });
    setNote(MSG.started, MSG.startedLink);
    onDownload?.();
    clearTimeout(resetT);
    resetT = setTimeout(() => { btnText.textContent = "Download for Mac"; btn.classList.remove("is-downloading"); }, 4000);
  };
  form.addEventListener("submit", onSubmit);
  input.addEventListener("input", clearError);
  return () => { form.removeEventListener("submit", onSubmit); input.removeEventListener("input", clearError); clearTimeout(resetT); };
}

/** For the menu bar Download pill: a remembered email downloads at once; returns true if it did. */
export function quickDownload({ onDownload } = {}) {
  const email = store.get("yf-email");
  if (!email || !RE.test(email) || isPhone()) return false;
  location.href = DMG_URL;
  onDownload?.();
  return true;
}

export { MSG as GATE_COPY };
