'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"icons/Icon-512.png": "60038f1a5d688cc65fe8d7f082e3da51",
"icons/Icon-maskable-512.png": "60038f1a5d688cc65fe8d7f082e3da51",
"icons/Icon-192.png": "ebf1c7e145331606d3324932422ed80e",
"icons/Icon-maskable-192.png": "ebf1c7e145331606d3324932422ed80e",
"manifest.json": "8656eb3c9c795b92384ee7f97ba85958",
"index.html": "8f8c6c4df9450b8356da4d5ba84f27b0",
"/": "8f8c6c4df9450b8356da4d5ba84f27b0",
"splash/img/light-4x.png": "1a45fb9a3aec0da1fece89a74ef6e845",
"splash/img/dark-4x.png": "1a45fb9a3aec0da1fece89a74ef6e845",
"splash/img/dark-3x.png": "e4d2c2710d39cfa0b41a2676ffc84f61",
"splash/img/light-background.png": "5e922c9774ec4bf6efb347f6dd8d412b",
"splash/img/dark-1x.png": "01d21888f8a6eb1a751ade17742206b3",
"splash/img/dark-2x.png": "72e2d814f7c6d269e9e654daf7541478",
"splash/img/light-1x.png": "01d21888f8a6eb1a751ade17742206b3",
"splash/img/light-3x.png": "e4d2c2710d39cfa0b41a2676ffc84f61",
"splash/img/light-2x.png": "72e2d814f7c6d269e9e654daf7541478",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "13b805aa93fe2d3af677b7f06bf3d9be",
"assets/assets/images/error_indicator.svg": "f17479e1b753e68b34f40595592cddec",
"assets/assets/images/splash_bg.png": "5e922c9774ec4bf6efb347f6dd8d412b",
"assets/assets/images/onboarding_1.jpg": "fd5bc174615370ffa1aad481b84b8796",
"assets/assets/images/welcome_background.jpg": "d0629ecd674c0dfeae1c9eb59591fb73",
"assets/assets/images/onboarding_3.jpg": "52bbf27a4752268938be92498f11b035",
"assets/assets/images/onboarding_2.jpg": "2883fae5d13a171e757d1d024342e212",
"assets/assets/logo/logo-square-192.png": "70ba837b8cf1471dc84d70e0a9b3ccba",
"assets/assets/logo/ig_logo.jpg": "9a62c2ced9934514b78b4ba575909e75",
"assets/assets/logo/logo-black-small.png": "52afce70299d734a299cddc72f183dd5",
"assets/assets/logo/logo-square-black-512.png": "6af7e458db61284d489fcb9dfa54d2c1",
"assets/assets/logo/Icon_white_square.png": "9543f82f747ea072e5e2b4fd0b3a4c15",
"assets/assets/logo/logo-square-512.png": "b73d54eef924ec6f2a89122a3c5b094e",
"assets/assets/logo/logo-black.svg": "2392da63352319080b05933a22ab177f",
"assets/assets/logo/logo-black.png": "396d4a2e0384dfa2298b3680e46c964c",
"assets/assets/logo/logo-small-white.png": "a5f98968f2daed0b601077842a804681",
"assets/assets/logo/logo-square.png": "0cab11b45cdff64bbd65627abefb5155",
"assets/assets/logo/logo-small-black.png": "c74f2387ea284954a275f91d5a7a3b78",
"assets/assets/logo/Icon_colored_square.png": "2ea532ede583720d43a6593987718e03",
"assets/assets/logo/ig_logo2.jpg": "535e42aea41ca2080a216f9099962c2e",
"assets/assets/logo/Icon_black_square.png": "4325285648f95e95729f194d8bbad3b2",
"assets/fonts/MaterialIcons-Regular.otf": "bcfdd08740389527ed0d5324befdcaeb",
"assets/NOTICES": "0324580713eba7f275bddeb0d1c12741",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/AssetManifest.bin": "f0d5beba7ee91546364968e5d2b3c85f",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"favicon.png": "665562327f55bb3de493b76a9c8cc678",
"flutter_bootstrap.js": "f4b177ac978efe50f2b58b052f0131a3",
"version.json": "1e60953885a3d011b4de5038d7dbc9b4",
"main.dart.js": "9d1a28af3296b1cbb5b31ed67acbdae7"};
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
