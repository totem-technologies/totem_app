# Permissions

How Totem behaves around camera, microphone, notification and background
permissions on iOS, Android and web (Chrome, Edge, Firefox, Safari, iOS WebKit
browsers).

This document describes outcomes. How they're built is in
`packages/totem_core/lib/features/permissions/README.md`.

Every corner case below has an ID. Tests that cover a case start their name
with the ID, alone or paired (`A1/A3:`), so `rg "A2[:/]"` finds the coverage
for any row.

## Policy

- **Joining needs microphone permission, not an open microphone.** Without
  permission, or while the microphone isn't working, Join is disabled and the
  screen shows how to fix it. A user who turns their microphone off in the
  preview still joins, muted.
- **The camera is optional.** Users can join with the camera refused,
  missing or broken, and turn it on at any point in the session.
- **Permissions can change at any time.** Before and during a session, both
  devices behave the same way:
  - Turning a device on asks for permission where the platform can still ask.
  - When the platform won't ask again, the user is shown how to fix it for
    their platform and browser.
  - A device that stops on its own mid-call (permission revoked, device
    unplugged) shows as off with a warning, and the user is told, with a way
    to fix it, wherever the platform reports it (X13).
- **Nothing turns on by itself in a session.** After fixing a device in
  Settings or the browser, the user turns it on again. Before joining, the
  preview is the exception: a device waiting for permission, or refused for
  lack of it, starts as soon as permission is granted, unless the user turned
  it off.
- **On iOS and Android the system prompt only follows a user action.** A
  priming screen explains why first.
- **On web the browser prompt appears when the preview starts**, since
  starting the camera or microphone is how a browser asks.
- **What actually happens beats what the platform claims.** Platforms report
  permission inaccurately in several cases (A2, A5, WF3, WS1). If a device
  works, it's treated as allowed; if it fails, the user sees the real reason.
- **Notifications never block joining**, and are asked for once, at app start,
  never during a session.
- **No battery-optimization exemption.** Totem isn't meant to run in the
  background. On Android a foreground service keeps the microphone working
  through brief app switches during a session; it starts on every join and
  needs no permission beyond the microphone.

## What the user can be told

Each device is in one situation at a time. A refusal takes precedence over a
device problem, so a device stopped by a revoked permission shows how to allow
it again rather than how to reconnect it.

