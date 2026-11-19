# Sessions widget test audit: chat and reactions

Inventory recorded before editing. Rows with `$role` apply independently to Keeper and participant variants; the peer-leaving row also covers automatic/explicit variants. KEEP means existing outcome assertions remain; rewritten tests remove incidental assertions without weakening their named contract.

## Chat sheet

| Existing test | Decision | Claimed / actual protection and rationale |
|---|---|---|
| `$role defaults to private chat and cannot select empty Everyone history` | KEEP | Sends to the auto-selected peer and verifies disabled empty Everyone selection. Genuine routing/product behavior. |
| `$role can select unread Everyone history with two people` | KEEP | Opens group history and clears its unread marker. Distinct from empty-history exclusion. |
| `$role defaults to Everyone when a third person joins before chat opens` | KEEP | Room changes before mounting produce correct initial recipient; Keeper sends to Everyone. Protects delayed mounting. |
| `$role switches from automatic private chat to Everyone when a third person joins` | KEEP | Live roster update reconciles automatic selection. Distinct mounted lifecycle. |
| `$role keeps an explicitly selected / clears the automatically selected peer when they leave` | KEEP | Asserts retained explicit target versus cleared automatic target after roster loss. Existing explicit/automatic metadata is a product routing contract. |
| `$role reopens to Everyone after a third person joins while chat is closed` | KEEP | Unmount/remount with room change reconciles selection. Protects state while UI absent. |
| `$role keeps the auto-selected peer after explicitly selecting them and a third joins` | KEEP | Explicit selection of an automatic target survives group growth; protects selection metadata. |
| `$role keeps an explicitly selected private thread when the group grows` | KEEP | Explicit private target selected from group remains selected. Separate origin from automatic-peer case. |
| shows the Everyone hint and private Keeper CTA for participants | MERGE | Mostly copy, concrete list/controller presence and exact color; disabled Everyone and private CTA interaction already protected by participant private-thread workflow. Merge permission assertions there. |
| keeps the private Keeper action inset on narrow phones | MERGE | Only exact right edge <=300; move narrow viewport/reachability into actual private-message workflow. No product contract for a 20px inset. |
| shows the keeper composer for Everyone | MERGE | Only empty-state/hint/widget copy; trimmed-send test can protect enabled Everyone composition through successful sending. |
| keeps the composer above the keyboard | REWRITE | Current geometric inset protection is meaningful; also send while keyboard inset is active and verify cleared draft. |
| renders own and received messages as MessageBubbles | REWRITE | Message content is meaningful; remove concrete MessageBubble/SelectionArea/SelectableText counts. |
| hides private messages while viewing Everyone | KEEP | Private-message confidentiality between threads; exact fixture content identifies visible versus hidden messages. |
| hides keeper thread affordances while the keeper is absent | KEEP | Absent Keeper cannot be selected. Genuine participant routing restriction. |
| participant can open a private keeper thread | REWRITE | Real private-send/Everyone permission workflow; merge narrow-phone usable CTA; remove composer rectangle equality and redundant descriptive copy. |
| does not scroll when the reader is away from the bottom | REWRITE | Retain scroll position after incoming message, establish reading position by user drag rather than controller jump. |
| follows new messages when the reader is near the bottom | KEEP | New messages remain visible near list end. Different user intent from history reading. |
| long messages scroll clear of the hint and the thread chip | REWRITE | Preserve readable first/last content and nonoverlap; remove exact fade height/type and arbitrary 10/12px gaps. |
| sends a trimmed message from the composer | REWRITE | Verify targeted trimmed send and cleared actual input (old text absence assertion missed whitespace). Merge Keeper Everyone composer scenario. |
| does not carry a private draft into the Everyone thread | KEEP | Confidential draft does not cross recipients. Real privacy outcome. |
| keeps the composer text when the send is rejected | KEEP | Send failure preserves retryable draft. |
| selects a recipient from the header dropdown | REWRITE | Preserve selected accessibility semantics; add actual targeted send instead of relying on hint copy. |
| places the channel chevron beside the name and a plain close on the trailing edge | REMOVE | Only icon variants, cursor and spacing constants. Recipient selection and accessible close/navigation tests cover actions; no required visual contract. |
| bounds and lazily builds a long recipient list | REWRITE | Old concrete list counts only proved virtualization; scroll to last recipient, select and send while checking no overflow. |
| slides the overlay drawer in from the trailing edge | REWRITE | Old SlideTransition/type assertion did not prove navigation. Open, enter a draft, dismiss through platform Back, and await route completion without removing host. |
| typing in the composer disables session shortcuts | KEEP | Prevents media/reaction commands during typing. Focus regression needs widget test. |
| an open docked chat disables session shortcuts | KEEP | Suppresses media shortcuts without composer focus; distinct from typing. |

## Emoji overlay

| Existing test | Decision | Claimed / actual protection and rationale |
|---|---|---|
| does not auto-dismiss after a few seconds | MERGE | Fake-time persistence is a real product behavior; merge with repeated emoji selection, proving it remains usable rather than only checking widget type. |
| selecting an emoji calls onEmojiSelected | REWRITE | Repeated semantic actions before/after elapsed fake time verify persistent reaction chooser and exact selections. |
| all reactions remain tappable in a narrow layout | KEEP | Every reaction remains actionable without overflow. Distinct compact-layout contract. |
| shows transient hover and press feedback for an emoji | REMOVE | Exact AnimatedScale values are incidental style; selection already protected by reaction interaction. |
| tapping outside the menu dismisses it | REWRITE | Merge dismissal-completion scenario and verify one callback even after repeated taps; barrier behavior remains. |
| dismiss plays a fade-out animation before completing | MERGE | Animation implementation is not contract; callback completion/idempotency merges into barrier test. Replace separate animation assertion with Escape and unmount safety workflows. |

## Preserved confidence and gaps

Chat recipient reconciliation, unread history, draft isolation, permission gating, reader scroll intent, keyboard suppression/insets and route lifecycle remain covered. Reactions retain all compact controls, persistent repeated selection, explicit dismissal and teardown cancellation. Responsive docked/overlay ownership remains in room-screen tests; this file does not duplicate it.

No production styling, protocol, admission logic or leak exclusions change. RTL placement and reduced-motion behavior are not established by these two files; add tests only if a concrete product regression or requirement warrants them.

## Validation

`flutter test --no-pub test/features/sessions/screens/chat_sheet_test.dart test/features/sessions/widgets/emoji_bar_overlay_test.dart --reporter expanded`: **39 passed** (34 chat workflows, 5 emoji workflows).

`dart analyze test/features/sessions/screens/chat_sheet_test.dart test/features/sessions/widgets/emoji_bar_overlay_test.dart`: no issues. Both files formatted; `git diff --check` clean. Temporary test implementation failures (a checks API typo and missing/late semantics-handle cleanup) were corrected; no production behavior was changed to satisfy tests.
