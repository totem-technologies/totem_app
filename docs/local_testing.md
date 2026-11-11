# Testing on real devices against a local server

How to run the apps and the web app on physical Android and iOS devices, and on
desktop browsers, against a local `totem-server`, and how an agent can drive
each device. Everything here was worked out on macOS with OrbStack, an Android
phone over USB, and an iPhone over USB.

Simulators and emulators are fine for layout, but not for media:

- The iOS simulator's microphone fails to start (`AudioProcessingException`),
  so it can't join a session.
- The Android emulator has no hardware video encoders. The app asks for H.265
  and falls back to software VP8, which LiveKit never forwards, so other
  participants don't see its camera. Real phones publish H.265 fine.

## The server

`totem-server` runs in Docker (OrbStack) and is reachable on the Mac at
`http://localhost:8000` and `https://totem.local`. The commands below that use
`$TOTEM_SERVER` mean the directory of your `totem-server` checkout. Login PINs
aren't emailed; the server logs them:

```sh
docker logs --since 5m totem_local_django 2>&1 | rg "Sending PIN email to"
```

Which address each client uses:

| Client | Address | Why |
|---|---|---|
| Desktop browsers | `https://totem.local` | The Mac already resolves it and trusts OrbStack's certificate |
| iPhone app | `http://<mac-lan-ip>:8000` | OrbStack publishes ports on the LAN by default |
| iPhone Safari | `https://totem.local` | Camera and microphone need HTTPS, so through the Mac once the iPhone trusts OrbStack's CA ([below](#safari)) |
| Android app and Chrome | `http://localhost` over `adb reverse` | Needs no certificate, DNS or LAN exposure, and `localhost` is a secure context |

Android stays on `localhost` because `adb reverse` forwards ports, not names,
and `totem.local` would need both mDNS on the LAN, which Android resolves
unevenly, and a user-installed CA, which apps don't trust by default.

### Serving this checkout's web app

The server proxies `/room/` to a Flutter web build. To serve this checkout's
build, start the server with this override:

```yaml
# room-local.yml
services:
  django:
    ports:
      - "80:8000"
    environment:
      ROOM_APP_PROXY_BASE_URL: http://host.docker.internal:5173
      ROOM_APP_PROXY_BROWSER_HOST: localhost:5173
```

```sh
cd "$TOTEM_SERVER"
docker compose -f local.yml -f /path/to/room-local.yml up -d django
```

The port 80 mapping is for Android Chrome. The web app builds its API base
from the page's scheme and host and drops the port, so a page on
`localhost:8000` would call `localhost`. Pages on `https://totem.local` use the
default port and don't need it.

Build the web app with a same-origin asset base, so one build works from
`totem.local` and `localhost`, then serve it:

```sh
WEB_ASSET_BASE=/room/ dart scripts/web_build.dart
dart scripts/serve_web.dart 5173 packages/totem_web/build/web
```

`scripts/web_build.dart` reads `packages/totem_web/.env`, so set
`API_URL=http://localhost` there first. Running it directly rather than through
`make build-web-release` keeps that edit, since the make target regenerates
`.env`. `serve_web` serves the directory live, so a rebuild needs only a
reload.

### A session to join

Joining needs the user to be an attendee and inside the join window: from 15
minutes before the start (60 for staff or users who already joined) until a
grace period after it. Once a session has started, other users get "already
started"; adding them to `joined` widens their window.

Create the session in the Django admin, then, for each test account:

```sh
cd "$TOTEM_SERVER"
docker compose -f local.yml exec -T django /entrypoint python manage.py shell -c "
from django.contrib.auth import get_user_model
from django.utils import timezone
from totem.spaces.models import Session
s = Session.objects.get(slug='SLUG')
users = list(get_user_model().objects.filter(email__in=['participant01@example.com']))
s.attendees.add(*users)
s.joined.add(*users)
# To reopen the join window: Session.objects.filter(pk=s.pk).update(start=timezone.now())
"
```

Delete test sessions with `Session.objects.filter(...).delete()`.
`Session.delete()` calls the real Google Calendar API if the server
is configured to do so.

Each device needs its own account: joining as a user who is already in the
call asks to move the call to the new device.

### Inspecting the LiveKit room

