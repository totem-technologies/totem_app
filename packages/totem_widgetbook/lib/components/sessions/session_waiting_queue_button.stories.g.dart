// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_waiting_queue_button.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<SessionWaitingQueueButton, StoryArgs<SessionWaitingQueueButton>>;
typedef _Scenario = SessionWaitingQueueButtonScenario;
typedef _Defaults = SessionWaitingQueueButtonDefaults;
typedef _Story = SessionWaitingQueueButtonStory;
typedef _Args = SessionWaitingQueueButtonArgs;
final SessionWaitingQueueButtonComponent =
    Component<SessionWaitingQueueButton, StoryArgs<SessionWaitingQueueButton>>(
      name: component.name ?? 'SessionWaitingQueueButton',
      path: component.path ?? 'components/sessions',
      docsBuilder: component.docsBuilder,
      docComment: r'''Keeper's queue indicator. The host supplies the current waiting count and
opens the admission surface; this control never owns the queue.''',
      stories: [
        $Default..$generatedName = 'Default',
        $OneWaiting..$generatedName = 'OneWaiting',
        $Empty..$generatedName = 'Empty',
      ],
    );
typedef SessionWaitingQueueButtonScenario =
    Scenario<SessionWaitingQueueButton, SessionWaitingQueueButtonArgs>;
typedef SessionWaitingQueueButtonDefaults =
    Defaults<SessionWaitingQueueButton, SessionWaitingQueueButtonArgs>;

class SessionWaitingQueueButtonStory
    extends Story<SessionWaitingQueueButton, SessionWaitingQueueButtonArgs> {
  SessionWaitingQueueButtonStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionWaitingQueueButton, SessionWaitingQueueButtonArgs>?
    setup,
    super.modes,
    SessionWaitingQueueButtonArgs? args,
    StoryWidgetBuilder<
      SessionWaitingQueueButton,
      SessionWaitingQueueButtonArgs
    >?
    builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionWaitingQueueButtonArgs(),
         builder:
             builder ??
             (context, args) => SessionWaitingQueueButton(
               count: args.count,
               key: args.key,
               onPressed: args.onPressed,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class SessionWaitingQueueButtonArgs
    extends StoryArgs<SessionWaitingQueueButton> {
  SessionWaitingQueueButtonArgs({
    Arg<int>? count,
    Arg<Key?>? key,
    Arg<void Function()?>? onPressed,
  }) : this.countArg = $initArg('count', count, IntArg(0))!,
       this.keyArg = $initArg('key', key, null),
       this.onPressedArg = $initArg('onPressed', onPressed, null);

  SessionWaitingQueueButtonArgs.fixed({
    int count = 0,
    Key? key,
    void Function()? onPressed,
  }) : this.countArg = $initArg('count', Arg.fixed(count), null)!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.onPressedArg = $initArg(
         'onPressed',
         onPressed == null ? null : Arg.fixed(onPressed),
         null,
       );

  final Arg<int> countArg;

  final Arg<Key?>? keyArg;

  final Arg<void Function()?>? onPressedArg;

  int get count => countArg.value;

  Key? get key => keyArg?.value;

  void Function()? get onPressed => onPressedArg?.value;

  @override
  List<Arg?> get list => [countArg, keyArg, onPressedArg];
}
