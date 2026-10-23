// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'sessions.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SessionsScreen, StoryArgs<SessionsScreen>>;
typedef _Scenario = SessionsScreenScenario;
typedef _Defaults = SessionsScreenDefaults;
typedef _Story = SessionsScreenStory;
typedef _Args = SessionsInputArgs;
final SessionsScreenComponent =
    Component<SessionsScreen, StoryArgs<SessionsScreen>>(
      name: component.name ?? 'SessionsScreen',
      path: component.path ?? 'screens',
      docsBuilder: component.docsBuilder,
      docComment:
          r'''Figma "Sessions" (2315:8056): every upcoming Session, grouped by day.

The chip row narrows the list to one kind of Space. "My Sessions"
narrows it to the ones the member is attending. When both leave
nothing, an empty note offers to show everything again.

Fills the viewport height. The list scrolls under a fixed bottom
navigation bar.''',
      stories: [
        $Default..$generatedName = 'Default',
        $Filtered..$generatedName = 'Filtered',
        $MySessions..$generatedName = 'MySessions',
        $Empty..$generatedName = 'Empty',
      ],
    );
typedef SessionsScreenScenario = Scenario<SessionsScreen, SessionsInputArgs>;
typedef SessionsScreenDefaults = Defaults<SessionsScreen, SessionsInputArgs>;

class SessionsScreenStory extends Story<SessionsScreen, SessionsInputArgs> {
  SessionsScreenStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionsScreen, SessionsInputArgs>? setup,
    super.modes,
    SessionsInputArgs? args,
    StoryWidgetBuilder<SessionsScreen, SessionsInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SessionsInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class SessionsInputArgs extends StoryArgs<SessionsScreen> {
  SessionsInputArgs({Arg<SessionsFilter>? filter, Arg<bool>? mySessions})
    : this.filterArg = $initArg(
        'filter',
        filter,
        EnumArg<SessionsFilter>(
          SessionsFilter.all,
          values: SessionsFilter.values,
        ),
      )!,
      this.mySessionsArg = $initArg('mySessions', mySessions, BoolArg(false))!;

  SessionsInputArgs.fixed({
    SessionsFilter filter = SessionsFilter.all,
    bool mySessions = false,
  }) : this.filterArg = $initArg('filter', Arg.fixed(filter), null)!,
       this.mySessionsArg = $initArg(
         'mySessions',
         Arg.fixed(mySessions),
         null,
       )!;

  final Arg<SessionsFilter> filterArg;

  final Arg<bool> mySessionsArg;

  SessionsFilter get filter => filterArg.value;

  bool get mySessions => mySessionsArg.value;

  @override
  List<Arg?> get list => [filterArg, mySessionsArg];
}
