// Compiles a dart2wasm-generated main module from `source` which can then
// instantiatable via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm modules from `bytes` which is then
// instantiatable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export async function instantiate(modulePromise, importObjectPromise) {
  var moduleOrCompiledApp = await modulePromise;
  if (!(moduleOrCompiledApp instanceof CompiledApp)) {
    moduleOrCompiledApp = new CompiledApp(moduleOrCompiledApp);
  }
  const instantiatedApp = await moduleOrCompiledApp.instantiate(await importObjectPromise);
  return instantiatedApp.instantiatedModule;
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export const invoke = (moduleInstance, ...args) => {
  moduleInstance.exports.$invokeMain(args);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arugments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `load-ids` option is passed. Each load ID maps to one
  //   or more wasm files as specified in the emitted JSON file. It also takes a
  //   callback that should be invoked for each loaded module with 2 arugments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDynamicModule` is a JS function that takes two string names matching,
  //   in order, a wasm file produced by the dart2wasm compiler during dynamic
  //   module compilation and a corresponding js file produced by the same
  //   compilation. It also takes a callback that should be invoked with the
  //   loaded module in a format supported by `WebAssembly.compile` or
  //   `WebAssembly.compileStreaming` and the result of using the JS 'import'
  //   API on the js file path. It should return a Promise that resolves when
  //   all the modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports,
      {loadDeferredModules, loadDynamicModule, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            _1: (decoder, codeUnits) => decoder.decode(codeUnits),
      _2: () => new TextDecoder("utf-8", {fatal: true}),
      _3: () => new TextDecoder("utf-8", {fatal: false}),
      _4: (s) => +s,
      _5: x0 => new Uint8Array(x0),
      _6: (x0,x1,x2) => x0.set(x1,x2),
      _7: (x0,x1) => x0.transferFromImageBitmap(x1),
      _8: x0 => x0.arrayBuffer(),
      _9: (x0,x1,x2) => x0.slice(x1,x2),
      _10: (x0,x1) => x0.decode(x1),
      _11: (x0,x1) => x0.segment(x1),
      _12: () => new TextDecoder(),
      _13: (x0,x1) => x0.get(x1),
      _14: x0 => x0.buffer,
      _15: x0 => x0.wasmMemory,
      _16: () => globalThis.window._flutter_skwasmInstance,
      _17: x0 => x0.rasterStartMilliseconds,
      _18: x0 => x0.rasterEndMilliseconds,
      _19: x0 => x0.imageBitmaps,
      _135: (x0,x1) => x0.appendChild(x1),
      _166: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _167: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _168: (x0,x1) => new OffscreenCanvas(x0,x1),
      _169: x0 => x0.remove(),
      _170: (x0,x1) => x0.append(x1),
      _172: x0 => x0.unlock(),
      _173: x0 => x0.getReader(),
      _174: (x0,x1) => x0.item(x1),
      _175: x0 => x0.next(),
      _176: x0 => x0.now(),
      _177: (x0,x1) => x0.revokeObjectURL(x1),
      _178: x0 => x0.close(),
      _179: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      _180: x0 => new window.ImageDecoder(x0),
      _181: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      _182: (x0,x1) => x0.decode(x1),
      _183: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._183(f,arguments.length,x0) }),
      _184: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _186: (x0,x1) => x0.getModifierState(x1),
      _187: x0 => x0.preventDefault(),
      _188: x0 => x0.stopPropagation(),
      _189: (x0,x1) => x0.removeProperty(x1),
      _190: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._190(f,arguments.length,x0) }),
      _191: x0 => new window.FinalizationRegistry(x0),
      _192: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      _194: (x0,x1) => x0.unregister(x1),
      _195: (x0,x1) => x0.prepend(x1),
      _196: x0 => new Intl.Locale(x0),
      _197: (x0,x1) => x0.observe(x1),
      _198: x0 => x0.disconnect(),
      _199: (x0,x1) => x0.getAttribute(x1),
      _200: (x0,x1) => x0.contains(x1),
      _201: (x0,x1) => x0.querySelector(x1),
      _202: (x0,x1) => x0.matchMedia(x1),
      _203: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._203(f,arguments.length,x0) }),
      _204: (x0,x1,x2) => x0.call(x1,x2),
      _205: x0 => x0.blur(),
      _206: x0 => x0.hasFocus(),
      _207: (x0,x1) => x0.removeAttribute(x1),
      _208: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _209: (x0,x1) => x0.hasAttribute(x1),
      _210: (x0,x1) => x0.getModifierState(x1),
      _211: (x0,x1) => x0.createTextNode(x1),
      _212: x0 => x0.getBoundingClientRect(),
      _213: (x0,x1) => x0.replaceWith(x1),
      _214: (x0,x1) => x0.contains(x1),
      _215: (x0,x1) => x0.closest(x1),
      _653: x0 => new Uint8Array(x0),
      _656: () => globalThis.window.flutterConfiguration,
      _658: x0 => x0.assetBase,
      _663: x0 => x0.canvasKitMaximumSurfaces,
      _664: x0 => x0.debugShowSemanticsNodes,
      _665: x0 => x0.hostElement,
      _666: x0 => x0.multiViewEnabled,
      _667: x0 => x0.nonce,
      _669: x0 => x0.fontFallbackBaseUrl,
      _679: x0 => x0.console,
      _680: x0 => x0.devicePixelRatio,
      _681: x0 => x0.document,
      _682: x0 => x0.history,
      _683: x0 => x0.innerHeight,
      _684: x0 => x0.innerWidth,
      _685: x0 => x0.location,
      _686: x0 => x0.navigator,
      _687: x0 => x0.visualViewport,
      _688: x0 => x0.performance,
      _689: x0 => x0.parent,
      _691: x0 => x0.URL,
      _693: (x0,x1) => x0.getComputedStyle(x1),
      _694: x0 => x0.screen,
      _695: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._695(f,arguments.length,x0) }),
      _696: (x0,x1) => x0.requestAnimationFrame(x1),
      _700: (x0,x1) => x0.warn(x1),
      _702: (x0,x1) => x0.debug(x1),
      _703: x0 => globalThis.parseFloat(x0),
      _704: () => globalThis.window,
      _705: () => globalThis.Intl,
      _706: () => globalThis.Symbol,
      _707: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      _709: x0 => x0.clipboard,
      _710: x0 => x0.maxTouchPoints,
      _711: x0 => x0.vendor,
      _712: x0 => x0.language,
      _713: x0 => x0.platform,
      _714: x0 => x0.userAgent,
      _715: (x0,x1) => x0.vibrate(x1),
      _716: x0 => x0.languages,
      _717: x0 => x0.documentElement,
      _718: (x0,x1) => x0.querySelector(x1),
      _719: (x0,x1) => x0.querySelectorAll(x1),
      _721: (x0,x1) => x0.createElement(x1),
      _724: (x0,x1) => x0.createEvent(x1),
      _725: x0 => x0.activeElement,
      _728: x0 => x0.head,
      _729: x0 => x0.body,
      _731: (x0,x1) => { x0.title = x1 },
      _734: x0 => x0.visibilityState,
      _735: () => globalThis.document,
      _736: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._736(f,arguments.length,x0) }),
      _737: (x0,x1) => x0.dispatchEvent(x1),
      _745: x0 => x0.target,
      _747: x0 => x0.timeStamp,
      _748: x0 => x0.type,
      _750: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      _756: x0 => x0.baseURI,
      _757: x0 => x0.firstChild,
      _761: x0 => x0.parentElement,
      _763: (x0,x1) => { x0.textContent = x1 },
      _764: x0 => x0.parentNode,
      _765: x0 => x0.nextSibling,
      _766: (x0,x1) => x0.removeChild(x1),
      _767: x0 => x0.isConnected,
      _775: x0 => x0.clientHeight,
      _776: x0 => x0.clientWidth,
      _777: x0 => x0.offsetHeight,
      _778: x0 => x0.offsetWidth,
      _779: x0 => x0.id,
      _780: (x0,x1) => { x0.id = x1 },
      _783: (x0,x1) => { x0.spellcheck = x1 },
      _784: x0 => x0.tagName,
      _785: x0 => x0.style,
      _787: (x0,x1) => x0.querySelectorAll(x1),
      _788: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _789: x0 => x0.tabIndex,
      _790: (x0,x1) => { x0.tabIndex = x1 },
      _791: (x0,x1) => x0.focus(x1),
      _792: x0 => x0.scrollTop,
      _793: (x0,x1) => { x0.scrollTop = x1 },
      _794: (x0,x1) => { x0.scrollLeft = x1 },
      _795: x0 => x0.scrollLeft,
      _796: x0 => x0.classList,
      _797: (x0,x1) => x0.scrollIntoView(x1),
      _800: (x0,x1) => { x0.className = x1 },
      _802: (x0,x1) => x0.getElementsByClassName(x1),
      _803: x0 => x0.click(),
      _804: (x0,x1) => x0.attachShadow(x1),
      _807: x0 => x0.computedStyleMap(),
      _808: (x0,x1) => x0.get(x1),
      _814: (x0,x1) => x0.getPropertyValue(x1),
      _815: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      _816: x0 => x0.offsetLeft,
      _817: x0 => x0.offsetTop,
      _818: x0 => x0.offsetParent,
      _820: (x0,x1) => { x0.name = x1 },
      _821: x0 => x0.content,
      _822: (x0,x1) => { x0.content = x1 },
      _826: (x0,x1) => { x0.src = x1 },
      _827: x0 => x0.naturalWidth,
      _828: x0 => x0.naturalHeight,
      _832: (x0,x1) => { x0.crossOrigin = x1 },
      _834: (x0,x1) => { x0.decoding = x1 },
      _835: x0 => x0.decode(),
      _840: (x0,x1) => { x0.nonce = x1 },
      _845: (x0,x1) => { x0.width = x1 },
      _847: (x0,x1) => { x0.height = x1 },
      _850: (x0,x1) => x0.getContext(x1),
      _918: x0 => x0.width,
      _919: x0 => x0.height,
      _921: (x0,x1) => x0.fetch(x1),
      _922: x0 => x0.status,
      _923: x0 => x0.headers,
      _924: x0 => x0.body,
      _925: x0 => x0.arrayBuffer(),
      _928: x0 => x0.read(),
      _929: x0 => x0.value,
      _930: x0 => x0.done,
      _937: x0 => x0.name,
      _938: x0 => x0.x,
      _939: x0 => x0.y,
      _942: x0 => x0.top,
      _943: x0 => x0.right,
      _944: x0 => x0.bottom,
      _945: x0 => x0.left,
      _955: x0 => x0.height,
      _956: x0 => x0.width,
      _957: x0 => x0.scale,
      _958: (x0,x1) => { x0.value = x1 },
      _961: (x0,x1) => { x0.placeholder = x1 },
      _963: (x0,x1) => { x0.name = x1 },
      _964: x0 => x0.selectionDirection,
      _965: x0 => x0.selectionStart,
      _966: x0 => x0.selectionEnd,
      _969: x0 => x0.value,
      _971: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _972: x0 => x0.readText(),
      _973: (x0,x1) => x0.writeText(x1),
      _975: x0 => x0.altKey,
      _976: x0 => x0.code,
      _977: x0 => x0.ctrlKey,
      _978: x0 => x0.key,
      _979: x0 => x0.keyCode,
      _980: x0 => x0.location,
      _981: x0 => x0.metaKey,
      _982: x0 => x0.repeat,
      _983: x0 => x0.shiftKey,
      _984: x0 => x0.isComposing,
      _986: x0 => x0.state,
      _987: (x0,x1) => x0.go(x1),
      _989: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      _990: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _991: x0 => x0.pathname,
      _992: x0 => x0.search,
      _993: x0 => x0.hash,
      _997: x0 => x0.state,
      _1000: (x0,x1) => x0.createObjectURL(x1),
      _1002: x0 => new Blob(x0),
      _1012: x0 => x0.matches,
      _1016: x0 => x0.matches,
      _1020: x0 => x0.relatedTarget,
      _1022: x0 => x0.clientX,
      _1023: x0 => x0.clientY,
      _1024: x0 => x0.offsetX,
      _1025: x0 => x0.offsetY,
      _1028: x0 => x0.button,
      _1029: x0 => x0.buttons,
      _1030: x0 => x0.ctrlKey,
      _1034: x0 => x0.pointerId,
      _1035: x0 => x0.pointerType,
      _1036: x0 => x0.pressure,
      _1037: x0 => x0.tiltX,
      _1038: x0 => x0.tiltY,
      _1039: x0 => x0.getCoalescedEvents(),
      _1042: x0 => x0.deltaX,
      _1043: x0 => x0.deltaY,
      _1044: x0 => x0.wheelDeltaX,
      _1045: x0 => x0.wheelDeltaY,
      _1046: x0 => x0.deltaMode,
      _1053: x0 => x0.changedTouches,
      _1056: x0 => x0.clientX,
      _1057: x0 => x0.clientY,
      _1060: x0 => x0.data,
      _1063: (x0,x1) => { x0.disabled = x1 },
      _1065: (x0,x1) => { x0.type = x1 },
      _1066: (x0,x1) => { x0.max = x1 },
      _1067: (x0,x1) => { x0.min = x1 },
      _1068: x0 => x0.value,
      _1069: (x0,x1) => { x0.value = x1 },
      _1070: x0 => x0.disabled,
      _1071: (x0,x1) => { x0.disabled = x1 },
      _1073: (x0,x1) => { x0.placeholder = x1 },
      _1075: (x0,x1) => { x0.name = x1 },
      _1076: (x0,x1) => { x0.autocomplete = x1 },
      _1078: x0 => x0.selectionDirection,
      _1079: x0 => x0.selectionStart,
      _1081: x0 => x0.selectionEnd,
      _1084: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1085: (x0,x1) => x0.add(x1),
      _1087: (x0,x1) => { x0.noValidate = x1 },
      _1088: (x0,x1) => { x0.method = x1 },
      _1089: (x0,x1) => { x0.action = x1 },
      _1095: (x0,x1) => x0.getContext(x1),
      _1097: x0 => x0.convertToBlob(),
      _1114: x0 => x0.orientation,
      _1115: x0 => x0.width,
      _1116: x0 => x0.height,
      _1117: (x0,x1) => x0.lock(x1),
      _1136: x0 => new ResizeObserver(x0),
      _1139: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1139(f,arguments.length,x0,x1) }),
      _1147: x0 => x0.length,
      _1148: x0 => x0.iterator,
      _1149: x0 => x0.Segmenter,
      _1150: x0 => x0.v8BreakIterator,
      _1151: (x0,x1) => new Intl.Segmenter(x0,x1),
      _1154: x0 => x0.language,
      _1155: x0 => x0.script,
      _1156: x0 => x0.region,
      _1174: x0 => x0.done,
      _1175: x0 => x0.value,
      _1176: x0 => x0.index,
      _1180: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      _1181: (x0,x1) => x0.adoptText(x1),
      _1182: x0 => x0.first(),
      _1183: x0 => x0.next(),
      _1184: x0 => x0.current(),
      _1186: () => globalThis.window.FinalizationRegistry,
      _1197: x0 => x0.hostElement,
      _1198: x0 => x0.viewConstraints,
      _1201: x0 => x0.maxHeight,
      _1202: x0 => x0.maxWidth,
      _1203: x0 => x0.minHeight,
      _1204: x0 => x0.minWidth,
      _1205: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1205(f,arguments.length,x0) }),
      _1206: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1206(f,arguments.length,x0) }),
      _1207: (x0,x1) => ({addView: x0,removeView: x1}),
      _1210: x0 => x0.loader,
      _1211: () => globalThis._flutter,
      _1212: (x0,x1) => x0.didCreateEngineInitializer(x1),
      _1213: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1213(f,arguments.length,x0) }),
      _1214: (module,f) => finalizeWrapper(f, function() { return module.exports._1214(f,arguments.length) }),
      _1215: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      _1218: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1218(f,arguments.length,x0) }),
      _1219: x0 => ({runApp: x0}),
      _1221: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1221(f,arguments.length,x0,x1) }),
      _1222: x0 => new Promise(x0),
      _1223: x0 => x0.length,
      _1224: () => globalThis.window.ImageDecoder,
      _1225: x0 => x0.tracks,
      _1227: x0 => x0.completed,
      _1229: x0 => x0.image,
      _1235: x0 => x0.displayWidth,
      _1236: x0 => x0.displayHeight,
      _1237: x0 => x0.duration,
      _1240: x0 => x0.ready,
      _1241: x0 => x0.selectedTrack,
      _1242: x0 => x0.repetitionCount,
      _1243: x0 => x0.frameCount,
      _1285: (x0,x1) => x0.getElementById(x1),
      _1286: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1286(f,arguments.length,x0,x1) }),
      _1287: (x0,x1) => x0.requestVideoFrameCallback(x1),
      _1288: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      _1289: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1289(f,arguments.length,x0) }),
      _1290: (x0,x1) => x0.requestAnimationFrame(x1),
      _1291: (x0,x1) => x0.cancelVideoFrameCallback(x1),
      _1292: (x0,x1) => x0.cancelAnimationFrame(x1),
      _1293: () => new MediaStream(),
      _1294: x0 => x0.getVideoTracks(),
      _1295: (x0,x1) => x0.addTrack(x1),
      _1296: x0 => x0.getAudioTracks(),
      _1297: (x0,x1) => x0.append(x1),
      _1298: (x0,x1) => x0.removeAttribute(x1),
      _1299: x0 => x0.load(),
      _1300: x0 => x0.remove(),
      _1301: x0 => x0.hasChildNodes(),
      _1302: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _1303: (x0,x1) => x0.appendChild(x1),
      _1304: x0 => new Float32Array(x0),
      _1305: (x0,x1) => x0.getFloatFrequencyData(x1),
      _1306: x0 => ({latencyHint: x0}),
      _1307: x0 => new AudioContext(x0),
      _1308: x0 => new MediaStream(x0),
      _1309: (x0,x1) => x0.createMediaStreamSource(x1),
      _1310: x0 => x0.createAnalyser(),
      _1311: (x0,x1) => x0.connect(x1),
      _1312: (x0,x1) => x0.getByteFrequencyData(x1),
      _1313: x0 => x0.close(),
      _1314: x0 => x0.close(),
      _1315: (x0,x1) => x0.send(x1),
      _1316: x0 => new WebSocket(x0),
      _1327: x0 => x0.play(),
      _1328: (x0,x1) => x0.setSinkId(x1),
      _1346: (x0,x1) => x0.createElement(x1),
      _1350: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1350(f,arguments.length,x0) }),
      _1351: x0 => ({createScriptURL: x0}),
      _1352: (x0,x1,x2) => x0.createPolicy(x1,x2),
      _1353: (x0,x1,x2) => x0.createScriptURL(x1,x2),
      _1354: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _1355: (x0,x1) => x0.querySelectorAll(x1),
      _1356: (x0,x1) => x0.item(x1),
      _1364: (x0,x1) => x0.createElement(x1),
      _1370: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1371: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1371(f,arguments.length,x0,x1) }),
      _1372: x0 => globalThis.Sentry.init(x0),
      _1373: () => new Sentry.getClient(),
      _1374: x0 => x0.getOptions(),
      _1375: () => new Sentry.getIsolationScope(),
      _1376: x0 => x0.getSession(),
      _1377: (x0,x1) => x0.setSession(x1),
      _1378: () => globalThis.Sentry.globalHandlersIntegration(),
      _1379: () => globalThis.Sentry.dedupeIntegration(),
      _1380: () => globalThis.Sentry.close(),
      _1381: (x0,x1) => x0.sendEnvelope(x1),
      _1382: x0 => globalThis.Sentry.startSession(x0),
      _1383: () => globalThis.Sentry.captureSession(),
      _1384: () => globalThis.globalThis,
      _1385: x0 => x0.sdk,
      _1386: (x0,x1) => { x0.sdk = x1 },
      _1387: (x0,x1) => { x0.name = x1 },
      _1388: () => globalThis.Notification.requestPermission(),
      _1389: x0 => x0.preventDefault(),
      _1390: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _1391: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      _1392: (x0,x1) => x0.getAttribute(x1),
      _1393: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1393(f,arguments.length,x0) }),
      _1394: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1394(f,arguments.length,x0) }),
      _1395: (x0,x1) => x0.closest(x1),
      _1396: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1397: x0 => x0.decode(),
      _1398: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1399: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1400: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1400(f,arguments.length,x0) }),
      _1401: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1401(f,arguments.length,x0) }),
      _1402: x0 => x0.send(),
      _1403: () => new XMLHttpRequest(),
      _1408: (x0,x1) => x0.getItem(x1),
      _1409: (x0,x1) => x0.removeItem(x1),
      _1410: (x0,x1,x2) => x0.setItem(x1,x2),
      _1411: x0 => ({name: x0}),
      _1412: (x0,x1) => x0.query(x1),
      _1413: x0 => ({audio: x0}),
      _1414: (x0,x1) => x0.getUserMedia(x1),
      _1415: x0 => x0.stop(),
      _1416: x0 => ({video: x0}),
      _1417: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1417(f,arguments.length,x0) }),
      _1418: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1418(f,arguments.length,x0) }),
      _1419: (x0,x1,x2) => x0.getCurrentPosition(x1,x2),
      _1423: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      _1424: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      _1425: x0 => globalThis.firebase_core.getApp(x0),
      _1426: () => globalThis.firebase_core.getApp(),
      _1427: (x0,x1,x2) => globalThis.firebase_core.registerVersion(x0,x1,x2),
      _1455: () => globalThis.firebase_core.SDK_VERSION,
      _1461: x0 => x0.apiKey,
      _1463: x0 => x0.authDomain,
      _1465: x0 => x0.databaseURL,
      _1467: x0 => x0.projectId,
      _1469: x0 => x0.storageBucket,
      _1471: x0 => x0.messagingSenderId,
      _1473: x0 => x0.measurementId,
      _1475: x0 => x0.appId,
      _1477: x0 => x0.name,
      _1478: x0 => x0.options,
      _1479: (x0,x1) => x0.debug(x1),
      _1480: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1480(f,arguments.length,x0) }),
      _1481: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1481(f,arguments.length,x0,x1) }),
      _1482: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      _1483: (x0,x1) => x0.createScriptURL(x1),
      _1484: (x0,x1,x2) => x0.createScript(x1,x2),
      _1485: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1485(f,arguments.length,x0) }),
      _1486: x0 => x0.deviceMemory,
      _1487: x0 => x0.getBattery(),
      _1488: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1488(f,arguments.length,x0) }),
      _1489: (x0,x1,x2,x3) => x0.identify(x1,x2,x3),
      _1490: (x0,x1,x2,x3) => x0.capture(x1,x2,x3),
      _1491: (x0,x1) => x0.alias(x1),
      _1492: x0 => x0.get_distinct_id(),
      _1493: x0 => x0.reset(),
      _1494: (x0,x1) => x0.debug(x1),
      _1495: (x0,x1) => x0.isFeatureEnabled(x1),
      _1496: (x0,x1,x2,x3) => x0.group(x1,x2,x3),
      _1497: x0 => x0.reloadFeatureFlags(),
      _1498: (x0,x1,x2) => x0.setPersonProperties(x1,x2),
      _1499: (x0,x1,x2) => x0.setPersonPropertiesForFlags(x1,x2),
      _1500: x0 => x0.resetPersonPropertiesForFlags(),
      _1501: (x0,x1,x2) => x0.setGroupPropertiesForFlags(x1,x2),
      _1502: (x0,x1) => x0.resetGroupPropertiesForFlags(x1),
      _1503: x0 => x0.opt_in_capturing(),
      _1504: x0 => x0.opt_out_capturing(),
      _1505: x0 => x0.has_opted_out_capturing(),
      _1506: (x0,x1) => x0.getFeatureFlag(x1),
      _1507: (x0,x1) => x0.getFeatureFlagPayload(x1),
      _1508: (x0,x1,x2) => x0.getFeatureFlagResult(x1,x2),
      _1509: (x0,x1) => x0.register(x1),
      _1510: (x0,x1) => x0.unregister(x1),
      _1511: x0 => x0.get_session_id(),
      _1512: x0 => x0.startSessionRecording(),
      _1513: x0 => x0.stopSessionRecording(),
      _1514: x0 => x0.sessionRecordingStarted(),
      _1515: x0 => x0.sessionManager,
      _1516: (x0,x1,x2) => x0._overrideSDKInfo(x1,x2),
      _1517: x0 => x0.resetSessionId(),
      _1518: () => globalThis.window.posthog,
      _1519: (x0,x1) => x0.key(x1),
      _1520: (x0,x1,x2,x3,x4,x5,x6,x7) => x0.unwrapKey(x1,x2,x3,x4,x5,x6,x7),
      _1521: (x0,x1,x2,x3,x4,x5) => x0.importKey(x1,x2,x3,x4,x5),
      _1522: (x0,x1,x2,x3) => x0.generateKey(x1,x2,x3),
      _1523: (x0,x1,x2,x3,x4) => x0.wrapKey(x1,x2,x3,x4),
      _1524: (x0,x1,x2) => x0.exportKey(x1,x2),
      _1525: (x0,x1) => x0.getRandomValues(x1),
      _1526: (x0,x1,x2,x3) => x0.encrypt(x1,x2,x3),
      _1527: (x0,x1,x2,x3) => x0.decrypt(x1,x2,x3),
      _1529: (x0,x1) => x0.querySelector(x1),
      _1533: Date.now,
      _1534: secondsSinceEpoch => {
        const date = new Date(secondsSinceEpoch * 1000);
        const match = /\((.*)\)/.exec(date.toString());
        if (match == null) {
            // This should never happen on any recent browser.
            return '';
        }
        return match[1];
      },
      _1535: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _1536: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _1537: () => typeof dartUseDateNowForTicks !== "undefined",
      _1538: () => 1000 * performance.now(),
      _1539: () => Date.now(),
      _1540: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _1541: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _1542: () => new WeakMap(),
      _1543: (map, o) => map.get(o),
      _1544: (map, o, v) => map.set(o, v),
      _1545: x0 => new WeakRef(x0),
      _1546: x0 => x0.deref(),
      _1553: () => globalThis.WeakRef,
      _1557: s => JSON.stringify(s),
      _1558: s => printToConsole(s),
      _1559: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      _1560: (o, p, r) => o.replaceAll(p, () => r),
      _1561: (o, p, r) => o.replace(p, () => r),
      _1562: Function.prototype.call.bind(String.prototype.toLowerCase),
      _1563: s => s.toUpperCase(),
      _1564: s => s.trim(),
      _1565: s => s.trimLeft(),
      _1566: s => s.trimRight(),
      _1567: (string, times) => string.repeat(times),
      _1568: Function.prototype.call.bind(String.prototype.indexOf),
      _1569: (s, p, i) => s.lastIndexOf(p, i),
      _1570: (string, token) => string.split(token),
      _1571: Object.is,
      _1576: (o, c) => o instanceof c,
      _1577: o => Object.keys(o),
      _1579: (o) => {
        const typeofValue = typeof o;
        return (typeofValue === 'object') ||
            typeofValue === 'function';
      },
      _1631: x0 => new Array(x0),
      _1633: x0 => x0.length,
      _1635: (x0,x1) => x0[x1],
      _1636: (x0,x1,x2) => { x0[x1] = x2 },
      _1639: (x0,x1,x2) => new DataView(x0,x1,x2),
      _1641: x0 => new Int8Array(x0),
      _1642: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      _1644: x0 => new Uint8ClampedArray(x0),
      _1646: x0 => new Int16Array(x0),
      _1648: x0 => new Uint16Array(x0),
      _1650: x0 => new Int32Array(x0),
      _1652: x0 => new Uint32Array(x0),
      _1655: x0 => new Float64Array(x0),
      _1679: x0 => x0.random(),
      _1680: (x0,x1) => x0.getRandomValues(x1),
      _1681: () => globalThis.crypto,
      _1682: () => globalThis.Math,
      _1684: () => globalThis.performance,
      _1685: () => globalThis.JSON,
      _1686: x0 => x0.measure,
      _1687: x0 => x0.mark,
      _1688: x0 => x0.clearMeasures,
      _1689: x0 => x0.clearMarks,
      _1690: (x0,x1,x2,x3) => x0.measure(x1,x2,x3),
      _1691: (x0,x1,x2) => x0.mark(x1,x2),
      _1692: x0 => x0.clearMeasures(),
      _1693: x0 => x0.clearMarks(),
      _1694: (x0,x1) => x0.parse(x1),
      _1695: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _1696: (handle) => clearTimeout(handle),
      _1697: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _1698: (handle) => clearInterval(handle),
      _1699: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _1700: () => Date.now(),
      _1701: () => new Error().stack,
      _1702: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _1703: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _1704: (x0,x1) => x0.exec(x1),
      _1705: (x0,x1) => x0.test(x1),
      _1706: x0 => x0.pop(),
      _1708: o => o === undefined,
      _1710: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _1712: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _1713: o => o instanceof RegExp,
      _1714: (l, r) => l === r,
      _1715: o => o,
      _1716: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      _1717: o => o,
      _1718: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      _1719: o => o,
      _1720: b => !!b,
      _1721: o => o.length,
      _1723: (o, i) => o[i],
      _1724: f => f.dartFunction,
      _1725: () => ({}),
      _1726: () => [],
      _1728: () => globalThis,
      _1729: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _1730: (o, p) => p in o,
      _1731: (o, p) => o[p],
      _1732: (o, p, v) => o[p] = v,
      _1733: (o, m, a) => o[m].apply(o, a),
      _1735: o => String(o),
      _1736: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _1737: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1737(f,arguments.length,x0) }),
      _1738: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1738(f,arguments.length,x0,x1) }),
      _1739: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      _1740: o => [o],
      _1741: (o0, o1) => [o0, o1],
      _1742: (o0, o1, o2) => [o0, o1, o2],
      _1743: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _1744: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      _1745: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1746: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1747: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1748: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1749: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1750: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1751: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1752: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1753: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1754: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1755: x0 => new ArrayBuffer(x0),
      _1756: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _1757: x0 => x0.input,
      _1758: x0 => x0.index,
      _1759: x0 => x0.groups,
      _1760: x0 => x0.flags,
      _1761: x0 => x0.multiline,
      _1762: x0 => x0.ignoreCase,
      _1763: x0 => x0.unicode,
      _1764: x0 => x0.dotAll,
      _1765: (x0,x1) => { x0.lastIndex = x1 },
      _1766: (o, p) => p in o,
      _1767: (o, p) => o[p],
      _1768: (o, p, v) => o[p] = v,
      _1769: (o, p) => delete o[p],
      _1770: (x0,x1) => x0.replaceTrack(x1),
      _1771: x0 => x0.getParameters(),
      _1772: (x0,x1) => x0.setParameters(x1),
      _1773: x0 => x0.getStats(),
      _1774: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1774(f,arguments.length,x0,x1) }),
      _1776: (x0,x1) => x0.setCodecPreferences(x1),
      _1777: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1777(f,arguments.length,x0) }),
      _1778: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1779: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1779(f,arguments.length,x0) }),
      _1780: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1780(f,arguments.length,x0) }),
      _1781: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1781(f,arguments.length,x0) }),
      _1782: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1782(f,arguments.length,x0) }),
      _1783: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1783(f,arguments.length,x0) }),
      _1784: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1784(f,arguments.length,x0) }),
      _1785: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1785(f,arguments.length,x0) }),
      _1786: x0 => x0.close(),
      _1787: (x0,x1) => x0.setConfiguration(x1),
      _1788: (x0,x1) => x0.createOffer(x1),
      _1789: (x0,x1) => x0.createAnswer(x1),
      _1792: (x0,x1) => ({type: x0,sdp: x1}),
      _1793: (x0,x1) => x0.setLocalDescription(x1),
      _1794: (x0,x1) => ({type: x0,sdp: x1}),
      _1795: (x0,x1) => x0.setRemoteDescription(x1),
      _1796: (x0,x1,x2) => ({candidate: x0,sdpMid: x1,sdpMLineIndex: x2}),
      _1797: (x0,x1) => x0.addIceCandidate(x1),
      _1799: x0 => x0.getStats(),
      _1800: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1800(f,arguments.length,x0,x1) }),
      _1803: (x0,x1,x2,x3) => ({ordered: x0,protocol: x1,negotiated: x2,id: x3}),
      _1804: (x0,x1,x2) => x0.createDataChannel(x1,x2),
      _1805: x0 => x0.restartIce(),
      _1808: (x0,x1) => x0.removeTrack(x1),
      _1809: x0 => x0.getSenders(),
      _1812: (x0,x1,x2) => x0.addTransceiver(x1,x2),
      _1814: (x0,x1) => { x0.binaryType = x1 },
      _1816: x0 => globalThis.RTCRtpReceiver.getCapabilities(x0),
      _1817: x0 => new RTCPeerConnection(x0),
      _1827: x0 => x0.getStats(),
      _1828: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1828(f,arguments.length,x0,x1) }),
      _1830: (x0,x1) => ({video: x0,audio: x1}),
      _1831: (x0,x1) => x0.getDisplayMedia(x1),
      _1832: x0 => x0.enumerateDevices(),
      _1834: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1834(f,arguments.length,x0) }),
      _1842: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1842(f,arguments.length,x0) }),
      _1843: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1843(f,arguments.length,x0) }),
      _1844: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1844(f,arguments.length,x0) }),
      _1847: x0 => x0.getSettings(),
      _1854: x0 => x0.arrayBuffer(),
      _1856: x0 => x0.clone(),
      _1860: () => new XMLHttpRequest(),
      _1863: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1864: (x0,x1) => x0.send(x1),
      _1865: x0 => x0.send(),
      _1868: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1868(f,arguments.length,x0) }),
      _1869: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1869(f,arguments.length,x0) }),
      _1875: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1875(f,arguments.length,x0) }),
      _1876: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1876(f,arguments.length,x0) }),
      _1877: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1877(f,arguments.length,x0) }),
      _1878: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1878(f,arguments.length,x0) }),
      _1879: (x0,x1) => x0.send(x1),
      _1881: x0 => x0.deviceMemory,
      _1888: (x0,x1) => x0.matchMedia(x1),
      _1889: (x0,x1,x2) => x0.open(x1,x2),
      _1890: x0 => x0.abort(),
      _1891: x0 => x0.getAllResponseHeaders(),
      _1895: () => new AbortController(),
      _1896: x0 => x0.abort(),
      _1897: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _1898: (x0,x1) => globalThis.fetch(x0,x1),
      _1899: (x0,x1) => x0.get(x1),
      _1900: (module,f) => finalizeWrapper(f, function(x0,x1,x2) { return module.exports._1900(f,arguments.length,x0,x1,x2) }),
      _1901: (x0,x1) => x0.forEach(x1),
      _1902: x0 => x0.getReader(),
      _1903: x0 => x0.cancel(),
      _1904: x0 => x0.read(),
      _1905: x0 => x0.trustedTypes,
      _1906: (x0,x1) => { x0.text = x1 },
      _1907: o => o instanceof Array,
      _1911: a => a.pop(),
      _1912: (a, i) => a.splice(i, 1),
      _1913: (a, s) => a.join(s),
      _1914: (a, s, e) => a.slice(s, e),
      _1916: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _1917: a => a.length,
      _1918: (a, l) => a.length = l,
      _1919: (a, i) => a[i],
      _1920: (a, i, v) => a[i] = v,
      _1922: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      _1923: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _1925: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      _1926: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _1927: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      _1928: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _1929: o => o instanceof Uint8ClampedArray,
      _1930: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _1931: o => o instanceof Uint16Array,
      _1932: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _1933: o => o instanceof Int16Array,
      _1934: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _1935: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      _1936: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _1937: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      _1938: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _1940: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _1941: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      _1942: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _1943: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      _1944: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _1945: (a, i) => a.push(i),
      _1946: (t, s) => t.set(s),
      _1947: l => new DataView(new ArrayBuffer(l)),
      _1948: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _1950: o => o.buffer,
      _1951: o => o.byteOffset,
      _1952: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _1953: (b, o) => new DataView(b, o),
      _1954: (b, o, l) => new DataView(b, o, l),
      _1955: Function.prototype.call.bind(DataView.prototype.getUint8),
      _1956: Function.prototype.call.bind(DataView.prototype.setUint8),
      _1957: Function.prototype.call.bind(DataView.prototype.getInt8),
      _1958: Function.prototype.call.bind(DataView.prototype.setInt8),
      _1959: Function.prototype.call.bind(DataView.prototype.getUint16),
      _1960: Function.prototype.call.bind(DataView.prototype.setUint16),
      _1961: Function.prototype.call.bind(DataView.prototype.getInt16),
      _1962: Function.prototype.call.bind(DataView.prototype.setInt16),
      _1963: Function.prototype.call.bind(DataView.prototype.getUint32),
      _1964: Function.prototype.call.bind(DataView.prototype.setUint32),
      _1965: Function.prototype.call.bind(DataView.prototype.getInt32),
      _1966: Function.prototype.call.bind(DataView.prototype.setInt32),
      _1969: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _1970: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _1971: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _1972: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _1973: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _1974: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _1975: Function.prototype.call.bind(Number.prototype.toString),
      _1976: Function.prototype.call.bind(BigInt.prototype.toString),
      _1977: Function.prototype.call.bind(Number.prototype.toString),
      _1978: (d, digits) => d.toFixed(digits),
      _1999: () => globalThis.document,
      _2001: () => globalThis.console,
      _2006: (x0,x1) => { x0.height = x1 },
      _2008: (x0,x1) => { x0.width = x1 },
      _2010: (x0,x1) => { x0.pointerEvents = x1 },
      _2019: x0 => x0.style,
      _2022: x0 => x0.src,
      _2023: (x0,x1) => { x0.src = x1 },
      _2024: x0 => x0.naturalWidth,
      _2025: x0 => x0.naturalHeight,
      _2040: (x0,x1) => x0.error(x1),
      _2045: x0 => x0.status,
      _2046: (x0,x1) => { x0.responseType = x1 },
      _2048: x0 => x0.response,
      _2086: x0 => x0.readyState,
      _2088: (x0,x1) => { x0.timeout = x1 },
      _2090: (x0,x1) => { x0.withCredentials = x1 },
      _2091: x0 => x0.upload,
      _2092: x0 => x0.responseURL,
      _2093: x0 => x0.status,
      _2094: x0 => x0.statusText,
      _2096: (x0,x1) => { x0.responseType = x1 },
      _2097: x0 => x0.response,
      _2109: x0 => x0.loaded,
      _2110: x0 => x0.total,
      _2173: x0 => x0.style,
      _2742: (x0,x1) => { x0.width = x1 },
      _2744: (x0,x1) => { x0.height = x1 },
      _2745: x0 => x0.videoWidth,
      _2746: x0 => x0.videoHeight,
      _2775: x0 => x0.error,
      _2779: (x0,x1) => { x0.srcObject = x1 },
      _2787: x0 => x0.readyState,
      _2789: x0 => x0.currentTime,
      _2803: (x0,x1) => { x0.autoplay = x1 },
      _2807: (x0,x1) => { x0.controls = x1 },
      _2811: (x0,x1) => { x0.muted = x1 },
      _2826: x0 => x0.code,
      _2827: x0 => x0.message,
      _3406: (x0,x1) => { x0.src = x1 },
      _3408: (x0,x1) => { x0.type = x1 },
      _3412: (x0,x1) => { x0.async = x1 },
      _3416: (x0,x1) => { x0.crossOrigin = x1 },
      _3418: (x0,x1) => { x0.text = x1 },
      _3420: (x0,x1) => { x0.integrity = x1 },
      _3426: (x0,x1) => { x0.charset = x1 },
      _3874: () => globalThis.window,
      _3911: x0 => x0.document,
      _3914: x0 => x0.location,
      _3933: x0 => x0.navigator,
      _3937: x0 => x0.screen,
      _3949: x0 => x0.devicePixelRatio,
      _4188: x0 => x0.isSecureContext,
      _4191: x0 => x0.crypto,
      _4195: x0 => x0.trustedTypes,
      _4196: x0 => x0.sessionStorage,
      _4197: x0 => x0.localStorage,
      _4205: x0 => x0.href,
      _4207: x0 => x0.origin,
      _4210: x0 => x0.host,
      _4216: x0 => x0.pathname,
      _4300: x0 => x0.geolocation,
      _4303: x0 => x0.mediaDevices,
      _4305: x0 => x0.permissions,
      _4306: x0 => x0.maxTouchPoints,
      _4313: x0 => x0.appCodeName,
      _4314: x0 => x0.appName,
      _4315: x0 => x0.appVersion,
      _4316: x0 => x0.platform,
      _4317: x0 => x0.product,
      _4318: x0 => x0.productSub,
      _4319: x0 => x0.userAgent,
      _4320: x0 => x0.vendor,
      _4321: x0 => x0.vendorSub,
      _4323: x0 => x0.language,
      _4324: x0 => x0.languages,
      _4325: x0 => x0.onLine,
      _4330: x0 => x0.hardwareConcurrency,
      _4369: x0 => x0.data,
      _4525: x0 => x0.length,
      _4744: x0 => x0.readyState,
      _4757: (x0,x1) => { x0.binaryType = x1 },
      _4807: x0 => x0.localDescription,
      _4810: x0 => x0.remoteDescription,
      _4813: x0 => x0.signalingState,
      _4814: x0 => x0.iceGatheringState,
      _4815: x0 => x0.iceConnectionState,
      _4816: x0 => x0.connectionState,
      _4829: (x0,x1) => { x0.onicegatheringstatechange = x1 },
      _4841: x0 => x0.type,
      _4842: x0 => x0.sdp,
      _4843: x0 => x0.type,
      _4845: x0 => x0.sdp,
      _4853: x0 => x0.candidate,
      _4854: x0 => x0.sdpMid,
      _4855: x0 => x0.sdpMLineIndex,
      _4877: x0 => x0.candidate,
      _4913: x0 => x0.track,
      _4919: x0 => x0.headerExtensions,
      _4921: x0 => x0.rtcp,
      _4929: (x0,x1) => { x0.encodings = x1 },
      _4937: x0 => x0.active,
      _4952: x0 => x0.cname,
      _4954: x0 => x0.reducedSize,
      _4966: x0 => x0.clockRate,
      _4973: x0 => x0.payloadType,
      _4976: x0 => x0.codecs,
      _4978: x0 => x0.headerExtensions,
      _5003: x0 => x0.sender,
      _5046: x0 => x0.receiver,
      _5047: x0 => x0.track,
      _5048: x0 => x0.streams,
      _5049: x0 => x0.transceiver,
      _5065: x0 => x0.label,
      _5071: x0 => x0.id,
      _5073: x0 => x0.bufferedAmount,
      _5074: x0 => x0.bufferedAmountLowThreshold,
      _5075: (x0,x1) => { x0.bufferedAmountLowThreshold = x1 },
      _5077: (x0,x1) => { x0.onopen = x1 },
      _5079: (x0,x1) => { x0.onbufferedamountlow = x1 },
      _5085: (x0,x1) => { x0.onclose = x1 },
      _5087: (x0,x1) => { x0.onmessage = x1 },
      _5094: (x0,x1) => { x0.maxPacketLifeTime = x1 },
      _5096: (x0,x1) => { x0.maxRetransmits = x1 },
      _5106: x0 => x0.channel,
      _5993: (x0,x1) => { x0.fftSize = x1 },
      _5994: x0 => x0.frequencyBinCount,
      _5996: (x0,x1) => { x0.minDecibels = x1 },
      _5998: (x0,x1) => { x0.maxDecibels = x1 },
      _6000: (x0,x1) => { x0.smoothingTimeConstant = x1 },
      _6395: x0 => x0.target,
      _6435: x0 => x0.signal,
      _6444: x0 => x0.length,
      _6487: x0 => x0.baseURI,
      _6493: x0 => x0.firstChild,
      _6504: () => globalThis.document,
      _6576: x0 => x0.cookie,
      _6584: x0 => x0.body,
      _6586: x0 => x0.head,
      _6913: x0 => x0.tagName,
      _6914: x0 => x0.id,
      _6915: (x0,x1) => { x0.id = x1 },
      _7350: x0 => x0.ctrlKey,
      _7351: x0 => x0.shiftKey,
      _7352: x0 => x0.altKey,
      _7353: x0 => x0.metaKey,
      _8261: x0 => x0.value,
      _8263: x0 => x0.done,
      _8956: x0 => x0.url,
      _8958: x0 => x0.status,
      _8960: x0 => x0.statusText,
      _8961: x0 => x0.headers,
      _8962: x0 => x0.body,
      _9229: x0 => x0.type,
      _9244: x0 => x0.matches,
      _9255: x0 => x0.availWidth,
      _9256: x0 => x0.availHeight,
      _9261: x0 => x0.orientation,
      _9349: x0 => x0.state,
      _9745: x0 => x0.id,
      _9746: x0 => x0.active,
      _9752: x0 => x0.kind,
      _9753: x0 => x0.id,
      _9754: x0 => x0.label,
      _9755: x0 => x0.enabled,
      _9756: (x0,x1) => { x0.enabled = x1 },
      _9757: x0 => x0.muted,
      _9990: x0 => x0.width,
      _9992: x0 => x0.height,
      _9994: x0 => x0.aspectRatio,
      _9996: x0 => x0.frameRate,
      _9998: x0 => x0.facingMode,
      _10000: x0 => x0.resizeMode,
      _10002: x0 => x0.sampleRate,
      _10004: x0 => x0.sampleSize,
      _10006: x0 => x0.echoCancellation,
      _10008: x0 => x0.autoGainControl,
      _10010: x0 => x0.noiseSuppression,
      _10012: x0 => x0.latency,
      _10014: x0 => x0.channelCount,
      _10016: x0 => x0.deviceId,
      _10018: x0 => x0.groupId,
      _10072: (x0,x1) => { x0.ondevicechange = x1 },
      _10074: x0 => x0.deviceId,
      _10075: x0 => x0.kind,
      _10076: x0 => x0.label,
      _10077: x0 => x0.groupId,
      _11342: (x0,x1) => { x0.cursor = x1 },
      _11352: (x0,x1) => { x0.display = x1 },
      _11516: (x0,x1) => { x0.height = x1 },
      _11572: (x0,x1) => { x0.left = x1 },
      _11710: (x0,x1) => { x0.objectFit = x1 },
      _11728: (x0,x1) => { x0.opacity = x1 },
      _11840: (x0,x1) => { x0.pointerEvents = x1 },
      _11842: (x0,x1) => { x0.position = x1 },
      _12134: (x0,x1) => { x0.top = x1 },
      _12138: (x0,x1) => { x0.transform = x1 },
      _12206: (x0,x1) => { x0.width = x1 },
      _12497: x0 => x0.charging,
      _12500: x0 => x0.level,
      _12502: (x0,x1) => { x0.onchargingchange = x1 },
      _12574: x0 => x0.name,
      _12578: x0 => x0.subtle,
      _13281: () => globalThis.console,
      _13304: () => globalThis.window.flutterCanvasKit,
      _13305: () => globalThis.window._flutter_skwasmInstance,
      _13306: x0 => globalThis.Wakelock.toggle(x0),
      _13308: x0 => x0.name,
      _13309: x0 => x0.message,
      _13310: x0 => x0.code,

    };

    const baseImports = {
      dart2wasm: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });
    dartInstance.exports.$setThisModule(dartInstance);

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
