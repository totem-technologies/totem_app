'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"icons/Icon-maskable-192.png": "ebf1c7e145331606d3324932422ed80e",
"icons/Icon-192.png": "ebf1c7e145331606d3324932422ed80e",
"icons/Icon-maskable-512.png": "60038f1a5d688cc65fe8d7f082e3da51",
"icons/Icon-512.png": "60038f1a5d688cc65fe8d7f082e3da51",
"assets/fonts/MaterialIcons-Regular.otf": "64abb617de75474428f6c05c7290e252",
"assets/AssetManifest.bin.json": "324c85149e43941d3a139c01a9606405",
"assets/AssetManifest.bin": "b297765d959d9c2ed00c34b436f106fb",
"assets/AssetManifest.json": "74783efb8291b0227030d92694afa67e",
"assets/assets/logo/Icon_black_square.png": "4325285648f95e95729f194d8bbad3b2",
"assets/assets/logo/logo-small-white.png": "a5f98968f2daed0b601077842a804681",
"assets/assets/logo/ig_logo.jpg": "9a62c2ced9934514b78b4ba575909e75",
"assets/assets/logo/Icon_colored_square.png": "2ea532ede583720d43a6593987718e03",
"assets/assets/logo/ig_logo2.jpg": "535e42aea41ca2080a216f9099962c2e",
"assets/assets/logo/logo-square-192.png": "70ba837b8cf1471dc84d70e0a9b3ccba",
"assets/assets/logo/logo-square.png": "0cab11b45cdff64bbd65627abefb5155",
"assets/assets/logo/logo-black.png": "396d4a2e0384dfa2298b3680e46c964c",
"assets/assets/logo/logo-square-black-512.png": "6af7e458db61284d489fcb9dfa54d2c1",
"assets/assets/logo/logo-black-small.png": "52afce70299d734a299cddc72f183dd5",
"assets/assets/logo/logo-square-512.png": "b73d54eef924ec6f2a89122a3c5b094e",
"assets/assets/logo/logo-black.svg": "2392da63352319080b05933a22ab177f",
"assets/assets/logo/Icon_white_square.png": "9543f82f747ea072e5e2b4fd0b3a4c15",
"assets/assets/logo/logo-small-black.png": "c74f2387ea284954a275f91d5a7a3b78",
"assets/assets/images/welcome_background.jpg": "d0629ecd674c0dfeae1c9eb59591fb73",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/NOTICES": "7b7d92d40752f6a9d5b192b089e0a3b6",
"main.dart.js": "ff61bf3ee840c8f3c39757fa58d79a34",
"manifest.json": "9ec3308ecb18ab3bffe001d076132e57",
"version.json": "603643c6f115811ceb7a1c809487013f",
"canvaskit/skwasm.js.symbols": "9fe690d47b904d72c7d020bd303adf16",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/skwasm.wasm": "1c93738510f202d9ff44d36a4760126b",
"canvaskit/canvaskit.wasm": "a37f2b0af4995714de856e21e882325c",
"canvaskit/canvaskit.js.symbols": "27361387bc24144b46a745f1afe92b50",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.wasm": "c054c2c892172308ca5a0bd1d7a7754b",
"canvaskit/chromium/canvaskit.js.symbols": "f7c5e5502d577306fb6d530b1864ff86",
"flutter_bootstrap.js": "b664dc422205953b76d55911c5ff5676",
"splash/img/branding-dark-4x.png": "30374a77cfd2b58267aa4c78ceeb7cfa",
"splash/img/light-3x.png": "7acbb0a37af4a006e2d91aed86ccc300",
"splash/img/branding-4x.png": "30374a77cfd2b58267aa4c78ceeb7cfa",
"splash/img/branding-dark-2x.png": "3e9bde46d6a2b9e25e923b38785c295f",
"splash/img/branding-3x.png": "3cfb9b6939aff49891d8a77cb5e517e9",
"splash/img/dark-4x.png": "ad34f030ccbbbb2f49bcd352efe2f58f",
"splash/img/light-1x.png": "03f9f789f2d84f61b7c1d36ea1967f0d",
"splash/img/dark-1x.png": "03f9f789f2d84f61b7c1d36ea1967f0d",
"splash/img/light-2x.png": "dd48e8d48c1bf353e2bfb374828c42be",
"splash/img/branding-dark-1x.png": "4dff858510e3336c4ddcbce3ecaad0fa",
"splash/img/branding-1x.png": "4dff858510e3336c4ddcbce3ecaad0fa",
"splash/img/branding-2x.png": "3e9bde46d6a2b9e25e923b38785c295f",
"splash/img/branding-dark-3x.png": "3cfb9b6939aff49891d8a77cb5e517e9",
"splash/img/dark-2x.png": "dd48e8d48c1bf353e2bfb374828c42be",
"splash/img/dark-3x.png": "7acbb0a37af4a006e2d91aed86ccc300",
"splash/img/light-4x.png": "ad34f030ccbbbb2f49bcd352efe2f58f",
"favicon.png": "665562327f55bb3de493b76a9c8cc678",
"index.html": "2469e4ba1a6e168ac61dd033df38622b",
"/": "2469e4ba1a6e168ac61dd033df38622b",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