| Situation | What the user sees |
|---|---|
| Never asked, or the prompt was dismissed | An "Allow" action that asks again |
| Refused, may ask again (Android, first refusal) | An "Allow" action that asks again |
| Refused for good (iOS, Android's second refusal) | "Open Settings", with steps for the platform |
| Blocked by the browser's site settings | Steps for that browser, then reload |
| The OS blocks the browser itself | Steps for the OS privacy settings, naming the browser |
| Restricted by Screen Time or device management | An explanation; nothing to fix here |
| Allowed, but the device is busy | "Busy", close the other app or tab, try again |
| Allowed, but there's no device | "No device found", connect one, try again |
| Allowed, but it failed for an unknown reason | "Didn't start", try again |
| It was working and stopped | "Stopped", check it's connected, try again |
| Can't capture here (insecure page, in-app browser) | Open in a real browser (with a copy-link action), or an explanation |

## Corner cases

Status column: **Done** handled, with tests named by ID where the behaviour can
run off-device; **OK** needed no change; **Open** not handled yet; **VERIFY**
needs a device test before the behaviour is trusted.

### Cross-platform (X)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| X1 | Returning user, permissions already granted, session data loads slowly | Join enables once loading completes | Done |
| X2 | First-time user on iOS/Android | Priming screen first; the system prompt only after the user taps; the preview doesn't start a device before it's allowed | Done |
| X3 | Allows the mic, refuses the camera | Can join with the camera off; the camera control flags it | Done |
| X4 | Refuses the mic, or the mic fails to start | Can't join; the fix is shown | Done |
| X5 | Fixes a permission in Settings and returns | The app notices on return; the preview starts the device | Done |
| X6 | Turns the camera on mid-session, never asked | System prompt, then the camera turns on | Done |
| X7 | Turns the camera on mid-session after refusing | The fix is shown; the control is flagged | Done |
| X8 | Revokes a permission in Settings during a session | The OS ends the app (iOS and Android); on relaunch, X3/X4 apply | OK; Open: make sure the termination isn't reported as a crash |
| X9 | Device in use by another app | "Busy" with a retry | Done |
| X10 | No device (simulator camera, some desktops) | A missing camera still joins; a missing mic blocks joining (X4) | Done |
| X11 | Prompt dismissed without answering | Can ask again, and isn't asked again on its own | Done |
| X12 | Permission changes while pre-join is open (another tab, Settings, browser UI) | Join and the preview follow the new state; a device refused for lack of permission starts once allowed | Done |
| X13 | Microphone or camera revoked or reset mid-call, or unplugged | Native, revoked: the OS ends the app (X8). Native, unplugged: not detected, since the native WebRTC plugin never reports a capture ending. Web: the device shows off and flagged, the user is told ("Your microphone stopped"), and turning it on shows the fix | Done; VERIFY which browsers end capture rather than mute it (WS3) |
| X14 | Turns a device on while the room's connection is down | The user is told it couldn't turn on and to try again once connected; it isn't treated as a permission or device problem. Unmuting a microphone already published works without a connection | Done; VERIFY on a real reconnect |
| X15 | The connection fully restarts mid-call | LiveKit briefly reports every other participant as gone, so the keeper reads as away: the microphone may be muted and the keeper-left notice shown | Open: session behaviour, outside this module |
| X16 | Picks another camera mid-call and it fails to open | The camera stays as it was | Open: LiveKit swallows the failure, so the user isn't told. Session behaviour, outside this module |
| X17 | Joins with the camera on and no preview camera (such as a rejoin), and the room can't take the track | The join fails and can be retried | Open: LiveKit may leave that camera capturing until the session ends. Session behaviour, outside this module |

### iOS (I)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| I1 | The permission API reports never-asked the same way as refused | Treated as never asked: the user is asked | Done |
| I2 | User refused | "Open Settings" | Done |
| I3 | Restricted by Screen Time or MDM | Explained as managed by device restrictions | Done |
| I4 | Changing a permission in Settings ends the app on iOS 27, granting as well as revoking | Relaunch shows the session to rejoin; pre-join starts the newly allowed device (X5); nothing to do on revoke (X8) | Done |
| I5 | App backgrounded mid-session | The camera pauses (no `voip` background mode); the mic continues. The camera resumes on return. The track stays published, so others see a frozen frame | Done |
| I6 | iPad Split View / Slide Over / Stage Manager | The camera is interrupted; tell the user it's paused while multitasking. iPadOS 16+ can allow multitasking camera access | Open, VERIFY |
| I7 | Phone call or Siri interrupts the mic | Treated as an interruption, not a permission change; the mic resumes when the app is active again | Done |
| I8 | The system prompt appears over the app | Returning from the prompt doesn't confuse the outcome; the device starts once | Done |
| I9 | Missing `NS*UsageDescription` | The OS ends the app on capture. The keys are present | OK; keep the keys |
| I10 | `permission_handler_apple` under Swift Package Manager derives its permission support from `Info.plist` at build time | All builds go through `flutter build`, which includes camera and microphone support | OK |

### Android (A)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| A1 | First refusal | Can ask again | Done |
| A2 | Second refusal (Android 11+) | The system stops prompting and its status still says "may ask". The app offers Settings instead of a prompt that never shows. After a relaunch the first request returns refused without a prompt, so a refusal on Android always explains how to allow it in Settings, including a second refusal just made. Choosing "Ask every time" in Settings doesn't change the status the app can read, so turning a device on always asks first: a refusal still in place returns at once and is explained | Done |
| A3 | Back or tap-outside on the dialog | Same as a first refusal: can ask again. The OS records nothing, so it isn't reported as a permanent refusal | Done |
| A4 | "Only this time" grant, app backgrounded mid-session | Any running foreground service keeps a one-time grant, so ours keeps the camera's too. The service has no camera type, so the camera stops capturing in the background and others see a frozen frame; it resumes on return | Done |
| A5 | Quick Settings camera/mic privacy toggle off (Android 12+) | The permission reads allowed, but capture gives black frames or silence; the system shows an unblock dialog. Not detectable | Open: mention in help copy |
| A6 | Android 14: microphone foreground service | Needs microphone permission while the app is visible; joining guarantees both | OK |
| A7 | Permissions auto-reset for unused apps | Rechecked on every launch and return | Done |
| A8 | Revoking in Settings | The OS ends the app (X8) | OK |
| A9 | Camera in use by another app / multi-window | Before capture: "Didn't start" with a retry. Taken mid-session: the plugin reopens the camera on return and the UI never shows a problem | Done; VERIFY the platform's error text before capture |
| A10 | Android 13+ notification permission | Separate; see N rows | OK |

### Web, all browsers (W)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| W1 | Insecure context (plain HTTP, LAN IP in dev) | "Can't use the camera or microphone here" | Done |
| W2 | Embedded without `allow="camera; microphone"` | Looks like a refusal. Not embedded today | OK; note for embedders |
| W3 | Browsers report failures differently | See [Browser errors](#browser-errors) | Done |
| W4 | The browser's permission status is unreliable (missing in Firefox < 132, stale in Safari, per-device in Firefox) | Never trusted over what capture shows; rechecked on return to the tab and on browser change events | Done |
| W5 | Device list before a grant | Default devices with empty labels; the device picker must refresh after the first grant | Done |
| W6 | Hidden or unfocused tab | The camera waits for the tab to be visible, then starts | OK |
| W7 | Private / Incognito | Nothing persists; every visit is a first visit | OK |
| W8 | Chrome / Firefox on Android: the OS refused the browser app | The site looks allowed but capture is refused; the steps mention Android's app settings for the browser | Done |
| W9 | Device unplugged or permission revoked | The device shows stopped; before joining a stopped mic blocks Join; in the session see X13 | Done |

### Chrome and Edge (WC)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| WC1 | One-time grant ("Allow this time") expires (tab close, navigation, 16 h, 5 min in the background while not capturing) | Treated as never asked | Done |
| WC2 | Prompt dismissed | Can ask again and isn't re-prompted on its own. Repeated dismissals make Chrome block the prompt for a while (believed 3 dismissals / 7 days, unverified), which then looks like a block | Done |
| WC3 | macOS blocks Chrome | Steps for macOS System Settings, not site settings | Done |
| WC4 | Windows: device in use, or the OS privacy block | Chrome can't tell them apart: "Busy", with a note about Windows privacy settings | Done |
| WC5 | Safety Check auto-revokes unused site permissions | Rechecked every time | OK |
| WC6 | Edge reports an OS block as a site block | The steps should mention both | Open: only site settings are covered |

### Firefox (WF)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| WF1 | No permission status before Firefox 132 | Capture decides | Done |
| WF2 | Refused without "Remember this decision" | Blocked until reload; the steps say to reload | Done |
| WF3 | Grants are per device | Switching camera can bring the prompt back even though the status says allowed | Done |
| WF4 | The OS blocks Firefox | Firefox reports it as a missing device; when a device is listed it's treated as an OS block | Done |
| WF5 | Device in use | "Busy" | Done |

### Safari and iOS WebKit browsers (WS)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| WS1 | Grants last only until reload or user navigation; change events are unreliable | Expect a prompt every visit; capture outcomes win over the stale status | Done |
| WS2 | A second capture of the same device mutes the first | Each device is captured once, and the preview hands its capture to the session | Done |
| WS3 | Backgrounding, an interruption or another tab capturing | iOS: switching tabs or backgrounding stops the camera at once, so others see it black; the mic keeps going. macOS Safari keeps capturing in a background tab or a minimised window | Done |
| WS4 | Overlapping capture requests on a cold start | Captures never overlap | OK |
| WS5 | All iOS browsers are WebKit; in-app browsers (Instagram, TikTok, Gmail, SFSafariViewController) may refuse silently | In-app browsers that identify themselves are detected; a refusal there suggests opening the page in Safari, with copy link. SFSafariViewController identifies as Safari and can't be told apart, so it gets Safari's help | Done; VERIFY per app |
| WS6 | iOS 17.4 paused capture on navigation (fixed later) | Avoid navigating while capturing on old iOS | VERIFY |
| WS7 | A lasting refusal: macOS Safari's prompt has "Never for This Website"; iOS Safari's prompt has none, and the only lasting refusal is in Safari's settings, for every site | Rare, mostly technical users; the same steps fix it | OK |
| WS8 | iOS Safari's address-bar control stops the camera or microphone outside the app | The control can still show the microphone on while nothing is sent; turning it off and on fixes it | Open: watch the media track's mute events so the control follows |

### Notifications and background (N)

| ID | Scenario | Expected outcome | Status |
|---|---|---|---|
| N1 | Notification permission | Asked once, at app start; never during a session | Done |
| N2 | Battery-optimization exemption | Never asked | Done |
| N3 | Notifications refused | Never blocks joining | Done |
| N4 | iOS provisional notification authorization | Decide whether provisional counts as allowed anywhere it's shown | VERIFY |
| N5 | Android: notifications refused | The foreground service still runs (its notification is hidden), so the mic keeps working through app switches | Done |

### Browser errors

| Error | Chrome / Edge | Firefox | Safari | User sees |
|---|---|---|---|---|
| `NotAllowedError` "Permission denied" | Site blocked (Edge: also an OS block) | Site blocked, temporary or remembered | Site blocked | Browser site settings steps |
| `NotAllowedError` "Permission dismissed" | Prompt dismissed | — | — | "Allow" again |
| `NotAllowedError` "Permission denied by system" | macOS blocks the browser | — | — | OS privacy steps |
| `NotAllowedError` in an in-app browser | — | — | — | Open in a real browser |
| `NotFoundError` | No device | No device, **or** the OS blocks Firefox (WF4) | No device | "No device found", or OS privacy steps for Firefox with a listed device |
| `NotReadableError` | Busy, or a Windows privacy block | The OS blocks Firefox | Hardware error | "Busy" (Firefox: OS privacy steps) |
| `AbortError` | — | Busy | — | "Busy" |
| `OverconstrainedError` | The selected device is gone | same | same | "No device found" |
| `SecurityError`, or no `navigator.mediaDevices` | Insecure page or policy | same | same | "Can't use it here" |
| Anything else | | | | "Didn't start", reported as a bug |

## Auditability

All permission behaviour lives in one module, and an automated test fails if
platform permission APIs, notification prompts, battery-optimization APIs or
browser sniffing are used anywhere else. Totem's web build never includes
Firebase.

## Device test matrix

Rows marked VERIFY need a manual pass before their behaviour is relied on:
A3, A4 (highest risk), A9, I5, I6, I7, W5, WS3, WS5, WS6, X13, X14, N4.

Unverified facts carried in this document: Chrome's dismissal embargo numbers
(WC2), Safari's change event reliability (WS1), and in-app browser behaviour
per vendor (WS5).
