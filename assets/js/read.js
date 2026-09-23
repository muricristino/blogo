// The reading beacon: one request per article read, sent when the reader
// leaves.
//
// Three decisions worth knowing, because each one changes what the panel means:
//
//  1. **One beacon, at the end.** Sending on load would count opening a tab as
//     reading it, and would have no depth or duration to report. The cost is
//     that a read lost to a browser crash is never counted — the figure
//     undercounts rather than inflates, which is the direction to err.
//  2. **Visible time only.** A tab left in the background for an hour is not an
//     hour of reading, so the clock stops when the page is hidden.
//  3. **No identifier of any kind.** Nothing is stored in the browser and
//     nothing identifying is sent. The server learns that an article was read,
//     how far, for how long, and which kind of site sent the reader — never
//     who.

const beacon = document.getElementById("read-beacon")

if (beacon) {
  let visibleMs = 0
  let lastResume = document.visibilityState === "visible" ? performance.now() : null
  let deepest = 0
  let sent = false

  const measureDepth = () => {
    const doc = document.documentElement
    const scrollable = doc.scrollHeight - innerHeight

    // A page shorter than the window was read to the end the moment it opened;
    // the alternative is dividing by zero and calling every short note a
    // bounce.
    const reached = scrollable > 0 ? Math.round((scrollY / scrollable) * 100) : 100
    deepest = Math.max(deepest, Math.min(100, Math.max(0, reached)))
  }

  const elapsedSeconds = () => {
    const running = lastResume === null ? 0 : performance.now() - lastResume
    return Math.round((visibleMs + running) / 1000)
  }

  const send = () => {
    if (sent) return
    sent = true
    measureDepth()

    const body = JSON.stringify({
      token: beacon.dataset.token,
      depth: deepest,
      seconds: elapsedSeconds(),
      referrer: document.referrer || "",
      utm_source: new URLSearchParams(location.search).get("utm_source") || ""
    })

    // sendBeacon survives the page going away, which fetch does not. The type
    // has to be a JSON blob for Phoenix to parse it as JSON rather than as a
    // form.
    try {
      navigator.sendBeacon(beacon.dataset.endpoint, new Blob([body], { type: "application/json" }))
    } catch (e) {
      // A reader who blocks this loses nothing; the panel simply never hears
      // about the read.
    }
  }

  addEventListener("scroll", measureDepth, { passive: true })

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") {
      if (lastResume !== null) {
        visibleMs += performance.now() - lastResume
        lastResume = null
      }
      send()
    } else if (lastResume === null) {
      lastResume = performance.now()
    }
  })

  // pagehide covers the cases visibilitychange misses, notably Safari leaving
  // a page through a link.
  addEventListener("pagehide", send)

  measureDepth()
}
