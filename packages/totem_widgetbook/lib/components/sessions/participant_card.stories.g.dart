// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'participant_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ParticipantCard, StoryArgs<ParticipantCard>>;
typedef _Scenario = ParticipantCardScenario;
typedef _Defaults = ParticipantCardDefaults;
typedef _Story = ParticipantCardStory;
typedef _Args = ParticipantCardArgs;
final ParticipantCardComponent =
    Component<ParticipantCard, StoryArgs<ParticipantCard>>(
      name: component.name ?? 'ParticipantCard',
      path: component.path ?? 'components/sessions',
      docsBuilder: component.docsBuilder,
      docComment:
          r'''One tile for the circle and the waiting-room preview. Video (or a still)
fills the card edge to edge. No picture? The Figma wash sits
underneath so the name still reads. The name sits low and centered;
more sits top right; the talking piece sits top left when this
person holds it.

Type, radius, and inset all scale with the card's own size, measured
against the 180 × 220 Figma card. Each proportion is written against
both sides and the smaller wins, so a short, wide gallery tile scales
down the same way a narrow one does. Values stop at the Figma size, so
big speaker tiles don't blow up. The speaker tile on web (3800:10538)
lets the name grow with the frame.''',
      stories: [
        $InTheCircle..$generatedName = 'InTheCircle',
        $CameraOff..$generatedName = 'CameraOff',
        $TalkingPiece..$generatedName = 'TalkingPiece',
        $WaitingRoom..$generatedName = 'WaitingRoom',
        $Speaker..$generatedName = 'Speaker',
        $SmallTile..$generatedName = 'SmallTile',
      ],
    );
typedef ParticipantCardScenario =
    Scenario<ParticipantCard, ParticipantCardArgs>;
typedef ParticipantCardDefaults =
    Defaults<ParticipantCard, ParticipantCardArgs>;

class ParticipantCardStory extends Story<ParticipantCard, ParticipantCardArgs> {
  ParticipantCardStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    ParticipantCardArgs? args,
    StoryWidgetBuilder<ParticipantCard, ParticipantCardArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? ParticipantCardArgs(),
         builder:
             builder ??
             (context, args) => ParticipantCard(
               key: args.key,
               name: args.name,
               photo: args.photo,
               background: args.background,
               onMore: args.onMore,
               showMore: args.showMore,
               showTalkingPiece: args.showTalkingPiece,
               feature: args.feature,
             ),
       );
}

class ParticipantCardArgs extends StoryArgs<ParticipantCard> {
  ParticipantCardArgs({
    Arg<Key?>? key,
    Arg<String>? name,
    Arg<ImageProvider<Object>?>? photo,
    Arg<Gradient?>? background,
    Arg<void Function()?>? onMore,
    Arg<bool>? showMore,
    Arg<bool>? showTalkingPiece,
    Arg<bool>? feature,
  }) : this.keyArg = $initArg('key', key, null),
       this.nameArg = $initArg('name', name, StringArg(''))!,
       this.photoArg = $initArg('photo', photo, null),
       this.backgroundArg = $initArg('background', background, null),
       this.onMoreArg = $initArg('onMore', onMore, null),
       this.showMoreArg = $initArg('showMore', showMore, BoolArg(true))!,
       this.showTalkingPieceArg = $initArg(
         'showTalkingPiece',
         showTalkingPiece,
         BoolArg(false),
       )!,
       this.featureArg = $initArg('feature', feature, BoolArg(false))!;

  ParticipantCardArgs.fixed({
    Key? key,
    String name = '',
    ImageProvider<Object>? photo,
    Gradient? background,
    void Function()? onMore,
    bool showMore = true,
    bool showTalkingPiece = false,
    bool feature = false,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.nameArg = $initArg('name', Arg.fixed(name), null)!,
       this.photoArg = $initArg(
         'photo',
         photo == null ? null : Arg.fixed(photo),
         null,
       ),
       this.backgroundArg = $initArg(
         'background',
         background == null ? null : Arg.fixed(background),
         null,
       ),
       this.onMoreArg = $initArg(
         'onMore',
         onMore == null ? null : Arg.fixed(onMore),
         null,
       ),
       this.showMoreArg = $initArg('showMore', Arg.fixed(showMore), null)!,
       this.showTalkingPieceArg = $initArg(
         'showTalkingPiece',
         Arg.fixed(showTalkingPiece),
         null,
       )!,
       this.featureArg = $initArg('feature', Arg.fixed(feature), null)!;

  final Arg<Key?>? keyArg;

  final Arg<String> nameArg;

  final Arg<ImageProvider<Object>?>? photoArg;

  final Arg<Gradient?>? backgroundArg;

  final Arg<void Function()?>? onMoreArg;

  final Arg<bool> showMoreArg;

  final Arg<bool> showTalkingPieceArg;

  final Arg<bool> featureArg;

  Key? get key => keyArg?.value;

  String get name => nameArg.value;

  ImageProvider<Object>? get photo => photoArg?.value;

  Gradient? get background => backgroundArg?.value;

  void Function()? get onMore => onMoreArg?.value;

  bool get showMore => showMoreArg.value;

  bool get showTalkingPiece => showTalkingPieceArg.value;

  bool get feature => featureArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    nameArg,
    photoArg,
    backgroundArg,
    onMoreArg,
    showMoreArg,
    showTalkingPieceArg,
    featureArg,
  ];
}
