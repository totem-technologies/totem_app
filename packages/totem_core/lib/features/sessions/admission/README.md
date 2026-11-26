# Session admission

## Authority and deployment

The Flutter admission implementation is server-only. Django owns Session policy,
requests, decisions, membership and activation; LiveKit permissions are applied
by server reconciliation. Clients display authenticated snapshots and send
commands, not independent decisions. Do not add a hidden client enforcement
toggle or fall back to a local roster, journal or cooperative protocol when the
server response is missing, disabled, stale or unavailable. Fail closed: do not
activate or publish without verified admission and effective permissions.

The server rollout checklist is **NOT READY**. The current Django flag
`SERVER_ENFORCED_ADMISSION` defaults off, and admission endpoints return
`404 feature_disabled` while it is off. Removing the gate and verifying mandatory
enforcement are prerequisites for cutover; the flag is not a client toggle or a
documented rollback mechanism. Compatible Keeper and participant clients, an
effective upgrade gate and the other checklist blockers must be addressed first.
Existing client-local approvals are not imported. Drain legacy rooms and account
for old tokens before cutover; follow `totem/rooms/ADMISSION_ROLLOUT.md` in the
server repository for deployment and rollback.

## Connection and reconnection

1. Fetch `/admission/me` and resume an active attempt's request and attempt IDs,
   or generate new IDs for `/join`. Use the canonical IDs returned by the server.
2. Obtain a token via `/join` with those IDs and connect once. Pre-join owns the
   waiting room and preview tracks; `ServerParticipantAdmission` observes the
   connection but does not own it. Confirm presence using `/admission/request`
   with `connected: true` and the same IDs. Presence does not mean approval.
3. Fetch `/admission/me` after relevant notifications or permission changes.
   Require server readiness `ready_to_activate` or `activated` with no reason,
   confirmation of the current SID and effective local LiveKit permissions.
   Transfer the **same connected room**, observer and preview tracks to
   `SessionRuntime`; do not request another token or reconnect for approval.
4. After successful local activation, send `/admission/activated` with the
   request ID, attempt ID and current attempt version. Pre-join reports joined
   only after the response acknowledges `activated`; pending recovery waits for
   reconfirmation and retries without transferring media again. Waiting, approval
   and activation are separate;
   neither a token nor signaling presence records attendance or turn eligibility.
   The Keeper follows the same confirmation and activation sequence without
   waiting for manual approval. Runtime owns the adopted room and disposes the
   observer before the room.

On reconnect, fetch the authoritative snapshot and reconfirm a pending/granting
attempt with its existing IDs. A changed SID after activation uses a fresh
`/join` operation to obtain canonical request and attempt IDs, confirmed on the
existing reconnected room without another connection; durable
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

Admission snapshots include room state and room version read with admission data
under the server room lock. Admission `version` orders admission changes;
`room_version` orders room state independently, and `observed_at` orders presence
observations when versions are equal. Neither version tracks presence. `/me`
contains the caller's state and readiness, not the Keeper's queue or roster.

Snapshots also include the server's connected, activated recipient projection. The client intersects recipients
with its current transport presence; a missing projection or presence error
fails closed until the next successful refresh. Presence is a point-in-time
observation and is not an atomic guarantee with the room state.

## API generation

Generate from the checked-out local Django mobile OpenAPI schema, not production:
`make generate_api_models`; use `make check_api_models` to compare without
modifying the client. The default server checkout is `../totem-server`; set
`TOTEM_SERVER_DIR` for another checkout. The script uses a one-off Docker Compose
Django container with the server mounted read-only, Python 3 and the project's
locked `degenerate` tool. It includes uncommitted server changes and refuses to
overwrite differing uncommitted generated API changes. Record the server revision
and relevant working-tree changes, and do not edit generated API files by hand.
See the client root README for prerequisites and details.

## Security limitations and verification

Waiting connections can receive LiveKit broadcasts even with media subscription
disabled. Targeting chat and reactions from an up-to-date client projection is
best effort, not a server-enforced confidentiality boundary; stale, old or
modified clients can broadcast. Do not claim private data is fully protected.
Old/full-permission tokens and existing connections are not instantly revoked by
a flag change. Token replay, LiveKit outages and identity-addressed permission
races limit revocation; verify the actual deployment's invalidation behavior.

Before cutover, verify Keeper and participant flows, enforce
a compatible-client upgrade gate, and run real LiveKit staging tests with at
least four users including Safari. Cover settings, decisions, reconnect and
replacement SID, cancellation, partial permission failures, outages, capacity,
revocation and rollback. Mocked tests do not prove real-device behavior or data
confidentiality. The server rollout checklist contains the authoritative
operational prerequisites and drain procedure.
