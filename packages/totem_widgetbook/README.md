# totem_widgetbook

Widgetbook catalog for Totem UI. It is where we design: new widgets and screens
are built and reviewed here before they are wired into the app.

## Workflow

1. Create one branch per design ticket.
2. Build the widget or screen in `totem_core` and add stories for it here.
3. Deploy the web build (`make widgetbook-build`) and share it for review. The
   URL encodes the selected story and its args, so a link reproduces exactly
   what you saw. Use this for design feedback and bug reports.
4. Only after approval, wire the widget or screen into `totem_app` / `totem_web`.

Large features that need design up front stay Widgetbook-only (merged, but not
routed in the app) until they are ready to release. Don't keep them on a
long-lived branch.

## Running

All commands run from the repo root, using `fvm`:

| Command                 | What it does                                               |
| ----------------------- | ---------------------------------------------------------- |
| `make widgetbook`       | Runs the catalog in Chrome on port 5174.                   |
| `make widgetbook-gen`   | Regenerates story code. Run after editing any `*.stories.dart`. |
| `make widgetbook-build` | Builds the release web bundle to deploy for review.        |
| `make test-widgetbook`  | Renders every story and scenario.                          |

Commit the generated `*.g.dart` files.

## Package boundaries

This package depends on `totem_core` (and `material_ui`) only, never on
`totem_app` or `totem_web`. Anything shown here must live in `totem_core`.
Designing here therefore pushes shared UI into core.

**Catalog-only exception.** Figma session UI that is not in `totem_core` yet
lives under `lib/design/`. Those copies are for review in this catalog. Do
not import them from `totem_core`, `totem_app`, or `totem_web`. Promote a
widget into core when it is ready to ship.

## Tree structure

The catalog has exactly two roots:

```
Components/
  Buttons/     CircleIconButton, Button
  Dialogs/     ConfirmationDialog, ErrorDialog
  Feedback/    EmptyIndicator, ErrorScreen, InfoText, LoadingIndicator, LoadingScreen
  Navigation/  PageIndicator, SheetDragHandle
  Brand/       TotemIcon, TotemIconLogo, TotemLogo
  Sessions/    SessionCard, SessionControls, WaitingCard, ParticipantCard
Screens/
  session/:slug   SessionEntry (one story; args are the states)
```

### Rules

- **Set the path explicitly.** Widgetbook derives the tree path from the
  *widget's* source folder in `totem_core` (e.g. `shared/widgets`), not from
  the stories file. So every stories file must declare its place in the tree:

  ```dart
  const meta = Meta(LoadingIndicator.new);

  const component = ComponentMeta(path: 'Components/Feedback');
  ```

- **File location mirrors the tree.** `Components/Feedback` stories live in
  `lib/components/feedback/`, and screens live under `lib/screens/`.
- **Use an existing category.** Add a new `Components/` category only when a
  widget clearly fits none of the existing ones, and update the tree above
  when you do.
- **One component per widget class.** Variants such as compact, a type enum,
  destructive, or loading/empty/error are stories or args of that component.
  They are never separate components, and never separate widget classes made
  just for the catalog. For example, `ConfirmationDialog` has `$Standard` and
  `$Destructive` stories.
- **Story naming.** Use `$Default` for the common case, then `$<State>` in
  PascalCase (`$Destructive`, `$Empty`, `$Error`).
- **No light/dark duplicates.** Theming is not a story axis right now.

## Screens

Screens map to the app's routes in `RouteNames`
(`totem_core/lib/shared/router.dart`), so design states line up with real
navigation.

- **Path** is `Screens/` plus the route path, e.g.
  `ComponentMeta(path: 'Screens/spaces/:slug')` for `RouteNames.space(':slug')`.
- **Route params and query params become args.** They are the knobs.
- **Each story is a meaningful screen state**, e.g. loaded, empty, error, or
  keeper vs participant. Session entry is one story: those states are its
  args, and the args panel is what changes the screen.
- **Inject the data.** A screen takes its data and callbacks through
  constructor params, not providers or repositories. If a screen reads
  providers, split it into a thin route widget (reads providers, handles
  navigation) and a pure view, then write stories for the view. This keeps
  views easy to test and decoupled from the backend.

## Args helpers

Shared arg builders live in `lib/utils/args.dart`: `iconArg`,
`nullableIconArg`, `noop` and `asyncNoop`. Add new reusable args there rather
than redefining them per file.

## Widgetbook 4 beta

We're pinned to `widgetbook: 4.0.0-beta.14`. The 4.0 API differs from 3.x, and
its docs aren't published yet. As a reference, use the package's own
`README.md` and `example/` (in `~/.pub-cache/hosted/pub.dev/widgetbook-4.0.0-beta.14`
or a local clone of the repo).

LLMs tend to write 3.x code (`@UseCase`, `WidgetbookUseCase`, knobs). Don't use
it. The 4.0 API is `Meta`, `ComponentMeta`, `_Story` and `_Args` with typed
`*Arg`s. When in doubt, the analyzer is the ground truth.
