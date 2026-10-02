// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'error_dialog.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ErrorDialog, StoryArgs<ErrorDialog>>;
typedef _Scenario = ErrorDialogScenario;
typedef _Defaults = ErrorDialogDefaults;
typedef _Story = ErrorDialogStory;
typedef _Args = ErrorDialogArgs;
final ErrorDialogComponent = Component<ErrorDialog, StoryArgs<ErrorDialog>>(
  name: component.name ?? 'ErrorDialog',
  path: component.path ?? 'components/dialogs',
  docsBuilder: component.docsBuilder,
  docComment: null,
  stories: [$Default..$generatedName = 'Default'],
);
typedef ErrorDialogScenario = Scenario<ErrorDialog, ErrorDialogArgs>;
typedef ErrorDialogDefaults = Defaults<ErrorDialog, ErrorDialogArgs>;

class ErrorDialogStory extends Story<ErrorDialog, ErrorDialogArgs> {
  ErrorDialogStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    ErrorDialogArgs? args,
    StoryWidgetBuilder<ErrorDialog, ErrorDialogArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? ErrorDialogArgs(),
         builder:
             builder ??
             (context, args) => ErrorDialog(
               key: args.key,
               title: args.title,
               message: args.message,
             ),
       );
}

class ErrorDialogArgs extends StoryArgs<ErrorDialog> {
  ErrorDialogArgs({Arg<Key?>? key, Arg<String>? title, Arg<String?>? message})
    : this.keyArg = $initArg('key', key, null),
      this.titleArg = $initArg(
        'title',
        title,
        StringArg('Something went wrong!\nPlease try again later'),
      )!,
      this.messageArg = $initArg('message', message, NullableStringArg(null))!;

  ErrorDialogArgs.fixed({
    Key? key,
    String title = 'Something went wrong!\nPlease try again later',
    String? message = null,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.messageArg = $initArg(
         'message',
         message == null ? null : Arg.fixed(message),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<String?>? messageArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  String? get message => messageArg?.value;

  @override
  List<Arg?> get list => [keyArg, titleArg, messageArg];
}
