# Session reconnect: real-device checks

Run with a Keeper and two separately authenticated participants on independent devices or browser profiles. Record platform, browser, SDK version, timestamps, and observed participant/media state. Do not record tokens or personal data. These checks require a real network and LiveKit service; automated fake-transport tests do not establish media delivery.

1. Admit both participants and verify each participant can hear and see the others. Record existing turn ownership and active camera/microphone indicators.
2. Interrupt one participant's network briefly, restore it, and verify their existing admission and media recover without refreshing or prompting for approval. Confirm the other clients lose and regain that participant's visibility appropriately.
3. Interrupt and restore the Keeper's network, then repeat with both participants interrupted nearly simultaneously. Verify roster and media converge and turn ownership is unchanged.
4. Fully disconnect a participant and attempt re-entry. Confirm the normal admission decision is enforced and only one active connection and one capture per device exist.
5. During recovery, have the Keeper remove a participant. Confirm their access is revoked and is not restored by a late reconnect or roster message.
6. Leave one participant legitimately alone. Confirm the application does not repeatedly reconnect or report the empty room as a connection failure.
7. While recovery is pending, intentionally leave. Confirm the room stays closed and camera and microphone are released; no late callback rejoins it.
8. Repeat relevant scenarios on supported Safari and another supported browser with audio and video; check for duplicate capture, media rendering regressions, or sustained excessive retry activity.

A successful run establishes only the observed device, network, and server conditions; retain logs and repeat after SDK or transport changes.
