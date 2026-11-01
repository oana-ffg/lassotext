# Runtime waste audit

## Selection redraws

Before this change, both `mouseDown` and `mouseDragged` set `needsDisplay = true`,
invalidating the entire frozen display, even when the selection did not change.
Each resulting draw also constructed a fresh `NSImage` wrapper around the same
capture. AppKit can coalesce invalidations; event counts are not frame counts.

The view now invalidates the union of the previous and next selection bounds,
expanded for the outline and rounded outward to whole points. Identical
selections do not invalidate anything. A background `NSImage` is constructed once
per selection view and reused. Captures and drawing remain in memory.

### Measured evidence

Command: `swift test --filter SelectionViewTests`.
Environment: macOS 27.0.1, arm64, Apple Swift 6.4.2, debug build. All inputs are
synthetic; no desktop content was captured. The baseline was main commit
`f01c80135a7d4441b0b11130c598f3a403cebcd4`, with the capture files moved into a
testable module and the view made internal, but its drawing/event logic unchanged.
The fixed implementation uses the same fixture and instrumentation.

The test records `NSView.setNeedsDisplay(_:)` calls, intersects their rectangles
with the view bounds, and sums their areas. It supplies 1,000 changing positions
to a 3840 × 2160 point view, starting at (100, 100), then sends 1,000 identical
positions. It does not attach the view to a window or pump a rendering loop.

| Requested work | Baseline | Fixed |
| --- | ---: | ---: |
| Changing positions: invalidations | 1,000 | 1,000 |
| Changing positions: total area, square points | 8,294,400,000 | 20,788,947 |
| Identical positions: invalidations | 1,000 | 0 |

Requested redraw area fell by 99.75% for this small-selection fixture. This is
not a measurement of rendered frames, memory copies, CPU time, GPU work, battery
use, or latency. Large selections can still require large dirty regions. The
image-wrapper lifetime change was established by source inspection; allocation
counts were not profiled.

The performance assertion bounds total requested area to less than 1% of the
old full-display area, rather than asserting a wall-clock duration. It fails on
the baseline. Offscreen bitmap tests compare partial repaints byte-for-byte
against full repaints at 1× and 2× scale, including all drag directions,
fractional coordinates, screen edges, restarting a drag, and the instruction
box. Separate event tests cover reverse-drag cropping, tiny selections, Escape,
and right-click cancellation. The deterministic suites run in CI.

## Paths checked without changes

- **Idle:** no timers, polling loops, screen streams, or background tasks in the
  app's idle path. Carbon delivers the registered shortcut as an event. The
  screen-change observer is notification-driven. Menu-bar event monitors are
  installed only while the panel is open and removed on close. This is a source
  audit, not an eight-hour wake-up or energy measurement.
- **Capture admission:** `busy` is set before starting the capture task and
  remains set through selection and OCR. Repeated capture requests are rejected,
  so they cannot accumulate screenshot/OCR tasks.
- **All displays:** one screenshot is requested per connected display per
  capture, before selection. Freezing all displays before choosing one is
  documented behavior. Capturing only the eventual selection would change that
  behavior. No real screens were captured for this audit.
- **During dragging:** no recaptures, crops, disk writes, or recognition calls.
  Cropping occurs once on mouse-up. The waste found here was redraw scope and
  image-wrapper reconstruction, not repeated screen capture or bitmap copies.
- **OCR:** `TextRecognizer` is a separate actor; the synchronous Vision request
  runs there, not on the UI actor. The launch-time supported-language query is a
  small, once-per-launch operation. Per-capture language configuration was not
  shown to be a material cost and was left alone.
- **Image/request lifetime:** overlay completion is cleared, windows are closed
  and removed, and the overlay callback captures its owner weakly. Vision
  requests/handlers are local to recognition, and only text is returned. No
  growing image/request collection or persistent cache was found. Actual
  framework deallocation and resident-memory behavior were not profiled.
- **Storage/network:** the capture and OCR paths contain no filesystem or
  network operations. Preference writes happen on preference changes and first
  launch, not periodically. Packaging writes icon/build artifacts, not captures.

No additional actionable waste, unrelated bugs, or dead code were established.
Manual checks in the installed app were not performed. Desktop integration,
screen permission behavior, real display changes, and live memory/energy use
remain outside this synthetic test evidence.
