# Phase 2 widget-test inventory: transition cards and action bars

Recorded before editing. KEEP retains a distinct behavioral contract; REWRITE changes a poor assertion; MERGE moves the scenario into the named workflow; REMOVE drops incidental implementation checks. Every historical test in these files is listed below. Layout checks retain bounds and non-overlap rather than preferred pixel metrics.

## `action_bar_button_test.dart`

| Historical test | Decision | Claimed / actual protection; resulting contract |
|---|---|---|
| shows the shortcut only on a desktop web target | REWRITE | Counts Tooltip widgets; exercise pointer hover and visible shortcut help instead, preserving desktop/web applicability. |
| does not show the shortcut on a mobile web target | MERGE | Same conditional wrapping as desktop test; mobile variant of hover workflow verifies no misleading keyboard hint. |
| invokes callback on tap | REWRITE | Real callback count is useful, but concrete finder is unnecessary; use named accessible enabled and disabled controls, verify only enabled action executes. |
| uses phone metrics on a phone-width surface | REWRITE | Exact 48px width is incidental; phone controls must fit, not overlap, and all activate. |
| uses phone metrics when nested in an unbounded Row | REWRITE | Exact width misses the historic unbounded-constraint risk; retain nesting and verify reachable non-overlapping actions without overflow. |
| falls back to compact when phone width cannot fit children | REWRITE | Exact 40px width mirrors sizing tier; constrained controls must remain on-screen and activate. |
| uses comfortable metrics on a wide tablet surface | MERGE | Exact 44px is incidental; representative wide layout joins behavioral layout matrix. |

## `transition_card_test.dart`

| Historical test | Decision | Claimed / actual protection; resulting contract |
|---|---|---|
| actionable transition cards forward completion | REWRITE | Invokes widget callback directly, bypassing gesture wiring; swipe each Join/Pass/Receive/Start action. |
| large viewport keeps the space shortcut caption under the receive control | REWRITE | Mixes caption/height with a useful click; verify desktop receive activation without pixel/copy assertions. |
| join card stays in place when its shortcut becomes unavailable | REWRITE | Visibility internals/card location do not prove disabled joining; disabled/waiting join cannot execute and waiting exit invokes cancellation. |
| small viewport keeps the space shortcut caption under the pill | MERGE | Caption-only overlap with desktop receive; include narrow desktop activation in same workflow. |
| pass card uses the glass dock surface instead of a white card | REMOVE | Checks Card absence, decoration color, instruction color only; no behavioral contract. |
| stacks the instruction above a full-width 48dp slider on a 360px phone | REWRITE | Keep non-overlap, on-screen action, and successful swipe; remove full-width/exact-height requirements. |
| gives the stacked instruction a third line at 1.5x text scale | REWRITE | maxLines=3 mirrors implementation; large-text instructions and actions must not overlap, remain on-screen, and activate. |
| receive slider still completes on swipe | MERGE | Same receive behavior now exercised by actionable cards and phone layout workflow. |
| does not show the space bar caption without a keyboard | KEEP | Prevents misleading input instructions for touch-only users; no theme/dimension dependency. |
| stacks in the landscape side column and stays on screen | REWRITE | Preserve side-column constrained layout, bounds and non-overlap; use one representative small landscape boundary rather than equivalent sizes. |
| stacks 400-500dp pills on small viewports so Pass text has room | MERGE | Additional equivalent stacked geometry; constrained landscape workflow protects usable instructions and action. |
| keeps the row once a small-viewport pill is 500dp wide | REWRITE | Preferred row tier is implementation; retain broad landscape boundary and non-overlapping usable controls. |
| keeps the row on a narrow medium viewport | MERGE | Equivalent inline geometry; representative narrow medium layout covers fit and activation. |
| keeps the row for a ~421dp pill on a medium viewport | REWRITE | Preserve actual constrained-medium regression, remove exact pill/slider widths and expected tier. |
| waiting card is a single-row pill at the inline pill height | MERGE | Exact height and decoration are incidental; waiting-state workflow verifies no actionable turn control. |
| prompt card stacks the field above a 48dp slider | REWRITE | Preserve non-overlapping editable field/action and actual send at phone boundary; drop surface/height assertions. |
| docked sliders use the action bar label; Join keeps its own | REMOVE | Font-size equality only; no product or accessibility requirement for these exact styles. |
| WaitingReceiveTransitionCard renders without action button | REWRITE | Concrete ActionSliderButton count/copy only; assert waiting exposes no accessible turn action, preserving passive turn state. |
| PromptTransitionCard renders and triggers action | REWRITE | Direct callback bypasses button wiring; enter prompt and activate real control. |
| PromptTransitionCard passes unchanged text without replacing the prompt | REWRITE | Valuable protocol distinction, but direct callback and null defaults could pass without action; real activation, call count, and arguments. |
| PromptTransitionCard explicitly clears a removed prompt | REWRITE | Valuable destructive intent distinction; real edit and activation must request clear once. |

## `session_action_bar_test.dart`

| Historical test | Decision | Claimed / actual protection; resulting contract |
|---|---|---|
| is hidden on loading, disconnected, and error screens | REWRITE | Concrete ActionBar absence; assert interactive session actions unavailable in each distinct lifecycle state. |
| confirms before unmuting when another participant has the Totem | KEEP | Actual mute, reject confirmation, and no unmute protect safety. Use microphone semantic control instead of first widget. |
| X6: the microphone asks for access, then unmutes | KEEP | Permission request and resulting local media command are meaningful. |
| X7: a blocked microphone explains the fix | REWRITE | No media command is meaningful; replace recovery widget-type existence with opening Settings through the fake adapter, then dismissing safely without unmuting. |
| shows the microphone on the receiving screen only for staff | KEEP | Role-specific control availability uses semantics; distinct policy. |
| offers reactions only while listening | REWRITE | Concrete emoji button count; named accessible reaction action availability across turns. |
| returns empty widget when session is null | MERGE | No session is a lifecycle-gating variant, not a separate render assertion. |
| returns empty widget when local participant is null | MERGE | Missing identity is another action-gating variant; no raw SDK room fixture needed. |
| opens options sheet when tapping more button | REWRITE | MoreOptions type only; open menu, open leave confirmation, cancel, and verify session remains. |
| shows pending badge and notification on new chat message | MERGE | Green circular Container is incidental; combine notification, unread domain state and action into unread-chat workflow. |
| toggles the chat open flag when Chat is tapped with unread | REWRITE | Keep room-host ownership: unread notification selects chat/thread; mark read then close through real action, verify unified selection and notification dismissal. |

## Confidence and gaps

Preserve third-party TextPainter exclusions only where already scoped to AutoSizeText consumers; add no exclusions. No production styling changes. Browser tooltip discoverability still requires the browser runner; the VM checks its non-web exclusion. Real-device touch sizing and screen-reader announcements remain manual integration concerns. Unit/controller tests remain authoritative for media permission, chat protocol, and session lifecycle business rules; these widget tests verify the user can reach those commands.

## Executed validation

- `flutter test --no-pub test/features/sessions/widgets/transition_card_test.dart test/features/sessions/widgets/action_bar/action_bar_button_test.dart test/features/sessions/widgets/action_bar/session_action_bar_test.dart --reporter expanded`: **37 passed**.
- Final named blocked-microphone recovery test (after extending it to activate Settings): **1 passed**.
- Narrow `dart analyze` of those three files, plus final recovery edit: **no issues**.
- Modified-file `dart format` and `git diff --check`: **passed**.

The full Sessions suite is run by the coordinating task after all widget-test edits. No browser or real-device validation is claimed.
