// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'totem_icon.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TotemIcon, StoryArgs<TotemIcon>>;
typedef _Scenario = TotemIconScenario;
typedef _Defaults = TotemIconDefaults;
typedef _Story = TotemIconStory;
typedef _Args = TotemIconArgs;
final TotemIconComponent = Component<TotemIcon, StoryArgs<TotemIcon>>(
  name: 'TotemIcon',
  path: 'shared/widgets',
  docComment: null,
  stories: [$Default..$generatedName = 'Default'],
);
typedef TotemIconScenario = Scenario<TotemIcon, TotemIconArgs>;
typedef TotemIconDefaults = Defaults<TotemIcon, TotemIconArgs>;

class TotemIconStory extends Story<TotemIcon, TotemIconArgs> {
  TotemIconStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    TotemIconArgs? args,
    StoryWidgetBuilder<TotemIcon, TotemIconArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? TotemIconArgs(),
         builder:
             builder ??
             (context, args) => TotemIcon(
               args.icon,
               key: args.key,
               size: args.size,
               color: args.color,
               fillColor: args.fillColor,
             ),
       );
}

class TotemIconArgs extends StoryArgs<TotemIcon> {
  TotemIconArgs({
    Arg<String>? icon,
    Arg<Key?>? key,
    Arg<double?>? size,
    Arg<Color?>? color,
    Arg<bool>? fillColor,
  }) : this.iconArg = $initArg('icon', icon, StringArg(''))!,
       this.keyArg = $initArg('key', key, null),
       this.sizeArg = $initArg('size', size, NullableDoubleArg(null))!,
       this.colorArg = $initArg('color', color, NullableColorArg(null))!,
       this.fillColorArg = $initArg('fillColor', fillColor, BoolArg(true))!;

  TotemIconArgs.fixed({
    String icon = '',
    Key? key,
    double? size = null,
    Color? color = null,
    bool fillColor = true,
  }) : this.iconArg = $initArg('icon', Arg.fixed(icon), null)!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.sizeArg = $initArg(
         'size',
         size == null ? null : Arg.fixed(size),
         null,
       ),
       this.colorArg = $initArg(
         'color',
         color == null ? null : Arg.fixed(color),
         null,
       ),
       this.fillColorArg = $initArg('fillColor', Arg.fixed(fillColor), null)!;

  final Arg<String> iconArg;

  final Arg<Key?>? keyArg;

  final Arg<double?>? sizeArg;

  final Arg<Color?>? colorArg;

  final Arg<bool> fillColorArg;

  String get icon => iconArg.value;

  Key? get key => keyArg?.value;

  double? get size => sizeArg?.value;

  Color? get color => colorArg?.value;

  bool get fillColor => fillColorArg.value;

  @override
  List<Arg?> get list => [iconArg, keyArg, sizeArg, colorArg, fillColorArg];
}
