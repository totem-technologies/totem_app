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

The release script handles versioning, tagging, and pushing. The resulting `v*`
tag starts `.github/workflows/draft-release-on-tag.yml`, which:

1. Creates or updates a GitHub draft release with generated notes.
2. Builds signed staging and production Android App Bundles and iOS IPAs.
3. Attaches all four artifacts to the draft release.
4. Uploads each AAB to its configured Google Play track.
5. Uploads each IPA to the corresponding App Store Connect app for TestFlight processing.

### Prerequisites

Before creating a release, ensure:

- You are on the `main` branch.
- Your working tree is clean (no uncommitted changes).
- Your local `main` branch is up-to-date with `origin/main`.
- The repository store-upload configuration below is complete.

### Creating a Release

```bash
make release
```

The script will:
1. Display the current version from `pubspec.yaml`
2. Suggest a default version (increments patch and build number)
3. Prompt you to enter a new version
   Build numbers and Android version codes are immutable in both stores; a failed job must be retried with a new version if the store already accepted that build.

### Store upload configuration

Configure these GitHub repository **secrets** in addition to the existing build
and signing secrets:

| Secret | Source | Applies to |
| --- | --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | Key ID shown for an App Store Connect API key under Users and Access → Integrations | Both iOS apps |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID shown on the App Store Connect API keys page | Both iOS apps |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Complete contents of the API key's downloaded `AuthKey_<KEY_ID>.p8` file | Both iOS apps |
| `ANDROID_SERVICE_ACCOUNT_JSON` | Complete JSON key for the dedicated Google service account linked to Play Console | Both Android apps |

Configure these non-sensitive GitHub repository **variables**. Tracks are
required explicitly because this repository does not document a staging track;
do not choose `production` unless these tag builds are intended to go public.
The previous production-only workflow used the custom `qa` track with
`completed` status.

| Variable | Value | Applies to |
| --- | --- | --- |
| `GOOGLE_PLAY_STAGING_TRACK` | Existing Play track name for `org.totem.app.dev` (for example, a configured custom/internal testing track) | Staging Android |
| `GOOGLE_PLAY_STAGING_RELEASE_STATUS` | Android Publisher status: `draft`, `completed`, `halted`, or `inProgress` | Staging Android |
| `GOOGLE_PLAY_PRODUCTION_TRACK` | Existing Play track name for `org.totem.app` (previously `qa`) | Production Android |
| `GOOGLE_PLAY_PRODUCTION_RELEASE_STATUS` | Android Publisher status: `draft`, `completed`, `halted`, or `inProgress` (previously `completed`) | Production Android |

The Android package names come from the checked-in Gradle flavor configuration
and are intentionally not duplicated as secrets or variables.

#### App Store Connect setup

Create an App Store Connect team API key that can upload builds to both
`org.totem.ios` and `org.totem.ios.dev` and download their provisioning profiles.
The download action recommends at least App Manager access. Store the key metadata
and one-time-download `.p8` contents in the secrets above. Both app records,
bundle IDs, distribution certificates, and provisioning profiles must already
exist.

CI downloads active App Store distribution profiles using
`apple-actions/download-provisioning-profiles@v6` and the same API key used for
uploads. The team key must have access to the provisioning API; upload permission
alone is insufficient. CI selects these profiles for team `LNLXP4VK97` and
installs them in Xcode's profile directory. Each profile must include the distribution certificate
stored in `IOS_BUILD_CERTIFICATE_BASE64` and be unexpired. The profile names must
match both the Runner release signing settings and the export options plist.

| Flavor | Bundle ID | Profile name |
| --- | --- | --- |
| Production | `org.totem.ios` | `org.totem.ios Profile 2` |
| Staging | `org.totem.ios.dev` | `org.totem.dev Profile 2` |

The profile names also appear in the release workflow matrix. Renew profiles in
Apple's developer portal before they expire; CI downloads them on each run but
does not create or renew them. If a profile is renamed, update the matrix,
Runner signing settings, and export options together.

`IOS_MOBILE_PROVISIONING_PROFILE_BASE64` and
`IOS_STAGING_PROVISIONING_PROFILE_BASE64` are not needed by this workflow.
Keep `IOS_BUILD_CERTIFICATE_BASE64`, `IOS_BUILD_CERTIFICATE_PASSWORD`, and
`IOS_GITHUB_KEYCHAIN_PASSWORD`: downloading a profile does not supply the signing
certificate's private key.

