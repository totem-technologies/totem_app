import assert from 'node:assert/strict';
import test from 'node:test';
import {chromeCpu, distribution, firefoxCpu, unionLength} from './metrics.mjs';
import {Packets} from './firefox-profiler.mjs';

test('Firefox packets survive chunked UTF-8 and binary payloads', () => {
  const packets = new Packets();
  const json = Buffer.from(JSON.stringify({from: 'root', name: 'µs'}));
  const data = Buffer.from([0, 1, 128, 255]);
  const stream = Buffer.concat([Buffer.from(`${json.length}:`), json,
    Buffer.from(`bulk perf profile ${data.length}:`), data]);
  const decoded = [];
  for (const byte of stream) decoded.push(...packets.push(Buffer.from([byte])));
  assert.deepEqual(decoded, [{from: 'root', name: 'µs'}, {from: 'perf', data}]);
});

test('CPU intervals exclude nested double counting and preserve gaps', () => {
  assert.equal(unionLength([[0, 10], [1, 4], [8, 14], [20, 25]]), 19);
  assert.equal(unionLength([]), 0);
});

test('Chrome uses measurement markers, thread clocks, and excludes warmup', () => {
  const traceEvents = [
    {name: 'room-benchmark-start', ts: 100},
    {name: 'room-benchmark-end', ts: 200},
    ...[[0, 1000, 90], [110, 10, 50], [120, 15, 10]].map(([ts, tts, tdur]) =>
      ({pid: 1, tid: 2, ph: 'X', ts, dur: 10, tts, tdur})),
  ];
  assert.equal(chromeCpu({traceEvents})[0].cpuPercent, 50);
});

test('Firefox aligns process clocks and excludes first sample CPU delta', () => {
  const child = {meta: {startTime: 1000, sampleUnits: {threadCPUDelta: 'µs'}},
    threads: [{pid: 1, tid: 2, name: 'GeckoMain', samples: {
      schema: {time: 0, threadCPUDelta: 1},
      data: [[0, 99999], [10, 5000], [20, 5000], [30, 99999]],
    }}]};
  assert.equal(firefoxCpu({processes: [child]}, 1000, 1020)[0].cpuPercent, 50);
});

test('percentiles report absent samples without inventing zero duration', () => {
  assert.deepEqual(distribution([]), {count: 0, p50: null, p95: null, p99: null});
  assert.equal(distribution([4, 1, 3, 2]).p50, 2.5);
});
