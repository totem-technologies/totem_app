// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'button.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<Button, StoryArgs<Button>>;
typedef _Scenario = ButtonScenario;
typedef _Defaults = ButtonDefaults;
typedef _Story = ButtonStory;
typedef _Args = ButtonArgs;
final ButtonComponent = Component<Button, StoryArgs<Button>>(
  name: component.name ?? 'Button',
  path: component.path ?? 'components/buttons',
  docsBuilder: component.docsBuilder,
  docComment: r'''Totem's pill button.

Primary is Figma "Button / Primary" (3734:10292): mauve pill, white
SemiBold 16, 52px tall. Secondary keeps that geometry with a mauve
outline. Text drops the pill.

Width is flex, not a Figma frame. Regular pills sit on a 140 min
and grow when [block] is set, so the same control works on phone
and desktop. A null `onPressed` disables it, which reads as
"waiting, not broken". For a link inside a sentence, use
[Button.inlineSpan].''',
  stories: [
    $Primary..$generatedName = 'Primary',
    $Secondary..$generatedName = 'Secondary',
    $Text..$generatedName = 'Text',
    $Disabled..$generatedName = 'Disabled',
    $Compact..$generatedName = 'Compact',
  ],
);
typedef ButtonScenario = Scenario<Button, ButtonArgs>;
typedef ButtonDefaults = Defaults<Button, ButtonArgs>;

class ButtonStory extends Story<Button, ButtonArgs> {
  ButtonStory({
    super.name,
    super.designLink,
    SetupBuilder<Button, ButtonArgs>? setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<Button, ButtonArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => Button(
               key: args.key,
               child: args.child,
               onPressed: args.onPressed,
               variant: args.variant,
               size: args.size,
               block: args.block,
               semanticLabel: args.semanticLabel,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class ButtonArgs extends StoryArgs<Button> {
  ButtonArgs({
    Arg<Key?>? key,
    required Arg<Widget> child,
    Arg<void Function()?>? onPressed,
    Arg<ButtonVariant>? variant,
    Arg<ButtonSize>? size,
    Arg<bool>? block,
    Arg<String?>? semanticLabel,
  }) : this.keyArg = $initArg('key', key, null),
       this.childArg = $initArg('child', child, null)!,
       this.onPressedArg = $initArg('onPressed', onPressed, null),
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<ButtonVariant>(
           ButtonVariant.primary,
           values: ButtonVariant.values,
         ),
       )!,
       this.sizeArg = $initArg(
         'size',
         size,
         EnumArg<ButtonSize>(ButtonSize.regular, values: ButtonSize.values),
       )!,
       this.blockArg = $initArg('block', block, BoolArg(false))!,
       this.semanticLabelArg = $initArg(
         'semanticLabel',
         semanticLabel,
         NullableStringArg(null),
       )!;

  ButtonArgs.fixed({
    Key? key,
    required Widget child,
    void Function()? onPressed,
    ButtonVariant variant = ButtonVariant.primary,
    ButtonSize size = ButtonSize.regular,
    bool block = false,
    String? semanticLabel = null,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.childArg = $initArg('child', Arg.fixed(child), null)!,
       this.onPressedArg = $initArg(
         'onPressed',
         onPressed == null ? null : Arg.fixed(onPressed),
         null,
       ),
       this.variantArg = $initArg('variant', Arg.fixed(variant), null)!,
       this.sizeArg = $initArg('size', Arg.fixed(size), null)!,
       this.blockArg = $initArg('block', Arg.fixed(block), null)!,
       this.semanticLabelArg = $initArg(
         'semanticLabel',
         semanticLabel == null ? null : Arg.fixed(semanticLabel),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<Widget> childArg;

  final Arg<void Function()?>? onPressedArg;

  final Arg<ButtonVariant> variantArg;

  final Arg<ButtonSize> sizeArg;

  final Arg<bool> blockArg;

  final Arg<String?>? semanticLabelArg;

  Key? get key => keyArg?.value;

  Widget get child => childArg.value;

  void Function()? get onPressed => onPressedArg?.value;

  ButtonVariant get variant => variantArg.value;

  ButtonSize get size => sizeArg.value;

  bool get block => blockArg.value;

  String? get semanticLabel => semanticLabelArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    childArg,
    onPressedArg,
    variantArg,
    sizeArg,
    blockArg,
    semanticLabelArg,
  ];
}
