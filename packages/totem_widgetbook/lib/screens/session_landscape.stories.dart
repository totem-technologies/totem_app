import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_landscape.stories.g.dart';

const component = ComponentMeta(path: 'Screens/session/landscape');

/// Custom args: turn, headcount, prompt, and media are knobs. Photos are
/// seeded from the count so crop review stays about tile geometry.
const meta = Meta(SessionLandscape.new, argsType: SessionLandscapeInput.new);

class SessionLandscapeInput {
  const SessionLandscapeInput({
    this.turn = LandscapeTurn.listening,
    this.participantCount = 4,
    this.prompt = '"What are you ready to set down?"',
    this.micOn = true,
    this.cameraOn = true,
  });

  final LandscapeTurn turn;

  /// People in the circle, including you. Listening features the first
  /// person; speaking puts you in the self-view and everyone else in the
  /// equal grid.
  final int participantCount;
  final String prompt;
  final bool micOn;
  final bool cameraOn;
}

const _photoA = AssetImage(
  'assets/design/participant_card/participant-photo.jpg',
);
const _photoB = AssetImage('assets/design/participant_card/preview.jpg');
const _photoC = AssetImage('assets/design/session_card/photo.jpg');

/// Still stands in for camera. The environmental frame ([_photoC]) is the
/// crop test: a tall portrait still inside a 4:3 tile should keep the
/// subject and a strip of room, not punch in to a face.
const _photos = <ImageProvider?>[_photoA, _photoB, _photoC, null];

const _names = [
  'Noah',
  'Maya',
  'Sam',
  'Jules',
  'Priya',
  'Liam',
  'Oliver',
  'Mason',
  'Sara',
  'Omar',
  'Lina',
  'Alex',
];

List<LandscapePerson> _circle(int count) {
  final n = count.clamp(1, _names.length);
  // A lone featured speaker is not you — that's the takeover case.
  // Otherwise Alex sits last so speaking gets a self-view.
  if (n == 1) {
    return [LandscapePerson(name: _names.first, photo: _photos.first)];
  }
  return [
    for (var i = 0; i < n - 1; i++)
      LandscapePerson(name: _names[i], photo: _photos[i % _photos.length]),
    const LandscapePerson(name: 'Alex', photo: _photoB, isYou: true),
  ];
}

String? _nextName(List<LandscapePerson> people, LandscapeTurn turn) {
  if (people.length < 2) return null;
  if (turn == LandscapeTurn.speaking) {
    return people
        .firstWhere((person) => !person.isYou, orElse: () => people.first)
        .name;
  }
  return people[1].name;
}

final defaults = _Defaults(
  // Fill the viewport, but keep Widgetbook's arg-keyed setup so
  // changing turn / count rebuilds the stage instead of reusing
  // the first listening tree.
  setup: (context, child, args) =>
      SizedBox.expand(child: Story.defaultSetup(context, child, args)),
  builder: (context, args) {
    final people = _circle(args.participantCount);
    return SessionLandscape(
      turn: args.turn,
      people: people,
      prompt: args.prompt,
      nextName: _nextName(people, args.turn),
      micOn: args.micOn,
      cameraOn: args.cameraOn,
      onMic: () => args.micOnArg.update(context, !args.micOn),
      onCamera: () => args.cameraOnArg.update(context, !args.cameraOn),
    );
  },
);

/// One story. Scrub turn, headcount, prompt, and media in Args.
final $Default = _Story(
  modes: [ViewportMode(TotemViewports.phoneLandscape)],
  args: _Args(
    turn: EnumArg(LandscapeTurn.listening, values: LandscapeTurn.values),
    participantCount: IntArg(4),
    prompt: StringArg('"What are you ready to set down?"'),
    micOn: BoolArg(true),
    cameraOn: BoolArg(true),
  ),
);
