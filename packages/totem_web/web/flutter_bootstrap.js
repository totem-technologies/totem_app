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
  // Run skwasm single-threaded even when the page is cross-origin isolated.
  // Multi-threaded skwasm renders on a worker and hands each frame to the main
  // thread via OffscreenCanvas.transferToImageBitmap, which costs frame rate:
  // - Firefox: ImageBitmap transfer is slow, and frame rates are noticeably
  //   better single-threaded.
  //   https://github.com/flutter/flutter/issues/145420
  //   https://bugzilla.mozilla.org/show_bug.cgi?id=1788206
  // - Chrome 148+: the per-frame bitmap triggers a major V8 GC on the raster
  //   worker every frame.
  //   https://github.com/flutter/flutter/issues/196484
  // - Safari: moving image sources between canvases (including
  //   transferToImageBitmap) is slow, and WebKit has to fix that before
  //   multi-threaded skwasm is viable there.
  //   https://bugs.webkit.org/show_bug.cgi?id=267291
  //   Safari also lacks `Cross-Origin-Embedder-Policy: credentialless`, so
  //   cross-origin isolation there requires `require-corp`, which blocks any
  //   cross-origin subresource that isn't served with CORP or CORS headers.
  //   https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Embedder-Policy#browser_compatibility
  forceSingleThreadedSkwasm: true,
};

_flutter.loader.load({ config });
