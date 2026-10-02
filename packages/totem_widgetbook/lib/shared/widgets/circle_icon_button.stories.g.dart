// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'circle_icon_button.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<CircleIconButton, StoryArgs<CircleIconButton>>;
typedef _Scenario = CircleIconButtonScenario;
typedef _Defaults = CircleIconButtonDefaults;
typedef _Story = CircleIconButtonStory;
typedef _Args = CircleIconButtonArgs;
final CircleIconButtonComponent =
    Component<CircleIconButton, StoryArgs<CircleIconButton>>(
      name: 'CircleIconButton',
      path: 'shared/widgets',
      docComment: null,
      stories: [$Default..$generatedName = 'Default'],
    );
typedef CircleIconButtonScenario =
    Scenario<CircleIconButton, CircleIconButtonArgs>;
typedef CircleIconButtonDefaults =
    Defaults<CircleIconButton, CircleIconButtonArgs>;

class CircleIconButtonStory
    extends Story<CircleIconButton, CircleIconButtonArgs> {
  CircleIconButtonStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<CircleIconButton, CircleIconButtonArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => CircleIconButton(
               icon: args.icon,
               onPressed: args.onPressed,
               margin: args.margin,
               color: args.color,
               tooltip: args.tooltip,
               key: args.key,
             ),
       );
}

class CircleIconButtonArgs extends StoryArgs<CircleIconButton> {
  CircleIconButtonArgs({
    Arg<String>? icon,
    required Arg<void Function()> onPressed,
    Arg<EdgeInsetsGeometry?>? margin,
    Arg<Color?>? color,
    Arg<String?>? tooltip,
    Arg<Key?>? key,
  }) : this.iconArg = $initArg('icon', icon, StringArg(''))!,
       this.onPressedArg = $initArg('onPressed', onPressed, null)!,
       this.marginArg = $initArg('margin', margin, null),
       this.colorArg = $initArg('color', color, NullableColorArg(null))!,
       this.tooltipArg = $initArg('tooltip', tooltip, NullableStringArg(null))!,
       this.keyArg = $initArg('key', key, null);

  CircleIconButtonArgs.fixed({
    String icon = '',
    required void Function() onPressed,
    EdgeInsetsGeometry? margin,
    Color? color = null,
    String? tooltip = null,
    Key? key,
  }) : this.iconArg = $initArg('icon', Arg.fixed(icon), null)!,
       this.onPressedArg = $initArg('onPressed', Arg.fixed(onPressed), null)!,
       this.marginArg = $initArg(
         'margin',
         margin == null ? null : Arg.fixed(margin),
         null,
       ),
       this.colorArg = $initArg(
         'color',
         color == null ? null : Arg.fixed(color),
         null,
       ),
       this.tooltipArg = $initArg(
         'tooltip',
         tooltip == null ? null : Arg.fixed(tooltip),
         null,
       ),
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> iconArg;

  final Arg<void Function()> onPressedArg;

  final Arg<EdgeInsetsGeometry?>? marginArg;

  final Arg<Color?>? colorArg;

  final Arg<String?>? tooltipArg;

  final Arg<Key?>? keyArg;

  String get icon => iconArg.value;

  void Function() get onPressed => onPressedArg.value;

  EdgeInsetsGeometry? get margin => marginArg?.value;

  Color? get color => colorArg?.value;

  String? get tooltip => tooltipArg?.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [
    iconArg,
    onPressedArg,
    marginArg,
    colorArg,
    tooltipArg,
    keyArg,
  ];
}
