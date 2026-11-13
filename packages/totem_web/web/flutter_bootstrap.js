{{flutter_js}}
{{flutter_build_config}}

const assetBase = "{{ASSET_BASE}}";
const hasAssetBase = assetBase && !assetBase.includes("{{");
// Where flutter.js loads the entrypoint from, resolved the same way it does.
// The app shows it on /__version.
window.totemEntrypointBaseUrl = new URL(
  hasAssetBase ? assetBase : ".",
  document.baseURI,
).href;
const config = {
  wasmAllowList: {
    blink: true,
    gecko: true,
    webkit: true,
    unknown: false,
  },
  // assetBase only affects the engine's asset fetches (assets/, canvaskit);
  // the entrypoint (main.dart.js / .mjs / .wasm) is fetched by flutter.js,
  // which reads entrypointBaseUrl. Set both so everything loads from the CDN.
  ...(hasAssetBase
    ? { assetBase, entrypointBaseUrl: window.totemEntrypointBaseUrl }
    : {}),
  // ?force_st runs skwasm single-threaded even when the page is
  // cross-origin isolated, to compare against the multi-threaded renderer.
  ...(new URLSearchParams(window.location.search).has("force_st")
    ? { forceSingleThreadedSkwasm: true }
    : {}),
};

_flutter.loader.load({ config });
