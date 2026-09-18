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
