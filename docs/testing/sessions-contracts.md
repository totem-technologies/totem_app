# Sessions test contracts — test-quality Phase 1

This pass starts from the current architecture, where `SessionRuntime` already
serializes joins and `SessionTurnService` already commits a pass before muting.
It does not repeat those extractions. The old test expecting immediate success
while initialization was blocked had already been replaced on this branch.

## Contracts verified

| Contract | Regression protection |
|---|---|
| Concurrent callers share the actual join result | Existing controller initialization scenario now covers both success and failure; existing transport/runtime tests cover connection failure, cancellation, and retry |
| Join success includes required publication | Camera and microphone rejection by the real media adapter each produce retryable failure, never connected success |
| Duplicate calls cannot reclaim first-attempt capture | Extra tracks release exactly once while initialization is blocked; original tracks remain owned until publication or failure |
| Disposal finishes resource cleanup | Existing publication/disposal test now awaits runtime disposal and checks the unused microphone, accepted camera ownership, and final room release |
| Cleanup failure is observable | `disconnectFromRoom()` propagates the original failure after the existing best-effort cleanup; the same test still verifies release and a subsequent successful join |
| Pass rejection preserves local decisions | Backend rejection/network failure leave the speaking turn intact and preserve manual microphone changes made while pending |
| Successful pass applies committed media policy | Canonical state is accepted before muting; a failed mute is explicit partial success and never rolls back the committed turn |
| A reply must confirm a real turn transition | Lower or conflicting equal-version replies are rejected. An unchanged reply at the request version cannot claim a completed pass. A newer response already observed through room events remains valid; the established terminal equal-version ending rule is preserved |
| Overlapping passes do not duplicate work | Existing command overlap test checks one backend transition and one committed media policy |
| Keeper presence tests describe actual ownership | Deterministic grace-period, reconnect, cancellation, awaited leave, failure/retry, and provider-disposal workflows replace contradictory participant-state and call-only assertions |

## Behavioral fixes demonstrated by regressions

- Join previously ignored a `false` publication-acceptance result from
  `LiveKitLocalMedia`. A released capture owner could therefore report successful
  joining despite publishing nothing. Required publications must now be accepted.
- Turn commands could accept an equal-version payload which the canonical room
  reducer would reject. Pass could also report completion from its original,
  unchanged state. Both are conflicts; neither may change local microphone state.
- The convenience disconnect command swallowed failed leave/cleanup Futures.
  Callers now receive the original error. Background presence/removal callers
  already have explicit error sinks; normal cleanup still attempts every release.

The implementation still never compensates a failed pass by automatically
unmuting. That would overwrite a user's newer device decision. Media failures
following a committed pass remain partial successes requiring local recovery.

## Deferred to later test-quality / architecture work

These are additional coverage/API gaps, not failing tests left in main:

- **Admission command outcomes:** single-request `decide()` currently has guarded
  no-op paths for busy/unavailable recovery. A later API pass should distinguish
  blocked, failed, and applied decisions and add explicit completion signals,
  while preserving client-side protocol and roster recovery semantics.
- **Admission asynchronous fixtures:** replace remaining generic microtask/event
  queue drains with protocol receipt or persistence barriers. Existing headless
  tests already assert resulting roster and media permissions; preserve those
  outcomes during fixture work.
- **Cleanup failure matrix:** inject independent failures at listener cancellation,
  admission close, transport disposal, and device/infrastructure teardown, including
  multiple failures in one cleanup. Verify later releases still run and the first
  diagnostic remains available. Do not treat an SDK disposal invocation as proof
  that third-party native resources have disappeared.
- **Timeout reconciliation:** exercise a backend mutation that commits after the
  client times out, followed by canonical polling/reconnect recovery. Client
  failure cannot prove server rollback; no compensation should override a newer
  local microphone decision.
- **Other versioned moderation commands:** audit their equal-version/idempotent
  reply semantics separately, with authoritative-state tests, before broadening
  the turn-command change to those APIs.
- **Adapter/device integration:** retain fake-based ownership tests and the manual
  Safari/mobile smoke matrix in `docs/architecture/sessions.md`. Native capture,
  browser teardown, and third-party SDK leaks are not established by unit tests.

The third-party exclusions in `test/leak_testing_setup.dart` are unchanged.
Totem-owned cleanup remains checked through observable state, cancelled listeners
and timers, and idempotent disposal. No tests in this pass add wall-clock waits,
real network/media access, or new leak exclusions.

## Validation performed

Using the pinned Flutter 3.50.0 SDK, from `packages/totem_core`:

- `flutter test --no-pub test/features/sessions/controllers/core/session_controller_test.dart --reporter expanded`: 54 passed.
- `flutter test --no-pub test/features/sessions/controllers/features/session_keeper_controller_test.dart --reporter expanded`: 13 passed.
- `flutter test --no-pub test/features/sessions/services/session_turn_service_test.dart --reporter expanded`: 28 passed.
- `flutter test --no-pub test/features/sessions --reporter expanded`: 1,062 passed, 6 existing web-only tests skipped on the VM.
- `flutter analyze --no-pub`: no issues.

From the repository root, `dart run scripts/check_media_boundary.dart`, formatting
the five modified Dart files, and `git diff --check` passed. `flutter pub get`
succeeded without lockfile changes. `flutter doctor` confirmed the pinned SDK;
Android duplicate-ADB and unaccepted-license warnings remain environment issues.
Browser and real-device validation were not performed.
