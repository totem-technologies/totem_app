# Room rendering benchmark

This runs the shared call layout, video tile clipping, name overlays, waveform
bars, room background, and status notice without joining LiveKit or starting the
app's authentication, API, or telemetry services. Every participant has an HTML
video element playing a local loop. Audio levels are deterministic synthetic
samples delivered every 140 ms to the production `BarsView`, with its normal
three bars and interpolation. No microphone or camera is used.

The dedicated `totem_benchmark` package has no `.env` asset and is never an entry
point in the production build. Local artifacts live in ignored
`scratch/room-benchmark`. Browser automation uses fresh profiles and the installed
Chrome and Firefox; it never opens your normal browser profile.

## Setup and use

Requires Flutter, Node 22+, Bun, ffmpeg with libx264, Chrome, and Firefox. Install
only the pinned automation library locally:

```sh
cd scripts/benchmark
command bun install --frozen-lockfile
cd ../..
command make benchmark-build
command make benchmark-serve
```

Open <http://127.0.0.1:5180/>. The build generates a ten-second 640×480, 30 fps
moving test-pattern video. Use your own local MP4 with
`make benchmark-build BENCHMARK_ARGS='--media /absolute/path/clip.mp4'`.

Configuration is through query parameters (all optional):

| Parameter | Values | Default |
|---|---|---|
| `participants` | 1–12, including the featured tile | 6 |
| `video` | `playing`, `paused`, `hidden` | `playing` |
| `waveform` | `animated`, `frozen`, `hidden` | `animated` |
| `notice` | `true`, `false` (enable/disable tickers within the notice) | `true` |
| `clip` | `antiAlias`, `hardEdge`, `none`, `css` | `antiAlias` |
| `overlays` | `true`, `false` (names and waveform badges) | `true` |

For example: <http://127.0.0.1:5180/?participants=2&waveform=frozen&notice=false>.

## Automated captures

Stop the manual server first; the runner owns its server and closes it afterward.

```sh
# Short smoke run, including repeated join/leave, resize, and camera transitions.
command make benchmark BENCHMARK_ARGS='--repeat 1 --seconds 4 --warmup 2 --scenarios full,videos-only --lifecycle'

# Matched samples: both browsers, four scenarios, three repetitions each.
command make benchmark

# Keep a visible window to assess the actual display/GPU path.
command make benchmark BENCHMARK_ARGS='--browser firefox --headed --participants 2'
```

Defaults are a 1440×900 viewport at device pixel ratio 1, five seconds of warmup,
and fifteen seconds of measurement per run. Available scenarios:

| Scenario | Waveform | Status tickers | Video |
|---|---|---|---|
| `full` | animated | enabled | playing |
| `frozen-waveform` | frozen | enabled | playing |
| `frozen-notice` | animated | frozen | playing |
| `videos-only` | frozen | frozen | playing |
| `static` | frozen | frozen | paused |

The production status notice has a steady dot and schedules no animation frames.
Its ticker switch remains available when comparing archived builds. Waveform
interpolation uses a shared 30 Hz frame clock; sample updates and other widgets
can still request additional Flutter frames.

Rendering experiments hold the remaining workload fixed:

- `unclipped` and `hard-edge` match `frozen-notice` but change only tile clipping.
- `css-rounded` disables Flutter clipping and rounds the HTML video element
  with CSS. It is a benchmark experiment, not the production renderer.
- `no-overlays` matches `videos-only` but removes names and waveform badges.
  Both keep Flutter animations idle, so this isolates static overlay composition
  while videos play.

```sh
command make benchmark BENCHMARK_ARGS='--headed --motion no-preference --scenarios frozen-notice,unclipped,hard-edge,videos-only,no-overlays'
```

`--repeat`, `--seconds`, `--warmup`, `--participants`, `--scenarios`, `--browser`
(`chrome`, `firefox`, or `both`), `--headed`, `--lifecycle`, `--out`, and `--port`
configure the runner. `CHROME_BIN` and `FIREFOX_BIN` override the macOS executable
defaults. Browser runs are sequential. Scenario order reverses on alternate
repetitions to reduce order bias. Keep other workloads stable for comparisons.
The browser's reduced-motion preference is inherited and recorded; compare runs
with matching preferences, because it can shorten the waveform's transitions.
Use `--motion no-preference` or `--motion reduce` to hold that preference fixed.
Use `--build-dir scratch/room-benchmark/<previous-run>/build` to capture an archived
build without rebuilding it. This also works with `serve` for visual comparisons.

