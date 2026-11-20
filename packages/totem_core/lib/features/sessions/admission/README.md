# Session admission

## Authority and deployment

The Flutter admission implementation is server-only. Django owns Session policy,
requests, decisions, membership and activation; LiveKit permissions are applied
by server reconciliation. Clients display authenticated snapshots and send
commands, not independent decisions. Do not add a hidden client enforcement
toggle or fall back to a local roster, journal or cooperative protocol when the
server response is missing, disabled, stale or unavailable. Fail closed: do not
activate or publish without verified admission and effective permissions.

Keep `SERVER_ENFORCED_ADMISSION` **off** until the server and compatible Keeper and
participant clients are deployed together, an effective upgrade gate is in
place, and rollout checks pass. The Django flag defaults off and admission
endpoints return `404 feature_disabled` while off; it is not a client toggle.
Existing client-local approvals are not imported. Drain legacy rooms and account
for old tokens before cutover; follow `totem/rooms/ADMISSION_ROLLOUT.md` in the
server repository for deployment and rollback.

## Connection and reconnection

1. Generate request and attempt UUIDs. Persist a request with
   `POST /admission/request`, or supply the same IDs to `POST /join`.
2. Obtain a token via `/join` with those IDs and connect once. Pre-join owns the
   waiting room and preview tracks; `ServerParticipantAdmission` observes the
   connection but does not own it. Confirm presence using `/admission/request`
   with `connected: true` and the same IDs. Presence does not mean approval.
3. Fetch `/admission/me` after relevant notifications or permission changes.
   Wait for the authoritative decision and effective LiveKit permissions.
   Transfer the **same connected room**, observer and preview tracks to
   `SessionRuntime`; do not request another token or reconnect for approval.
4. After successful local activation, send `/admission/activated` with the
   current attempt version. Waiting, approval and activation are separate;
   neither a token nor signaling presence records attendance or turn eligibility.
   The Keeper follows the same confirmation and activation sequence without
   waiting for manual approval. Runtime owns the adopted room and disposes the
   observer before the room.

On reconnect, fetch the authoritative snapshot and reconfirm a pending/granting
attempt with its existing IDs. A changed SID after activation requires fresh
request and attempt IDs, confirmed on the existing reconnected room; durable
admission makes it a returning request. A temporary decline is terminal for its
IDs; a new intentional request needs new IDs. A missing participant or failed
confirmation is not approval. Notifications on `totem.admission.v2`, SDK events
and metadata are refresh hints only. Fetch on attachment, reconnect, relevant
events and after commands; retry transient failures with bounded backoff instead
of permanent short-interval polling.

## Keeper API and settings

All paths below are relative to `/api/mobile/protected/rooms/{session_slug}`;
use existing JWT authentication or Django session authentication with CSRF on
web. Only the current `Room.keeper` can access the full snapshot and issue
Keeper commands. Identities are authenticated public user slugs, not names or
client-supplied LiveKit attributes.

| Method and path | Purpose |
|---|---|
| `POST /join` | Obtain a connection token, optionally creating the request with its IDs. |
| `POST /admission/request` | Create or confirm the attendee's attempt. |
| `GET /admission/me` | Own admission, effective policy and aggregate counts. |
| `GET /admission` | Keeper snapshot: queue, membership and recent outcomes. |
| `POST /admission/{identity}/approve` | Approve a specific attempt. |
| `POST /admission/{identity}/decline` | Decline an attempt, optionally permanently. |
| `POST /admission/admit-all` | Decide the current captured queue. |
| `PATCH /admission/settings` | Set the Session's `approval_required` policy. |
| `POST /admission/{identity}/allow` | Clear a permanent exclusion; does not admit an old attempt or unban. |
| `POST /admission/{identity}/revoke` | Revoke returning-member privileges. |
| `POST /admission/activated` | Confirm successful local activation. |
| `POST /admission/cancel` | Cancel the owner's attempt without erasing prior durable admission. |

Approval required is a server-side per-Session policy controlled by the current
Keeper, not a hidden enforcement switch. Turning it off processes eligible pending
requests and auto-approves eligible newcomers; turning it on preserves existing
approvals. Bans and permanent exclusions take precedence, and revoked members
require explicit reapproval even with approval off. Ordinary departure retains
returning privileges.

Keeper commands use a new `command_id` for each intentional action and the
relevant snapshot versions. Retry an unknown outcome with the same ID and
identical payload; stale versions or conflicting reuse return 409. Snapshot
`room_version` supplies `expected_room_version`, `settings_revision` supplies
settings `expected_revision`, and participant attempt or admission versions
supply the appropriate `expected_version`. HTTP success acknowledges the
command, not necessarily applied permissions or activation: inspect per-result
errors, `partial_failure` and permission status, then refresh. See the server's
`totem/rooms/ADMISSION_API.md` for complete payloads, authorization, counts,
capacity, errors and retry semantics.

## Security limitations and verification

Waiting connections can receive LiveKit broadcasts even with media subscription
disabled. Targeting chat and reactions from an up-to-date client projection is
best effort, not a server-enforced confidentiality boundary; stale, old or
modified clients can broadcast. Do not claim private data is fully protected.
Old/full-permission tokens and existing connections are not instantly revoked by
a flag change. Token replay, LiveKit outages and identity-addressed permission
races limit revocation; verify the actual deployment's invalidation behavior.

Before enabling the backend flag, verify Keeper and participant flows, enforce
a compatible-client upgrade gate, and run real LiveKit staging tests with at
least four users including Safari. Cover settings, decisions, reconnect and
replacement SID, cancellation, partial permission failures, outages, capacity,
revocation and rollback. Mocked tests do not prove real-device behavior or data
confidentiality. The server rollout checklist contains the authoritative
operational prerequisites and drain procedure.
