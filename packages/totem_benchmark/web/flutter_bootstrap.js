{{flutter_js}}
{{flutter_build_config}}

// Match the deployed app's renderer selection while serving every asset locally.
_flutter.loader.load({config: {
  canvasKitBaseUrl: 'canvaskit/',
  wasmAllowList: {blink: true, gecko: false, webkit: false, unknown: false},
}});
