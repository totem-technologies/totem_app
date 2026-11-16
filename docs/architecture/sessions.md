# Sessions architecture contract

This document describes the target ownership model and records current gaps. It is a migration contract, not a claim that every boundary is implemented. Keep PR #190's `LocalMedia`/`RoomMedia` abstractions, client-side cooperative admission, Safari track reuse, and video rendering safeguards.

## Ownership matrix

| Concern | Authority / canonical owner | Current owner(s) and allowed mutation | Observers, lifetime, persistence |
|---|---|---|---|
| Connection lifecycle | Session connection coordinator; LiveKit is transport truth | `SessionRuntime` alone owns active attempts and transport lifetime; `SessionController` reconciles feature state; the adapter owns SDK resources | Screens observe; connection scoped to one session; never persisted |
| Server room state | Versioned backend room-state stream, reduced into `SessionRoomState` | `SessionStateReducer` is the client projection; only accepted server events mutate it | Controllers/widgets observe projection; reset on connection identity change; no local persistence |
| Turn order, participants | Same canonical server room-state projection | Reducer applies authoritative updates; UI may issue commands, not edit roster/order | Widgets observe; no independent mirrored domain copy |
| Capture | Local device / `LocalMedia` | `PreJoinMediaController` before handoff; room media owner after handoff; no widget capture ownership | Preview/room renderers observe; device scoped then session scoped; release exactly once |
| Publication | LiveKit transport, mediated by `RoomMedia`/adapter | `LiveKitLocalMedia` is the only publication boundary | Session controller and UI observe; release before disconnect |
| Device selection | Local device preferences/provider | `SessionDeviceController` may select; media adapter applies | Controls observe; device lifetime; persistence only where explicit user preference exists |
| Admission decisions | Cooperative client-side admission protocol | Admission controllers and keeper actions mutate decisions; panel is presentation only | Waiting/admitted/declined UI observes; session scoped, recoverable from protocol state; no backend authority implied |
| Admitted roster | Admission protocol projection | `KeeperAdmissionRoster` currently owns a projection; must not become an independent competing room roster | Admission UI observes; reset per session |
| Chat | Messaging service/protocol | `SessionMessagingController` sends and receives; widgets submit intents | Chat UI observes; session lifetime; persistence follows server history contract |
| Reactions | Ephemeral client events | `emojiReactionsProvider`/controller owns transient events | UI observes; expire/clear on session end; not durable |
| Prompts | Client session domain/controller | `SessionPromptsController` mutates prompt state from allowed actions/events | Prompt widgets observe; session scoped |
| Panel visibility | Presentation state | Each active session presentation scope owns its own panel selection/visibility | Widgets only; reset with presentation/session; never server state |
| Timers | Domain-specific timer owner (admission or turn) | Owning controller creates/cancels; widgets render remaining state | Session scoped; cancel on terminal transition; no persistence unless protocol defines it |
| Notifications | Session notification owner | Controllers emit; presentation displays | Do not use widget lifetime as service lifetime; clear/cancel on session end |
| Errors | Operation/connection owner creates typed error state | Controllers translate boundary failures; UI renders/retries via intents | Scoped to operation/session; clear only through defined recovery or reset |

A derived view, selector, or immutable projection is legitimate when it has one upstream authority and cannot independently accept writes. Two writable copies of participants, connection status, room state, or admission state are a defect.

## Dependency and SDK rules

Dependencies point inward: widgets depend on view state and intent interfaces; controllers depend on domain contracts; adapters implement device, backend, and transport boundaries. Screens may not own domain services whose work must survive screen replacement. Riverpod scopes must match the session identity and lifetime; a provider's auto-dispose behavior is not itself proof that a LiveKit resource has been released.

LiveKit SDK types belong in `features/sessions/media/` adapters and narrowly documented transport integration code. Domain controllers should use `LocalMedia`/`RoomMedia` contracts. Existing pre-join capture controller is an explicit temporary exception until Phase 4 completes; do not expand that exception.

## Lifecycle contracts

