// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'update_available_dialog.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<UpdateAvailableDialog, StoryArgs<UpdateAvailableDialog>>;
typedef _Scenario = UpdateAvailableDialogScenario;
typedef _Defaults = UpdateAvailableDialogDefaults;
typedef _Story = UpdateAvailableDialogStory;
typedef _Args = UpdateAvailableDialogArgs;
final UpdateAvailableDialogComponent =
    Component<UpdateAvailableDialog, StoryArgs<UpdateAvailableDialog>>(
      name: component.name ?? 'UpdateAvailableDialog',
      path: component.path ?? 'components/dialogs',
      docsBuilder: component.docsBuilder,
      docComment:
          r'''Dialog shown when a newer store version of the mobile app is available.

Shares [TotemDialogLayout] with ConfirmationDialog but not its buttons:
ConfirmationDialog's Cancel / async busy handlers pop the route themselves,
while upgrader's `onUser*` callbacks also pop — reusing them would
double-pop. Used by the mobile upgrader integration in totem_app;
previewed in Widgetbook under Components/Dialogs.''',
      stories: [
        $Default..$generatedName = 'Default',
        $WithoutDismiss..$generatedName = 'WithoutDismiss',
      ],
    );
typedef UpdateAvailableDialogScenario =
    Scenario<UpdateAvailableDialog, UpdateAvailableDialogArgs>;
typedef UpdateAvailableDialogDefaults =
    Defaults<UpdateAvailableDialog, UpdateAvailableDialogArgs>;

class UpdateAvailableDialogStory
    extends Story<UpdateAvailableDialog, UpdateAvailableDialogArgs> {
  UpdateAvailableDialogStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<UpdateAvailableDialog, UpdateAvailableDialogArgs>?
    builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => UpdateAvailableDialog(
               title: args.title,
               message: args.message,
               updateButtonText: args.updateButtonText,
               onUpdate: args.onUpdate,
               prompt: args.prompt,
               laterButtonText: args.laterButtonText,
               onLater: args.onLater,
               icon: args.icon,
               iconSize: args.iconSize,
               key: args.key,
             ),
       );
}

class UpdateAvailableDialogArgs extends StoryArgs<UpdateAvailableDialog> {
  UpdateAvailableDialogArgs({
    Arg<String>? title,
    Arg<String>? message,
    Arg<String>? updateButtonText,
    required Arg<void Function()> onUpdate,
    Arg<String?>? prompt,
    Arg<String?>? laterButtonText,
    Arg<void Function()?>? onLater,
    Arg<String?>? icon,
    Arg<double>? iconSize,
    Arg<Key?>? key,
  }) : this.titleArg = $initArg('title', title, StringArg(''))!,
       this.messageArg = $initArg('message', message, StringArg(''))!,
       this.updateButtonTextArg = $initArg(
         'updateButtonText',
         updateButtonText,
         StringArg(''),
       )!,
       this.onUpdateArg = $initArg('onUpdate', onUpdate, null)!,
       this.promptArg = $initArg('prompt', prompt, NullableStringArg(null))!,
       this.laterButtonTextArg = $initArg(
         'laterButtonText',
         laterButtonText,
         NullableStringArg(null),
       )!,
       this.onLaterArg = $initArg('onLater', onLater, null),
       this.iconArg = $initArg(
         'icon',
         icon,
         NullableStringArg(TotemIcons.downloadApp),
       )!,
       this.iconSizeArg = $initArg('iconSize', iconSize, DoubleArg(60))!,
       this.keyArg = $initArg('key', key, null);

  UpdateAvailableDialogArgs.fixed({
    String title = '',
    String message = '',
    String updateButtonText = '',
    required void Function() onUpdate,
    String? prompt = null,
    String? laterButtonText = null,
    void Function()? onLater,
    String? icon = TotemIcons.downloadApp,
    double iconSize = 60,
    Key? key,
  }) : this.titleArg = $initArg('title', Arg.fixed(title), null)!,
       this.messageArg = $initArg('message', Arg.fixed(message), null)!,
       this.updateButtonTextArg = $initArg(
         'updateButtonText',
         Arg.fixed(updateButtonText),
         null,
       )!,
       this.onUpdateArg = $initArg('onUpdate', Arg.fixed(onUpdate), null)!,
       this.promptArg = $initArg(
         'prompt',
         prompt == null ? null : Arg.fixed(prompt),
         null,
       ),
       this.laterButtonTextArg = $initArg(
         'laterButtonText',
         laterButtonText == null ? null : Arg.fixed(laterButtonText),
         null,
       ),
       this.onLaterArg = $initArg(
         'onLater',
         onLater == null ? null : Arg.fixed(onLater),
         null,
       ),
       this.iconArg = $initArg(
         'icon',
         icon == null ? null : Arg.fixed(icon),
         null,
       ),
       this.iconSizeArg = $initArg('iconSize', Arg.fixed(iconSize), null)!,
       this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null);

  final Arg<String> titleArg;

  final Arg<String> messageArg;

  final Arg<String> updateButtonTextArg;

  final Arg<void Function()> onUpdateArg;

  final Arg<String?>? promptArg;

  final Arg<String?>? laterButtonTextArg;

  final Arg<void Function()?>? onLaterArg;

  final Arg<String?>? iconArg;

  final Arg<double> iconSizeArg;

  final Arg<Key?>? keyArg;

  String get title => titleArg.value;

  String get message => messageArg.value;

  String get updateButtonText => updateButtonTextArg.value;

  void Function() get onUpdate => onUpdateArg.value;

  String? get prompt => promptArg?.value;

  String? get laterButtonText => laterButtonTextArg?.value;

  void Function()? get onLater => onLaterArg?.value;

  String? get icon => iconArg?.value;

  double get iconSize => iconSizeArg.value;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [
    titleArg,
    messageArg,
    updateButtonTextArg,
    onUpdateArg,
    promptArg,
    laterButtonTextArg,
    onLaterArg,
    iconArg,
    iconSizeArg,
    keyArg,
  ];
}
