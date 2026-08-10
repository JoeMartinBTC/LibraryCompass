/* EAN-13 aus einem Kamerabild lesen.
 *
 * Nötig, weil `BarcodeDetector` genau dort fehlt, wo diese Seite benutzt wird:
 * in Safari ist die Schnittstelle bis Version 26 **standardmäßig abgeschaltet**,
 * Firefox kennt sie gar nicht. Auf dem iPhone erschien der Scan-Knopf deshalb nie.
 *
 * Eine fertige Bibliothek wäre 400 KB Fremdcode und eine Abhängigkeit zur Laufzeit —
 * beides widerspricht der Doktrin dieser Seite (eine Datei, nichts von außen, offline).
 * EAN-13 ist dafür einfach genug: 95 Module, feste Struktur, Prüfziffer.
 *
 * Der Weg: Bildzeile → Hell/Dunkel-Lauflängen → Ziffern über Musterabgleich →
 * erste Ziffer aus dem Paritätsmuster → Prüfziffer. Gelesen wird nicht eine Zeile,
 * sondern viele über das Bild verteilt; angenommen wird nur, was **drei** davon
 * übereinstimmend liefern.
 */

/**
 * Wie breit ein Modul mindestens sein muss, in Pixeln.
 *
 * Der Wert ist kein Feinschliff, sondern der wirksamste Schutz gegen erfundene Nummern.
 * Bildrauschen erzeugt Läufe von ein bis zwei Pixeln, und daraus setzt sich mit genug
 * Versuchen eine Folge zusammen, die Prüfziffer und Breitenprobe besteht — im Test kam
 * `9511145768041` aus fünf verschiedenen Zufallsbildern.
 *
 * Ein echter Strichcode ist im Kamerabild gröber: bei 640 Pixeln Breite und einem Code,
 * der ein Drittel des Bildes einnimmt, sind es gut zwei Pixel je Modul. Wer darunter
 * liegt, hält das Buch zu weit weg — dann lieber nichts erkennen als etwas erfinden.
 */
const MIN_UNIT = 1.6;

/** Die vier Lauflängen je Ziffer (Balken, Lücke, Balken, Lücke) in Modulen. */
const L = [[3,2,1,1],[2,2,2,1],[2,1,2,2],[1,4,1,1],[1,1,3,2],
           [1,2,3,1],[1,1,1,4],[1,3,1,2],[1,2,1,3],[3,1,1,2]];
// G ist L rückwärts, R ist L mit vertauschten Balken und Lücken.
const G = L.map(p => [...p].reverse());
const R = L;

/** Welches Paritätsmuster der linken Hälfte für welche erste Ziffer steht. */
const PARITY = ["LLLLLL","LLGLGG","LLGGLG","LLGGGL","LGLLGG",
                "LGGLLG","LGGGLL","LGLGLG","LGLGGL","LGGLGL"];

/** Graustufen einer Bildzeile, mit Schwelle in Hell/Dunkel geteilt. */
function runsOfRow(data, width, y) {
  let min = 255, max = 0;
  const row = new Uint8Array(width);
  for (let x = 0; x < width; x++) {
    const i = (y * width + x) * 4;
    // Grün wiegt am schwersten — es trägt den größten Teil der Helligkeit.
    const v = (data[i] * 3 + data[i + 1] * 6 + data[i + 2]) / 10;
    row[x] = v;
    if (v < min) min = v;
    if (v > max) max = v;
  }
  // Zu wenig Kontrast heißt: hier ist kein Strichcode, sondern Tischplatte.
  if (max - min < 40) return null;
  const threshold = (min + max) / 2;

  const runs = [];
  let dark = row[0] < threshold, length = 0;
  for (let x = 0; x < width; x++) {
    const isDark = row[x] < threshold;
    if (isDark === dark) { length++; continue; }
    runs.push(length);
    dark = isDark;
    length = 1;
  }
  runs.push(length);
  return { runs, startsDark: row[0] < threshold };
}

/** Wie gut passen vier gemessene Längen zu einem Muster? Kleiner ist besser. */
function distance(measured, pattern) {
  const sum = measured[0] + measured[1] + measured[2] + measured[3];
  if (sum <= 0) return Infinity;
  const unit = sum / 7;                    // jede Ziffer belegt sieben Module
  if (unit < MIN_UNIT) return Infinity;
  let total = 0;
  for (let i = 0; i < 4; i++) {
    const diff = Math.abs(measured[i] / unit - pattern[i]);
    if (diff > 0.75) return Infinity;      // ein grob falscher Balken verwirft sofort
    total += diff;
  }
  return total;
}

function bestDigit(measured, table) {
  let best = -1, bestScore = Infinity;
  for (let d = 0; d < 10; d++) {
    const score = distance(measured, table[d]);
    if (score < bestScore) { bestScore = score; best = d; }
  }
  return best < 0 ? null : { digit: best, score: bestScore };
}

