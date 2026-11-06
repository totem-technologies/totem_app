# Totem Client

The open-source Flutter client for [Totem](https://totem.org), a platform for
guided group introspection. It supports iOS, Android, and web.

## Install

Install [FVM](https://fvm.app/). Flutter **3.50.0-0.2.pre** (bundled Dart
3.14.0 beta) is the default for Android, web, desktop, and shared development.
iOS uses **3.44.9** (bundled Dart 3.12.2) and requires macOS and Xcode.

```sh
git clone https://github.com/totem-technologies/totem_app.git
cd totem_app
fvm install 3.44.9
fvm install 3.50.0-0.2.pre
fvm flutter config --enable-swift-package-manager
make prepare-native
make githooks
```

`.fvmrc` pins the default beta SDK. Use `make run-ios RUN_ARGS='-d <device-id>'`
for iOS, or `fvm spawn 3.44.9` for other iOS-specific Flutter commands.

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
make run          # Android/desktop with the default beta SDK
make run-ios      # iOS with Flutter 3.44.9 (use RUN_ARGS to select a device)
make run-chrome   # Web client with the default beta SDK
make build-web-release
make lint
make test
```

There is one `pubspec.lock`. Run `make install` after changing SDKs so Pub can
resolve dependencies compatible with the selected SDK. No lockfile swapping or
`.dart_tool` deletion is required. `make test` resolves once, then runs all
shared/native suites and Chrome web tests.

The [Makefile](Makefile) contains additional commands. The codebase has a
[mobile app](packages/totem_app), [web client](packages/totem_web), and
[shared library](packages/totem_core). Follow the engineering and test
conventions in [AGENTS.md](AGENTS.md).

### Git validation

`make githooks` installs incremental local hooks. Pre-commit runs only the
applicable custom source checks for staged Dart changes; it does not format or
run Flutter analysis.

Pre-push intentionally runs no validation: pushing a PR never waits for local
SDK setup, analysis, or tests, and does not require `git push --no-verify`.
GitHub Actions runs the complete validation before merging.

For optional local incremental validation, run `make test-changed`. It compares
the working tree to the merge base with the remote default branch, analyzes
affected packages and core dependents, and tests directly affected packages.
Shared configuration or an unavailable comparison base selects full validation.

Run `make lint` and `make test` for complete local validation; they remain the
full-repository commands used by CI. Formatting is manual (`make format`) and
is not part of hooks or CI. `make lint-changed` and `make test-changed` expose
the local staged checks and optional incremental validation respectively.

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
and Flutter 3.44.9 APIs. Do not add newer Dart language features or Flutter APIs
unavailable in 3.44.9 to shared code.

| Platform | Flutter | Bundled Dart | Resolution |
| --- | --- | --- | --- |
| iOS | 3.44.9 | 3.12.2 | SDK-specific `pub get` |
| Android / Web / desktop | 3.50.0-0.2.pre | 3.14.0 beta | `pubspec.lock` |

The Web pin includes the CanvasKit/Skwasm context-loss recovery change from
[flutter/flutter#185116](https://github.com/flutter/flutter/pull/185116), which
addresses the `LateInitializationError` reported in
[flutter/flutter#190192](https://github.com/flutter/flutter/issues/190192).
It does **not** prove that Totem's Safari failure is resolved. iOS remains on
3.44.9 because Flutter 3.47 has the platform-view composition regression in
[flutter/flutter#193363](https://github.com/flutter/flutter/issues/193363),
where video platform views can appear above Flutter dialogs and sheets.

Only `pubspec.lock` is maintained, using `fvm flutter pub get` with the default
beta SDK. CI runs ordinary `flutter pub get` once with each job's selected SDK;
it may adjust SDK-pinned packages in that ephemeral checkout. A lockfile that
needs an SDK-specific adjustment is not rejected with `--enforce-lockfile`.
Dependency resolution errors still fail CI.

For iOS development, run `make prepare-ios` before stable SDK commands and
`make install` when returning to beta. Pub may update `pubspec.lock` when
switching SDKs; commit dependency updates using the default beta resolution,
not a second snapshot. CI runs the complete lint/test suite on beta and the
shared/native compatibility checks on stable for iOS. Android and web builds
use beta; iOS builds use stable.

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

The Flutter 3.50.0-0.2.pre upgrade is a targeted mitigation, not confirmation
that the Safari incident is fixed. Before closing the incident, manually test Safari
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
