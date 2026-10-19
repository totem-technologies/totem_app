# Totem Client

The open-source Flutter client for [Totem](https://totem.org), a platform for
guided group introspection. It supports iOS, Android, and web.

## Install

Install [Flutter](https://docs.flutter.dev/get-started/install) **3.44.9**.

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
make run          # Mobile app
make run-chrome   # Web client
make lint
make test
```

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