The workflow writes the private key temporarily to the path expected by
`xcrun altool`, uploads the local IPA, and deletes the temporary key even when
the command fails. It does not wait for Apple processing or submit for review.

#### Google Play setup

Create a dedicated Google Cloud service account, enable the Google Play Android
Developer API for its project, link the service account in Play Console, and
limit its Play Console access to the two apps. Grant only the release permission
needed by the configured tracks (testing-track release permission for testing
tracks, plus production release permission only if a production track is
actually configured). Both package records must already exist in Play Console,
and Play App Signing must be configured as required by Google.

The repository-owned `.github/scripts/google-play-upload.mjs` uses no npm
packages. It creates an Android Publisher edit, uploads the local AAB, assigns
the returned version code to the configured track/status, and commits the edit.
On failure it attempts to delete the uncommitted edit.

### Remaining manual release work

After Apple finishes processing the build, assign the appropriate build to the
desired TestFlight groups in App Store Connect. TestFlight groups and testers
are not managed by CI.

For Google Play, `completed` makes the release available according to the
selected track's existing audience and review rules. A `draft` release still
requires review/completion in Play Console. CI does not add testers, change a
track's tester lists, perform staged-rollout management, or promote a build to a
different track.

### Testing store deployment safely

Run the dependency-free script tests locally first:

```bash
node --test .github/scripts/google-play-upload.test.mjs
```

Before relying on a normal release, configure both Android targets as
non-production testing tracks (or `draft` where supported), use a new unique
Flutter build number, and run the normal `make release` flow. Confirm all four
artifacts remain on the GitHub draft release, both Play edits are committed to
the intended tracks/statuses, and both IPAs appear in App Store Connect. Apple
and Google do not allow an accepted build/version code to be overwritten, so a
store upload cannot be safely tested by repeatedly reusing the same version.

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
https://totem.kbl.io/?room_preview=pr-166-video-experience
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

The staging server uses `ROOM_PREVIEW_ENABLED=True` to enable build selection.
Deploy the preview middleware from `totem-server` and enable that setting on
staging before using these links. Selection remains disabled by default.

- Handle `room_preview` on staging GET requests after session middleware and before
  view/login redirects, including requests to `/` and `/room/<session>`.
- A valid value is a preview alias, such as `pr-166-video-experience`. Validate
  the `pr-<positive-number>-<slug>` format, allowing only lowercase letters,
  numbers, and dashes, and require the alias plus `-totem-web-preview` to fit the
  63-character DNS label limit. Construct the upstream using the fixed
  `https://<alias>-totem-web-preview.lopkerk.workers.dev/` domain; never accept an
  arbitrary URL.
- Store `{alias, expires_at}` in `request.session["room_preview"]`, with an expiry
  two hours after selection. Requests without `room_preview` use the saved
  selection, including after ordinary login. Browsing does not extend the timer;
  following a preview link again starts a new two-hour period. Once expired,
  clear only this selection and use the normal staging build on the next load.
  [Django's session rotation preserves session data during login](https://docs.djangoproject.com/en/6.0/topics/http/sessions/#django.contrib.sessions.backends.base.SessionBase.cycle_key).
- `?room_preview=off` removes only `room_preview` and restores the configured staging
  bundle. Logout or expiry of the Django session also clears the selection.
  The login session's lifetime is unchanged. No additional cookie or browser
  storage is needed.
- After setting or clearing the choice, redirect to the same path with only
  `room_preview` removed from the query string. This keeps refreshes from reapplying
  an old selection and preserves other URL parameters.
- For room HTML, resolve the CDN from the saved selection and set its upstream
  Host header accordingly. Keep the normal staging CDN as the default. Return
  session-dependent HTML and selection redirects with `Cache-Control: private,
  no-store`; do not reuse another preview's conditional HTML response.
- If a saved deployment's index returns 404 or 410, clear the selection and ask
  the user to reload to return to normal staging. Treat temporary upstream
  failures as errors rather than silently switching builds. Production must
  not enable preview selection.

The selection is shared across tabs using the same Django session for up to two
hours. A loaded room keeps its build; newly opened or reloaded rooms use the
current selection, or normal staging after expiry.
Separate browser profiles can compare different builds concurrently. Use the
PR comment's **Return to normal staging** link to clear the selection early.

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
