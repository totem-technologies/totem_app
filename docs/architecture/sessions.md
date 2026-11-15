# Sessions architecture contract

This document describes the target ownership model and records current gaps. It is a migration contract, not a claim that every boundary is implemented. Keep PR #190's `LocalMedia`/`RoomMedia` abstractions, client-side cooperative admission, Safari track reuse, and video rendering safeguards.

## Ownership matrix

| Concern | Authority / canonical owner | Current owner(s) and allowed mutation | Observers, lifetime, persistence |
|---|---|---|---|
| Connection lifecycle | Session connection coordinator; LiveKit is transport truth | `SessionController` and LiveKit adapter currently overlap join/leave; coordinator alone should serialize transitions | Screens observe; connection scoped to one session; never persisted |
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
3. Concurrent same-connection joins deduplicate; success waits for required initialization. **Gap:** serialize lifecycle in Phase 2.
4. Pre-join capture transfers exactly once. **Gap:** make transfer token/ownership explicit in Phase 4.
5. Cleanup is idempotent; stale/disposed sessions cannot mutate newer sessions. **Gap:** generation fencing and owner teardown in Phases 2 and 4.
6. Admission is independent of panel visibility and remains cooperative/client-side. Existing protocol tests cover recovery; preserve and extend in Phase 3.
7. Each active session has isolated presentation state. **Gap:** scope panel state by session identity in Phase 5.
8. Widgets do not own domain services that outlive them. **Gap:** extract and re-scope service ownership in Phase 5.
9. Media capture/publication goes through media abstractions, preserving Safari reuse and video safeguards. Existing guard checks capture calls; broaden only with reliable checks in Phase 4.

## Riverpod and lifetime

The session scope is a container for dependencies and presentation projections, not a universal owner. Session identity must key the scope. Providers that own subscriptions/controllers must dispose them; root/navigation ownership must retain a session service when it outlives a route. Generated `@riverpod` providers are preferred. Generated provider code is not an architectural authority; inspect its dependencies and disposal behavior alongside annotations.

## Phases 2–6 issues

- **Phase 2:** single connection lifecycle owner; deduplicated join, initialization barrier, generation fencing, monotonic version reducer.
- **Phase 3:** admission protocol/roster ownership independent of panel and explicit reconnect/recovery contract.
- **Phase 4:** explicit one-time pre-join media transfer and adapter-only SDK access, retaining Safari safeguards.
- **Phase 5:** session-keyed provider/presentation scopes; move domain services out of widget ownership.
- **Phase 6:** consolidate remaining feature state ownership (messaging, prompts, reactions, timers, notifications, errors), remove obsolete mirrors, and validate teardown end to end.

## Phase 2 admission implementation

`SessionController` retains `SessionAdmissionService` independently of the overlay. Its state listener drives attachment; connection teardown awaits admission detachment before releasing the room. Final provider disposal closes admission and fences late callbacks. Protocol controllers and recovery stores retain their existing formats and client-side semantics. The overlay observes service state and renders recovery stores; it no longer constructs transports, owns protocol subscriptions, or installs a moderation callback.

The service serializes transport replacement and journal writes. Moderation obtains a prepared revocation operation before backend removal, capturing the storage boundary while the session is alive. After backend success, that operation records a local revocation intent before updating admission. If the session has disposed, the intent survives for the next Keeper attachment. Recovery consumes these intents and persists the corrected roster before creating an advertising transport. Successful live revocation clears its intent. Persistence failures keep removal blocked and expose a retry path; backend removal is never described as rolled back or atomic with local storage. Storage failure can prevent durable recording, and is reported explicitly.

Participant visibility is a reactive projection of the service roster, with the existing Keeper fallback. Media permissions are updated from the same roster. Approval settings invoke a service command. The default remains approval required. No backend authorization guarantees are added.

Validation covers the protocol suite, headless admission and transport reuse, media/visibility projection, replacement and disposal callbacks, persistence retry, and a backend completion represented by a prepared revocation after final disposal. Phase 5 must preserve the distinct pending pre-join connection owner until its explicit handoff, retain the session provider across temporary route changes, and avoid introducing a second admission owner during that handoff.

## Phase 3: session presentation ownership

`SessionPresentation` owns immutable `SessionPresentationState`: one `SessionPanel` enum and a revision. Opening a panel atomically replaces the previous selection. Closing can require the expected panel and revision; an older modal completion cannot close a newer selection. The three `session*SelectedProvider` functions are read-only selectors, not separately writable panel flags.

The pre-join screen keys the nested `ProviderScope` by the identity of its join options. The options object is retained during a join and reconnection, while a new join attempt creates a new object, including for the same slug. Presentation, thread-target reconciliation, and unread threads depend explicitly on `sessionScopeProvider` and are retained only in that entry's container. Mounting or resizing the room no longer invalidates them. Persistent self-view preferences remain separate.

`SessionPanels` is the sole in-session route host for Chat, Prompts, and Admission. Entry actions change panel intent; the host chooses the dock, drawer, or phone sheet. Named panel routes, a generation fence, and selection revisions protect route replacement and dismissal. The dock waits for an active overlay to be removed, avoiding duplicate hosts. Nested dialogs and prompt mutations defer responsive transfer; the latest intent is applied when they finish. The existing two-person thread selection, explicit Everyone selection, recipient checks, and coalesced reconciliation remain in `SessionChatThreadTarget`.

`SessionNavigatorScope` directs session-owned dialogs, sheets, and responsive modals to the room navigator, including actions from docked content. Its observer tracks only routes in that navigator. Termination removes those specific transient routes, including covered confirmations; it does not pop parent application routes. Child panel widgets do not own modal cleanup. Standalone Prompts calls retain their explicit non-session fallback.

Domain resources remain outside this presentation state: admission service/protocol, prompt repository/controller, chat messages, backend room state, and media ownership are unchanged. Tests cover atomic selection, stale close revisions, isolated replacement containers, existing chat reconciliation/unread behaviors, room termination with stacked dialogs, and responsive Chat/Prompts/Admission handoff.
