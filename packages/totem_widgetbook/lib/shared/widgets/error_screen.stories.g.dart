// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'error_screen.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ErrorScreen, StoryArgs<ErrorScreen>>;
typedef _Scenario = ErrorScreenScenario;
typedef _Defaults = ErrorScreenDefaults;
typedef _Story = ErrorScreenStory;
typedef _Args = ErrorScreenArgs;
final ErrorScreenComponent = Component<ErrorScreen, StoryArgs<ErrorScreen>>(
  name: 'ErrorScreen',
  path: 'shared/widgets',
  docComment: null,
  stories: [$WithRetry..$generatedName = 'WithRetry'],
);
typedef ErrorScreenScenario = Scenario<ErrorScreen, ErrorScreenArgs>;
typedef ErrorScreenDefaults = Defaults<ErrorScreen, ErrorScreenArgs>;

class ErrorScreenStory extends Story<ErrorScreen, ErrorScreenArgs> {
  ErrorScreenStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    ErrorScreenArgs? args,
    StoryWidgetBuilder<ErrorScreen, ErrorScreenArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? ErrorScreenArgs(),
         builder:
             builder ??
             (context, args) => ErrorScreen(
               title: args.title,
               error: args.error,
               showHomeButton: args.showHomeButton,
               onRetry: args.onRetry,
               hideAppBar: args.hideAppBar,
               key: args.key,
             ),
       );
}

class ErrorScreenArgs extends StoryArgs<ErrorScreen> {
  ErrorScreenArgs({
    Arg<String?>? title,
    Arg<Object?>? error,
    Arg<bool?>? showHomeButton,
    Arg<Future<void> Function()?>? onRetry,
    Arg<bool>? hideAppBar,
    Arg<Key?>? key,
  }) : this.titleArg = $initArg('title', title, NullableStringArg(null))!,
       this.errorArg = $initArg('error', error, null),
       this.showHomeButtonArg = $initArg(
         'showHomeButton',
         showHomeButton,
         NullableBoolArg(null),
       )!,
       this.onRetryArg = $initArg('onRetry', onRetry, null),
       this.hideAppBarArg = $initArg('hideAppBar', hideAppBar, BoolArg(false))!,
       this.keyArg = $initArg('key', key, null);

  ErrorScreenArgs.fixed({
    String? title = null,
    Object? error,
    bool? showHomeButton = null,
    Future<void> Function()? onRetry,
    bool hideAppBar = false,
    Key? key,
  }) : this.titleArg = $initArg(
         'title',
         title == null ? null : Arg.fixed(title),
         null,
       ),
       this.errorArg = $initArg(
         'error',
         error == null ? null : Arg.fixed(error),
         null,
       ),
       this.showHomeButtonArg = $initArg(
         'showHomeButton',
         showHomeButton == null ? null : Arg.fixed(showHomeButton),
         null,
       ),
       this.onRetryArg = $initArg(
         'onRetry',
         onRetry == null ? null : Arg.fixed(onRetry),
         null,
       ),
       this.hideAppBarArg = $initArg(
         'hideAppBar',
         Arg.fixed(hideAppBar),
         null,
       )!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String?>? titleArg;

  final Arg<Object?>? errorArg;

  final Arg<bool?>? showHomeButtonArg;

  final Arg<Future<void> Function()?>? onRetryArg;

  final Arg<bool> hideAppBarArg;

  final Arg<Key?>? keyArg;

  String? get title => titleArg?.value;

  Object? get error => errorArg?.value;

  bool? get showHomeButton => showHomeButtonArg?.value;

  Future<void> Function()? get onRetry => onRetryArg?.value;

  bool get hideAppBar => hideAppBarArg.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [
    titleArg,
    errorArg,
    showHomeButtonArg,
    onRetryArg,
    hideAppBarArg,
    keyArg,
  ];
}
