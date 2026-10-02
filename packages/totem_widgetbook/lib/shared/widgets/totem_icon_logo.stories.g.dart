// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'totem_icon_logo.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TotemIconLogo, StoryArgs<TotemIconLogo>>;
typedef _Scenario = TotemIconLogoScenario;
typedef _Defaults = TotemIconLogoDefaults;
typedef _Story = TotemIconLogoStory;
typedef _Args = TotemIconLogoArgs;
final TotemIconLogoComponent =
    Component<TotemIconLogo, StoryArgs<TotemIconLogo>>(
      name: 'TotemIconLogo',
      path: 'shared/widgets',
      docComment: null,
      stories: [$Default..$generatedName = 'Default'],
    );
typedef TotemIconLogoScenario = Scenario<TotemIconLogo, TotemIconLogoArgs>;
typedef TotemIconLogoDefaults = Defaults<TotemIconLogo, TotemIconLogoArgs>;

class TotemIconLogoStory extends Story<TotemIconLogo, TotemIconLogoArgs> {
  TotemIconLogoStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    TotemIconLogoArgs? args,
    StoryWidgetBuilder<TotemIconLogo, TotemIconLogoArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? TotemIconLogoArgs(),
         builder:
             builder ??
             (context, args) => TotemIconLogo(
               key: args.key,
               size: args.size,
               color: args.color,
             ),
       );
}

class TotemIconLogoArgs extends StoryArgs<TotemIconLogo> {
  TotemIconLogoArgs({Arg<Key?>? key, Arg<double?>? size, Arg<Color?>? color})
    : this.keyArg = $initArg('key', key, null),
      this.sizeArg = $initArg('size', size, NullableDoubleArg(null))!,
      this.colorArg = $initArg('color', color, NullableColorArg(null))!;

  TotemIconLogoArgs.fixed({Key? key, double? size = null, Color? color = null})
    : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
      this.sizeArg = $initArg(
        'size',
        size == null ? null : Arg.fixed(size),
        null,
      ),
      this.colorArg = $initArg(
        'color',
        color == null ? null : Arg.fixed(color),
        null,
      );

  final Arg<Key?>? keyArg;

  final Arg<double?>? sizeArg;

  final Arg<Color?>? colorArg;

  Key? get key => keyArg?.value;

  double? get size => sizeArg?.value;

  Color? get color => colorArg?.value;

  @override
  List<Arg?> get list => [keyArg, sizeArg, colorArg];
}