export function checksum(digits) {
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += digits[i] * (i % 2 ? 3 : 1);
  return (10 - sum % 10) % 10;
}

/**
 * Eine Folge von Lauflängen ab `start` als EAN-13 lesen.
 * `start` zeigt auf den ersten Balken des Startmusters (dunkel).
 */
function decodeFrom(runs, start) {
  // Startmuster 101: drei Läufe von je einem Modul.
  const unit = (runs[start] + runs[start + 1] + runs[start + 2]) / 3;
  if (!unit || unit < MIN_UNIT) return null;
  for (let i = 0; i < 3; i++) {
    if (Math.abs(runs[start + i] / unit - 1) > 0.5) return null;
  }

  let at = start + 3;
  const left = [], parity = [];
  for (let d = 0; d < 6; d++) {
    const four = runs.slice(at, at + 4);
    if (four.length < 4) return null;
    const asL = bestDigit(four, L), asG = bestDigit(four, G);
    if (!asL && !asG) return null;
    if (asL && (!asG || asL.score <= asG.score)) { left.push(asL.digit); parity.push("L"); }
    else { left.push(asG.digit); parity.push("G"); }
    at += 4;
  }

  // Trennmuster in der Mitte: 01010, also fünf Läufe von je einem Modul.
  for (let i = 0; i < 5; i++) {
    const run = runs[at + i];
    if (run === undefined || Math.abs(run / unit - 1) > 0.6) return null;
  }
  at += 5;

  const right = [];
  for (let d = 0; d < 6; d++) {
    const four = runs.slice(at, at + 4);
    if (four.length < 4) return null;
    const digit = bestDigit(four, R);
    if (!digit) return null;
    right.push(digit.digit);
    at += 4;
  }

  const first = PARITY.indexOf(parity.join(""));
  if (first < 0) return null;

  const digits = [first, ...left, ...right];
  if (digits.length !== 13) return null;
  if (checksum(digits) !== digits[12]) return null;

  // Die Modulbreite muss über den **ganzen** Code halten.
  //
  // Ein echter EAN-13 ist 95 Module breit; die Summe aller Läufe von Start bis Ende
  // muss also 95 × Modulbreite ergeben. Ohne diese Prüfung setzt sich aus reinem
  // Bildrauschen irgendwann eine Ziffernfolge zusammen, die sogar die Prüfziffer
  // besteht — im Test genau so passiert (`5932571848413` aus einem Zufallsbild).
  // Eine erfundene Nummer ist hier das Schlimmste: sie beantwortet „habe ich das
  // schon?" mit einem fremden Buch.
  let span = 0;
  for (let i = start; i < at; i++) span += runs[i];
  if (Math.abs(span / (95 * unit) - 1) > 0.12) return null;

  return digits.join("");
}

/**
 * Eine Zeile absuchen — vorwärts und rückwärts, weil der Code verkehrt herum im Bild
 * liegen kann, und mit beiden Startparitäten.
 *
 * Die zweite Parität deckt den hell-auf-dunkel gedruckten Code ab. Selten, aber es
 * kostet nichts: Prüfziffer, Breitenprobe und die Forderung nach drei übereinstimmenden
 * Zeilen fangen ab, was dabei zusätzlich an Zufallsmustern hereinkäme.
 */
function decodeRuns(runs) {
  const flipped = [...runs].reverse();
  for (const series of [runs, flipped]) {
    for (let i = 0; i + 59 < series.length; i++) {
      const hit = decodeFrom(series, i);
      if (hit) return hit;
    }
  }
  return null;
}

/**
 * Sucht in Bilddaten nach einem EAN-13.
 *
 * Es werden mehrere Zeilen über das Bild verteilt gelesen, und ein Ergebnis gilt erst,
 * wenn **drei verschiedene Zeilen** dieselbe Nummer liefern. Zwei reichten nicht: im
 * Test lieferte reines Rauschen zweimal dieselbe Folge. Eine falsche Nummer ist hier
 * teurer als gar keine — sie beantwortet „habe ich das schon?" mit dem falschen Buch.
 */
export function findEAN13(data, width, height, lines = 21) {
  const seen = new Map();
  for (let n = 0; n < lines; n++) {
    const y = Math.round(((n + 0.5) / lines) * height);
    if (y < 0 || y >= height) continue;
    const row = runsOfRow(data, width, y);
    if (!row || row.runs.length < 59) continue;
    const hit = decodeRuns(row.runs);
    if (!hit) continue;
    const count = (seen.get(hit) || 0) + 1;
    // Drei Zeilen, nicht zwei: zwei Übereinstimmungen kamen im Test auch aus Rauschen.
    if (count >= 3) return hit;
    seen.set(hit, count);
  }
  return null;
}
