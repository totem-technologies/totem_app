// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_entry.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<PreJoinView, StoryArgs<PreJoinView>>;
typedef _Scenario = PreJoinViewScenario;
typedef _Defaults = PreJoinViewDefaults;
typedef _Story = PreJoinViewStory;
typedef _Args = PreJoinStoryInputArgs;
final PreJoinViewComponent = Component<PreJoinView, StoryArgs<PreJoinView>>(
  name: component.name ?? 'PreJoinView',
  path: component.path ?? 'screens',
  docsBuilder: component.docsBuilder,
  docComment: null,
  stories: [
    $Default..$generatedName = 'Default',
    $Waiting..$generatedName = 'Waiting',
  ],
);
typedef PreJoinViewScenario = Scenario<PreJoinView, PreJoinStoryInputArgs>;
typedef PreJoinViewDefaults = Defaults<PreJoinView, PreJoinStoryInputArgs>;

class PreJoinViewStory extends Story<PreJoinView, PreJoinStoryInputArgs> {
  PreJoinViewStory({
    super.name,
    super.designLink,
    SetupBuilder<PreJoinView, PreJoinStoryInputArgs>? setup,
    super.modes,
    PreJoinStoryInputArgs? args,
    StoryWidgetBuilder<PreJoinView, PreJoinStoryInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? PreJoinStoryInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class PreJoinStoryInputArgs extends StoryArgs<PreJoinView> {
  PreJoinStoryInputArgs({
    Arg<String>? slug,
    Arg<bool>? waiting,
    Arg<bool>? cameraOn,
    Arg<bool>? microphoneOn,
  }) : this.slugArg = $initArg('slug', slug, StringArg('session'))!,
       this.waitingArg = $initArg('waiting', waiting, BoolArg(false))!,
       this.cameraOnArg = $initArg('cameraOn', cameraOn, BoolArg(false))!,
       this.microphoneOnArg = $initArg(
         'microphoneOn',
         microphoneOn,
         BoolArg(false),
       )!;

  PreJoinStoryInputArgs.fixed({
    String slug = 'session',
    bool waiting = false,
    bool cameraOn = false,
    bool microphoneOn = false,
  }) : this.slugArg = $initArg('slug', Arg.fixed(slug), null)!,
       this.waitingArg = $initArg('waiting', Arg.fixed(waiting), null)!,
       this.cameraOnArg = $initArg('cameraOn', Arg.fixed(cameraOn), null)!,
       this.microphoneOnArg = $initArg(
         'microphoneOn',
         Arg.fixed(microphoneOn),
         null,
       )!;

  final Arg<String> slugArg;

  final Arg<bool> waitingArg;

  final Arg<bool> cameraOnArg;

  final Arg<bool> microphoneOnArg;

  String get slug => slugArg.value;

  bool get waiting => waitingArg.value;

  bool get cameraOn => cameraOnArg.value;

  bool get microphoneOn => microphoneOnArg.value;

  @override
  List<Arg?> get list => [slugArg, waitingArg, cameraOnArg, microphoneOnArg];
}
