import {createConnection, createServer} from 'node:net';

export async function unusedPort() {
  const server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}

// Firefox DevTools' local transport uses length-prefixed JSON and bulk packets.
// https://firefox-source-docs.mozilla.org/devtools/backend/protocol.html
export class Packets {
  buffer = Buffer.alloc(0);
  push(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    const messages = [];
    while (true) {
      const colon = this.buffer.indexOf(':');
      if (colon < 0) break;
      const header = this.buffer.subarray(0, colon).toString();
      const bulk = /^bulk (\S+) (\S+) (\d+)$/.exec(header);
      const length = Number(bulk ? bulk[3] : header);
      if (!Number.isSafeInteger(length) || length < 0) throw new Error('Invalid Firefox packet');
      if (this.buffer.length < colon + 1 + length) break;
      const payload = this.buffer.subarray(colon + 1, colon + 1 + length);
      messages.push(bulk ? {from: bulk[1], data: payload} : JSON.parse(payload.toString()));
      this.buffer = this.buffer.subarray(colon + 1 + length);
    }
    return messages;
  }
}

export async function connectProfiler(port) {
  const socket = createConnection({port, host: '127.0.0.1'});
  const packets = new Packets();
  let pending;
  const receive = (message) => {
    if (!pending || message.from !== pending.actor ||
        ['profiler-started', 'profiler-stopped'].includes(message.type)) return;
    const {resolve, reject, timeout} = pending;
    pending = null;
    clearTimeout(timeout);
    if (message.error) reject(new Error(JSON.stringify(message)));
    else resolve(message);
  };
  socket.on('data', chunk => {
    try { for (const message of packets.push(chunk)) receive(message); }
    catch (error) { socket.destroy(error); }
  });
  socket.on('error', error => pending?.reject(error));
  const response = actor => new Promise((resolve, reject) => {
    pending = {actor, resolve, reject,
      timeout: setTimeout(() => reject(new Error('Firefox profiler response timed out')), 30000)};
  });
  const request = (actor, type, options = {}) => {
    const result = response(actor);
    const body = JSON.stringify({to: actor, type, ...options});
    socket.write(`${Buffer.byteLength(body)}:${body}`);
    return result;
  };
  try {
    await response('root');
    const {perfActor} = await request('root', 'getRoot');
    if (!perfActor) throw new Error('Firefox did not expose its profiler actor');
    return {
      async start() {
        const result = await request(perfActor, 'startProfiler', {
          entries: 20000000, interval: 1, features: ['js', 'stackwalk', 'cpuallthreads'],
          threads: ['GeckoMain', 'Compositor', 'Renderer', 'CanvasRenderer', 'DOM Worker'],
        });
        if (!result.value) throw new Error('Firefox profiler did not start');
      },
      async capture() {
        const {value: handle} = await request(perfActor, 'startCaptureAndStopProfiler');
        const {data} = await request(perfActor, 'getPreviouslyCapturedProfileDataBulk', {handle});
        return data;
      },
      close() { clearTimeout(pending?.timeout); socket.destroy(); },
    };
  } catch (error) { clearTimeout(pending?.timeout); socket.destroy(); throw error; }
}
