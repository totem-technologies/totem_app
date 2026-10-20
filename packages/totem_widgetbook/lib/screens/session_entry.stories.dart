import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_info_card.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_entry.stories.g.dart';

const component = ComponentMeta(path: 'Screens/session/:slug');

/// Custom args: the Keeper's queue is a count of guests rather than a
/// list, and every callback writes back to a knob — Admit shrinks the
/// queue, closing the panel flips `panelOpen`, Join moves to the lobby.
const meta = Meta(SessionEntry.new, argsType: SessionEntryInput.new);

class SessionEntryInput {
  const new({
    this.role = EntryRole.participant,
    this.phase = DetailsPhase.tooEarly,
    this.status = EntryStatus.browsing,
    this.waiting = 0,
    this.panelOpen = false,
    this.showOrientation = false,
    this.declineVariant = DeclineVariant.nextSession,
    this.expiresLabel,
  });

  final EntryRole role;
  final DetailsPhase phase;
  final EntryStatus status;

  /// People waiting to be admitted. Keeper only.
  final int waiting;
  final bool panelOpen;
  final bool showOrientation;
  final DeclineVariant declineVariant;

  /// The participant's own request countdown, e.g. `1:47`.
  final String? expiresLabel;
}

const _spaceName = 'Shame & Self-Worth';
const _sessionName = 'Letting Shame Fall Away';
const _details = 'assets/design/session_entry';

const _nextOffer = SessionCard(
  photo: AssetImage('assets/design/session_card/photo.jpg'),
  spaceName: _spaceName,
  sessionName: 'After the Storm',
  keeperName: 'Vanessa',
  keeperPhoto: AssetImage('$_details/avatar-vanessa.png'),
  time: '6:30',
  meridiem: 'PM',
  seatsLeft: 5,
);
const _relatedOffer = SessionCard(
  photo: AssetImage('$_details/similar.jpg'),
  spaceName: _spaceName,
  sessionName: 'Holding the Hard Thing',
  keeperName: 'Jonah',
  time: '7:00',
  meridiem: 'PM',
  seatsLeft: 3,
);

const _facts = [
  (icon: 'icon-subscribers', value: '9', label: 'subscribers'),
  (icon: 'icon-duration', value: '60', label: 'min'),
  (icon: 'icon-seats', value: '9', label: 'seats left'),
  (icon: 'icon-repeat', value: '', label: 'Twice a month'),
  (icon: 'icon-cost', value: '', label: 'No Cost'),
];

const _guests = ['Sara', 'Omar', 'Lina', 'Noah', 'Maya'];
const _expiries = ['1:47', '3:12', '4:05', '4:40', '5:15'];

final defaults = _Defaults(
  // Fill the device viewport. AlignmentAddon would otherwise keep
  // the screen at its intrinsic 812px Figma height.
  //
  // The default setup also keys the child on the current args. This
  // screen is stateful (mic, camera, the admission sheet). Without
  // that key it keeps the first state, and the args panel looks dead.
  setup: (context, child, args) =>
      Story.defaultSetup(context, SizedBox.expand(child: child), args),
  builder: (context, args) {
    final waiting = args.waiting.clamp(0, _guests.length);
    void shrinkQueue() {
      args.waitingArg.update(context, waiting - 1);
      if (waiting <= 1) args.panelOpenArg.update(context, false);
    }

    return SessionEntry(
      role: args.role,
      phase: args.phase,
      status: args.status,
      spaceName: _spaceName,
      sessionName: _sessionName,
      keeperName: 'Vanessa',
      startDateLabel: 'Wednesday, February 11th',
      startTime: '6:30 PM GMT',
      joinTime: '6:20 PM GMT',
      participantName: 'Alex',
      previewPhoto: const AssetImage(
        'assets/design/participant_card/preview.jpg',
      ),
      heroPhoto: const AssetImage('$_details/hero.jpg'),
      keeperPhoto: const AssetImage('$_details/avatar-vanessa.png'),
      about: "Shame is loud, and it lies. This circle is where you turn the volume down. Nobody fixes you, nobody gives advice, and nobody performs. You share when the talking piece reaches you and listen when it doesn't.\n\nCome as you are. Camera on is lovely. Camera off is fine. You can pass on any turn — that counts as a full turn.",
      similarSession: const SessionCard(
        photo: AssetImage('$_details/similar.jpg'),
        spaceName: 'What is Love?',
        sessionName: 'The Fear of Being Loved',
        keeperName: 'Heather',
        keeperPhoto: AssetImage('$_details/avatar-heather.png'),
        time: '8:30',
        meridiem: 'PM',
        seatsLeft: 2,
      ),
      keeperLocation: 'Earth',
      keeperBio: "Vanessa is a Los Angeles-based artist and recovering hot mess. She's battled many challenges, from undiagnosed depression to struggling with alcohol abuse, and knows first hand how hard it is to face complex emotions alone.",
      onShare: () {},
      onKeeperProfile: () {},
      prompt: 'What are you ready to set down?',
      facts: [
        for (final fact in _facts)
          SessionEntryFact(
            icon: SvgPicture.asset(
              '$_details/${fact.icon}.svg',
              width: 16.4646,
              height: 16.4646,
            ),
            value: fact.value,
            label: fact.label,
          ),
      ],
      nextOffer: _nextOffer,
      relatedOffer: _relatedOffer,
      requests: [
        for (var i = 0; i < waiting; i++)
          AdmissionRequest(
            id: _guests[i],
            name: _guests[i],
            expiresLabel: _expiries[i],
          ),
      ],
      panelOpen: args.panelOpen,
      showOrientation: args.showOrientation,
      declineVariant: args.declineVariant,
      expiresLabel: args.expiresLabel,
      onJoin: () => args.statusArg.update(context, EntryStatus.lobby),
      onLeaveLobby: () => args.statusArg.update(context, EntryStatus.browsing),
      onSignUp: () {},
      onBackToSpace: () => args.statusArg.update(context, EntryStatus.browsing),
      onAdmit: (_) => shrinkQueue(),
      onDeclineRequest: (_) => shrinkQueue(),
      onAdmitAll: () {
        args.waitingArg.update(context, 0);
        args.panelOpenArg.update(context, false);
      },
      onOpenPanel: () => args.panelOpenArg.update(context, true),
      onDismissPanel: () => args.panelOpenArg.update(context, false),
      onDismissOrientation: () =>
          args.showOrientationArg.update(context, false),
    );
  },
);

/// One screen. Role, phase, status, and the queue are args, so the
/// right panel moves through every state this screen has.
///
/// Starts where a participant lands: too early to join. Phone, tablet,
/// and desktop are scenarios of this same screen.
final $Default = _Story(
  designLink: figma('3800:10532'),
  modes: [ViewportMode(TotemViewports.phone)],
  scenarios: [
    for (final viewport in [
      TotemViewports.phone,
      TotemViewports.tablet,
      TotemViewports.desktop,
    ])
      _Scenario(name: viewport.name, modes: [ViewportMode(viewport)]),
  ],
);
