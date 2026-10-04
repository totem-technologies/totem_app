// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_controls.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SessionControls, StoryArgs<SessionControls>>;
typedef _Scenario = SessionControlsScenario;
typedef _Defaults = SessionControlsDefaults;
typedef _Story = SessionControlsStory;
typedef _Args = SessionControlsInputArgs;
final SessionControlsComponent =
    Component<SessionControls, StoryArgs<SessionControls>>(
      name: component.name ?? 'SessionControls',
      path: component.path ?? 'components/sessions',
      docsBuilder: component.docsBuilder,
      docComment: r'''Session Controls / Compact bar.

One pill, round buttons, the same order every time:
mic, camera, reactions, chat, more.

A filled button means "something is different from normal":
  - Mic muted or camera off  → berry fill, rose glyph
  - Reactions open           → cream fill, slate glyph
Everything else is a bare cream glyph on the glass.

Every measurement is a ratio of the Figma frame, where a button is 78px.
Change [buttonSize] and the whole bar scales with it: padding, gap,
border, radius, and glyphs.''',
      stories: [
        $InTheCircle..$generatedName = 'InTheCircle',
        $Muted..$generatedName = 'Muted',
        $CameraOff..$generatedName = 'CameraOff',
        $ReactionsOpen..$generatedName = 'ReactionsOpen',
        $BeforeAdmission..$generatedName = 'BeforeAdmission',
        $OnCream..$generatedName = 'OnCream',
      ],
    );
typedef SessionControlsScenario =
    Scenario<SessionControls, SessionControlsInputArgs>;
typedef SessionControlsDefaults =
    Defaults<SessionControls, SessionControlsInputArgs>;

class SessionControlsStory
    extends Story<SessionControls, SessionControlsInputArgs> {
  SessionControlsStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionControls, SessionControlsInputArgs>? setup,
    super.modes,
    SessionControlsInputArgs? args,
    StoryWidgetBuilder<SessionControls, SessionControlsInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionControlsInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class SessionControlsInputArgs extends StoryArgs<SessionControls> {
  SessionControlsInputArgs({
    Arg<bool>? micOn,
    Arg<bool>? cameraOn,
    Arg<bool>? showSessionActions,
    Arg<bool>? reactionsOpen,
    Arg<bool>? moreExpanded,
    Arg<SessionControlsTone>? tone,
  }) : this.micOnArg = $initArg('micOn', micOn, BoolArg(true))!,
       this.cameraOnArg = $initArg('cameraOn', cameraOn, BoolArg(true))!,
       this.showSessionActionsArg = $initArg(
         'showSessionActions',
         showSessionActions,
         BoolArg(true),
       )!,
       this.reactionsOpenArg = $initArg(
         'reactionsOpen',
         reactionsOpen,
         BoolArg(false),
       )!,
       this.moreExpandedArg = $initArg(
         'moreExpanded',
         moreExpanded,
         BoolArg(false),
       )!,
       this.toneArg = $initArg(
         'tone',
         tone,
         EnumArg<SessionControlsTone>(
           SessionControlsTone.glass,
           values: SessionControlsTone.values,
         ),
       )!;

  SessionControlsInputArgs.fixed({
    bool micOn = true,
    bool cameraOn = true,
    bool showSessionActions = true,
    bool reactionsOpen = false,
    bool moreExpanded = false,
    SessionControlsTone tone = SessionControlsTone.glass,
  }) : this.micOnArg = $initArg('micOn', Arg.fixed(micOn), null)!,
       this.cameraOnArg = $initArg('cameraOn', Arg.fixed(cameraOn), null)!,
       this.showSessionActionsArg = $initArg(
         'showSessionActions',
         Arg.fixed(showSessionActions),
         null,
       )!,
       this.reactionsOpenArg = $initArg(
         'reactionsOpen',
         Arg.fixed(reactionsOpen),
         null,
       )!,
       this.moreExpandedArg = $initArg(
         'moreExpanded',
         Arg.fixed(moreExpanded),
         null,
       )!,
       this.toneArg = $initArg('tone', Arg.fixed(tone), null)!;

  final Arg<bool> micOnArg;

  final Arg<bool> cameraOnArg;

  final Arg<bool> showSessionActionsArg;

  final Arg<bool> reactionsOpenArg;

  final Arg<bool> moreExpandedArg;

  final Arg<SessionControlsTone> toneArg;

  bool get micOn => micOnArg.value;

  bool get cameraOn => cameraOnArg.value;

  bool get showSessionActions => showSessionActionsArg.value;

  bool get reactionsOpen => reactionsOpenArg.value;

  bool get moreExpanded => moreExpandedArg.value;

  SessionControlsTone get tone => toneArg.value;

  @override
  List<Arg?> get list => [
    micOnArg,
    cameraOnArg,
    showSessionActionsArg,
    reactionsOpenArg,
    moreExpandedArg,
    toneArg,
  ];
}