The server talks to LiveKit Cloud. A read-only listing of participants and
their tracks (codec, simulcast layers, mute state) answers "is this device
actually publishing" without looking at any screen. Reading the keys from the
container keeps them out of files and logs:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["livekit-api"]
# ///
import asyncio, subprocess, sys
from livekit import api

def env(name):
    return subprocess.run(["docker", "exec", "totem_local_django", "printenv", name],
                          capture_output=True, text=True, check=True).stdout.strip()

async def main(room):
    lk = api.LiveKitAPI(env("LIVEKIT_URL").replace("wss://", "https://"),
                        env("LIVEKIT_API_KEY"), env("LIVEKIT_API_SECRET"))
    try:
        res = await lk.room.list_participants(api.ListParticipantsRequest(room=room))
        for p in res.participants:
            print(p.identity, p.name)
            for t in p.tracks:
                print("   ", api.TrackSource.Name(t.source), "muted" if t.muted else "live",
                      t.mime_type, [c.mime_type for c in t.codecs])
    finally:
        await lk.aclose()

asyncio.run(main(sys.argv[1]))  # the room name is the session slug
```

## Desktop browsers

Open `https://totem.local/room/SLUG`. `http://localhost/room/SLUG` also works,
since `localhost` is a secure context, but each host has its own login. A LAN
address over plain HTTP doesn't get camera or microphone.

An agent can drive Chrome through Chrome extensions. To check
media rather than pixels, hook `RTCPeerConnection` before joining, then read
`getStats()`:

```js
window.__pcs = new Set();
const Orig = window.RTCPeerConnection;
window.RTCPeerConnection = new Proxy(Orig, {
  construct(t, a, nt) { const pc = Reflect.construct(t, a, nt); window.__pcs.add(pc); return pc; },
});
```

Inbound `framesDecoded` and `bytesReceived` sampled a few seconds apart show
whether each participant's video is flowing, frozen, or absent, and
`totalAudioEnergy` does the same for audio. The hook lasts until the next
reload.

## Android

### App

USB plus `adb reverse` gives the phone's `localhost` a tunnel, so
nothing is exposed on the network and the same build works on the emulator and
the phone:

```sh
adb reverse tcp:8000 tcp:8000
```

Set `API_URL=http://localhost:8000` in `packages/totem_app/.env`, then:

```sh
cd packages/totem_app
flutter build apk --debug --flavor production
adb install -r build/app/outputs/flutter-apk/app-production-debug.apk
```

A store install of `org.totem.app` has a different signature, so the debug
build only installs after `adb uninstall org.totem.app`, which wipes its data.

### Chrome

```sh
adb reverse tcp:80 tcp:80
```

Then open `http://localhost/room/SLUG` in Chrome on the phone. Chrome labels it
"not secure", but `localhost` still gets camera and microphone.

### Agent control

Everything goes through `adb` (set `ANDROID_SERIAL` when several devices are
attached):

| Need | Command |
|---|---|
| Screen contents | `adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml`, then read `text`, `content-desc` and `bounds` |
| Tap, type, swipe | `adb shell input tap X Y`, `input text 'hello'`, `input swipe X1 Y1 X2 Y2 600` |
| Screenshot | `adb exec-out screencap -p > shot.png` |
| Launch | `adb shell monkey -p org.totem.app -c android.intent.category.LAUNCHER 1` |
| Open a URL in Chrome | `adb shell am start -a android.intent.action.VIEW -d URL com.android.chrome` |
| Foreground app | `adb shell dumpsys activity activities \| rg topResumedActivity` |
| Permission flags | `adb shell dumpsys package org.totem.app \| rg "CAMERA:\|RECORD_AUDIO:"` |
| Reset to never asked | `pm revoke org.totem.app android.permission.CAMERA` then `pm clear-permission-flags org.totem.app android.permission.CAMERA user-set user-fixed` |
| Privacy toggles | `adb shell cmd sensor_privacy enable 0 camera` (or `microphone`, `disable`) |
| Crashes | `adb logcat -d -b crash` |

Things that trip an agent up:

- `pm revoke` alone leaves `USER_SET`, so the next prompt counts as a second
  refusal and Android stops asking. Clear the flags too.
