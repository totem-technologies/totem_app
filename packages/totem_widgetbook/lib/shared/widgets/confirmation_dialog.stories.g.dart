// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'confirmation_dialog.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ConfirmationDialog, StoryArgs<ConfirmationDialog>>;
typedef _Scenario = ConfirmationDialogScenario;
typedef _Defaults = ConfirmationDialogDefaults;
typedef _Story = ConfirmationDialogStory;
typedef _Args = ConfirmationDialogArgs;
final ConfirmationDialogComponent =
    Component<ConfirmationDialog, StoryArgs<ConfirmationDialog>>(
      name: 'ConfirmationDialog',
      path: 'shared/widgets',
      docComment: null,
      stories: [
        $Destructive..$generatedName = 'Destructive',
        $Standard..$generatedName = 'Standard',
      ],
    );
typedef ConfirmationDialogScenario =
    Scenario<ConfirmationDialog, ConfirmationDialogArgs>;
typedef ConfirmationDialogDefaults =
    Defaults<ConfirmationDialog, ConfirmationDialogArgs>;

class ConfirmationDialogStory
    extends Story<ConfirmationDialog, ConfirmationDialogArgs> {
  ConfirmationDialogStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ConfirmationDialog, ConfirmationDialogArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => ConfirmationDialog(
               confirmButtonText: args.confirmButtonText,
               onConfirm: args.onConfirm,
               contentStyle: args.contentStyle,
               content: args.content,
               contentSpan: args.contentSpan,
               title: args.title,
               icon: args.icon,
               iconWidget: args.iconWidget,
               iconSize: args.iconSize,
               type: args.type,
               showCancel: args.showCancel,
               extraButtons: args.extraButtons,
               contentWidget: args.contentWidget,
               scrollable: args.scrollable,
               key: args.key,
             ),
       );
}

class ConfirmationDialogArgs extends StoryArgs<ConfirmationDialog> {
  ConfirmationDialogArgs({
    Arg<String>? confirmButtonText,
    required Arg<Future<void> Function()> onConfirm,
    Arg<TextStyle?>? contentStyle,
    Arg<String?>? content,
    Arg<InlineSpan?>? contentSpan,
    Arg<String>? title,
    Arg<String?>? icon,
    Arg<Widget?>? iconWidget,
    Arg<double>? iconSize,
    Arg<ConfirmationDialogType>? type,
    Arg<bool>? showCancel,
    Arg<List<ConfirmationDialogButton>>? extraButtons,
    Arg<Widget?>? contentWidget,
    Arg<bool>? scrollable,
    Arg<Key?>? key,
  }) : this.confirmButtonTextArg = $initArg(
         'confirmButtonText',
         confirmButtonText,
         StringArg(''),
       )!,
       this.onConfirmArg = $initArg('onConfirm', onConfirm, null)!,
       this.contentStyleArg = $initArg('contentStyle', contentStyle, null),
       this.contentArg = $initArg('content', content, NullableStringArg(null))!,
       this.contentSpanArg = $initArg('contentSpan', contentSpan, null),
       this.titleArg = $initArg('title', title, StringArg('Are you sure?'))!,
       this.iconArg = $initArg('icon', icon, NullableStringArg(null))!,
       this.iconWidgetArg = $initArg('iconWidget', iconWidget, null),
       this.iconSizeArg = $initArg('iconSize', iconSize, DoubleArg(60))!,
       this.typeArg = $initArg(
         'type',
         type,
         EnumArg<ConfirmationDialogType>(
           ConfirmationDialogType.destructive,
           values: ConfirmationDialogType.values,
         ),
       )!,
       this.showCancelArg = $initArg('showCancel', showCancel, BoolArg(true))!,
       this.extraButtonsArg = $initArg(
         'extraButtons',
         extraButtons,
         ConstArg(const []),
       )!,
       this.contentWidgetArg = $initArg('contentWidget', contentWidget, null),
       this.scrollableArg = $initArg('scrollable', scrollable, BoolArg(false))!,
       this.keyArg = $initArg('key', key, null);

