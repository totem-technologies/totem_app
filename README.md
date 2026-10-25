# Totem Client

The open-source Flutter client for [Totem](https://totem.org), a platform for
guided group introspection. It supports iOS, Android, and web.

## Install

Install [FVM](https://fvm.app/) and both pinned Flutter SDKs. Native development
uses Flutter **3.44.9** (bundled Dart 3.12.2); Web uses Flutter **3.47.7**
(bundled Dart 3.13.5). iOS development also requires macOS and Xcode.

```sh
git clone https://github.com/totem-technologies/totem_app.git
cd totem_app
fvm install 3.44.9
fvm install 3.47.7
fvm flutter config --enable-swift-package-manager
make prepare-native
make githooks
```

`.fvmrc` deliberately remains pinned to 3.44.9, so `fvm flutter` and `fvm dart`
are the native/default commands. Do not change it to run the Web client.

Configure [Firebase](https://firebase.google.com/docs/flutter/setup) locally:

```sh
make flutterfire # mobile
cd packages/totem_web && flutterfire configure --platforms=web
```

Firebase configuration is generated locally and is not committed. To point a
local app at a backend, create `config/development.local.env` from its example
and set `MOBILE_API_URL`. Do not edit generated package `.env` files; see the
[configuration guide](config/README.md) for the supported configuration layers.

## Develop

```sh
make run          # iOS/Android with Flutter 3.44.9
make run-chrome   # Web client with Flutter 3.47.7
make build-web-release
make lint
make test
```

Web commands temporarily select the Web dependency resolution, then restore the
native `pubspec.lock` and `.dart_tool`, including after failures. `make test`
runs native/shared tests first and Web tests second.

The [Makefile](Makefile) contains additional commands. The codebase has a
[mobile app](packages/totem_app), [web client](packages/totem_web), and
[shared library](packages/totem_core). Follow the engineering and test
conventions in [AGENTS.md](AGENTS.md).

### Useful development commands

Open a session deep link while the app is running:

```sh
# Android
adb shell 'am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://totem.org/spaces/session/doa689fvb"' org.totem.app

# iOS simulator
xcrun simctl openurl booted "https://totem.org/spaces/session/doa689fvb"
```

For repeatable room rendering experiments without a call connection, use the
[local rendering benchmark](scripts/benchmark/README.md).

## Release

From a clean, up-to-date `main` branch:

```sh
make release
```

This commits the version change and pushes a release tag. CI creates a draft
GitHub release, uploads mobile builds to it, and sends them to Google Play
internal testing and App Store Connect. Publishing the GitHub release deploys
the production web client.

Use a new build number after a store accepts a build; accepted builds cannot be
overwritten. After Apple processes a build, assign it to TestFlight groups
manually. See the [release workflow](.github/workflows/draft-release-on-tag.yml)
for the signing configuration and build targets.

### Release credentials

Configure the repository secrets required by the release workflow, including:

| Secret | Purpose |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Downloaded `AuthKey_<KEY_ID>.p8` contents |
| `ANDROID_SERVICE_ACCOUNT_JSON` | Google Play service-account JSON |

Apple requires an existing app record, bundle ID, distribution certificate, and
valid provisioning profile. Export the signing certificate and its private key
as a password-protected `.p12` for `IOS_BUILD_CERTIFICATE_BASE64`; store its
password in `IOS_BUILD_CERTIFICATE_PASSWORD`. Keep the provisioning-profile
names synchronized with the release workflow.

For Google Play, enable the Android Developer API for a dedicated service
account, link it in Play Console, and grant access to both apps with **View app
information (read-only)** and **Release apps to testing tracks** permissions.

## Flutter SDK compatibility and lockfiles

Shared packages keep `environment: sdk: ^3.12.2`; this is the Dart language
baseline, not an instruction to replace Flutter's bundled Dart SDK or cap its
upper bound. Shared and generated source must remain compatible with Dart 3.12
and Flutter 3.44.9 APIs. Do not add Dart 3.13-only language features or Flutter
3.47-only APIs to shared code.

| Platform | Flutter | Bundled Dart | Resolution |
| --- | --- | --- | --- |
| iOS / Android | 3.44.9 | 3.12.2 | `pubspec.lock` |
| Web | 3.47.7 | 3.13.5 | `pubspec.web.lock` |

The Web pin includes the CanvasKit/Skwasm context-loss recovery change from
[flutter/flutter#185116](https://github.com/flutter/flutter/pull/185116), which
addresses the `LateInitializationError` reported in
[flutter/flutter#190192](https://github.com/flutter/flutter/issues/190192).
It does **not** prove that Totem's Safari failure is resolved. Native remains on
3.44.9 because Flutter 3.47 has the platform-view composition regression in
[flutter/flutter#193363](https://github.com/flutter/flutter/issues/193363),
where video platform views can appear above Flutter dialogs and sheets.

Pub supports one active workspace lockfile. `pubspec.lock` is the native
baseline; `pubspec.web.lock` is the Web snapshot. CI and Make targets copy the
selected snapshot to `pubspec.lock`, clear `.dart_tool`, and use
`flutter pub get --enforce-lockfile`.

After changing dependencies, update the native baseline with `fvm flutter pub
get`, then run `make update-web-lockfile`. It refreshes and verifies the Web
snapshot, restores the native state, and validates both resolutions. Before
upgrading either SDK, check the relevant upstream issue and update both
resolutions and the CI matrix. CI analyzes shared code under both SDKs, tests
native/shared code under 3.44.9 and Web code under 3.47.7, and compiles Web on
PRs and `main`.

## Web hosting

Django serves the client at `/room/` so it shares the backend login session and
origin; Cloudflare Workers serves its assets. Deployment configuration is in
[wrangler.toml](packages/totem_web/wrangler.toml) and CI is in the
[Web workflow](.github/workflows/web.yml).

The Makefile applies `WEBRTC_USE_HTML_ELEMENT_VIEW=true` to web runs and builds.
Pass the same `--dart-define` when invoking Flutter directly.

| Trigger | Result |
| --- | --- |
| Pull request or push to `main` | Staging build validation |
| Push a `v*` tag | Staging deployment |
| Publish the GitHub release | Production deployment |

A pushed `v*` tag uses release `totem_web@<tag>` with distribution `staging`.
Publishing that GitHub Release uses the same release name with distribution
`production`. The Flutter SDK sends the same release and distribution with web
events; it retains the application-configured Sentry environment.

After deployment, open **Releases** in the configured Sentry project, select
`totem_web@<tag>`, and inspect its **Artifact Bundles** (or source-map artifacts)
to confirm the uploaded bundle. To test JavaScript-fallback symbolication, use
Firefox (the current bootstrap disables its Wasm renderer), open the deployed
staging app, and trigger a temporary uncaught JavaScript error from DevTools:

```js
setTimeout(() => { throw new Error('Sentry JS fallback source-map check'); });
```

Confirm the resulting Sentry event resolves JavaScript frames to the uploaded
source context, then remove the temporary test event. Release builds produce
both JavaScript and WebAssembly maps, and the plugin uploads all map artifacts. Wasm
symbolication is **unverified**: the plugin injects Debug IDs into JavaScript
artifacts, while current Sentry Flutter documentation does not guarantee
WebAssembly-frame symbolication. Oversized `.map` files (over Cloudflare's
25 MiB per-static-asset limit) are removed only after a successful Sentry upload;
JavaScript and Wasm executables are never removed or rebuilt.

To deploy manually with Cloudflare credentials configured:

```sh
make deploy-web-staging
# or: make deploy-web-production
```

Cloudflare requires `CLOUDFLARE_API_TOKEN` with **Workers Scripts: Edit** and
`CLOUDFLARE_ACCOUNT_ID`. Release deployments also upload Sentry source maps and
require `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT`; `SENTRY_URL` is
optional for self-hosted Sentry. Tags use `totem_web@<tag>` with the `staging`
distribution, and published releases use the same name with `production`.
Confirm uploaded artifacts in the corresponding Sentry release when setting up
a deployment.

### Safari regression checklist

The Flutter 3.47.7 upgrade is a targeted mitigation, not confirmation that the
Safari incident is fixed. Before closing the incident, manually test Safari
26.2 on Mac M1, Safari 27 on Mac M4, and Chrome on Mac M1. For each browser:

- enter a session and transition into an active session;
- exercise multiple participant videos and self-view toggling;
- resize responsively, background and restore the tab; and
- confirm Flutter UI renders above and around the HTML video platform views.

Also track [flutter/flutter#162868](https://github.com/flutter/flutter/issues/162868):
WebGL recovery can still fail when recreating the context fails. Do not infer a
complete engine fix from a successful build or from the resolved
`LateInitializationError` alone.

### Pull-request previews

Eligible repository pull requests, including drafts, receive an **Open preview**
link in a bot comment; fork pull requests do not. Preview assets share staging
accounts and data. A selected build applies to newly opened or reloaded rooms
for two hours within a login session. Use **Return to normal staging** in the
comment to clear it, or reopen the preview link to restart the window.

Initial setup requires preview middleware from `totem-server` with
`ROOM_PREVIEW_ENABLED=True` on staging, plus a one-time preview Worker deploy:

```sh
cd packages/totem_web
bunx wrangler deploy --env preview
```

See the [preview workflow](.github/workflows/web-preview.yml) for deployment
and retry details.

## Community

Visit [totem.org](https://totem.org), or open an issue or pull request to
discuss development.