Connection: `idle -> joining -> connected -> leaving -> ended`; failures enter recoverable `failed` and may retry. Repeated join for the same connection while joining or connected returns/awaits the same operation. `connected` is observable only after required initialization (room listeners, canonical initial state, and media ownership setup) completes. A connection generation/session identity gates every async completion; stale generations cannot publish state into a newer session.

Admission: `waiting -> admitted | declined`; recovery/reconnect reconstructs client state from protocol events. The panel may mount/unmount without starting or stopping admission. Admission is cooperative and remains client-side; it does not guarantee server-side access control.

Pre-join media has one owner at a time. Transfer to the room occurs once after successful join preparation; failed join retains or releases according to the explicit failure path. Release is idempotent. Teardown order: stop accepting intents; invalidate session generation; cancel timers and subscriptions/listeners; release published tracks/capture through media owner; disconnect transport; dispose controllers/providers. Every cleanup step tolerates repetition.

## Enforceable invariants and phase gaps

1. One authoritative owner per resource; projections are read-only. **Gap:** overlapping controller responsibilities; Phases 2–5.
2. One canonical server room-state source; accepted version never rolls back. **Gap:** verify/strengthen reducer and stream contract in Phase 2.
3. Concurrent same-connection joins deduplicate; success waits for required initialization. **Implemented in Phase 5:** runtime single-flight joining waits for initialization and media publication.
4. Pre-join capture transfers exactly once. **Implemented in Phase 5:** pre-join rejects repeated capture claims; `JoinMediaReceipt` tracks only unaccepted tracks and publication decisions.
5. Cleanup is idempotent; stale/disposed sessions cannot mutate newer sessions. **Implemented in Phase 5:** scoped attempt validity, serialized cleanup, and entry-owned infrastructure prevent replacement races.
6. Admission is independent of panel visibility and remains cooperative/client-side. Existing protocol tests cover recovery; preserve and extend in Phase 3.
7. Each active session has isolated presentation state. **Implemented in Phase 3:** presentation and chat UI state depend on the entry scope.
8. Widgets do not own domain services that outlive them. **Implemented for admission in Phase 2:** the runtime retains its lifetime in Phase 5; feature separation continues in Phase 6.
9. Media capture/publication goes through media abstractions, preserving Safari reuse and video safeguards. Existing guard checks capture calls; broaden only with reliable checks in Phase 4.

## Riverpod and lifetime

The session scope is a container for dependencies and presentation projections, not a universal owner. Session identity must key the scope. Providers that own subscriptions/controllers must dispose them; root/navigation ownership must retain a session service when it outlives a route. Generated `@riverpod` providers are preferred. Generated provider code is not an architectural authority; inspect its dependencies and disposal behavior alongside annotations.

## Phases 2–6 issues

- **Phase 2 (implemented):** session-owned admission and roster recovery.
- **Phase 3 (implemented):** entry-scoped presentation and room-owned transient routes.
- **Phase 4 (partially implemented on this branch):** complete the remaining SDK integrations listed below; preserve the runtime ownership boundary.
- **Phase 5 (implemented):** runtime attempts, single-flight joining, lease adoption, coordinated cleanup, and media/polling ownership.
- **Phase 6:** consolidate remaining feature state ownership (messaging, prompts, reactions, timers, notifications, errors), remove obsolete mirrors, and validate teardown end to end.

## Phase 2 admission implementation

`SessionController` retains `SessionAdmissionService` independently of the overlay. Its state listener drives attachment; connection teardown awaits admission detachment before releasing the room. Final provider disposal closes admission and fences late callbacks. Protocol controllers and recovery stores retain their existing formats and client-side semantics. The overlay observes service state and renders recovery stores; it no longer constructs transports, owns protocol subscriptions, or installs a moderation callback.

The service serializes transport replacement and journal writes. Moderation obtains a prepared revocation operation before backend removal, capturing the storage boundary while the session is alive. After backend success, that operation records a local revocation intent before updating admission. If the session has disposed, the intent survives for the next Keeper attachment. Recovery consumes these intents and persists the corrected roster before creating an advertising transport. Successful live revocation clears its intent. Persistence failures keep removal blocked and expose a retry path; backend removal is never described as rolled back or atomic with local storage. Storage failure can prevent durable recording, and is reported explicitly.

