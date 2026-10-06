import {spawn, execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {createReadStream} from 'node:fs';
import {mkdir, readFile, writeFile, copyFile, cp, stat, rm} from 'node:fs/promises';
import {createServer} from 'node:http';
import {dirname, resolve, extname, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';
import {gunzipSync} from 'node:zlib';
import {connectProfiler, unusedPort} from './firefox-profiler.mjs';
import {setTimeout as delay} from 'node:timers/promises';
import {chromeCpu, firefoxCpu, distribution} from './metrics.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const scratch = resolve(root, 'scratch/room-benchmark');
const {positionals, values: options} = parseArgs({allowPositionals: true, options: {
  browser: {type: 'string', default: 'both'},
  repeat: {type: 'string', default: '3'},
  seconds: {type: 'string', default: '15'},
  warmup: {type: 'string', default: '5'},
  participants: {type: 'string', default: '6'},
  scenarios: {type: 'string', default: 'full,frozen-waveform,frozen-notice,videos-only'},
  headed: {type: 'boolean', default: false},
  profile: {type: 'boolean', default: false},
  media: {type: 'string'},
  port: {type: 'string', default: '5180'},
  out: {type: 'string'},
  lifecycle: {type: 'boolean', default: false},
  'build-dir': {type: 'string'},
  motion: {type: 'string', default: 'system'},
}});
const buildDir = resolve(options['build-dir'] ?? resolve(scratch, 'build'));
const scenarios = {
  full: {waveform: 'animated', notice: 'true', video: 'playing'},
  'frozen-waveform': {waveform: 'frozen', notice: 'true', video: 'playing'},
  'frozen-notice': {waveform: 'animated', notice: 'false', video: 'playing'},
  'videos-only': {waveform: 'frozen', notice: 'false', video: 'playing'},
  static: {waveform: 'frozen', notice: 'false', video: 'paused'},
  unclipped: {waveform: 'animated', notice: 'false', video: 'playing', clip: 'none'},
  'hard-edge': {waveform: 'animated', notice: 'false', video: 'playing', clip: 'hardEdge'},
  'css-rounded': {waveform: 'animated', notice: 'false', video: 'playing', clip: 'css'},
  'no-overlays': {waveform: 'frozen', notice: 'false', video: 'playing', overlays: 'false'},
};

function positive(name, max, integer = false) {
  const value = Number(options[name]);
  if (!(value > 0 && value <= max) || (integer && !Number.isInteger(value))) {
    throw new Error(`Invalid --${name}`);
  }
  return value;
}
function hash(data) { return createHash('sha256').update(data).digest('hex'); }
function git(...args) { return execFileSync('git', args, {cwd: root, encoding: 'utf8'}).trim(); }
async function command(bin, args, cwd = root) {
  const child = spawn(bin, args, {cwd, stdio: 'inherit'});
  await new Promise((yes, no) => {
    child.on('error', no);
    child.on('exit', code => code === 0 ? yes() : no(new Error(`${bin} exited ${code}`)));
  });
}

async function build() {
  if (options['build-dir']) throw new Error('--build-dir selects an existing build for run/serve');
  await mkdir(scratch, {recursive: true});
  const flags = ['build', 'web', '--wasm', '--source-maps', '--no-web-resources-cdn',
    '--dart-define=WEBRTC_USE_HTML_ELEMENT_VIEW=true', '--output', buildDir];
  if (options.profile) flags.push('--profile', '--dart-define=BENCHMARK_ATTRIBUTION=true');
  await command('flutter', flags, resolve(root, 'packages/totem_benchmark'));
  if (options.media) {
    await copyFile(resolve(options.media), resolve(buildDir, 'loop.mp4'));
  } else {
    await command('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i', 'testsrc2=size=640x480:rate=30', '-t', '10',
      '-an', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart', resolve(buildDir, 'loop.mp4')]);
  }
  const sdk = JSON.parse(execFileSync('flutter', ['--version', '--machine'], {encoding: 'utf8'}));
  const metadata = {
    builtAt: new Date().toISOString(), commit: git('rev-parse', 'HEAD'),
    trackedDiffSha256: hash(git('diff', 'HEAD')), status: git('status', '--short'),
    flutter: sdk, flags, mode: options.profile ? 'profile-attribution' : 'release',
    media: {kind: options.media ? 'custom' : 'generated-test-pattern',
      sha256: hash(await readFile(resolve(buildDir, 'loop.mp4')))},
    bundleSha256: {
      wasm: hash(await readFile(resolve(buildDir, 'main.dart.wasm'))),
      js: hash(await readFile(resolve(buildDir, 'main.dart.js'))),
    },
  };
  await writeFile(resolve(buildDir, 'benchmark-build.json'), JSON.stringify(metadata, null, 2));
  console.log(`Built local benchmark: ${buildDir}`);
}

// Bound to loopback, with the same isolation headers as room HTML. Byte ranges
// support seeking and looping without re-downloading the entire media file.
async function serve(port, rootDir = buildDir) {
  const types = {'.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
    '.wasm': 'application/wasm', '.json': 'application/json', '.mp4': 'video/mp4',
    '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf'};
  const server = createServer(async (req, res) => {
    try {
      if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
      const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      const path = resolve(rootDir, `.${pathname === '/' ? '/index.html' : pathname}`);
      if (!path.startsWith(rootDir + sep) || pathname.split('/').some(s => s.startsWith('.'))) {
        res.writeHead(403).end(); return;
      }
      const info = await stat(path);
      if (!info.isFile()) { res.writeHead(404).end(); return; }
      const headers = {'Content-Type': types[extname(path)] ?? 'application/octet-stream',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'credentialless', 'Accept-Ranges': 'bytes',
        'Cache-Control': 'no-store'};
      let start = 0, end = info.size - 1, status = 200;
      if (req.headers.range) {
        const match = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range);
        if (!match) { res.writeHead(416).end(); return; }
        start = Number(match[1]);
        end = match[2] ? Math.min(Number(match[2]), end) : end;
        if (start > end) { res.writeHead(416, {'Content-Range': `bytes */${info.size}`}).end(); return; }
        status = 206;
        headers['Content-Range'] = `bytes ${start}-${end}/${info.size}`;
      }
      headers['Content-Length'] = end - start + 1;
      res.writeHead(status, headers);
      if (req.method === 'HEAD') res.end();
      else createReadStream(path, {start, end}).on('error', () => res.destroy()).pipe(res);
    } catch { res.writeHead(404).end(); }
  });
  await new Promise((yes, no) => {server.once('error', no); server.listen(port, '127.0.0.1', yes);});
  return server;
}

async function mediaSnapshot(page) {
  return page.evaluate(() => ({
    epochMs: performance.timeOrigin + performance.now(),
    isolated: crossOriginIsolated, visibility: document.visibilityState,
    viewport: {width: innerWidth, height: innerHeight, dpr: devicePixelRatio},
    reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
    rendererResources: performance.getEntriesByType('resource')
      .map(e => e.name).filter(n => /skwasm|canvaskit/.test(n)),
    videos: [...document.querySelectorAll('video')].map(v => {
      const quality = v.getVideoPlaybackQuality();
      return {id: v.dataset.participant, time: v.currentTime, paused: v.paused,
        readyState: v.readyState, width: v.videoWidth, height: v.videoHeight,
        frames: quality.totalVideoFrames, dropped: quality.droppedVideoFrames,
        error: v.error?.message ?? null};
    }),
  }));
}

async function readyMedia(page, count, mode = 'playing') {
  await page.waitForFunction((count, mode) => {
    const videos = [...document.querySelectorAll('video')];
    return videos.length === count && videos.every(v => v.readyState >= 2 &&
      v.videoWidth > 0 && (mode === 'paused' ? v.paused : !v.paused && v.currentTime > 0));
  }, {timeout: 30000, polling: 200}, count, mode);
}

async function lifecycle(page) {
  const counts = [];
  for (let i = 0; i < 3; i++) {
    for (const participants of [12, 2]) {
      await page.evaluate(n => roomBenchmarkConfigure(`participants=${n}&notice=false`), participants);
      await readyMedia(page, participants);
      counts.push((await mediaSnapshot(page)).videos.length);
    }
  }
  await page.setViewport({width: 390, height: 844, deviceScaleFactor: 1});
  await readyMedia(page, 2);
  await page.evaluate(() => roomBenchmarkConfigure('participants=2&video=paused&notice=false'));
  await readyMedia(page, 2, 'paused');
  await page.evaluate(() => roomBenchmarkConfigure('participants=2&video=hidden&notice=false'));
  await page.waitForFunction(() => document.querySelectorAll('video').length === 0);
  await page.evaluate(() => roomBenchmarkConfigure('participants=2&notice=false'));
  await readyMedia(page, 2);
  return {counts, final: await mediaSnapshot(page)};
}

async function capture(browserName, scenario, repetition, output, url, buildMetadata) {
  const {default: puppeteer} = await import('puppeteer-core');
  const directory = resolve(output, `${browserName}-${scenario}-${repetition}`);
  await mkdir(directory);
  const profile = resolve(directory, 'browser-profile');
  await mkdir(profile, {recursive: true});
  const appData = resolve(directory, 'firefox-app-data');
  const localAppData = resolve(directory, 'firefox-local-data');
  if (browserName === 'firefox') {
    await mkdir(appData, {recursive: true});
    await mkdir(localAppData, {recursive: true});
  }
  const firefoxTrace = resolve(directory, 'firefox-profile.json.gz');
  const executablePath = browserName === 'chrome'
    ? process.env.CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    : process.env.FIREFOX_BIN ?? '/Applications/Firefox.app/Contents/MacOS/firefox';
  console.log(`Capturing ${browserName} ${scenario} ${repetition}...`);
  const profilerPort = browserName === 'firefox' ? await unusedPort() : null;
  const browser = await puppeteer.launch({
    browser: browserName, executablePath, headless: !options.headed,
    args: browserName === 'firefox'
      ? ['--new-instance', '--start-debugger-server', String(profilerPort)] : [],
    extraPrefsFirefox: {
      'devtools.debugger.remote-enabled': true,
      'devtools.debugger.prompt-connection': false,
      'devtools.debugger.force-local': true,
      'devtools.chrome.enabled': true,
      ...(options.motion === 'system' ? {} : {
        'ui.prefersReducedMotion': options.motion === 'reduce' ? 1 : 0,
      }),
    },
    dumpio: process.env.BENCHMARK_BROWSER_LOG === '1',
    userDataDir: profile, defaultViewport: {width: 1440, height: 900, deviceScaleFactor: 1},
    env: {...process.env, TMPDIR: scratch,
      ...(browserName === 'firefox' ? {
        // Firefox consults app data before --profile; keep that isolated too.
        // This also avoids macOS 27's protection of the normal app-data folder.
        MOZ_APP_DATA: appData, MOZ_LOCAL_APP_DATA: localAppData,
        MOZ_DISABLE_UPDATE_PROCESSING: '1',
      } : {}),
    },
  });
  const errors = [];
  const requestFailures = [];
  const requests = new Set();
  let report;
  let profiler;
  try {
    if (browserName === 'firefox') profiler = await connectProfiler(profilerPort);
    const page = await browser.newPage();
    if (browserName === 'chrome' && options.motion !== 'system') {
      await page.emulateMediaFeatures([{name: 'prefers-reduced-motion', value: options.motion}]);
    }
    page.on('pageerror', e => errors.push(e.message));
    page.on('request', r => requests.add(r.url()));
    page.on('requestfailed', r => {
      requestFailures.push({url: r.url(), error: r.failure()?.errorText});
    });
    const query = new URLSearchParams({participants: options.participants, ...scenarios[scenario]});
    await page.goto(`${url}?${query}`, {waitUntil: 'load', timeout: 60000});
    await page.waitForFunction(() => globalThis.roomBenchmarkReady, {timeout: 60000});
    await readyMedia(page, Number(options.participants), scenarios[scenario].video);
    await delay(positive('warmup', 60) * 1000);
    const before = await mediaSnapshot(page);
    if (options.motion !== 'system' && before.reducedMotion !== (options.motion === 'reduce')) {
      throw new Error('Browser did not apply the requested motion preference');
    }
    if (!before.isolated || before.visibility !== 'visible') throw new Error('Page is not isolated and visible');
    if (browserName === 'chrome') await page.tracing.start({
      path: resolve(directory, 'chrome-trace.json'),
      categories: ['devtools.timeline', 'v8', 'blink.user_timing', 'toplevel',
        'disabled-by-default-devtools.timeline', 'disabled-by-default-v8.cpu_profiler'],
    });
    if (profiler) await profiler.start();
    const startEpochMs = await page.evaluate(() => {
      roomBenchmarkStart(); performance.mark('room-benchmark-start');
      return performance.timeOrigin + performance.now();
    });
    await delay(positive('seconds', 300) * 1000);
    const measurement = await page.evaluate(async () => {
      performance.mark('room-benchmark-end');
      return {endEpochMs: performance.timeOrigin + performance.now(),
        flutter: JSON.parse(await roomBenchmarkStop())};
    });
    if (browserName === 'chrome') await page.tracing.stop();
    if (profiler) await writeFile(firefoxTrace, await profiler.capture());
    const after = await mediaSnapshot(page);
    await page.screenshot({path: resolve(directory, 'screenshot.png')});
    const videoDeltas = after.videos.map((v, i) => ({id: v.id,
      frames: v.frames - before.videos[i].frames,
      dropped: v.dropped - before.videos[i].dropped,
      fps: 1000 * (v.frames - before.videos[i].frames) / (after.epochMs - before.epochMs),
    }));
    if (scenarios[scenario].video === 'playing' && videoDeltas.some(v => v.frames <= 0)) {
      throw new Error('A video stopped producing frames during measurement');
    }
    if (after.visibility !== 'visible') throw new Error('Page became hidden during measurement');
    const lifecycleResult = options.lifecycle ? await lifecycle(page) : null;
    if (lifecycleResult) await page.screenshot({path: resolve(directory, 'lifecycle.png')});
    const externalRequests = [...requests].filter(r => !r.startsWith(url) && !/^(blob:|data:)/.test(r));
    // Cancellation signals also occur for font and media requests on healthy
    // pages. Retain them for diagnosis alongside readiness/playback checks.
    const cancelledRequests = [];
    for (const failure of requestFailures) {
      if (/ERR_ABORTED|NS_BINDING_ABORTED/.test(failure.error ?? '')) {
        cancelledRequests.push(failure);
      } else errors.push(`${failure.url}: ${failure.error}`);
    }
    if (externalRequests.length) errors.push(`External requests: ${externalRequests.join(', ')}`);
    if (after.videos.some(video => video.error)) errors.push('Video element reported a media error');
    if (errors.length) throw new Error(errors.join('\n'));
    report = {browser: browserName, browserVersion: await browser.version(), url: `${url}?${query}`,
      scenario, repetition, headed: options.headed, build: buildMetadata,
      startEpochMs, ...measurement, before, after, videoDeltas, lifecycle: lifecycleResult,
      buildMs: distribution(measurement.flutter.buildMs),
      rasterMs: distribution(measurement.flutter.rasterMs), requests: [...requests],
      cancelledRequests, errors};
    await writeFile(resolve(directory, 'report.json'), JSON.stringify(report, null, 2));
  } catch (error) {
    await writeFile(resolve(directory, 'failure.json'), JSON.stringify({error: String(error), errors, requests: [...requests]}, null, 2));
    throw error;
  } finally {
    profiler?.close();
    await browser.close();
    await rm(profile, {recursive: true, force: true});
    await rm(appData, {recursive: true, force: true});
    await rm(localAppData, {recursive: true, force: true});
  }
  report.cpu = browserName === 'chrome'
    ? chromeCpu(JSON.parse(await readFile(resolve(directory, 'chrome-trace.json'), 'utf8')))
    : firefoxCpu(JSON.parse(gunzipSync(await readFile(firefoxTrace)).toString()), report.startEpochMs, report.endEpochMs);
  if (!report.cpu.length) throw new Error(`No thread CPU samples found for ${browserName}`);
  await writeFile(resolve(directory, 'report.json'), JSON.stringify(report, null, 2));
  console.log(`${browserName} ${scenario}: ${report.flutter.flutterFrames} Flutter frames; ` +
    report.cpu.slice(0, 3).map(t => `${t.name} ${t.cpuPercent.toFixed(1)}% CPU`).join(', '));
  return report;
}

async function run() {
  if (!['system', 'reduce', 'no-preference'].includes(options.motion)) throw new Error('Invalid --motion');
  const repeat = positive('repeat', 20, true);
  positive('participants', 12, true);
  positive('seconds', 300); positive('warmup', 60);
  const names = options.scenarios.split(',');
  if (names.some(n => !Object.hasOwn(scenarios, n))) throw new Error('Unknown scenario');
  const browsers = options.browser === 'both' ? ['chrome', 'firefox'] : [options.browser];
  if (browsers.some(b => !['chrome', 'firefox'].includes(b))) throw new Error('Unknown browser');
  const metadata = JSON.parse(await readFile(resolve(buildDir, 'benchmark-build.json'), 'utf8'));
  const output = resolve(options.out ?? resolve(scratch, `runs/${new Date().toISOString().replaceAll(':', '-')}`));
  await mkdir(output, {recursive: true});
  const snapshot = resolve(output, 'build');
  await mkdir(snapshot);
  await cp(buildDir, snapshot, {recursive: true});
  const server = await serve(positive('port', 65535, true), snapshot);
  const url = `http://127.0.0.1:${server.address().port}/`;
  const reports = [];
  try {
    for (let repetition = 1; repetition <= repeat; repetition++) {
      // Reverse order on alternating repetitions to reduce systematic warmup bias.
      for (const name of repetition % 2 ? names : names.toReversed()) {
        for (const browser of browsers) {
          reports.push(await capture(browser, name, repetition, output, url, metadata));
          await writeFile(resolve(output, 'reports.json'), JSON.stringify(reports, null, 2));
        }
      }
    }
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
  const rows = ['| Browser | Scenario | Runs | Main CPU median % | Flutter build p95 ms (median) |',
    '|---|---|---:|---:|---:|'];
  for (const browser of browsers) for (const name of names) {
    const group = reports.filter(r => r.browser === browser && r.scenario === name);
    const cpu = group.map(r => r.cpu.filter(t => browser === 'chrome'
      ? t.name === 'CrRendererMain' && t.isPageProcess
      : t.name === 'GeckoMain' && t.pages?.includes(r.url))
      .reduce((sum, t) => sum + t.cpuPercent, 0));
    rows.push(`| ${browser} | ${name} | ${group.length} | ${distribution(cpu).p50?.toFixed(2)} | ${distribution(group.map(r => r.buildMs.p95)).p50?.toFixed(2) ?? 'n/a'} |`);
  }
  await writeFile(resolve(output, 'summary.md'), rows.join('\n') +
    '\n\nCPU is percent of one core, restricted to the benchmark page process.\n' +
    'Headless results are for matched local comparisons. Flutter timings are engine reports, not display latency.\n');
  console.log(`Artifacts: ${output}`);
}

switch (positionals[0]) {
  case 'build': await build(); break;
  case 'serve': {
    await serve(positive('port', 65535, true));
    console.log(`Benchmark: http://127.0.0.1:${options.port}/`);
    break;
  }
  case 'run': await run(); break;
  default: throw new Error('Usage: node scripts/benchmark/run.mjs build|serve|run [options]');
}
