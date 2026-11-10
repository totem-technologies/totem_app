// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_disconnected.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<SessionDisconnectedView, StoryArgs<SessionDisconnectedView>>;
typedef _Scenario = SessionDisconnectedViewScenario;
typedef _Defaults = SessionDisconnectedViewDefaults;
typedef _Story = SessionDisconnectedViewStory;
typedef _Args = SessionDisconnectedInputArgs;
final SessionDisconnectedViewComponent =
    Component<SessionDisconnectedView, StoryArgs<SessionDisconnectedView>>(
      name: component.name ?? 'SessionDisconnectedView',
      path: component.path ?? 'screens',
      docsBuilder: component.docsBuilder,
      docComment: r'''What a participant sees once they leave a session.

Pure: [SessionDisconnectedScreen] reads the providers and supplies the
data and callbacks.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef SessionDisconnectedViewScenario =
    Scenario<SessionDisconnectedView, SessionDisconnectedInputArgs>;
typedef SessionDisconnectedViewDefaults =
    Defaults<SessionDisconnectedView, SessionDisconnectedInputArgs>;

class SessionDisconnectedViewStory
    extends Story<SessionDisconnectedView, SessionDisconnectedInputArgs> {
  SessionDisconnectedViewStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionDisconnectedView, SessionDisconnectedInputArgs>? setup,
    super.modes,
    SessionDisconnectedInputArgs? args,
    StoryWidgetBuilder<SessionDisconnectedView, SessionDisconnectedInputArgs>?
    builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionDisconnectedInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class SessionDisconnectedInputArgs extends StoryArgs<SessionDisconnectedView> {
  SessionDisconnectedInputArgs({
    Arg<SessionDisconnectedReason>? reason,
    Arg<RoomStatus>? background,
    Arg<NextSessionVariant>? nextSession,
    Arg<bool>? showFeedback,
    Arg<String>? spaceTitle,
    Arg<String>? sessionTitle,
    Arg<String>? keeperName,
    Arg<int>? seatsLeft,
  }) : this.reasonArg = $initArg(
         'reason',
         reason,
         EnumArg<SessionDisconnectedReason>(
           SessionDisconnectedReason.keeperEnded,
           values: SessionDisconnectedReason.values,
         ),
       )!,
       this.backgroundArg = $initArg(
         'background',
         background,
         ConstArg(RoomStatus.ended),
       )!,
       this.nextSessionArg = $initArg(
         'nextSession',
         nextSession,
         EnumArg<NextSessionVariant>(
           NextSessionVariant.nextSession,
           values: NextSessionVariant.values,
         ),
       )!,
       this.showFeedbackArg = $initArg(
         'showFeedback',
         showFeedback,
         BoolArg(true),
       )!,
       this.spaceTitleArg = $initArg(
         'spaceTitle',
         spaceTitle,
         StringArg('Community Connections'),
       )!,
       this.sessionTitleArg = $initArg(
         'sessionTitle',
         sessionTitle,
         StringArg('Finding Home in New Places'),
       )!,
       this.keeperNameArg = $initArg(
         'keeperName',
         keeperName,
         StringArg('Daisy Mccoy'),
       )!,
       this.seatsLeftArg = $initArg('seatsLeft', seatsLeft, IntArg(10))!;

  SessionDisconnectedInputArgs.fixed({
    SessionDisconnectedReason reason = SessionDisconnectedReason.keeperEnded,
    RoomStatus background = RoomStatus.ended,
    NextSessionVariant nextSession = NextSessionVariant.nextSession,
    bool showFeedback = true,
    String spaceTitle = 'Community Connections',
    String sessionTitle = 'Finding Home in New Places',
    String keeperName = 'Daisy Mccoy',
    int seatsLeft = 10,
  }) : this.reasonArg = $initArg('reason', Arg.fixed(reason), null)!,
       this.backgroundArg = $initArg(
         'background',
         Arg.fixed(background),
         null,
       )!,
       this.nextSessionArg = $initArg(
         'nextSession',
         Arg.fixed(nextSession),
         null,
       )!,
       this.showFeedbackArg = $initArg(
         'showFeedback',
         Arg.fixed(showFeedback),
         null,
       )!,
       this.spaceTitleArg = $initArg(
         'spaceTitle',
         Arg.fixed(spaceTitle),
         null,
       )!,
       this.sessionTitleArg = $initArg(
         'sessionTitle',
         Arg.fixed(sessionTitle),
         null,
       )!,
       this.keeperNameArg = $initArg(
         'keeperName',
         Arg.fixed(keeperName),
         null,
       )!,
       this.seatsLeftArg = $initArg('seatsLeft', Arg.fixed(seatsLeft), null)!;

  final Arg<SessionDisconnectedReason> reasonArg;

  final Arg<RoomStatus> backgroundArg;

  final Arg<NextSessionVariant> nextSessionArg;

  final Arg<bool> showFeedbackArg;

  final Arg<String> spaceTitleArg;

  final Arg<String> sessionTitleArg;

  final Arg<String> keeperNameArg;

  final Arg<int> seatsLeftArg;

  SessionDisconnectedReason get reason => reasonArg.value;

  RoomStatus get background => backgroundArg.value;

  NextSessionVariant get nextSession => nextSessionArg.value;

  bool get showFeedback => showFeedbackArg.value;

  String get spaceTitle => spaceTitleArg.value;

  String get sessionTitle => sessionTitleArg.value;

  String get keeperName => keeperNameArg.value;

  int get seatsLeft => seatsLeftArg.value;

  @override
  List<Arg?> get list => [
    reasonArg,
    backgroundArg,
    nextSessionArg,
    showFeedbackArg,
    spaceTitleArg,
    sessionTitleArg,
    keeperNameArg,
    seatsLeftArg,
  ];
}