Participant visibility is a reactive projection of the service roster, with the existing Keeper fallback. Media permissions are updated from the same roster. Approval settings invoke a service command. The default remains approval required. No backend authorization guarantees are added.

Validation covers the protocol suite, headless admission and transport reuse, media/visibility projection, replacement and disposal callbacks, persistence retry, and a backend completion represented by a prepared revocation after final disposal. Phase 5 must preserve the distinct pending pre-join connection owner until its explicit handoff, retain the session provider across temporary route changes, and avoid introducing a second admission owner during that handoff.

## Phase 3: session presentation ownership

`SessionPresentation` owns immutable `SessionPresentationState`: one `SessionPanel` enum and a revision. Opening a panel atomically replaces the previous selection. Closing can require the expected panel and revision; an older modal completion cannot close a newer selection. The three `session*SelectedProvider` functions are read-only selectors, not separately writable panel flags.

The pre-join screen keys the nested `ProviderScope` by the identity of its join options. The options object is retained during a join and reconnection, while a new join attempt creates a new object, including for the same slug. Presentation, thread-target reconciliation, and unread threads depend explicitly on `sessionScopeProvider` and are retained only in that entry's container. Mounting or resizing the room no longer invalidates them. Persistent self-view preferences remain separate.

`SessionPanels` is the sole in-session route host for Chat, Prompts, and Admission. Entry actions change panel intent; the host chooses the dock, drawer, or phone sheet. Named panel routes, a generation fence, and selection revisions protect route replacement and dismissal. The dock waits for an active overlay to be removed, avoiding duplicate hosts. When the viewport changes presentation tier in either direction (dock, drawer, or phone sheet), the host closes its panels and session-owned popups instead of transferring them. Neither widening nor shrinking reopens a closed panel. Nested dialogs are dismissed with their panel on a tier change; an in-flight prompt mutation defers closure until its owner completes. The existing two-person thread selection, explicit Everyone selection, recipient checks, and coalesced reconciliation remain in `SessionChatThreadTarget`.

`SessionNavigatorScope` directs session-owned dialogs, sheets, and responsive modals to the room navigator, including actions from docked content. Its observer tracks only routes in that navigator. Termination removes those specific transient routes, including covered confirmations; it does not pop parent application routes. Child panel widgets do not own modal cleanup. Standalone Prompts calls retain their explicit non-session fallback.

Domain resources remain outside this presentation state: admission service/protocol, prompt repository/controller, chat messages, backend room state, and media ownership are unchanged. Tests cover atomic selection, stale close revisions, isolated replacement containers, existing chat reconciliation/unread behaviors, room termination with stacked dialogs, and responsive Chat/Prompts/Admission handoff.

## Phase 4 transport migration status: incomplete

`transport/session_transport.dart` defines application-owned connection state,
disconnect reasons, failures with original diagnostic causes, participant and
metadata events, immutable data packets, media access, and transport/factory
interfaces. `media/livekit_session_transport.dart` implements those interfaces
using private SDK room/listener ownership and the existing media adapters.
`ConnectedSessionLease` supports one claim of an existing connected transport;
disposing a consumed lease cannot dispose the claimed transport. The offering
owner is responsible for cancelling its subscriptions before offering it.

Configurable fake transports and factories live under
`test/features/sessions/transport/`. Their controlled connection completion,
publication failures, recorded permissions, and lifecycle counters support
orchestration migration without a LiveKit backend.

Milestone B1 is implemented; Phase 5 delegates ownership to `SessionRuntime`. `SessionController` uses a `SessionTransport`,
created by the generated `sessionTransportFactoryProvider`. The production
factory creates `LiveKitSessionTransport`; preparation, connection, events,
permissions, subscriptions, disconnection, and disposal cross that boundary.
Factory-owned media facades remain stable across connection replacements, so
existing device listeners and video consumers do not acquire a second capture
or media surface. Connection failures are classified with application-owned
failure types. The controller is removed from the direct SDK import allowlist.

