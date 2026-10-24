// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_details.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<SessionDetailsPage, StoryArgs<SessionDetailsPage>>;
typedef _Scenario = SessionDetailsPageScenario;
typedef _Defaults = SessionDetailsPageDefaults;
typedef _Story = SessionDetailsPageStory;
typedef _Args = SessionDetailsInputArgs;
final SessionDetailsPageComponent =
    Component<SessionDetailsPage, StoryArgs<SessionDetailsPage>>(
      name: component.name ?? 'SessionDetailsPage',
      path: component.path ?? 'screens',
      docsBuilder: component.docsBuilder,
      docComment:
          r'''Figma "Session Details (Latest)" (2379:2497): one Session of a Space.

Hero photo with back and share, the Space and Session names, a card of
facts with the date and Attend, the description, a similar Session, and
the Keeper. An ended Session is covered by a dialog that points to the
next one.

Fills the viewport height and scrolls.''',
      stories: [
        $Open..$generatedName = 'Open',
        $Attending..$generatedName = 'Attending',
        $Full..$generatedName = 'Full',
        $Ended..$generatedName = 'Ended',
      ],
    );
typedef SessionDetailsPageScenario =
    Scenario<SessionDetailsPage, SessionDetailsInputArgs>;
typedef SessionDetailsPageDefaults =
    Defaults<SessionDetailsPage, SessionDetailsInputArgs>;

class SessionDetailsPageStory
    extends Story<SessionDetailsPage, SessionDetailsInputArgs> {
  SessionDetailsPageStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionDetailsPage, SessionDetailsInputArgs>? setup,
    super.modes,
    SessionDetailsInputArgs? args,
    StoryWidgetBuilder<SessionDetailsPage, SessionDetailsInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionDetailsInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class SessionDetailsInputArgs extends StoryArgs<SessionDetailsPage> {
  SessionDetailsInputArgs({
    Arg<SessionDetailsStatus>? status,
    Arg<int>? seatsLeft,
    Arg<bool>? recurring,
    Arg<bool>? free,
    Arg<bool>? showSimilar,
  }) : this.statusArg = $initArg(
         'status',
         status,
         EnumArg<SessionDetailsStatus>(
           SessionDetailsStatus.open,
           values: SessionDetailsStatus.values,
         ),
       )!,
       this.seatsLeftArg = $initArg('seatsLeft', seatsLeft, IntArg(9))!,
       this.recurringArg = $initArg('recurring', recurring, BoolArg(true))!,
       this.freeArg = $initArg('free', free, BoolArg(true))!,
       this.showSimilarArg = $initArg(
         'showSimilar',
         showSimilar,
         BoolArg(true),
       )!;

  SessionDetailsInputArgs.fixed({
    SessionDetailsStatus status = SessionDetailsStatus.open,
    int seatsLeft = 9,
    bool recurring = true,
    bool free = true,
    bool showSimilar = true,
  }) : this.statusArg = $initArg('status', Arg.fixed(status), null)!,
       this.seatsLeftArg = $initArg('seatsLeft', Arg.fixed(seatsLeft), null)!,
       this.recurringArg = $initArg('recurring', Arg.fixed(recurring), null)!,
       this.freeArg = $initArg('free', Arg.fixed(free), null)!,
       this.showSimilarArg = $initArg(
         'showSimilar',
         Arg.fixed(showSimilar),
         null,
       )!;

  final Arg<SessionDetailsStatus> statusArg;

  final Arg<int> seatsLeftArg;

  final Arg<bool> recurringArg;

  final Arg<bool> freeArg;

  final Arg<bool> showSimilarArg;

  SessionDetailsStatus get status => statusArg.value;

  int get seatsLeft => seatsLeftArg.value;

  bool get recurring => recurringArg.value;

  bool get free => freeArg.value;

  bool get showSimilar => showSimilarArg.value;

  @override
  List<Arg?> get list => [
    statusArg,
    seatsLeftArg,
    recurringArg,
    freeArg,
    showSimilarArg,
  ];
}
