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
  ...(assetBase && !assetBase.includes("{{") ? { assetBase } : {}),
};

_flutter.loader.load({ config });
