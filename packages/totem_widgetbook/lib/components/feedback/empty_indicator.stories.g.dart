// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'empty_indicator.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<EmptyIndicator, StoryArgs<EmptyIndicator>>;
typedef _Scenario = EmptyIndicatorScenario;
typedef _Defaults = EmptyIndicatorDefaults;
typedef _Story = EmptyIndicatorStory;
typedef _Args = EmptyIndicatorArgs;
final EmptyIndicatorComponent =
    Component<EmptyIndicator, StoryArgs<EmptyIndicator>>(
      name: component.name ?? 'EmptyIndicator',
      path: component.path ?? 'components/feedback',
      docsBuilder: component.docsBuilder,
      docComment: null,
      stories: [
        $Default..$generatedName = 'Default',
        $WithRetry..$generatedName = 'WithRetry',
      ],
    );
typedef EmptyIndicatorScenario = Scenario<EmptyIndicator, EmptyIndicatorArgs>;
typedef EmptyIndicatorDefaults = Defaults<EmptyIndicator, EmptyIndicatorArgs>;

class EmptyIndicatorStory extends Story<EmptyIndicator, EmptyIndicatorArgs> {
  EmptyIndicatorStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    EmptyIndicatorArgs? args,
    StoryWidgetBuilder<EmptyIndicator, EmptyIndicatorArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? EmptyIndicatorArgs(),
         builder:
             builder ??
             (context, args) => EmptyIndicator(
               key: args.key,
               text: args.text,
               icon: args.icon,
               onRetry: args.onRetry,
             ),
       );
}

class EmptyIndicatorArgs extends StoryArgs<EmptyIndicator> {
  EmptyIndicatorArgs({
    Arg<Key?>? key,
    Arg<String?>? text,
    Arg<String>? icon,
    Arg<void Function()?>? onRetry,
  }) : this.keyArg = $initArg('key', key, null),
       this.textArg = $initArg('text', text, NullableStringArg(null))!,
       this.iconArg = $initArg('icon', icon, StringArg(TotemIcons.lock))!,
       this.onRetryArg = $initArg('onRetry', onRetry, null);

  EmptyIndicatorArgs.fixed({
    Key? key,
    String? text = null,
    String icon = TotemIcons.lock,
    void Function()? onRetry,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.textArg = $initArg(
         'text',
         text == null ? null : Arg.fixed(text),
         null,
       ),
       this.iconArg = $initArg('icon', Arg.fixed(icon), null)!,
       this.onRetryArg = $initArg(
         'onRetry',
         onRetry == null ? null : Arg.fixed(onRetry),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<String?>? textArg;

  final Arg<String> iconArg;

  final Arg<void Function()?>? onRetryArg;

  Key? get key => keyArg?.value;

  String? get text => textArg?.value;

  String get icon => iconArg.value;

  void Function()? get onRetry => onRetryArg?.value;

  @override
  List<Arg?> get list => [keyArg, textArg, iconArg, onRetryArg];
}