`media/session_transport_compatibility.dart` isolates the remaining bridges:

- **B2:** messaging receives its original SDK data event through a weak-keyed
  adapter cache, retaining sender information even if presence changes. The
  controller's read-through `room` getter also supports existing messaging.
- **C1:** pre-join capture options, retained-track publication, and the existing
  SDK-shaped error presentation remain infrastructure integrations. The
  existing state/error consumers are preserved, not migrated in B1.
- **C2:** `activateConnectedRoom` still accepts the existing raw room at the
  pre-join boundary. Phase 5 replaced `LegacyConnectedRoomOffer` with
  `ConnectedSessionLease.deferred`: after prior cleanup, its single claim wraps
  that same room and attaches the stable media facades. No second connection is
  made. The pending flow releases admission listeners before calling this path.
  Remaining SDK migration must replace the raw argument and remove read-through
  access in admission/presentation; it must preserve this ownership mechanism.

Phase 4 remains incomplete until messaging, pre-join, admission, SDK-dependent
state, and connected ownership transfer finish their later milestones. B1 does
not introduce a second production connection path or a new SDK allowlist entry.


## Phase 5: implemented lifecycle ownership

`SessionRuntime` is a focused lifecycle coordinator created by the generated
`SessionController` provider. It owns the active transport, typed event
subscription, admission service lifetime, unaccepted media receipts, device-setup
timer, polling scheduler, operation retention, and cancellation generation.
`SessionController` remains the backend-state reconciliation facade; device,
Keeper, messaging, prompts, and presentation retain their feature state.

```mermaid
flowchart TD
  Preview[PreJoinMediaController: preview capture] -->|one transfer after capture settles| Receipt[JoinMediaOwner: unaccepted tracks]
  Pending[PreJoinFlowController: pending admission connection] -->|cancel pending listeners; offer same room| Lease[ConnectedSessionLease: single claim]
  Lease --> Runtime[SessionRuntime: entry + attempt identity]
  Receipt --> Runtime
  Runtime --> Transport[SessionTransport: one active connection]
  Runtime --> Admission[SessionAdmissionService: protocol and roster]
  Runtime --> Poll[SessionPollScheduler: one sync timer + one poll timer]
  Runtime --> Infra[SessionInfraController: entry-owned foreground service]
  Runtime -->|publication accepted| Media[LocalMedia adapter: published tracks]
  Facade[SessionController: backend state and feature facade] --> Runtime
  UI[Room UI: entry-scoped presentation] --> Facade
```

The runtime has a read-only entry identity. It remains stable during retries and
reconnects, and rotates when joining after a completed leave. A newly constructed
provider has a different identity even for the same slug. Attempt tokens are
separate: each new operation or cleanup invalidates older callbacks. Room metadata
updates use a provider listener and do not rebuild the runtime. If the provider
itself is replaced, the replacement awaits its predecessor's final cleanup before
it may attach the stable media facades. The runtime retains
the Riverpod entry only while a join is in flight; the pre-join listener and room
screen then retain it through normal provider subscriptions. The former imperative
`preventAutoDispose`/`allowAutoDispose` handoff is removed. Provider teardown starts
best-effort asynchronous disposal; normal navigation must await `leave()`.

Admission remains orthogonal to connection state. Before active-room adoption,
`PreJoinFlowPhase.pending` and `AdmissionStatus` describe the waiting connection;
pre-join owns that connection. Approval releases the pending protocol listeners
and offers the connected room. `activating` describes the runtime's single claim,
infrastructure setup, metadata/presence initialization, and local publication.
Declines, expiry, waiting retries, and recovery retain their client-side protocol.

