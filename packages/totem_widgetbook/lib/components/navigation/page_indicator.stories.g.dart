// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'page_indicator.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<PageIndicator, StoryArgs<PageIndicator>>;
typedef _Scenario = PageIndicatorScenario;
typedef _Defaults = PageIndicatorDefaults;
typedef _Story = PageIndicatorStory;
typedef _Args = PageIndicatorArgs;
final PageIndicatorComponent =
    Component<PageIndicator, StoryArgs<PageIndicator>>(
      name: component.name ?? 'PageIndicator',
      path: component.path ?? 'components/navigation',
      docsBuilder: component.docsBuilder,
      docComment: null,
      stories: [
        $Default..$generatedName = 'Default',
        $Last..$generatedName = 'Last',
      ],
    );
typedef PageIndicatorScenario = Scenario<PageIndicator, PageIndicatorArgs>;
typedef PageIndicatorDefaults = Defaults<PageIndicator, PageIndicatorArgs>;

class PageIndicatorStory extends Story<PageIndicator, PageIndicatorArgs> {
  PageIndicatorStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    PageIndicatorArgs? args,
    StoryWidgetBuilder<PageIndicator, PageIndicatorArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? PageIndicatorArgs(),
         builder:
             builder ??
             (context, args) => PageIndicator(
               length: args.length,
               currentIndex: args.currentIndex,
               key: args.key,
             ),
       );
}

class PageIndicatorArgs extends StoryArgs<PageIndicator> {
  PageIndicatorArgs({
    Arg<int?>? length,
    Arg<int?>? currentIndex,
    Arg<Key?>? key,
  }) : this.lengthArg = $initArg('length', length, NullableIntArg(null))!,
       this.currentIndexArg = $initArg(
         'currentIndex',
         currentIndex,
         NullableIntArg(null),
       )!,
       this.keyArg = $initArg('key', key, null);

  PageIndicatorArgs.fixed({
    int? length = null,
    int? currentIndex = null,
    Key? key,
  }) : this.lengthArg = $initArg(
         'length',
         length == null ? null : Arg.fixed(length),
         null,
       ),
       this.currentIndexArg = $initArg(
         'currentIndex',
         currentIndex == null ? null : Arg.fixed(currentIndex),
         null,
       ),
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<int?>? lengthArg;

  final Arg<int?>? currentIndexArg;

  final Arg<Key?>? keyArg;

  int? get length => lengthArg?.value;

  int? get currentIndex => currentIndexArg?.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [lengthArg, currentIndexArg, keyArg];
}