- Revoking a permission ends the app, as on a real device.
- Matching a node by a text fragment can hit a label instead of a button
  ("Tap Open Settings." versus "Open Settings"); prefer exact text or bounds.
- Text fields often have no label, so find the `android.widget.EditText` in
  the dump and tap the center of its bounds.
- `KEYCODE_BACK` to close the keyboard can leave the app; submit with
  `KEYCODE_ENTER` instead.
- Foldables have one display per screen, and `screencap` without `-d` prints a
  warning instead of an image. Take the ID of the display that's on from
  `dumpsys display` (`uniqueId="local:ID"` with `state ON`) and pass `-d ID`.
- The session room screen is capture-protected, so screenshots of it are
  black. Use the UI dump, the LiveKit listing, or the far end's stats.
- Flutter web in Chrome draws to a canvas, so the dump shows only "Enable
  accessibility"; use screenshots there.
- Slide-to-join needs `input swipe` across the handle, not a tap.

## iOS

The iPhone can't use `adb reverse`, so it reaches the server over the LAN.

### App

OrbStack's **Expose ports to LAN** setting (`docker.expose_ports_to_lan`, on by
default) publishes the server on the Mac's LAN address. Set
`API_URL=http://<mac-lan-ip>:8000` in `packages/totem_app/.env`
(`ipconfig getifaddr en0` gives the address). iOS asks for local network
access on the first request; allow it.