  ConfirmationDialogArgs.fixed({
    String confirmButtonText = '',
    required Future<void> Function() onConfirm,
    TextStyle? contentStyle,
    String? content = null,
    InlineSpan? contentSpan,
    String title = 'Are you sure?',
    String? icon = null,
    Widget? iconWidget,
    double iconSize = 60,
    ConfirmationDialogType type = ConfirmationDialogType.destructive,
    bool showCancel = true,
    List<ConfirmationDialogButton> extraButtons = const [],
    Widget? contentWidget,
    bool scrollable = false,
    Key? key,
  }) : this.confirmButtonTextArg = $initArg(
         'confirmButtonText',
         Arg.fixed(confirmButtonText),
         null,
       )!,
       this.onConfirmArg = $initArg('onConfirm', Arg.fixed(onConfirm), null)!,
       this.contentStyleArg = $initArg(
         'contentStyle',
         contentStyle == null ? null : Arg.fixed(contentStyle),
         null,
       ),
       this.contentArg = $initArg(
         'content',
         content == null ? null : Arg.fixed(content),
         null,
       ),
       this.contentSpanArg = $initArg(
         'contentSpan',
         contentSpan == null ? null : Arg.fixed(contentSpan),
         null,
       ),
       this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.iconArg = $initArg(
         'icon',
         icon == null ? null : Arg.fixed(icon),
         null,
       ),
       this.iconWidgetArg = $initArg(
         'iconWidget',
         iconWidget == null ? null : Arg.fixed(iconWidget),
         null,
       ),
       this.iconSizeArg = $initArg('iconSize', Arg.fixed(iconSize), null)!,
       this.typeArg = $initArg('type', Arg.fixed(type), null)!,
       this.showCancelArg = $initArg(
         'showCancel',
         Arg.fixed(showCancel),
         null,
       )!,
       this.extraButtonsArg = $initArg(
         'extraButtons',
         Arg.fixed(extraButtons),
         null,
       )!,
       this.contentWidgetArg = $initArg(
         'contentWidget',
         contentWidget == null ? null : Arg.fixed(contentWidget),
         null,
       ),
       this.scrollableArg = $initArg(
         'scrollable',
         Arg.fixed(scrollable),
         null,
       )!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> confirmButtonTextArg;

  final Arg<Future<void> Function()> onConfirmArg;

  final Arg<TextStyle?>? contentStyleArg;

  final Arg<String?>? contentArg;

  final Arg<InlineSpan?>? contentSpanArg;

  final Arg<String> titleArg;

  final Arg<String?>? iconArg;

  final Arg<Widget?>? iconWidgetArg;

  final Arg<double> iconSizeArg;

  final Arg<ConfirmationDialogType> typeArg;

  final Arg<bool> showCancelArg;

  final Arg<List<ConfirmationDialogButton>> extraButtonsArg;

  final Arg<Widget?>? contentWidgetArg;

  final Arg<bool> scrollableArg;

  final Arg<Key?>? keyArg;

  String get confirmButtonText => confirmButtonTextArg.value;

  Future<void> Function() get onConfirm => onConfirmArg.value;

  TextStyle? get contentStyle => contentStyleArg?.value;

  String? get content => contentArg?.value;

  InlineSpan? get contentSpan => contentSpanArg?.value;

  String get title => titleArg.value;

  String? get icon => iconArg?.value;

  Widget? get iconWidget => iconWidgetArg?.value;

  double get iconSize => iconSizeArg.value;

  ConfirmationDialogType get type => typeArg.value;

  bool get showCancel => showCancelArg.value;

  List<ConfirmationDialogButton> get extraButtons => extraButtonsArg.value;

  Widget? get contentWidget => contentWidgetArg?.value;

  bool get scrollable => scrollableArg.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [
    confirmButtonTextArg,
    onConfirmArg,
    contentStyleArg,
    contentArg,
    contentSpanArg,
    titleArg,
    iconArg,
    iconWidgetArg,
    iconSizeArg,
    typeArg,
    showCancelArg,
    extraButtonsArg,
    contentWidgetArg,
    scrollableArg,
    keyArg,
  ];
}
