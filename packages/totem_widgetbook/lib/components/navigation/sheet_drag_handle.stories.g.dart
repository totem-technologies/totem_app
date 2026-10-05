// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'sheet_drag_handle.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SheetDragHandle, StoryArgs<SheetDragHandle>>;
typedef _Scenario = SheetDragHandleScenario;
typedef _Defaults = SheetDragHandleDefaults;
typedef _Story = SheetDragHandleStory;
typedef _Args = SheetDragHandleArgs;
final SheetDragHandleComponent =
    Component<SheetDragHandle, StoryArgs<SheetDragHandle>>(
      name: component.name ?? 'SheetDragHandle',
      path: component.path ?? 'components/navigation',
      docsBuilder: component.docsBuilder,
      docComment: null,
      stories: [$Default..$generatedName = 'Default'],
    );
typedef SheetDragHandleScenario =
    Scenario<SheetDragHandle, SheetDragHandleArgs>;
typedef SheetDragHandleDefaults =
    Defaults<SheetDragHandle, SheetDragHandleArgs>;

class SheetDragHandleStory extends Story<SheetDragHandle, SheetDragHandleArgs> {
  SheetDragHandleStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    SheetDragHandleArgs? args,
    StoryWidgetBuilder<SheetDragHandle, SheetDragHandleArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? SheetDragHandleArgs(),
         builder:
             builder ??
             (context, args) =>
                 SheetDragHandle(key: args.key, margin: args.margin),
       );
}

class SheetDragHandleArgs extends StoryArgs<SheetDragHandle> {
  SheetDragHandleArgs({Arg<Key?>? key, Arg<EdgeInsetsGeometry>? margin})
    : this.keyArg = $initArg('key', key, null),
      this.marginArg = $initArg(
        'margin',
        margin,
        ConstArg(const EdgeInsetsDirectional.only(top: 20, bottom: 20)),
      )!;

  SheetDragHandleArgs.fixed({
    Key? key,
    EdgeInsetsGeometry margin = const EdgeInsetsDirectional.only(
      top: 20,
      bottom: 20,
    ),
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.marginArg = $initArg('margin', Arg.fixed(margin), null)!;

  final Arg<Key?>? keyArg;

  final Arg<EdgeInsetsGeometry> marginArg;

  Key? get key => keyArg?.value;

  EdgeInsetsGeometry get margin => marginArg.value;

  @override
  List<Arg?> get list => [keyArg, marginArg];
}
