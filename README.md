<div align="center">
<h1>Totem Client</h1>
<a href="https://github.com/totem-technologies/totem_app/actions/workflows/build.yaml"><img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/totem-technologies/totem_app/build.yaml?color=%2320A920"></a>
<a href="https://pub.dev/packages/flutter">
  <img alt="Flutter SDK" src="https://img.shields.io/badge/flutter-%3E%3D3.29-blue?logo=flutter&style=flat-square">
</a>
<a href="https://totem.org">
  <img alt="Website" src="https://img.shields.io/badge/visit-totem.org-orange?style=flat-square">
</a>
<p><em>Guided introspection groups at <a href="https://www.totem.org">totem.org</a></em></p>
</div>

## 🧭 Overview

Totem is a space for guided group introspection. This Flutter app is the **official open-source mobile client** for the Totem platform.
It connects people through structured group sessions and authentic conversations, powered by a thoughtfully crafted UI and backend.

This client targets **iOS**, **Android** and the **Web**, using **Flutter** and **Riverpod** for a fast, modern, and scalable development experience.

---

## 📦 Installation

Make sure you have [Flutter installed](https://docs.flutter.dev/get-started/install) and configured.

```bash
git clone https://github.com/totem-technologies/totem_app.git
flutter config --enable-swift-package-manager
make install
make githooks  # Install git hooks for code formatting
```

> \[!NOTE]
>
> You must setup firebase locally.
> ⚠️ You must run `make flutterfire` to generate firebase_options.dart and add your own Firebase config files (google-services.json, GoogleService-Info.plist) locally. This runs `flutterfire configure` inside both the `totem_app` (android + ios) and `totem_web` (web) packages. These files are not committed to the repo. [Learn more](https://firebase.google.com/docs/flutter/setup)

### 📲 Running on Devices

For development:

```bash
make run
make run-chrome
```

Runtime config is composed from the layered files in `config/` into each package's `.env`. `make run` / `make run-chrome` do this automatically for the `development` flavor; run `make env-dev` to (re)generate it manually. To override a value on your machine, copy `config/development.local.env.example` to `config/development.local.env` and edit it. See [`config/README.md`](config/README.md) for the full layering model and available keys.

If testing on an iOS device, ensure you're using macOS and have Xcode installed.

You can use the `--flavor` option to build for `staging` or `production` (default).

On android, When reattaching, use:

```bash
adb logcat "*:S" flutter:V
flutter attach
```

or

```bash
flutter run --use-application-binary=packages\totem_app\build\app\outputs\apk\debug\app-debug.apk
```

### 🧪 Testing

Run all tests:

```bash
make test
```

### Deep Linking

To test deep linking, with the app running, you can use the following commands:

For Android:

```bash
adb shell 'am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://totem.org/spaces/session/doa689fvb"' org.totem.app
```

For iOS:

```bash
xcrun simctl openurl booted "https://totem.org/spaces/session/doa689fvb"
```

### Local Server

To run the app with a local server, you can set the `MOBILE_API_URL` environment variable at the `.env` file in the `packages/totem_app` or `packages/totem_web` directory of the project. This allows you to connect to a local instance of the Totem API.

```bash
MOBILE_API_URL="http://localhost:8000/"
```

## ✍️ Project Structure

This repository is organized as a multi-package Flutter workspace.

```
.
├── packages/
│   ├── totem_core/    # Shared library: firebase_options.dart, common logic, models
│   │   └── lib/
│   ├── totem_app/     # Mobile app (iOS / Android)
│   │   └── lib/
│   └── totem_web/     # Web client
│       └── lib/
├── scripts/
├── specs/
└── README.md
```

### 🔔 Notifications

Notifications are handled using Firebase Cloud Messaging (FCM). In the notification data, one may include a `path` key to specify the route to navigate to when the user taps on the notification.

## 🚢 Release (for developers)

The release process is automated via a Dart script that handles versioning, tagging, and pushing to the repository.

### Prerequisites

Before creating a release, ensure:
- You are on the `main` branch
- Your working tree is clean (no uncommitted changes)
- Your local `main` branch is up-to-date with `origin/main`

### Creating a Release

Run the release command:

```bash
make release
```

The script will:
1. Display the current version from `pubspec.yaml`
2. Suggest a default version (increments patch and build number)
3. Prompt you to enter a new version

## 🌐 Web hosting (Cloudflare Workers)

The `totem_web` client is mounted at the **`/room/`** base route. The Django
origin serves (and patches) the HTML document — it proxies the page from this
deployment — while the Cloudflare Worker acts as a CDN, serving every other
asset directly. Two build settings make this work:

- **`--base-href /room/`** sets `<base href="/room/">` so the page and go_router
  routing live under `/room/` on the Django origin.
- **`--web-define=ASSET_BASE=<worker-url>`** points Flutter's loader
  (`web/flutter_bootstrap.js`) at the Cloudflare deployment, so `main.dart.js`,
  CanvasKit, the wasm runtime and `assets/` are fetched directly from the CDN.

The bootstrap script is **inlined** into `index.html` (via the
`{{flutter_bootstrap_js}}` token), so there is no separate
`flutter_bootstrap.js` request: Django serves only the HTML document and the CDN
serves everything the loader pulls.

The Worker is assets-only and serves the bundle flat from its own origin. SPA
fallback is **off** (`not_found_handling = "none"`) — Django owns the HTML and
client-side routing, so a missing asset 404s instead of being masked by
`index.html`. Because the assets are fetched cross-origin, they ship with CORS
headers via `web/_headers` (honored by Workers Static Assets); `scripts/serve_web.dart`
mirrors those headers for local testing.

Config lives in `packages/totem_web/wrangler.toml`; deploys are driven by
`.github/workflows/web.yml`:

- **Pull request / push to `main`** — builds the web bundle as a check.
- **Repository pull requests, including drafts** — `.github/workflows/web-preview.yml`
  also deploys an independent preview backed by public staging (see below).
- **Push a release tag `v*`** — builds and deploys the **staging** environment.
- **Publish the GitHub release** (move the draft out to latest) — builds and
  deploys the **production** environment.

Required repository **secrets** (in addition to the existing `FIREBASE_OPTIONS_B64`):

- `CLOUDFLARE_API_TOKEN` — a token with the *Workers Scripts: Edit* permission.
- `CLOUDFLARE_ACCOUNT_ID` — the target Cloudflare account id.

`ASSET_BASE` (the public URL the loader fetches assets from) is mapped per
environment in `scripts/web_build.dart` — currently the `*.workers.dev`
URLs. `WEB_ASSET_BASE` overrides that mapping for preview builds.

To build and deploy manually:

```bash
cd packages/totem_web
flutter build web --wasm --base-href /room/ \
  --web-define=ASSET_BASE=https://totem-web-staging.<sub>.workers.dev/
bunx wrangler deploy --env staging   # or --env production
```

### Pull request previews

Every open PR from a branch in this repository, including drafts, gets an
aliased version of the shared assets-only Worker `totem-web-preview`:

```text
https://pr-<number>-<branch-slug>-totem-web-preview.lopkerk.workers.dev
```

For example, PR #166 from `video-experience` gets
`https://pr-166-video-experience-totem-web-preview.lopkerk.workers.dev`.
Branch names are lowercased, punctuation becomes dashes, and long names are
truncated to fit the 63-character DNS label limit, including the Worker name.
The PR number prevents collisions. Title edits do not change the URL. New
commits and reopening a PR update the preview. Fork PRs are excluded.

Each upload moves that PR's alias to its new version; other PR aliases keep
serving their own versions. Uploads for the same PR are serialized, and a status
check skips closed PRs and superseded commits. Different PRs can upload in
parallel.
There is no cleanup workflow or time-based expiry. We rely on
[Cloudflare's retention of the 1,000 most recent aliases](https://developers.cloudflare.com/workers/versions-and-deployments/preview-urls/#rules-and-limitations).
Closing a PR does not remove its preview.

The workflow's **Open preview** link selects that build on staging:

```text
https://totem.kbl.io/?preview=pr-166-video-experience
```

Django serves the selected deployment's HTML under `/room/`. The HTML includes
an absolute `ASSET_BASE` pointing to that PR's alias URL, so Flutter fetches its
JavaScript, WebAssembly, and assets directly from Cloudflare. Login, cookies,
CSRF, and API requests use **https://totem.kbl.io** and its shared staging data.
The Cloudflare hostname is the CDN; open the staging link to use the app.

The workflow uses the existing `FIREBASE_OPTIONS_B64`, `CLOUDFLARE_API_TOKEN`
(Workers Scripts: Edit), and `CLOUDFLARE_ACCOUNT_ID` repository secrets. No
custom DNS records are needed. Each successful upload exposes a link through its
GitHub environment and creates or updates one bot comment on the PR, including
the commit SHA and a link to return to normal staging. The comment action uses
the workflow's `GITHUB_TOKEN` with `pull-requests: write` permission.
The shared `web/index.html` includes a `noindex, nofollow` robots meta tag for
every environment. Assets use the cross-origin headers from `web/_headers`.

#### One-time Cloudflare setup

The shared Worker must exist and have preview URLs enabled before uploading PR
versions. After building the web bundle, initialize it once from
`packages/totem_web` with `npx wrangler deploy --env preview`. The configuration
sets `preview_urls = true`. Cloudflare requires this
[initial deployment before `versions upload`](https://developers.cloudflare.com/workers/versions-and-deployments/deployment-management/#first-upload).
Subsequent PR uploads only update their alias and do not change the Worker's
default deployment.

#### Server integration and persistence

**The staging server must implement this contract before the preview links
select a build.** This repository supplies deployments and links; selection
and persistence belong in `totem-server`.

- Handle `preview` on staging GET requests after session middleware and before
  view/login redirects, including requests to `/` and `/room/<session>`.
- A valid value is a preview alias, such as `pr-166-video-experience`. Validate
  the `pr-<positive-number>-<slug>` format, allowing only lowercase letters,
  numbers, and dashes, and require the alias plus `-totem-web-preview` to fit the
  63-character DNS label limit. Construct the upstream using the fixed
  `https://<alias>-totem-web-preview.lopkerk.workers.dev/` domain; never accept an
  arbitrary URL.
- Store the validated selection in `request.session["room_preview"]`. Requests
  without `preview` use the saved selection, including after ordinary login.
  [Django's session rotation preserves session data during login](https://docs.djangoproject.com/en/6.0/topics/http/sessions/#django.contrib.sessions.backends.base.SessionBase.cycle_key).
- `?preview=off` removes only `room_preview` and restores the configured staging
  bundle. Logout or expiry of the Django session also clears the selection.
  No additional cookie or browser storage is needed.
- After setting or clearing the choice, redirect to the same path with only
  `preview` removed from the query string. This keeps refreshes from reapplying
  an old selection and preserves other URL parameters.
- For room HTML, resolve the CDN from the saved selection and set its upstream
  Host header accordingly. Keep the normal staging CDN as the default. Return
  session-dependent HTML and selection redirects with `Cache-Control: private,
  no-store`; do not reuse another preview's conditional HTML response.
- If a saved deployment no longer exists, clear the selection and explain the
  return to normal staging. Treat temporary upstream failures as errors rather
  than silently switching builds. Production must not enable preview selection.

The selection is shared across tabs using the same Django session. A loaded
room keeps its build; newly opened or reloaded rooms use the current selection.
Separate browser profiles can compare different builds concurrently. The server
should show the selected PR and a **Return to normal staging** link so the active
build is visible.

The workflow builds directly from the PR head commit, including its build
scripts and Wrangler configuration. Open a PR or push another commit to deploy;
use **Re-run jobs** in Actions to retry a failed build.

Preview naming, links, and deployment checks are tested by the normal Flutter
Analysis workflow. Run them locally with `make test-scripts` (also included in
`make test`). All Worker environments share
`packages/totem_web/wrangler.toml`; PR deployments use
`wrangler versions upload --env preview --preview-alias <pr-alias>`.

## 👥 Community

Join the Totem movement at [totem.org](https://www.totem.org).
To discuss development or get involved, feel free to open an issue or pull request.

<div align="center"> ✨ Built with care by the Totem Technologies team ✨ </div>
