// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'waiting_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<WaitingCard, StoryArgs<WaitingCard>>;
typedef _Scenario = WaitingCardScenario;
typedef _Defaults = WaitingCardDefaults;
typedef _Story = WaitingCardStory;
typedef _Args = WaitingCardArgs;
final WaitingCardComponent = Component<WaitingCard, StoryArgs<WaitingCard>>(
  name: component.name ?? 'WaitingCard',
  path: component.path ?? 'components/sessions',
  docsBuilder: component.docsBuilder,
  docComment:
      r'''Figma waiting-for-approval card (3796:9181): a white slab under the
preview. Title, a short wait line, then whatever [action] the parent
passes — usually the secondary Button.

Figma frame is 366 × 214, radius 25, 20px vertical / 10px horizontal
inset. The action is a slot so the parent can pass a Button, or
nothing, without this card knowing.''',
  stories: [
    $Reviewing..$generatedName = 'Reviewing',
    $Admitted..$generatedName = 'Admitted',
  ],
);
typedef WaitingCardScenario = Scenario<WaitingCard, WaitingCardArgs>;
typedef WaitingCardDefaults = Defaults<WaitingCard, WaitingCardArgs>;

class WaitingCardStory extends Story<WaitingCard, WaitingCardArgs> {
  WaitingCardStory({
    super.name,
    super.designLink,
    SetupBuilder<WaitingCard, WaitingCardArgs>? setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<WaitingCard, WaitingCardArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => WaitingCard(
               key: args.key,
               title: args.title,
               body: args.body,
               action: args.action,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class WaitingCardArgs extends StoryArgs<WaitingCard> {
  WaitingCardArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    required Arg<Widget> body,
    Arg<Widget?>? action,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.bodyArg = $initArg('body', body, null)!,
       this.actionArg = $initArg('action', action, null);

  WaitingCardArgs.fixed({
    Key? key,
    String title = '',
    required Widget body,
    Widget? action,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.bodyArg = $initArg('body', Arg.fixed(body), null)!,
       this.actionArg = $initArg(
         'action',
         action == null ? null : Arg.fixed(action),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<Widget> bodyArg;

  final Arg<Widget?>? actionArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  Widget get body => bodyArg.value;

  Widget? get action => actionArg?.value;

  @override
  List<Arg?> get list => [keyArg, titleArg, bodyArg, actionArg];
}
