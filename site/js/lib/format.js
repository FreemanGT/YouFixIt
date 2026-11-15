// Ported exactly from Copy.swift `Format.size` and `Copy.things`. Inputs are MiB (the demo’s unit).
// size(5707.6) → "5.6 GB" · size(15462.4) → "15 GB" · size(690) → "690 MB" · size(21170) → "21 GB"
export function size(mib) {
  const mb = Number(mib) || 0;
  if (mb < 1000) return `${Math.round(mb)} MB`;
  const gb = mb / 1024;
  const whole = gb >= 10 || Math.abs(gb - Math.round(gb)) < 0.05;
  return whole ? `${Math.round(gb)} GB` : `${gb.toFixed(1)} GB`;
}

/** Bytes in, same rule (for anyone holding real bytes). */
export const sizeBytes = (bytes) => size(bytes / 1_048_576);

export const things = (n) => (n === 1 ? "1 thing" : `${n} things`);

/** Copy.tidyCaption: "Frees about X of memory and Y of space" (either half may be absent). */
export function frees(memMiB, diskMiB) {
  if (memMiB > 0 && diskMiB > 0) return `Frees about ${size(memMiB)} of memory and ${size(diskMiB)} of space`;
  if (memMiB > 0) return `Frees about ${size(memMiB)} of memory`;
  if (diskMiB > 0) return `Frees about ${size(diskMiB)} of space`;
  return "";
}
