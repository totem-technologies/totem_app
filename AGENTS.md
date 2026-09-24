Always prefer generated providers using `@riverpod` than manually written providers.

# Testing and Leak Detection

## Test style

- Prefer `package:checks` (`check(value).equals(...)`) over `expect` and `package:matcher` for new or updated assertions.
- Keep unit tests pure: do not use network, real filesystem access, platform channels, media devices, browser navigation, or wall-clock delays.
- Use fakes, mocks, provider overrides, and small inline fixtures. Create only the data required by the test.
- Use `Completer`, `fakeAsync`, and `WidgetTester.pump(Duration)` to control asynchronous work and time deterministically. Do not add `Future.delayed` waits to tests.
- Use `pump()` for one scheduled frame. Use `pumpAndSettle()` only when the widget has finite animations; do not use it with periodic timers, visualizers, or other continuous animations.
- Keep setup lightweight. Use `setUpAll` only for immutable, process-wide setup such as fallback-value registration. Do not share mutable state between tests.
- Tests must not depend on local `.env` files, developer credentials, or files generated outside the test.

## Behavioral test quality

- Optimize for confidence per test, not test count or raw coverage percentage.
- Every test should protect a meaningful user-facing behavior, business rule, state transition, error/recovery path, navigation outcome, permission rule, or application-owned contract. Before keeping an assertion, ask: “If this fails, is something meaningful broken?”
- Prefer Given/When/Then scenarios that exercise a complete interaction or workflow over isolated implementation checks.
- Test observable outcomes rather than private fields, internal callbacks, concrete widget classes, widget existence, or implementation structure when the user-visible behavior can be exercised directly.
- Do not add tests whose primary purpose is asserting hardcoded copy, colors, themes, padding, fonts, dimensions, icons, constants, trivial getters/setters, static configuration, or framework behavior. Assert exact copy or styling only when it is an explicit product, accessibility, or compatibility requirement.
- Remove or merge tests when they protect the same behavior, differ only by boilerplate, or duplicate a higher-level workflow. Do not preserve tests merely to maintain test counts.
- Parameterize genuinely distinct input/state variants when the setup and behavior are the same, but keep separate tests when the user-visible outcome or regression risk differs.
- Keep test names aligned with their assertions. A test named for recovery, navigation, or a specific error must verify that outcome rather than only checking that a generic widget is present.
- Keep UI tests useful: prefer tapping, dragging, entering text, submitting, retrying, navigating, and verifying resulting state over inspecting widget properties. Use stable semantics, keys, or domain-level state only when they represent a real contract.
- Avoid duplicated mocks, repeated `when` clauses, large fixture graphs, and test-to-test imports. Centralize shared harnesses only when they describe a stable package-level boundary; keep scenario-specific fakes local.
- Mock external boundaries, not application logic. Prefer real application providers/controllers and small fakes where practical.
- Do not heavily test generated code. Generated API clients, endpoint methods, schemas, DTO mappings, and provider implementations are not application-owned behavior; test only app-owned wrappers, error translation, caching, fallback, or integration contracts at their boundary.

## Widget lifecycle and resource ownership

- Every owned resource must be released by its owner: `StreamSubscription`, `Timer`, `AnimationController`, `CurvedAnimation`, `FocusNode`, `TextEditingController`, `OverlayEntry`, and platform/listener objects.
- An `OverlayEntry` must be removed before it is disposed. Make overlay cleanup idempotent because completion callbacks may run after screen teardown.
- Controllers that own overlays or subscriptions need an idempotent terminal `dispose()` method. After disposal, they must reject new work.
- Do not allocate stateful objects inline in `build` (for example `TapGestureRecognizer`, `CurvedAnimation`, or notification controllers). Store them in `State` and dispose them.
- If a static collection tracks temporary objects, remove entries both on the normal completion path and when Flutter unmounts the object during a tree teardown.
- In widget tests that intentionally leave a transient overlay visible for an assertion, clean it up explicitly before the test returns. Unmount test hosts with `await tester.pumpWidget(const SizedBox.shrink())` followed by a frame when needed.

## Leak tracking

Leak tracking is enabled through:

- `packages/totem_core/test/flutter_test_config.dart`
- `packages/totem_app/test/flutter_test_config.dart`
- `packages/totem_web/test/flutter_test_config.dart`

- Keep leak detection enabled for all first-party classes. Fix reported leaks; do not add broad ignores for app-owned types such as `TextPainter`, `OverlayEntry`, `TapGestureRecognizer`, or animation classes.
- Exceptions must be narrow and justified. If a third-party widget leaks an internal implementation type, apply `experimentalLeakTesting: LeakTesting.settings.withIgnored(...)` only to the individual test or test helper that mounts that widget.
- LiveKit classes may remain in the suite-level allowlist because their ownership is external to the app.
- When testing routers that use `GoRouterRefreshStream`, ensure the router owner disposes the refresh stream alongside `GoRouter` rather than suppressing it in leak-tracking configuration.

## Router lifecycle

- Construct each application `GoRouter` once in the app root `initState`; do not recreate it in `build`.
- A router that uses `GoRouterRefreshStream` must own the stream and dispose it when the app root disposes the router.
- Preserve raw auth-stream refresh behavior when redirect logic depends on every auth emission. A Riverpod state listener is not always equivalent to the authentication stream.

## Validation

```sh
make lint
make test
```

Run the focused test file first after a lifecycle or timing fix, then run the affected package suite.

## Test performance

- Prefer unit tests over widget tests when logic can be tested without a widget tree.
- Do not reduce coverage solely to make tests faster. Instead remove real waits, avoid unnecessary full-screen mounts, use representative layout boundaries, and replace expensive setup with minimal fakes.
- For layout breakpoints, test transition boundaries and representative variants rather than every equivalent size/count.
- When auditing or refactoring tests, first identify the behavior each existing test protects. Keep meaningful tests, rewrite brittle ones, merge overlapping scenarios, and remove tests with no meaningful protection; do not replace a weak assertion with another weak assertion.
- After test cleanup, report meaningful gaps separately instead of adding low-value tests solely to improve apparent coverage.
