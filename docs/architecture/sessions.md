# Sessions architecture contract

## Admission authority and rollout status

The Flutter admission implementation is **server-only**: Django owns policy, requests,
queue, decisions, durable membership and activation records. LiveKit enforces
connection permissions as reconciled by the server. The client presents
server-derived state and sends authenticated commands; local presence, tokens,
metadata, packets or client storage are not admission authority. There must be no
hidden client enforcement toggle, fallback to cooperative admission, or second
client-owned admission implementation. A missing admission response, disabled
endpoint, stale state or unavailable server must not silently admit a user.

Keep Django's `SERVER_ENFORCED_ADMISSION` **off** until compatible participant and Keeper
clients, an effective upgrade gate and the server are deployed and validated
together. The flag defaults off; admission endpoints return `404
feature_disabled` while it is off. The flag is a backend deployment control,
not a client setting or a reason to fail open. Follow the server's
`totem/rooms/ADMISSION_ROLLOUT.md` for cutover and rollback, including draining
old rooms and accounting for previously issued tokens.

## Ownership

| Concern | Authority and ownership |
|---|---|
| Admission policy, queue and decisions | Django; the current `Room.keeper` uses authenticated API commands. The admission panel is a presentation of server snapshots, not an owner of decisions. |
| Admission and participation | Django tracks durable admission, attempts, connection confirmation and activation. Approval, connectivity and successful activation are distinct states. |
| Room state and turn order | The backend owns versioned room state and turn order; `SessionStateReducer` maintains a client projection. Presence alone does not authorize participation. |
| Waiting connection | Pre-join owns the connected LiveKit room and preview tracks while `ServerParticipantAdmission` observes the connection and synchronizes with Django. The observer does not own the room. |
| Active connection | After authorization, pre-join transfers the **same room** and preview tracks through a single-claim handoff to `SessionRuntime`. The runtime owns active transport and observer lifetimes and disposes the observer before the room. Approval must not cause a second token request, connection or deliberate disconnect. |
| Capture and publication | Pre-join owns preview capture until transfer; the room media owner and `LocalMedia`/`RoomMedia` adapters own accepted tracks and publication. Preserve Safari track reuse and video rendering safeguards. |
| Session features and presentation | Feature services own chat, reactions, turns and moderation; panels and effects observe state and issue intents. Mounting or dismissing a panel must not create or destroy admission or transport ownership. |

One resource has one owner; derived state is read-only. Session entry and attempt
generations fence stale asynchronous callbacks. Joining is single-flight, cleanup
is serialized and idempotent, and normal leave awaits resource release. Provider
scope and screen lifetime alone do not prove a LiveKit resource has been released.

## Admission flow and recovery

The client creates request and attempt IDs, requests admission and obtains a
`/join` token using those IDs, then connects once. It confirms the connected
attempt with Django. Waiting permissions restrict media publication and
subscription, data sends and attribute updates; presence is not approval.
After a server decision and effective LiveKit permissions, the same room and
preview tracks are handed off. After local activation succeeds, the client sends
an activation receipt. Neither a token nor waiting presence records successful
activation or makes a user eligible for turns.

On reconnection, refresh authenticated server state and confirm a pending or
granting attempt again. If the SID changes after activation, create fresh
request and attempt IDs and confirm the returning attempt against the existing
reconnected room; do not reconnect solely for admission. Events, including
`totem.admission.v2` notifications and permission changes, are refresh hints,
not decisions. Fetch snapshots on attachment, reconnect, relevant events and
after commands; use bounded retries on transient failures. Do not infer approval
from presence or an event, or run a permanent short-interval polling loop.

The Keeper's **Require approval to join** setting is Django's per-Session
`approval_required` policy, changed through the settings API by the current
Keeper, not a local enforcement toggle. Turning it off processes eligible
pending requests and auto-approves eligible newcomers; bans, permanent
exclusions and explicit reapproval requirements still apply. Turning it on
does not revoke prior approvals. The server's current Keeper authorization and
version checks apply even when clients reconnect or the Keeper changes.

See [the admission README](../../packages/totem_core/lib/features/sessions/admission/README.md)
for endpoint and command details, and `totem/rooms/ADMISSION_API.md` in the
server repository for the complete contract.

## Security boundary and validation

Fail closed in the client when authoritative admission or required permissions
cannot be verified; do not activate, publish, or grant access based on a local
fallback. This is not a claim that all private data is protected. Waiting
connections can receive LiveKit broadcasts even when they cannot subscribe to
media. Client-side targeting of chat or reactions is only a best-effort
mitigation: stale, old or modified clients can broadcast. Old/full-permission
tokens and existing connections are not instantly revoked by a flag change;
LiveKit outages, token replay and identity-addressed permission races also limit
revocation. Verify behavior on the deployed LiveKit configuration rather than
assuming immediate invalidation or confidentiality.

Before enabling enforcement, validate the full Keeper and participant workflows,
reconnection and replacement SIDs, partial failures, outage recovery, capacity,
security controls and rollback using real LiveKit users, including Safari. The
server rollout checklist requires at least four users; mocked transport tests do
not establish real-device behavior or a confidentiality guarantee.
