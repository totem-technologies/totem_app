// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'home.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<HomeScreen, StoryArgs<HomeScreen>>;
typedef _Scenario = HomeScreenScenario;
typedef _Defaults = HomeScreenDefaults;
typedef _Story = HomeScreenStory;
typedef _Args = HomeInputArgs;
final HomeScreenComponent = Component<HomeScreen, StoryArgs<HomeScreen>>(
  name: component.name ?? 'HomeScreen',
  path: component.path ?? 'screens',
  docsBuilder: component.docsBuilder,
  docComment: r'''Figma "Home Page" (2316:7031).

Top to bottom: the member's next Session (or, for a new member, a card
about Totem), upcoming Sessions as compact rows, then the latest blog
post. The bottom navigation stays fixed with Home selected.

[live] turns the next Session into the "Now / Join Session" card
(Figma 2403:2424). It has no effect for a new member.''',
  stories: [
    $NewUser..$generatedName = 'NewUser',
    $Returning..$generatedName = 'Returning',
    $ReturningLive..$generatedName = 'ReturningLive',
    $NoUpcoming..$generatedName = 'NoUpcoming',
  ],
);
typedef HomeScreenScenario = Scenario<HomeScreen, HomeInputArgs>;
typedef HomeScreenDefaults = Defaults<HomeScreen, HomeInputArgs>;

class HomeScreenStory extends Story<HomeScreen, HomeInputArgs> {
  HomeScreenStory({
    super.name,
    super.designLink,
    SetupBuilder<HomeScreen, HomeInputArgs>? setup,
    super.modes,
    HomeInputArgs? args,
    StoryWidgetBuilder<HomeScreen, HomeInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? HomeInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class HomeInputArgs extends StoryArgs<HomeScreen> {
  HomeInputArgs({
    Arg<HomeUser>? user,
    Arg<bool>? live,
    Arg<int>? upcomingCount,
    Arg<bool>? showBlog,
  }) : this.userArg = $initArg(
         'user',
         user,
         EnumArg<HomeUser>(HomeUser.returning, values: HomeUser.values),
       )!,
       this.liveArg = $initArg('live', live, BoolArg(false))!,
       this.upcomingCountArg = $initArg(
         'upcomingCount',
         upcomingCount,
         IntArg(5),
       )!,
       this.showBlogArg = $initArg('showBlog', showBlog, BoolArg(true))!;

  HomeInputArgs.fixed({
    HomeUser user = HomeUser.returning,
    bool live = false,
    int upcomingCount = 5,
    bool showBlog = true,
  }) : this.userArg = $initArg('user', Arg.fixed(user), null)!,
       this.liveArg = $initArg('live', Arg.fixed(live), null)!,
       this.upcomingCountArg = $initArg(
         'upcomingCount',
         Arg.fixed(upcomingCount),
         null,
       )!,
       this.showBlogArg = $initArg('showBlog', Arg.fixed(showBlog), null)!;

  final Arg<HomeUser> userArg;

  final Arg<bool> liveArg;

  final Arg<int> upcomingCountArg;

  final Arg<bool> showBlogArg;

  HomeUser get user => userArg.value;

  bool get live => liveArg.value;

  int get upcomingCount => upcomingCountArg.value;

  bool get showBlog => showBlogArg.value;

  @override
  List<Arg?> get list => [userArg, liveArg, upcomingCountArg, showBlogArg];
}
