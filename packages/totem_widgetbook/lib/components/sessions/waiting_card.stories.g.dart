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
    Component<SessionWaitingCard, StoryArgs<SessionWaitingCard>>;
typedef _Scenario = SessionWaitingCardScenario;
typedef _Defaults = SessionWaitingCardDefaults;
typedef _Story = SessionWaitingCardStory;
typedef _Args = SessionWaitingCardArgs;
final SessionWaitingCardComponent =
    Component<SessionWaitingCard, StoryArgs<SessionWaitingCard>>(
      name: component.name ?? 'SessionWaitingCard',
      path: component.path ?? 'components/sessions',
      docsBuilder: component.docsBuilder,
      docComment: r'''Data and action for the lobby, or a passive admitted-before-start card.''',
      stories: [
        $Reviewing..$generatedName = 'Reviewing',
        $Admitted..$generatedName = 'Admitted',
      ],
    );
typedef SessionWaitingCardScenario =
    Scenario<SessionWaitingCard, SessionWaitingCardArgs>;
typedef SessionWaitingCardDefaults =
    Defaults<SessionWaitingCard, SessionWaitingCardArgs>;

class SessionWaitingCardStory
    extends Story<SessionWaitingCard, SessionWaitingCardArgs> {
  SessionWaitingCardStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionWaitingCard, SessionWaitingCardArgs>? setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<SessionWaitingCard, SessionWaitingCardArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => SessionWaitingCard(
               title: args.title,
               body: args.body,
               key: args.key,
               actionLabel: args.actionLabel,
               onAction: args.onAction,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class SessionWaitingCardArgs extends StoryArgs<SessionWaitingCard> {
  SessionWaitingCardArgs({
    Arg<String>? title,
    required Arg<Widget> body,
    Arg<Key?>? key,
    Arg<String?>? actionLabel,
    Arg<void Function()?>? onAction,
  }) : this.titleArg = $initArg('title', title, StringArg(''))!,
       this.bodyArg = $initArg('body', body, null)!,
       this.keyArg = $initArg('key', key, null),
       this.actionLabelArg = $initArg(
         'actionLabel',
         actionLabel,
         NullableStringArg(null),
       )!,
       this.onActionArg = $initArg('onAction', onAction, null);

  SessionWaitingCardArgs.fixed({
    String title = '',
    required Widget body,
    Key? key,
    String? actionLabel = null,
    void Function()? onAction,
  }) : this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.bodyArg = $initArg('body', Arg.fixed(body), null)!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.actionLabelArg = $initArg(
         'actionLabel',
         actionLabel == null ? null : Arg.fixed(actionLabel),
         null,
       ),
       this.onActionArg = $initArg(
         'onAction',
         onAction == null ? null : Arg.fixed(onAction),
         null,
       );

  final Arg<String> titleArg;

  final Arg<Widget> bodyArg;

  final Arg<Key?>? keyArg;

  final Arg<String?>? actionLabelArg;

  final Arg<void Function()?>? onActionArg;

  String get title => titleArg.value;

  Widget get body => bodyArg.value;

  Key? get key => keyArg?.value;

  String? get actionLabel => actionLabelArg?.value;

  void Function()? get onAction => onActionArg?.value;

  @override
  List<Arg?> get list => [
    titleArg,
    bodyArg,
    keyArg,
    actionLabelArg,
    onActionArg,
  ];
}
