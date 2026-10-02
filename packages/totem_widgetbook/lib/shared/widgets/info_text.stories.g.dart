// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'info_text.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<InfoText, StoryArgs<InfoText>>;
typedef _Scenario = InfoTextScenario;
typedef _Defaults = InfoTextDefaults;
typedef _Story = InfoTextStory;
typedef _Args = InfoTextArgs;
final InfoTextComponent = Component<InfoText, StoryArgs<InfoText>>(
  name: 'InfoText',
  path: 'shared/widgets',
  docComment: null,
  stories: [$Default..$generatedName = 'Default'],
);
typedef InfoTextScenario = Scenario<InfoText, InfoTextArgs>;
typedef InfoTextDefaults = Defaults<InfoText, InfoTextArgs>;

class InfoTextStory extends Story<InfoText, InfoTextArgs> {
  InfoTextStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    InfoTextArgs? args,
    StoryWidgetBuilder<InfoText, InfoTextArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? InfoTextArgs(),
         builder:
             builder ?? (context, args) => InfoText(args.text, key: args.key),
       );
}

class InfoTextArgs extends StoryArgs<InfoText> {
  InfoTextArgs({Arg<String>? text, Arg<Key?>? key})
    : this.textArg = $initArg('text', text, StringArg(''))!,
      this.keyArg = $initArg('key', key, null);

  InfoTextArgs.fixed({String text = '', Key? key})
    : this.textArg = $initArg('text', Arg.fixed(text), null)!,
      this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> textArg;

  final Arg<Key?>? keyArg;

  String get text => textArg.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [textArg, keyArg];
}
