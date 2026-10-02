// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'loading_indicator.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<LoadingIndicator, StoryArgs<LoadingIndicator>>;
typedef _Scenario = LoadingIndicatorScenario;
typedef _Defaults = LoadingIndicatorDefaults;
typedef _Story = LoadingIndicatorStory;
typedef _Args = LoadingIndicatorArgs;
final LoadingIndicatorComponent =
    Component<LoadingIndicator, StoryArgs<LoadingIndicator>>(
      name: 'LoadingIndicator',
      path: 'shared/widgets',
      docComment: null,
      stories: [$Default..$generatedName = 'Default'],
    );
typedef LoadingIndicatorScenario =
    Scenario<LoadingIndicator, LoadingIndicatorArgs>;
typedef LoadingIndicatorDefaults =
    Defaults<LoadingIndicator, LoadingIndicatorArgs>;

class LoadingIndicatorStory
    extends Story<LoadingIndicator, LoadingIndicatorArgs> {
  LoadingIndicatorStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    LoadingIndicatorArgs? args,
    StoryWidgetBuilder<LoadingIndicator, LoadingIndicatorArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? LoadingIndicatorArgs(),
         builder:
             builder ??
             (context, args) => LoadingIndicator(
               key: args.key,
               size: args.size,
               color: args.color,
               semanticsLabel: args.semanticsLabel,
             ),
       );
}

class LoadingIndicatorArgs extends StoryArgs<LoadingIndicator> {
  LoadingIndicatorArgs({
    Arg<Key?>? key,
    Arg<double>? size,
    Arg<Color?>? color,
    Arg<String>? semanticsLabel,
  }) : this.keyArg = $initArg('key', key, null),
       this.sizeArg = $initArg('size', size, DoubleArg(36.0))!,
       this.colorArg = $initArg('color', color, NullableColorArg(null))!,
       this.semanticsLabelArg = $initArg(
         'semanticsLabel',
         semanticsLabel,
         StringArg('Loading'),
       )!;

  LoadingIndicatorArgs.fixed({
    Key? key,
    double size = 36.0,
    Color? color = null,
    String semanticsLabel = 'Loading',
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.sizeArg = $initArg('size', Arg.fixed(size), null)!,
       this.colorArg = $initArg(
         'color',
         color == null ? null : Arg.fixed(color),
         null,
       ),
       this.semanticsLabelArg = $initArg(
         'semanticsLabel',
         Arg.fixed(semanticsLabel),
         null,
       )!;

  final Arg<Key?>? keyArg;

  final Arg<double> sizeArg;

  final Arg<Color?>? colorArg;

  final Arg<String> semanticsLabelArg;

  Key? get key => keyArg?.value;

  double get size => sizeArg.value;

  Color? get color => colorArg?.value;

  String get semanticsLabel => semanticsLabelArg.value;

  @override
  List<Arg?> get list => [keyArg, sizeArg, colorArg, semanticsLabelArg];
}
