# Totem Client

The open-source Flutter client for [Totem](https://totem.org), a platform for
guided group introspection. Supports iOS, Android, and web.

## Getting started

Install [Flutter](https://docs.flutter.dev/get-started/install). iOS development
also requires macOS and Xcode.

```sh
git clone https://github.com/totem-technologies/totem_app.git
cd totem_app
flutter config --enable-swift-package-manager
make install
make githooks
```

Set up [Firebase](https://firebase.google.com/docs/flutter/setup) locally.
`make flutterfire` configures the mobile package. For web, run
`flutterfire configure --platforms=web` from `packages/totem_web`.
Generated Firebase configuration files are not committed.

For local configuration, copy `config/development.local.env.example` to
`config/development.local.env`. Set `MOBILE_API_URL` there to use a local backend;
do not edit the generated package `.env` files. See the
[configuration guide](config/README.md).

## Development

```sh
make run          # Mobile app
make run-chrome   # Web client
make lint
make test
```

The [Makefile](Makefile) lists additional commands. Code is split between the
[mobile app](packages/totem_app), [web client](packages/totem_web), and
[shared library](packages/totem_core).

To test a session deep link with the app running:

```sh
# Android
adb shell 'am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://totem.org/spaces/session/doa689fvb"' org.totem.app

# iOS simulator
xcrun simctl openurl booted "https://totem.org/spaces/session/doa689fvb"
```

## Releases

From a clean, up-to-date `main` branch:

```sh
make release
```

This commits the version change and pushes a release tag. CI attaches the mobile
builds to a draft GitHub release and uploads them to Google Play's internal
testing tracks and App Store Connect. See the
[release workflow](.github/workflows/draft-release-on-tag.yml) for build targets
and signing configuration.

Use a new build number if a store has already accepted a build, even when
retrying a failed release. Accepted builds cannot be overwritten. After Apple
finishes processing, assign the builds to TestFlight groups manually. Tester
management and promotion beyond internal testing remain manual.

Publishing the GitHub release also deploys the production web client.

### Store credentials

Configure these repository secrets in addition to the build and signing
secrets referenced by the workflow:

| Secret | Value |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of the downloaded `AuthKey_<KEY_ID>.p8` file |
| `ANDROID_SERVICE_ACCOUNT_JSON` | JSON key for the Google service account linked to Play Console |

**Apple:** Create a team API key with access to both apps and permission to
download provisioning profiles as well as upload builds. The app records,
bundle IDs, distribution certificates, and provisioning profiles must already
exist. Save the `.p8` key when creating it; it can only be downloaded once.

Provisioning profiles must be unexpired and include the distribution certificate
used by CI. Renew them in Apple's developer portal; CI downloads profiles but
does not renew them. If a profile is renamed, update the release workflow,
Runner signing settings, and export options together.

The signing certificate must be exported with its private key as a
password-protected `.p12`. A provisioning profile or API key cannot replace a
missing signing private key. Store the export in `IOS_BUILD_CERTIFICATE_BASE64`
and its password in `IOS_BUILD_CERTIFICATE_PASSWORD`.

**Google:** Enable the Google Play Android Developer API for a dedicated service
account's project, link the account in Play Console, and grant it access to both
apps with **View app information (read-only)** and **Release apps to testing
tracks** permissions. The app records and Play App Signing setup must already
exist.

## Web hosting

Django serves the client at `/room/`, while Cloudflare Workers serves its assets.
This lets the web client share the backend's login session and origin. Hosting
configuration lives in [wrangler.toml](packages/totem_web/wrangler.toml), and
deployment is managed by the [Web workflow](.github/workflows/web.yml).

Web run and build commands enable HTML video with
`--dart-define=WEBRTC_USE_HTML_ELEMENT_VIEW=true`. The browser displays the
video elements directly through `HtmlElementView`.
Pass the same flag when invoking `flutter run` or `flutter build web` directly.
The Flutter UI still uses CanvasKit or skwasm; COOP/COEP headers independently
enable skwasm's rendering worker. When testing a build, check video clipping,
mirroring, camera toggles, and controls and menus over the video.

Cloudflare deployment requires these repository secrets:

- `CLOUDFLARE_API_TOKEN` with **Workers Scripts: Edit** permission.
- `CLOUDFLARE_ACCOUNT_ID` for the target account.

To deploy manually with Cloudflare credentials configured:

```sh
make deploy-web-staging
# or: make deploy-web-production
```

### Pull request previews

Repository PRs, including drafts, receive an **Open preview** link in a bot
comment. Fork PRs do not. Use that staging link to open the app; the Cloudflare
URL serves assets only. Previews share staging accounts and data.

The selected build applies to newly opened or reloaded rooms for two hours
across tabs in the same login session. An already loaded room keeps its build.
Open the preview link again to restart the two-hour window, or use **Return to
normal staging** in the PR comment to clear the selection. Separate browser
profiles can compare builds concurrently. Closing a PR does not remove its
preview deployment.

For initial setup:

- Deploy the preview middleware from `totem-server` and enable
  `ROOM_PREVIEW_ENABLED=True` on staging only.
- Create the preview Worker before uploading PR versions. After building the web
  bundle, run `bunx wrangler deploy --env preview` from `packages/totem_web` once.

See the [preview workflow](.github/workflows/web-preview.yml) for deployment
details. Use **Re-run jobs** in Actions to retry a failed preview build.

## Community

Visit [totem.org](https://totem.org), or open an issue or pull request to discuss
development.