Each run saves a screenshot, native Chrome trace or Firefox profile, and a JSON
report with playback counters, thread CPU, Flutter timings, viewport, isolation,
browser version, and build metadata. The report fails if videos do not produce
frames, the page is hidden, a page error occurs, or app assets load from another
origin. `summary.md` contains repeated-run medians; the individual reports retain
every measurement. Recordings include `room-benchmark-start` and
`room-benchmark-end` User Timing markers. Firefox profiles are captured through
its loopback-only DevTools profiler after warmup, before browser shutdown.
Each batch keeps and serves its own copy of the build, video, source maps, and
renderer symbols, so subsequent builds cannot change the workload or erase its
debugging artifacts. Use a new `--out` directory for each batch.

Chrome CPU uses the union of thread-clock intervals, so nested trace events are
not double-counted. Firefox CPU uses per-thread sample deltas, excluding samples
that straddle the measurement boundary. Percentages represent one CPU core, not
total machine usage or GPU utilization. The summary restricts main-thread CPU to
the process containing the benchmark page. Individual thread entries retain
browser, decoder, compositor, and raster-worker CPU for attribution.

## Optimization loop

1. Build once, run the baseline three times, retain the artifacts.
2. Compare `full`, `frozen-waveform`, `frozen-notice`, and `videos-only` to identify
   which animations drive rendering cost. Use `static` to isolate video decoding.
3. Make one shared-widget change, run focused tests, rebuild, then repeat the
   same capture settings. Compare medians and the individual runs' spread.
4. Keep a change only when its effect exceeds that spread and screenshots,
   playback, and lifecycle checks remain correct. Repeat until results plateau.

For attribution, build with `make benchmark-build BENCHMARK_ARGS=--profile`.
This enables Flutter widget build, layout, and paint timeline events plus source
maps. The metadata labels these instrumented runs separately. Rebuild without
`--profile` for release comparisons; instrumentation changes the workload.

The browser console exposes `roomBenchmarkConfigure(queryString)`,
`roomBenchmarkStart()`, and `roomBenchmarkStop()` for additional scripted
experiments. Await the last to receive a JSON string with Flutter frame timings.
Timing batches are flushed after the recording ends; frames outside the measured
window are excluded. The flush does not contribute to trace CPU measurements.

## Scope and limitations

This isolates rendering. It does not model WebRTC decode/transport, adaptive
streaming, LiveKit participant events, audio analysis, the entire session screen,
or real camera content. The synthetic pattern is repeatable but has different
decode complexity from a face. All synthetic participants animate; use participant
count and waveform switches to vary load. A production LiveKit run remains the
final check for an optimization suggested by this harness.

Chrome uses the deployed app's skwasm selection; Firefox uses CanvasKit and the
Dart-to-JavaScript fallback. Both receive COOP `same-origin` and COEP
`credentialless`. Headless results are useful for matched local experiments but
do not establish performance on a user's high-refresh display or mobile GPU.
Flutter frame timings describe engine work, not end-to-end presented frames;
video playback counters are collected separately. Native profiling also has
overhead, so compare captures with the same settings and browser version.

The lifecycle probe verifies DOM video counts and resumed playback; it does not
prove that browser/native memory has returned to baseline. Widget leak tracking
and pure metric tests run in `make test`.

References: [Puppeteer launch options](https://pptr.dev/api/puppeteer.launchoptions),
[Firefox profiler API](https://github.com/mozilla-firefox/firefox/blob/main/devtools/shared/specs/perf.js),
and [Flutter web profiling](https://docs.flutter.dev/perf/web-performance).

The Firefox launcher also isolates `MOZ_APP_DATA` and `MOZ_LOCAL_APP_DATA`, and
sets `MOZ_DISABLE_UPDATE_PROCESSING` for its process. This avoids reading the
normal profile registry and processing pending browser updates during a run.
The app-data redirect is needed for [Firefox's macOS 27 startup issue](https://bugzilla.mozilla.org/show_bug.cgi?id=2060476).
Set `BENCHMARK_BROWSER_LOG=1` for browser startup diagnostics.
