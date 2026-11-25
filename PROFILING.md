# CoderBar and tsk profiling protocol

Compare the original Swift baseline, optimized Swift builds, and Rust tsk.
Record shipped defaults separately from matched-feature runs.

| Mode | Shared input | What it measures |
| --- | --- | --- |
| Discovery only | Provider fixture and timed filesystem mutations | Provider costs and time to equivalent session state |
| UI only | Normalized session snapshots and timed pointer/window actions, with providers and hooks disabled | Notch input, polling, layout, and rendering costs |
| End to end | Provider mutations and the same UI actions | Total app and helper costs, and source-to-visible latency |

## Quick checks and matched runs

For a discovery change, run the same optimized harness before and after on
the same data. Record first-pass and in-process warm timings, session counts,
and provider or parser counts where useful. Start here before adding replay
harnesses or full signpost coverage.

For an app comparison, use the same Mac, display scaling and refresh rate,
power mode, release build settings, visible rows, and animation preferences.
Run one app at a time and replay the same inputs. Keep fixture and real-data
results separate. Repeat when the variance could change the conclusion.
Isolated fixtures, alternating runs and longer captures are useful when
results are close or need to be reproduced independently.

Run collapsed idle with a stationary pointer, collapsed idle with movement
outside the notch, repeated hover and expand/collapse, expanded static, and
active sessions with steady and bursty updates. Match visible behavior for
paired runs and record any differences.

## Instrumentation

Use corresponding macOS signpost intervals with synthetic correlation IDs
and a monotonic clock. Mark source writes, discovery completion, state
publication, layout/prepare, and frame submission. If actual presentation
is unavailable, label submission latency as a proxy. Aggregate frequent
counters behind opt-in instrumentation.

| Boundary | Counters and timings |
| --- | --- |
| Discovery | Passes by provider and reason, wall time, paths visited, bytes read/decoded, cache hits and misses, helper launches and child CPU |
| State | Updates received, coalesced, applied and published, visible changes, notification count |
| UI input and polling | Local/global pointer callbacks, tracking events, hover timers, elapsed-label ticks, spinner ticks, animation callbacks, redraw requests by reason |
| Rendering | Layout/prepare calls, frame submissions, observed presentations where available, missed deadlines, expand/collapse latency |
| Process/system | CPU seconds per minute, wakeups per second, steady and peak physical footprint, disk I/O, WindowServer and GPU cost where measurable |

Count scheduled callbacks, invalidations, layout work, and frames separately.
A timer can fire without a draw. A compositor frame can occur without layout.
For Swift, instrument mouse monitors, `TimelineView` activity, panel layout
requests, and the window-frame timer. Observe SwiftUI and compositor work
externally when instrumentation would change the render path. For Rust,
instrument AppKit events, scheduling, Figleaf preparation, and Metal
submission. Mark unavailable metrics and proxies explicitly.

Use Instruments Time Profiler and Points of Interest for attribution.
Capture system/energy and graphics data in separate matched passes where
needed. Include `lsof`, SQLite helper, and hook costs in end-to-end totals.
Report the app and helpers separately, and compare WindowServer to a
matched desktop baseline. Capture aggregate counters in a low-overhead run.

## Acceptance and reporting

Report p50/p95 for source-to-state and state-to-visible latency, with sample
counts and the timing boundary recorded. Compare first-frame latency and
motion cadence. For settled static panels, target zero periodic UI callbacks
and zero app redraws after startup. Account for provider reconciliation
separately. In active scenarios, compare equivalent final state and
notifications alongside latency, wakeups and resource use. Retain fixture
versions, raw traces, summary counters, and known confounders.
