{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Flutter disables WebKit by default for skwasm. Enable it explicitly
    // so modern Safari builds can attempt WASM when WasmGC is available.
    wasmAllowList: {
      blink: true,
      gecko: false,
      webkit: true,
      unknown: false,
    },
  },
});
