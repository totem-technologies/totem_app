// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'waiting_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<JoinTransitionCard, StoryArgs<JoinTransitionCard>>;
typedef _Scenario = JoinTransitionCardScenario;
typedef _Defaults = JoinTransitionCardDefaults;
typedef _Story = JoinTransitionCardStory;
typedef _Args = JoinCardInputArgs;
final JoinTransitionCardComponent =
    Component<JoinTransitionCard, StoryArgs<JoinTransitionCard>>(
      name: component.name ?? 'JoinTransitionCard',
      path: component.path ?? 'components/sessions',
      docsBuilder: component.docsBuilder,
      docComment: null,
      stories: [
        $Default..$generatedName = 'Default',
        $Waiting..$generatedName = 'Waiting',
        $KeeperUnresponsive..$generatedName = 'KeeperUnresponsive',
      ],
    );
typedef JoinTransitionCardScenario =
    Scenario<JoinTransitionCard, JoinCardInputArgs>;
typedef JoinTransitionCardDefaults =
    Defaults<JoinTransitionCard, JoinCardInputArgs>;

class JoinTransitionCardStory
    extends Story<JoinTransitionCard, JoinCardInputArgs> {
  JoinTransitionCardStory({
    super.name,
    super.designLink,
    SetupBuilder<JoinTransitionCard, JoinCardInputArgs>? setup,
    super.modes,
    JoinCardInputArgs? args,
    StoryWidgetBuilder<JoinTransitionCard, JoinCardInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? JoinCardInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class JoinCardInputArgs extends StoryArgs<JoinTransitionCard> {
  JoinCardInputArgs({Arg<bool>? waiting, Arg<bool>? keeperUnresponsive})
    : this.waitingArg = $initArg('waiting', waiting, BoolArg(false))!,
      this.keeperUnresponsiveArg = $initArg(
        'keeperUnresponsive',
        keeperUnresponsive,
        BoolArg(false),
      )!;

  JoinCardInputArgs.fixed({
    bool waiting = false,
    bool keeperUnresponsive = false,
  }) : this.waitingArg = $initArg('waiting', Arg.fixed(waiting), null)!,
       this.keeperUnresponsiveArg = $initArg(
         'keeperUnresponsive',
         Arg.fixed(keeperUnresponsive),
         null,
       )!;

  final Arg<bool> waitingArg;

  final Arg<bool> keeperUnresponsiveArg;

  bool get waiting => waitingArg.value;

  bool get keeperUnresponsive => keeperUnresponsiveArg.value;

  @override
  List<Arg?> get list => [waitingArg, keeperUnresponsiveArg];
}
