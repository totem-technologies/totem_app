// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'totem_logo.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TotemLogo, StoryArgs<TotemLogo>>;
typedef _Scenario = TotemLogoScenario;
typedef _Defaults = TotemLogoDefaults;
typedef _Story = TotemLogoStory;
typedef _Args = TotemLogoArgs;
final TotemLogoComponent = Component<TotemLogo, StoryArgs<TotemLogo>>(
  name: component.name ?? 'TotemLogo',
  path: component.path ?? 'components/brand',
  docsBuilder: component.docsBuilder,
  docComment: null,
  stories: [$Default..$generatedName = 'Default'],
);
typedef TotemLogoScenario = Scenario<TotemLogo, TotemLogoArgs>;
typedef TotemLogoDefaults = Defaults<TotemLogo, TotemLogoArgs>;

class TotemLogoStory extends Story<TotemLogo, TotemLogoArgs> {
  TotemLogoStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    TotemLogoArgs? args,
    StoryWidgetBuilder<TotemLogo, TotemLogoArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? TotemLogoArgs(),
         builder:
             builder ??
             (context, args) =>
                 TotemLogo(key: args.key, size: args.size, color: args.color),
       );
}

class TotemLogoArgs extends StoryArgs<TotemLogo> {
  TotemLogoArgs({Arg<Key?>? key, Arg<double?>? size, Arg<Color?>? color})
    : this.keyArg = $initArg('key', key, null),
      this.sizeArg = $initArg('size', size, NullableDoubleArg(null))!,
      this.colorArg = $initArg('color', color, NullableColorArg(null))!;

  TotemLogoArgs.fixed({Key? key, double? size = null, Color? color = null})
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
