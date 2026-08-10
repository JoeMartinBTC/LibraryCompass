/* Prüft den EAN-13-Decoder gegen erzeugte Strichcodes.
   Ein Barcode-Leser, der nur im Idealfall funktioniert, versagt genau im Laden. */
import { findEAN13, checksum } from "./ean.js";

const L = [[3,2,1,1],[2,2,2,1],[2,1,2,2],[1,4,1,1],[1,1,3,2],
           [1,2,3,1],[1,1,1,4],[1,3,1,2],[1,2,1,3],[3,1,1,2]];
const G = L.map(p => [...p].reverse());
const PARITY = ["LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG",
                "LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL"];

/** Erzeugt die 95 Module eines EAN-13 als 0/1-Feld (1 = dunkel). */
function modules(code) {
  const d = code.split("").map(Number);
  const bits = [];
  const push = (pattern, startDark) => {
    let dark = startDark;
    for (const len of pattern) { for (let i = 0; i < len; i++) bits.push(dark ? 1 : 0); dark = !dark; }
  };
  push([1,1,1], true);                               // Start 101
  const parity = PARITY[d[0]];
  for (let i = 0; i < 6; i++) {
    const table = parity[i] === "L" ? L : G;
    // L beginnt mit einer Lücke, G ebenfalls — beide Muster starten hell.
    push(table[d[i + 1]], false);
  }
  push([1,1,1,1,1], false);                          // Mitte 01010
  for (let i = 0; i < 6; i++) push(L[d[i + 7]], true); // R = L invertiert → startet dunkel
  push([1,1,1], true);                               // Ende 101
  return bits;
}

function withCheck(twelve) {
  const d = twelve.split("").map(Number);
  return twelve + checksum(d);
}

/** Baut ein RGBA-Bild aus den Modulen. */
function render(code, { unit = 3, quiet = 12, height = 60, noise = 0, blur = 0, invert = false } = {}) {
  const bits = modules(code);
  const width = Math.round((bits.length + quiet * 2) * unit);
  const data = new Uint8ClampedArray(width * height * 4);
  const line = new Float64Array(width).fill(255);
  // Pixelweise zuordnen statt modulweise schreiben: bei nicht-ganzzahliger
  // Modulbreite (2,5 Pixel) landet man sonst auf Bruchteil-Indizes, und der Test
  // prüft ein Bild, das es gar nicht gibt.
  for (let x = 0; x < width; x++) {
    const module = Math.floor(x / unit) - quiet;
    if (module >= 0 && module < bits.length && bits[module]) line[x] = 0;
  }
  let out = line;
  if (blur > 0) {                                   // simple Mittelung als Unschärfe
    out = new Float64Array(width);
    for (let x = 0; x < width; x++) {
      let sum = 0, n = 0;
      for (let k = -blur; k <= blur; k++) {
        const xx = x + k;
        if (xx >= 0 && xx < width) { sum += line[xx]; n++; }
      }
      out[x] = sum / n;
    }
  }
  let seed = 7;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let v = out[x];
      if (noise) v += (rnd() - 0.5) * 2 * noise;
      if (invert) v = 255 - v;
      v = Math.max(0, Math.min(255, v));
      const i = (y * width + x) * 4;
      data[i] = data[i + 1] = data[i + 2] = v; data[i + 3] = 255;
    }
  }
  return { data, width, height };
}

const codes = [
  withCheck("978344247776"),   // Cobra, Forsyth
  withCheck("978395890573"),   // Wie man einen Drachen tötet
  withCheck("978386352619"),   // dieselbe Reihe, Hörbuch
  withCheck("400000000000"),
  withCheck("501234567890"),
];

let pass = 0, fail = 0;
const report = [];
function check(name, code, opts) {
  const img = render(code, opts);
  const got = findEAN13(img.data, img.width, img.height);
  const ok = got === code;
  ok ? pass++ : fail++;
  if (!ok) report.push(`${name}: erwartet ${code}, bekam ${got}`);
}

for (const code of codes) {
  check("sauber u=3", code, { unit: 3 });
  check("klein u=2", code, { unit: 2 });
  check("groß u=6", code, { unit: 6 });
  check("krumm u=2.5", code, { unit: 2.5 });
  check("rauschen 40", code, { unit: 3, noise: 40 });
  check("rauschen 70", code, { unit: 4, noise: 70 });
  check("unschärfe 1", code, { unit: 4, blur: 1 });
  check("unschärfe 2", code, { unit: 5, blur: 2 });
  check("invertiert", code, { unit: 3, invert: true });
  check("wenig Rand", code, { unit: 3, quiet: 2 });
  check("dunkel/kontrastarm", code, { unit: 3, noise: 10 });
}

// Anti: Ein Bild ohne Strichcode darf nichts liefern.
const flat = { data: new Uint8ClampedArray(400 * 40 * 4).fill(200), width: 400, height: 40 };
for (let i = 3; i < flat.data.length; i += 4) flat.data[i] = 255;
const nothing = findEAN13(flat.data, flat.width, flat.height);
if (nothing === null) pass++; else { fail++; report.push(`leere Fläche lieferte ${nothing}`); }

// Anti: Zufallsrauschen darf keine Nummer erfinden.
let noiseHits = 0;
for (let run = 0; run < 40; run++) {
  let seed = 99 + run * 7919;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  const noiseImg = new Uint8ClampedArray(600 * 40 * 4);
  for (let i = 0; i < 600 * 40; i++) {
    const v = rnd() * 255;
    noiseImg[i * 4] = noiseImg[i * 4 + 1] = noiseImg[i * 4 + 2] = v; noiseImg[i * 4 + 3] = 255;
  }
  const fromNoise = findEAN13(noiseImg, 600, 40);
  if (fromNoise !== null) { noiseHits++; report.push(`Rauschen ${run} lieferte ${fromNoise}`); }
}
if (noiseHits === 0) pass++; else fail++;

// Anti: eine kaputte Prüfziffer darf nicht durchgehen.
const broken = "9783442477761";
const bad = render(broken, { unit: 3 });
const gotBad = findEAN13(bad.data, bad.width, bad.height);
if (gotBad === null) pass++; else { fail++; report.push(`falsche Prüfziffer akzeptiert: ${gotBad}`); }

console.log(`bestanden ${pass}, gescheitert ${fail}`);
for (const line of report) console.log("  ✗ " + line);
process.exit(fail ? 1 : 0);
