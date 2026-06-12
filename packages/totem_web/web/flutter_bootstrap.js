{{flutter_js}}
{{flutter_build_config}}

const assetBase = "{{ASSET_BASE}}";
const config = {
  // Flutter disables WebKit by default for skwasm. Enable it explicitly
  // so modern Safari builds can attempt WASM when WasmGC is available.
  wasmAllowList: {
    blink: true,
    gecko: false,
    webkit: true,
    unknown: false,
  },
  // assetBase only affects the engine's asset fetches (assets/, canvaskit);
  // the entrypoint (main.dart.js / .mjs / .wasm) is fetched by flutter.js,
  // which reads entrypointBaseUrl. Set both so everything loads from the CDN.
  ...(assetBase && !assetBase.includes("{{")
    ? { assetBase, entrypointBaseUrl: assetBase }
    : {}),
};

_flutter.loader.load({ config });
