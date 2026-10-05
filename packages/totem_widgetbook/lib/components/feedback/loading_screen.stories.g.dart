// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'loading_screen.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<LoadingScreen, StoryArgs<LoadingScreen>>;
typedef _Scenario = LoadingScreenScenario;
typedef _Defaults = LoadingScreenDefaults;
typedef _Story = LoadingScreenStory;
typedef _Args = LoadingScreenArgs;
final LoadingScreenComponent =
    Component<LoadingScreen, StoryArgs<LoadingScreen>>(
      name: component.name ?? 'LoadingScreen',
      path: component.path ?? 'components/feedback',
      docsBuilder: component.docsBuilder,
      docComment: null,
      stories: [$Default..$generatedName = 'Default'],
    );
typedef LoadingScreenScenario = Scenario<LoadingScreen, LoadingScreenArgs>;
typedef LoadingScreenDefaults = Defaults<LoadingScreen, LoadingScreenArgs>;

class LoadingScreenStory extends Story<LoadingScreen, LoadingScreenArgs> {
  LoadingScreenStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    LoadingScreenArgs? args,
    StoryWidgetBuilder<LoadingScreen, LoadingScreenArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? LoadingScreenArgs(),
         builder: builder ?? (context, args) => LoadingScreen(key: args.key),
       );
}

class LoadingScreenArgs extends StoryArgs<LoadingScreen> {
  LoadingScreenArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  LoadingScreenArgs.fixed({Key? key})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
