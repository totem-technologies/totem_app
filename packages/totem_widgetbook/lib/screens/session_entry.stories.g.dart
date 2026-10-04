// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_entry.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SessionEntry, StoryArgs<SessionEntry>>;
typedef _Scenario = SessionEntryScenario;
typedef _Defaults = SessionEntryDefaults;
typedef _Story = SessionEntryStory;
typedef _Args = SessionEntryInputArgs;
final SessionEntryComponent = Component<SessionEntry, StoryArgs<SessionEntry>>(
  name: component.name ?? 'SessionEntry',
  path: component.path ?? 'screens',
  docsBuilder: component.docsBuilder,
  docComment:
      r'''Joining a Session: Google Meet's join behavior, Totem's materials.

A participant never sees the room until a Keeper admits them. Join is
the only action — the admission request is a side effect. The Keeper
sees the same moment from the other side: a waiting pill, then the
admission panel.

Layout follows the screen's own width. Narrow is a phone with bottom
sheets. From 640 it reads as a window: side panel and centered modal.
From 1100 it is the web Session layout (Figma 3800:10532).''',
  stories: [
    $TooEarly..$generatedName = 'TooEarly',
    $JoinWindow..$generatedName = 'JoinWindow',
    $LobbyBeforeStart..$generatedName = 'LobbyBeforeStart',
    $LobbyLate..$generatedName = 'LobbyLate',
    $AdmittedEarly..$generatedName = 'AdmittedEarly',
    $AdmittedLate..$generatedName = 'AdmittedLate',
    $DeclinedNextSession..$generatedName = 'DeclinedNextSession',
    $DeclinedRelated..$generatedName = 'DeclinedRelated',
    $KeeperPreparing..$generatedName = 'KeeperPreparing',
    $KeeperOneRequest..$generatedName = 'KeeperOneRequest',
    $KeeperSeveralRequests..$generatedName = 'KeeperSeveralRequests',
    $KeeperPanelClosed..$generatedName = 'KeeperPanelClosed',
  ],
);
typedef SessionEntryScenario = Scenario<SessionEntry, SessionEntryInputArgs>;
typedef SessionEntryDefaults = Defaults<SessionEntry, SessionEntryInputArgs>;

class SessionEntryStory extends Story<SessionEntry, SessionEntryInputArgs> {
  SessionEntryStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionEntry, SessionEntryInputArgs>? setup,
    super.modes,
    SessionEntryInputArgs? args,
    StoryWidgetBuilder<SessionEntry, SessionEntryInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionEntryInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class SessionEntryInputArgs extends StoryArgs<SessionEntry> {
  SessionEntryInputArgs({
    Arg<EntryRole>? role,
    Arg<DetailsPhase>? phase,
    Arg<EntryStatus>? status,
    Arg<int>? waiting,
    Arg<bool>? panelOpen,
    Arg<bool>? showOrientation,
    Arg<DeclineVariant>? declineVariant,
    Arg<String?>? expiresLabel,
  }) : this.roleArg = $initArg(
         'role',
         role,
         EnumArg<EntryRole>(EntryRole.participant, values: EntryRole.values),
       )!,
       this.phaseArg = $initArg(
         'phase',
         phase,
         EnumArg<DetailsPhase>(
           DetailsPhase.tooEarly,
           values: DetailsPhase.values,
         ),
       )!,
       this.statusArg = $initArg(
         'status',
         status,
         EnumArg<EntryStatus>(EntryStatus.browsing, values: EntryStatus.values),
       )!,
       this.waitingArg = $initArg('waiting', waiting, IntArg(0))!,
       this.panelOpenArg = $initArg('panelOpen', panelOpen, BoolArg(false))!,
       this.showOrientationArg = $initArg(
         'showOrientation',
         showOrientation,
         BoolArg(false),
       )!,
       this.declineVariantArg = $initArg(
         'declineVariant',
         declineVariant,
         EnumArg<DeclineVariant>(
           DeclineVariant.nextSession,
           values: DeclineVariant.values,
         ),
       )!,
       this.expiresLabelArg = $initArg(
         'expiresLabel',
         expiresLabel,
         NullableStringArg(null),
       )!;

  SessionEntryInputArgs.fixed({
    EntryRole role = EntryRole.participant,
    DetailsPhase phase = DetailsPhase.tooEarly,
    EntryStatus status = EntryStatus.browsing,
    int waiting = 0,
    bool panelOpen = false,
    bool showOrientation = false,
    DeclineVariant declineVariant = DeclineVariant.nextSession,
    String? expiresLabel = null,
  }) : this.roleArg = $initArg('role', Arg.fixed(role), null)!,
       this.phaseArg = $initArg('phase', Arg.fixed(phase), null)!,
       this.statusArg = $initArg('status', Arg.fixed(status), null)!,
       this.waitingArg = $initArg('waiting', Arg.fixed(waiting), null)!,
       this.panelOpenArg = $initArg('panelOpen', Arg.fixed(panelOpen), null)!,
       this.showOrientationArg = $initArg(
         'showOrientation',
         Arg.fixed(showOrientation),
         null,
       )!,
       this.declineVariantArg = $initArg(
         'declineVariant',
         Arg.fixed(declineVariant),
         null,
       )!,
       this.expiresLabelArg = $initArg(
         'expiresLabel',
         expiresLabel == null ? null : Arg.fixed(expiresLabel),
         null,
       );

  final Arg<EntryRole> roleArg;

  final Arg<DetailsPhase> phaseArg;

  final Arg<EntryStatus> statusArg;

  final Arg<int> waitingArg;

  final Arg<bool> panelOpenArg;

  final Arg<bool> showOrientationArg;

  final Arg<DeclineVariant> declineVariantArg;

  final Arg<String?>? expiresLabelArg;

  EntryRole get role => roleArg.value;

  DetailsPhase get phase => phaseArg.value;

  EntryStatus get status => statusArg.value;

  int get waiting => waitingArg.value;

  bool get panelOpen => panelOpenArg.value;

  bool get showOrientation => showOrientationArg.value;

  DeclineVariant get declineVariant => declineVariantArg.value;

  String? get expiresLabel => expiresLabelArg?.value;

  @override
  List<Arg?> get list => [
    roleArg,
    phaseArg,
    statusArg,
    waitingArg,
    panelOpenArg,
    showOrientationArg,
    declineVariantArg,
    expiresLabelArg,
  ];
}
