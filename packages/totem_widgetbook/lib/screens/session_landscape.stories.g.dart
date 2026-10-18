// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_landscape.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SessionLandscape, StoryArgs<SessionLandscape>>;
typedef _Scenario = SessionLandscapeScenario;
typedef _Defaults = SessionLandscapeDefaults;
typedef _Story = SessionLandscapeStory;
typedef _Args = SessionLandscapeInputArgs;
final SessionLandscapeComponent =
    Component<SessionLandscape, StoryArgs<SessionLandscape>>(
      name: component.name ?? 'SessionLandscape',
      path: component.path ?? 'screens',
      docsBuilder: component.docsBuilder,
      docComment:
          r'''In-session circle, laid out for a phone (or tablet) on its side.

Portrait session layout does not rotate. A 4:5 tile that filled a
standing phone becomes a tall slab in landscape; `BoxFit.cover` then
chops the sides of a typical 16:9 / 4:3 camera and the face reads as
zoomed. The featured speaker also used to take a full-height column
(~40% of the short landscape width) and felt like it owned the room.

Landscape gets its own rules, not a scaled copy of portrait:

  • Tiles are **4:3** — closer to a front camera than 4:5, so cover
    keeps shoulders and room around the head.
  • Tiles **do not stretch** to fill leftover space. Extra slate is
    breathing room, not a bigger crop.
  • Featured speaker is **capped** so one person cannot take over.
  • Gallery / speaking grids pick a column count from how many
    people are on camera, then size every tile the same.

Chrome (prompt, pass, controls) sits in a right-hand column so the
video cluster can stay compact. This is catalog-only — wire it into
the live session screens after review.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef SessionLandscapeScenario =
    Scenario<SessionLandscape, SessionLandscapeInputArgs>;
typedef SessionLandscapeDefaults =
    Defaults<SessionLandscape, SessionLandscapeInputArgs>;

class SessionLandscapeStory
    extends Story<SessionLandscape, SessionLandscapeInputArgs> {
  SessionLandscapeStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionLandscape, SessionLandscapeInputArgs>? setup,
    super.modes,
    SessionLandscapeInputArgs? args,
    StoryWidgetBuilder<SessionLandscape, SessionLandscapeInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionLandscapeInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class SessionLandscapeInputArgs extends StoryArgs<SessionLandscape> {
  SessionLandscapeInputArgs({
    Arg<LandscapeTurn>? turn,
    Arg<int>? participantCount,
    Arg<String>? prompt,
    Arg<bool>? micOn,
    Arg<bool>? cameraOn,
  }) : this.turnArg = $initArg(
         'turn',
         turn,
         EnumArg<LandscapeTurn>(
           LandscapeTurn.listening,
           values: LandscapeTurn.values,
         ),
       )!,
       this.participantCountArg = $initArg(
         'participantCount',
         participantCount,
         IntArg(4),
       )!,
       this.promptArg = $initArg(
         'prompt',
         prompt,
         StringArg('"What are you ready to set down?"'),
       )!,
       this.micOnArg = $initArg('micOn', micOn, BoolArg(true))!,
       this.cameraOnArg = $initArg('cameraOn', cameraOn, BoolArg(true))!;

  SessionLandscapeInputArgs.fixed({
    LandscapeTurn turn = LandscapeTurn.listening,
    int participantCount = 4,
    String prompt = '"What are you ready to set down?"',
    bool micOn = true,
    bool cameraOn = true,
  }) : this.turnArg = $initArg('turn', Arg.fixed(turn), null)!,
       this.participantCountArg = $initArg(
         'participantCount',
         Arg.fixed(participantCount),
         null,
       )!,
       this.promptArg = $initArg('prompt', Arg.fixed(prompt), null)!,
       this.micOnArg = $initArg('micOn', Arg.fixed(micOn), null)!,
       this.cameraOnArg = $initArg('cameraOn', Arg.fixed(cameraOn), null)!;

  final Arg<LandscapeTurn> turnArg;

  final Arg<int> participantCountArg;

  final Arg<String> promptArg;

  final Arg<bool> micOnArg;

  final Arg<bool> cameraOnArg;

  LandscapeTurn get turn => turnArg.value;

  int get participantCount => participantCountArg.value;

  String get prompt => promptArg.value;

  bool get micOn => micOnArg.value;

  bool get cameraOn => cameraOnArg.value;

  @override
  List<Arg?> get list => [
    turnArg,
    participantCountArg,
    promptArg,
    micOnArg,
    cameraOnArg,
  ];
}
