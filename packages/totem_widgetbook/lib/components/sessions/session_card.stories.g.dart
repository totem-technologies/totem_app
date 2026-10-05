// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'session_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SessionCard, StoryArgs<SessionCard>>;
typedef _Scenario = SessionCardScenario;
typedef _Defaults = SessionCardDefaults;
typedef _Story = SessionCardStory;
typedef _Args = SessionCardArgs;
final SessionCardComponent = Component<SessionCard, StoryArgs<SessionCard>>(
  name: component.name ?? 'SessionCard',
  path: component.path ?? 'components/sessions',
  docsBuilder: component.docsBuilder,
  docComment:
      r'''Figma "Session Card — Session Screen" (3734:10290): photo on top,
time and seats, then the Space, the Session, and who holds it.
The calendar / Attend slot stays off — that variant hides it.

Native size is the Figma frame: 362 × 253, split evenly between the
photo and the white body. Width follows the parent; height keeps that
ratio so a narrower column doesn't squash the type against the picture.''',
  stories: [
    $Upcoming..$generatedName = 'Upcoming',
    $Tappable..$generatedName = 'Tappable',
    $NoKeeperPhoto..$generatedName = 'NoKeeperPhoto',
  ],
);
typedef SessionCardScenario = Scenario<SessionCard, SessionCardArgs>;
typedef SessionCardDefaults = Defaults<SessionCard, SessionCardArgs>;

class SessionCardStory extends Story<SessionCard, SessionCardArgs> {
  SessionCardStory({
    super.name,
    super.designLink,
    SetupBuilder<SessionCard, SessionCardArgs>? setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<SessionCard, SessionCardArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         builder:
             builder ??
             (context, args) => SessionCard(
               key: args.key,
               photo: args.photo,
               spaceName: args.spaceName,
               sessionName: args.sessionName,
               keeperName: args.keeperName,
               keeperPhoto: args.keeperPhoto,
               time: args.time,
               meridiem: args.meridiem,
               seatsLeft: args.seatsLeft,
               onSelect: args.onSelect,
             ),
         setup: setup ?? defaults.setup!,
       );
}

class SessionCardArgs extends StoryArgs<SessionCard> {
  SessionCardArgs({
    Arg<Key?>? key,
    required Arg<ImageProvider<Object>> photo,
    Arg<String>? spaceName,
    Arg<String>? sessionName,
    Arg<String>? keeperName,
    Arg<ImageProvider<Object>?>? keeperPhoto,
    Arg<String>? time,
    Arg<String>? meridiem,
    Arg<int>? seatsLeft,
    Arg<void Function()?>? onSelect,
  }) : this.keyArg = $initArg('key', key, null),
       this.photoArg = $initArg('photo', photo, null)!,
       this.spaceNameArg = $initArg('spaceName', spaceName, StringArg(''))!,
       this.sessionNameArg = $initArg(
         'sessionName',
         sessionName,
         StringArg(''),
       )!,
       this.keeperNameArg = $initArg('keeperName', keeperName, StringArg(''))!,
       this.keeperPhotoArg = $initArg('keeperPhoto', keeperPhoto, null),
       this.timeArg = $initArg('time', time, StringArg(''))!,
       this.meridiemArg = $initArg('meridiem', meridiem, StringArg(''))!,
       this.seatsLeftArg = $initArg('seatsLeft', seatsLeft, IntArg(0))!,
       this.onSelectArg = $initArg('onSelect', onSelect, null);

  SessionCardArgs.fixed({
    Key? key,
    required ImageProvider<Object> photo,
    String spaceName = '',
    String sessionName = '',
    String keeperName = '',
    ImageProvider<Object>? keeperPhoto,
    String time = '',
    String meridiem = '',
    int seatsLeft = 0,
    void Function()? onSelect,
  }) : this.keyArg = $initArg('key', key == null ? null : Arg.fixed(key), null),
       this.photoArg = $initArg('photo', Arg.fixed(photo), null)!,
       this.spaceNameArg = $initArg('spaceName', Arg.fixed(spaceName), null)!,
       this.sessionNameArg = $initArg(
         'sessionName',
         Arg.fixed(sessionName),
         null,
       )!,
       this.keeperNameArg = $initArg(
         'keeperName',
         Arg.fixed(keeperName),
         null,
       )!,
       this.keeperPhotoArg = $initArg(
         'keeperPhoto',
         keeperPhoto == null ? null : Arg.fixed(keeperPhoto),
         null,
       ),
       this.timeArg = $initArg('time', Arg.fixed(time), null)!,
       this.meridiemArg = $initArg('meridiem', Arg.fixed(meridiem), null)!,
       this.seatsLeftArg = $initArg('seatsLeft', Arg.fixed(seatsLeft), null)!,
       this.onSelectArg = $initArg(
         'onSelect',
         onSelect == null ? null : Arg.fixed(onSelect),
         null,
       );

  final Arg<Key?>? keyArg;

  final Arg<ImageProvider<Object>> photoArg;

  final Arg<String> spaceNameArg;

  final Arg<String> sessionNameArg;

  final Arg<String> keeperNameArg;

  final Arg<ImageProvider<Object>?>? keeperPhotoArg;

  final Arg<String> timeArg;

  final Arg<String> meridiemArg;

  final Arg<int> seatsLeftArg;

  final Arg<void Function()?>? onSelectArg;

  Key? get key => keyArg?.value;

  ImageProvider<Object> get photo => photoArg.value;

  String get spaceName => spaceNameArg.value;

  String get sessionName => sessionNameArg.value;

  String get keeperName => keeperNameArg.value;

  ImageProvider<Object>? get keeperPhoto => keeperPhotoArg?.value;

  String get time => timeArg.value;

  String get meridiem => meridiemArg.value;

  int get seatsLeft => seatsLeftArg.value;

  void Function()? get onSelect => onSelectArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    photoArg,
    spaceNameArg,
    sessionNameArg,
    keeperNameArg,
    keeperPhotoArg,
    timeArg,
    meridiemArg,
    seatsLeftArg,
    onSelectArg,
  ];
}