If that setting is off (`orb config show`), turn it on with
`orb config set docker.expose_ports_to_lan true`, or forward the port with the
forwarder from [Safari](#safari):

```sh
uv run lan_forward.py $(ipconfig getifaddr en0) 8000 127.0.0.1 8000
```

`flutter build ios --profile` fails on signing (the profile configurations
sign manually). Generate the config, then build with automatic signing:

```sh
cd packages/totem_app
flutter build ios --profile --flavor production --config-only
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme production \
  -configuration Profile-production -destination 'generic/platform=iOS' \
  -derivedDataPath ../build/ios_dd CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=LNLXP4VK97 \
  PROVISIONING_PROFILE_SPECIFIER= build
xcrun devicectl device install app --device UDID \
  ../build/ios_dd/Build/Products/Profile-production-iphoneos/Runner.app
```

Use a profile build: a debug build can't be relaunched from the home screen
without a debugger attached. `xcrun devicectl list devices` gives the UDID.

Installing over an existing install keeps its camera, microphone and
notification grants. To test from a first run, `xcrun devicectl device
uninstall app --device UDID org.totem.ios` first. The keychain survives
uninstalling, so the old login may come back.

Changing camera or microphone access in Settings ends the app on iOS 27,
granting as well as revoking.

### Safari

Safari needs HTTPS for camera and microphone off `localhost`. OrbStack serves
`https://totem.local` with a certificate from its own root CA, but its
container domains and HTTPS are only for the Mac: OrbStack terminates TLS in
its own proxy, so publishing port 443 wouldn't carry that certificate. The
iPhone needs to trust the CA, to resolve `totem.local` to the Mac, and to
reach OrbStack's proxy through the Mac.

The forwarding uses a small TCP forwarder:

```python
# /// script
# requires-python = ">=3.11"
# ///
"""uv run lan_forward.py LISTEN_HOST LISTEN_PORT TO_HOST TO_PORT"""
import asyncio, sys

async def pipe(reader, writer):
    try:
        while data := await reader.read(65536):
            writer.write(data)
            await writer.drain()
    except ConnectionError:
        pass
    finally:
        writer.close()

async def main(host, port, to_host, to_port):
    async def handle(cr, cw):
        try:
            sr, sw = await asyncio.open_connection(to_host, to_port)
        except OSError:
            cw.close()
            return
        await asyncio.gather(pipe(cr, sw), pipe(sr, cw))
    async with await asyncio.start_server(handle, host, port) as server:
        await server.serve_forever()

asyncio.run(main(sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4])))
```

1. Export the CA and serve it on the LAN:

   ```sh
   security find-certificate -c "OrbStack Development Root CA" -p \
     /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db \
     | awk '/BEGIN/{n++} n==1' > orbstack-root-ca.pem
   openssl x509 -in orbstack-root-ca.pem -outform der -out orbstack-root-ca.cer
   python3 -m http.server 8081 --bind $(ipconfig getifaddr en0)
   ```

   On the iPhone, open `http://<mac-lan-ip>:8081/orbstack-root-ca.cer`, then
   install it in Settings → General → VPN & Device Management, and turn on
   full trust in Settings → General → About → Certificate Trust Settings.
   Remove it when you're done.

2. Answer mDNS for `totem.local` with the Mac's LAN address. OrbStack already
   registers the name on its own bridge interface, so `dns-sd -P` reports a
   conflict. A separate responder bound to the LAN interface doesn't:

   ```python
   # /// script
   # requires-python = ">=3.11"
   # dependencies = ["zeroconf"]
   # ///
   """uv run mdns_totem.py MAC_LAN_IP"""
   import socket, sys, time
   from zeroconf import IPVersion, ServiceInfo, Zeroconf

   ip = sys.argv[1]
   zc = Zeroconf(interfaces=[ip], ip_version=IPVersion.V4Only)
   info = ServiceInfo("_https._tcp.local.", "totem-dev._https._tcp.local.",
                      addresses=[socket.inet_aton(ip)], port=443, server="totem.local.")
   zc.register_service(info, allow_name_change=True)
   try:
       while True:
           time.sleep(3600)
   finally:
       zc.unregister_service(info)
       zc.close()
   ```

3. Forward port 443 to OrbStack, passing TLS through so its certificate is
   what the phone sees. macOS lets an unprivileged process bind a low port
   only on the wildcard address:

   ```sh
   dscacheutil -q host -a name totem.local   # OrbStack's address for totem.local
   uv run lan_forward.py 0.0.0.0 443 <that-address> 443
   ```

Then open `https://totem.local/room/SLUG`. The web app calls the API on the
page's own origin, so nothing else changes.

### Agent control

`devicectl` covers everything except touch:

| Need | Command |
|---|---|
| Screenshot | `xcrun devicectl device capture screenshot --device UDID --destination shot.png` |
| Launch with logs | `xcrun devicectl device process launch --device UDID --terminate-existing --console org.totem.ios` (keep it running; it exits when the app does) |
| Install, uninstall | `xcrun devicectl device install app ...`, `... uninstall app ...` |

Touch goes through Apple's CoreDevice HID service with `pymobiledevice3`. It
needs a device tunnel running as root, which a person has to start:

```sh
sudo uvx pymobiledevice3 remote tunneld
```

Then each gesture runs in a session that waits for the media stream first; a
bare `tap` exits 0 but is dropped before the stream is up. Coordinates are
0–65535 across the screen, so scale from screenshot pixels:

```sh
printf 'sleep 1.5\ntap %d %d\nsleep 0.5\n' $((X * 65535 / WIDTH)) $((Y * 65535 / HEIGHT)) \
  | uvx pymobiledevice3 developer core-device universal-hid-service session --tunnel UDID
```

`drag X1 Y1 X2 Y2 STEPS DURATION` works the same way. `get-display-info`
gives the screen size.

Limits:

- There's no UI tree, so taps come from screenshots.
- Touch is refused while a call is in progress (`code 9022`), and a live Totem
  microphone counts. An agent can drive the priming sheet, Settings and the
  home screen, but a person has to tap while the microphone is live.
  Screenshots still work then.
- The session room screen is capture-protected, so screenshots of it are
  black.
- Xcode's MCP device tools only accept a device on exactly the SDK's iOS
  version (for example an iOS 27.0.1 phone with the 27.1 SDK is rejected),
  and list only simulators otherwise.

## Cleaning up

- Restore the `.env` files: `dart scripts/setup_env.dart development`, then
  rebuild the web app with the default asset base.
- Stop the forwarders, the mDNS responder, the CA file server and
  `serve_web`.
- Restart the server without the override, from `$TOTEM_SERVER`:
  `docker compose -f local.yml up -d --force-recreate django`.
- Remove the tunnels: `adb reverse --remove-all`.
- Stop `tunneld`.
- Remove the OrbStack CA from the iPhone.
- Delete test sessions with a queryset delete.
- Reinstall the store apps on the phones if they were replaced.
