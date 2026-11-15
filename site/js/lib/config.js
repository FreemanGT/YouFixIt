// The one place for URLs and the version. Never print VERSION in the hero (FACTS).
export const REPO_URL = "https://github.com/FreemanGT/YouFixIt";
export const DMG_URL = "https://github.com/FreemanGT/YouFixIt/releases/latest/download/YouFixIt.dmg";
export const API_URL = "https://api.github.com/repos/FreemanGT/YouFixIt";
export const VERSION = "0.6";
export const UNDO_WINDOW = 60_000; // Theme.undoWindow
export const STAR_MIN = 25; // show the live star count only from 25 up (FACTS)

// The signup endpoint lives only in <meta name="yf-signup"> (SPEC §I.4).
export const SIGNUP_URL = document.querySelector('meta[name="yf-signup"]')?.content || "";
