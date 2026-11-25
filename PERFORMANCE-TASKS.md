# CoderBar performance tasks

## Baseline

An optimized harness from `dfb92c5` found 23 sessions. The first pass took
4.00 s. Three warm in-process passes took 2.78–3.14 s. An older release CLI
took 3.53 s for Claude alone and 0.65 s for Codex alone. Treat that split as
directional. The desktop monitor sleeps 1.5 seconds after each scan, even with
the panel collapsed. These measurements are scan wall times. Live CPU,
memory, wakeups, and WindowServer cost remain unmeasured.

## P0 — Move the Claude age gate ahead of parsing

Claude currently calls the transcript activity loader before applying the
two-hour cutoff. A follow-up inventory reported 494 unarchived Claude
sessions with transcripts for a 256-entry LRU. With a stable iteration
order, that access pattern can evict each entry before its next use. This
is the leading explanation for the warm scan cost. The reported 15 ms
directory walk is a separate measurement and does not time Foundation's
enumeration or per-record metadata work.

- [ ] Move the existing cutoff before transcript activity lookup. Use the
  newer of record activity and the selected transcript's modification time.
  Preserve imported aliases and existing transcript selection.
- [ ] Test that archived and expired records cause no transcript content
  reads and that a recent transcript keeps an older record visible. Check the
  cutoff boundary and the imported-transcript fallback.
- [ ] Re-run optimized in-process scans on the same dataset. Use temporary
  per-provider timing and Claude cache hit/miss or parser-call counts if
  needed. Aim for a warm Claude-only median under 50 ms on this dataset.
  Verify equivalent visible sessions before accepting the performance result.

## P1 — Reduce recurring work

- [ ] Add adaptive discovery cadence. Keep the current 1.5 s delay while
  work is active or the panel is expanded. Start with a 10 s idle ceiling,
  and trigger an immediate, coalesced scan on expand, wake, or a relevant
  hook. Check that sessions discovered only through polling appear within
  the idle delay plus one scan. Record idle scan and wakeup rates.
- [ ] Time Codex's lock check and metadata query separately on the current
  build. Use in-process read-only SQLite and a slower lock reconciliation
  cadence where measurements justify them. Preserve lock ownership semantics
  and bound subprocess duration where a fallback remains.
- [ ] Replace global mouse-move delivery with panel tracking where it can
  preserve the current activation zone. Check hover entry, expansion and
  collapse, display changes, and the no-notch fallback. If a global
  fallback remains necessary, limit it to the modes that need it.
- [ ] Profile the collapsed app with the pointer stationary and moving
  outside the notch. Aim for under 0.5% average app-plus-helper CPU
  (0.3 CPU seconds per minute) on the reference Mac during settled idle,
  with zero periodic UI ticks for a static panel. Treat these as initial
  acceptance targets and record the workload and observed results.

## P2 — Follow the remaining costs

- [ ] Give providers independent publication and scheduling if one delays
  the other's updates or they need different cadences. Preserve the last
  good state on transient errors and retain hook precedence.
- [ ] Add filesystem-driven indexing or incremental transcript tailing
  only if directory traversal or active parsing still dominates measured
  work. Include recovery for missed events, replacement, and sleep/wake.
- [ ] Gate visible timers and profile panel animation, redundant view
  invalidations, and main-thread persistence as the profiles warrant.
  Benchmark history replay with a populated log before prioritizing it.

Use the [shared profiling protocol](PROFILING.md) when comparing the Swift
and Rust apps. A focused discovery benchmark is sufficient for the age gate.