| Current lifecycle | Trigger | Result / completion rule |
|---|---|---|
| idle / reset failure | join | preparing, then connecting |
| preparing / connecting / activating | same-attempt join | await the same final result; discard only newly offered unused media |
| preparing | connected lease | claim once, then activating; never request a token or connect again |
| connecting / activating | initialization and required publication succeed | connected; only now publish connected session state and resolve success |
| connecting / activating | retryable error | recoverableFailure; invalidate attempt; reset or next join awaits cleanup |
| connecting / activating | classified terminal error | terminalFailure; new joins return fatal until explicit reset |
| connected | join for the same active connection | idempotent success |
| connected | transport reconnecting / reconnected | reconnecting / connected; keep entry, listeners, capture, and schedules |
| any live phase | leave / transport teardown | invalidate attempt and stop timers immediately; serialize cleanup; queued join awaits it |
| leaving | another leave | same cleanup Future and outcome |
| leaving | cleanup completed | idle, entry ended; next join receives a fresh entry identity |
| any phase | dispose | terminal disposed; repeated disposal awaits the same Future; new joins are refused |

A different offered connection while joining/connected is rejected and released,
without changing the active owner. A consumed lease cannot claim again or dispose
its adopted transport. If a lease disconnects before claim, it releases the room
once. Adoption failure after claim belongs to runtime cleanup; the caller's reset
awaits it. Unexpected failures retain diagnostics, while classified connection
failures retain existing UI/retry behavior.

Media receipts are transfer leases for tracks, not a second capture mechanism.
The capture controller rechecks transfer eligibility after settling, preventing
two concurrent claimants. The owner records a weak claim history so repeated
commands cannot reclaim accepted/disposed tracks. Publication establishes a
barrier: cleanup waits for acceptance, then the adapter owns accepted tracks.
Unaccepted tracks detach preview renderers before stop/dispose, including when
leave wins the race. Preview rendering is left intact during publication for
Safari. No capture, codec, renderer, soft-mute, or audio-output policy changes.

Normal leave cancels attempt/timers, invalidates device intents and Keeper
presence timeout, closes admission while the connection is usable, waits for
publication decisions, releases local media, and disconnects. Cleanup then
cancels transport listeners, stops feature/device registrations, deactivates its
infrastructure ownership, detaches admission, disposes the transport, and releases
remaining media. Cleanup attempts every release even after an earlier failure and
returns the original error. Admission close and transport disposal are idempotent.
Entry-owned foreground-service registrations keep an old cleanup from stopping a
new session. The browser unload path initiates transport disconnect synchronously
without waiting; browser teardown cannot guarantee completion.

Polling owns one 20-second metadata/presence schedule and one 15-second backend
schedule. Requests coalesce, with reconciliation retained; identical fetches do
not overlap. Replacing schedules stops old timers. A fetch already in flight can
finish, but its captured runtime and generation must still match before it may
apply state or failure diagnostics. Accepted backend versions never roll back.
Device completions and Keeper room-state responses are likewise fenced; prepared
moderation revocation journals still finish after backend success, even when the
originating entry ends.

### Manual compatibility smoke matrix (not executed here)

Use a Keeper and at least two participants; inspect connection/capture counts and
confirm audio/video continuity, roster recovery, turn controls, and clean re-entry.

| Platform | Required manual scenarios |
|---|---|
| Safari macOS / iOS | Preview camera/mic, waiting approval, same-room approval handoff, immediate leave during publication; retain preview until accepted; one capture/connection |
| Chrome desktop | Concurrent join actions, transient network loss/reconnect, Keeper leave/rejoin, decline/retry/expiry, leave and rejoin same slug; no duplicate polls/listeners |
| Android physical device | Background/foreground, Bluetooth/headset route changes, leave while connecting, rapid A → B entry; foreground service stays for B and stops on final leave |
| iPhone / iPad physical device | Background/foreground audio, camera switch/mute, interrupted connection/adoption, final release of tracks and audio route listeners |
| Browser page close / refresh | Best-effort immediate disconnect; next entry recovers roster and identity without retaining previous local media |

Automated tests use controlled Futures, fake transports, and fake clocks. They do
not replace real-device Safari publication and mobile foreground-service checks.
The existing raw-room compatibility boundary and SDK-shaped domain errors are
remaining Phase 4 work on this branch. There is no extra SDK import exemption,
backend change, new protocol, or competing active connection owner in Phase 5.
