export function distribution(values) {
  const sorted = values.filter(Number.isFinite).toSorted((a, b) => a - b);
  const at = (p) => sorted.length ? sorted[Math.ceil(sorted.length * p) - 1] : null;
  const middle = Math.floor(sorted.length / 2);
  const median = !sorted.length ? null : sorted.length % 2
    ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  return {count: sorted.length, p50: median, p95: at(0.95), p99: at(0.99)};
}

// Nested events must not count the same CPU time twice.
export function unionLength(intervals) {
  let total = 0, end = -Infinity;
  for (const [a, b] of intervals.toSorted((x, y) => x[0] - y[0])) {
    if (b > end) total += b - Math.max(a, end);
    end = Math.max(end, b);
  }
  return total;
}

export function chromeCpu(trace) {
  const events = trace.traceEvents;
  const start = events.find(e => e.name === 'room-benchmark-start')?.ts;
  const pagePid = events.find(e => e.name === 'room-benchmark-start')?.pid;
  const end = events.findLast(e => e.name === 'room-benchmark-end')?.ts;
  if (!(end > start)) throw new Error('Trace is missing measurement markers');
  const threads = new Map();
  for (const e of events) {
    const id = `${e.pid}:${e.tid}`;
    if (!threads.has(id)) threads.set(id, {id, pid: e.pid, name: id, spans: []});
    const t = threads.get(id);
    if (e.name === 'thread_name') t.name = e.args.name;
    // Only fully-contained events: no extrapolation across the capture edges.
    if (e.ph === 'X' && e.ts >= start && e.ts + e.dur <= end &&
        Number.isFinite(e.tts) && e.tdur > 0) {
      t.spans.push([e.tts, e.tts + e.tdur]);
    }
  }
  return [...threads.values()].map(t => ({
    id: t.id, name: t.name,
    isPageProcess: t.pid === pagePid,
    cpuPercent: 100 * unionLength(t.spans) / (end - start),
  })).filter(t => t.cpuPercent > 0).sort((a, b) => b.cpuPercent - a.cpuPercent);
}

export function firefoxCpu(profile, startEpochMs, endEpochMs) {
  const result = [];
  function visit(process) {
    const scale = {ns: 1e-6, 'µs': 1e-3, us: 1e-3, ms: 1}[
      process.meta?.sampleUnits?.threadCPUDelta ?? profile.meta?.sampleUnits?.threadCPUDelta
    ];
    for (const t of process.threads ?? []) {
      const {schema, data} = t.samples;
      if (schema.threadCPUDelta == null || scale == null) continue;
      let cpuMs = 0;
      let previous = null;
      for (const row of data) {
        const epoch = process.meta.startTime + row[schema.time];
        if (previous >= startEpochMs && epoch <= endEpochMs) {
          cpuMs += (row[schema.threadCPUDelta] ?? 0) * scale;
        }
        previous = epoch;
      }
      result.push({id: `${t.pid}:${t.tid}`, name: t.name,
        processType: t.processType, pages: (process.pages ?? []).map(page => page.url),
        cpuPercent: 100 * cpuMs / (endEpochMs - startEpochMs)});
    }
    for (const child of process.processes ?? []) visit(child);
  }
  visit(profile);
  return result.filter(t => t.cpuPercent > 0).sort((a, b) => b.cpuPercent - a.cpuPercent);
}
