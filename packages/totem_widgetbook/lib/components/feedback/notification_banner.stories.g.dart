// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'notification_banner.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<NotificationBanner, StoryArgs<NotificationBanner>>;
typedef _Scenario = NotificationBannerScenario;
typedef _Defaults = NotificationBannerDefaults;
typedef _Story = NotificationBannerStory;
typedef _Args = NotificationBannerArgs;
final NotificationBannerComponent =
    Component<NotificationBanner, StoryArgs<NotificationBanner>>(
      name: component.name ?? 'NotificationBanner',
      path: component.path ?? 'components/feedback',
      docsBuilder: component.docsBuilder,
      docComment: null,
      stories: [
        $Default..$generatedName = 'Default',
        $Error..$generatedName = 'Error',
      ],
    );
typedef NotificationBannerScenario =
    Scenario<NotificationBanner, NotificationBannerArgs>;
typedef NotificationBannerDefaults =
    Defaults<NotificationBanner, NotificationBannerArgs>;

class NotificationBannerStory
    extends Story<NotificationBanner, NotificationBannerArgs> {
  NotificationBannerStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    NotificationBannerArgs? args,
    StoryWidgetBuilder<NotificationBanner, NotificationBannerArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? NotificationBannerArgs(),
         builder:
             builder ??
             (context, args) => NotificationBanner(
               icon: args.icon,
               title: args.title,
               message: args.message,
               iconBackgroundColor: args.iconBackgroundColor,
               key: args.key,
             ),
       );
}

class NotificationBannerArgs extends StoryArgs<NotificationBanner> {
  NotificationBannerArgs({
    Arg<String>? icon,
    Arg<String>? title,
    Arg<String>? message,
    Arg<Color?>? iconBackgroundColor,
    Arg<Key?>? key,
  }) : this.iconArg = $initArg('icon', icon, StringArg(''))!,
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.messageArg = $initArg('message', message, StringArg(''))!,
       this.iconBackgroundColorArg = $initArg(
         'iconBackgroundColor',
         iconBackgroundColor,
         NullableColorArg(null),
       )!,
       this.keyArg = $initArg('key', key, null);

  NotificationBannerArgs.fixed({
    String icon = '',
    String title = '',
    String message = '',
    Color? iconBackgroundColor = null,
    Key? key,
  }) : this.iconArg = $initArg('icon', Arg.fixed(icon), null)!,
       this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.messageArg = $initArg('message', Arg.fixed(message), null)!,
       this.iconBackgroundColorArg = $initArg(
         'iconBackgroundColor',
         iconBackgroundColor == null ? null : Arg.fixed(iconBackgroundColor),
         null,
       ),
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> iconArg;

  final Arg<String> titleArg;

  final Arg<String> messageArg;

  final Arg<Color?>? iconBackgroundColorArg;

  final Arg<Key?>? keyArg;

  String get icon => iconArg.value;

  String get title => titleArg.value;

  String get message => messageArg.value;

  Color? get iconBackgroundColor => iconBackgroundColorArg?.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [
    iconArg,
    titleArg,
    messageArg,
    iconBackgroundColorArg,
    keyArg,
  ];
}
