/* Offline-Betrieb. Im Buchladen ist Empfang oft schlecht, und genau dort wird gefragt.
 *
 * Zwei Strategien, weil zwei Arten von Dateien:
 *   - Gerüst und Katalog: erst Netz, dann Cache. Ein veralteter Bestand ist der
 *     schlimmste Fehler, den diese Seite machen kann — sie antwortet dann „hast du
 *     schon" zu einem Buch, das längst verkauft ist, oder umgekehrt.
 *   - Cover: erst Cache. Bilder ändern sich nie, und 1826 Anfragen übers Mobilnetz
 *     wären teuer und langsam.
 */
/* Zwei getrennte Versionen, mit Absicht: eine Änderung an der Seite darf den
 * Bilder-Cache nicht mitreißen. Bei einer gemeinsamen Nummer hätte jede
 * Layout-Korrektur 1825 Cover erneut übers Mobilnetz geholt — 31 MB dafür, dass
 * ein Knopf umzieht. Die Cover-Nummer steigt nur, wenn sich am Bildformat etwas
 * ändert. */
const SHELL = "shell-v3";
const COVERS = "cover-v1";
const CORE = ["./", "./index.html", "./ean.js", "./manifest.webmanifest", "./icon.svg"];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(SHELL).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== SHELL && k !== COVERS).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const url = new URL(event.request.url);
  if (event.request.method !== "GET" || url.origin !== location.origin) return;

  if (url.pathname.includes("/cover/")) {
    event.respondWith(
      caches.open(COVERS).then(cache =>
        cache.match(event.request).then(hit =>
          hit || fetch(event.request).then(res => {
            if (res.ok) cache.put(event.request, res.clone());
            return res;
          }).catch(() => hit)
        )
      )
    );
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(res => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(SHELL).then(c => c.put(event.request, copy));
        }
        return res;
      })
      .catch(() => caches.match(event.request).then(hit => hit || caches.match("./index.html")))
  );
});
