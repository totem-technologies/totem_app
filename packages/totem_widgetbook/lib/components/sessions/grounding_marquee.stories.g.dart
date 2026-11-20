// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'grounding_marquee.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<GroundingMarquee, StoryArgs<GroundingMarquee>>;
typedef _Scenario = GroundingMarqueeScenario;
typedef _Defaults = GroundingMarqueeDefaults;
typedef _Story = GroundingMarqueeStory;
typedef _Args = GroundingMarqueeInputArgs;
final GroundingMarqueeComponent =
    Component<GroundingMarquee, StoryArgs<GroundingMarquee>>(
      name: component.name ?? 'GroundingMarquee',
      path: component.path ?? 'components/sessions',
      docsBuilder: component.docsBuilder,
      docComment:
          r'''Rotating grounding tips shown while a participant waits for a session,
both before the Keeper admits them and in the room's waiting state.

Each tip fades in, stays for [tipDuration], fades out, and the next tip
follows after [tipDelay]. With reduced motion, tips swap in place without
fading, on the same cadence.

The marquee always reserves the height of its tallest tip, so rotating
between shorter and longer tips never moves the controls around it.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef GroundingMarqueeScenario =
    Scenario<GroundingMarquee, GroundingMarqueeInputArgs>;
typedef GroundingMarqueeDefaults =
    Defaults<GroundingMarquee, GroundingMarqueeInputArgs>;

class GroundingMarqueeStory
    extends Story<GroundingMarquee, GroundingMarqueeInputArgs> {
  GroundingMarqueeStory({
    super.name,
    super.designLink,
    SetupBuilder<GroundingMarquee, GroundingMarqueeInputArgs>? setup,
    super.modes,
    GroundingMarqueeInputArgs? args,
    StoryWidgetBuilder<GroundingMarquee, GroundingMarqueeInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? GroundingMarqueeInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class GroundingMarqueeInputArgs extends StoryArgs<GroundingMarquee> {
  GroundingMarqueeInputArgs({Arg<int>? initialIndex})
    : this.initialIndexArg = $initArg('initialIndex', initialIndex, IntArg(0))!;

  GroundingMarqueeInputArgs.fixed({int initialIndex = 0})
    : this.initialIndexArg = $initArg(
        'initialIndex',
        Arg.fixed(initialIndex),
        null,
      )!;

  final Arg<int> initialIndexArg;

  int get initialIndex => initialIndexArg.value;

  @override
  List<Arg?> get list => [initialIndexArg];
}
