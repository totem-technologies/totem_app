import 'package:flutter/widgets.dart';
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
  const SessionEntryInput({
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

const _guests = ['Sara', 'Omar', 'Lina', 'Noah', 'Maya'];
const _expiries = ['1:47', '3:12', '4:05', '4:40', '5:15'];

final defaults = _Defaults(
  // Fill the device viewport. AlignmentAddon would otherwise keep
  // the screen at its intrinsic 812px Figma height.
  setup: (context, child, args) => SizedBox.expand(child: child),
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

/// One story per screen state. Captured on the phone by default, and at
/// each layout the screen has: phone sheets, window panel, web Session.
_Story _state(
  String name, {
  EntryRole role = EntryRole.participant,
  DetailsPhase phase = DetailsPhase.tooEarly,
  EntryStatus status = EntryStatus.browsing,
  int waiting = 0,
  bool panelOpen = false,
  bool showOrientation = false,
  DeclineVariant declineVariant = DeclineVariant.nextSession,
  String? expiresLabel,
  String? designLink,
}) {
  return _Story(
    name: name,
    designLink: designLink,
    args: _Args(
      role: EnumArg(role, values: EntryRole.values),
      phase: EnumArg(phase, values: DetailsPhase.values),
      status: EnumArg(status, values: EntryStatus.values),
      waiting: IntArg(waiting),
      panelOpen: BoolArg(panelOpen),
      showOrientation: BoolArg(showOrientation),
      declineVariant: EnumArg(declineVariant, values: DeclineVariant.values),
      expiresLabel: NullableStringArg(expiresLabel),
    ),
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
}

// Participant, in the order they meet it.

final $TooEarly = _state('Too early');

final $JoinWindow = _state('Join window', phase: DetailsPhase.joinWindow);

final $LobbyBeforeStart = _state(
  'Lobby, before start',
  phase: DetailsPhase.joinWindow,
  status: EntryStatus.lobby,
);

final $LobbyLate = _state(
  'Lobby, arrived late',
  phase: DetailsPhase.inProgress,
  status: EntryStatus.lobby,
  expiresLabel: '1:47',
);

final $AdmittedEarly = _state(
  'Admitted early',
  phase: DetailsPhase.joinWindow,
  status: EntryStatus.waitingRoom,
);

final $AdmittedLate = _state(
  'Admitted late',
  phase: DetailsPhase.inProgress,
  status: EntryStatus.inSession,
  showOrientation: true,
  designLink: figma('3800:10532'),
);

final $DeclinedNextSession = _state(
  'Declined, next Session',
  phase: DetailsPhase.inProgress,
  status: EntryStatus.declined,
);

final $DeclinedRelated = _state(
  'Declined, related Session',
  phase: DetailsPhase.inProgress,
  status: EntryStatus.declined,
  declineVariant: DeclineVariant.related,
);

// Keeper, same moments from the other side.

final $KeeperPreparing = _state(
  'Keeper preparing',
  role: EntryRole.keeper,
  phase: DetailsPhase.joinWindow,
);

final $KeeperOneRequest = _state(
  'Keeper, one request',
  role: EntryRole.keeper,
  phase: DetailsPhase.inProgress,
  waiting: 1,
  panelOpen: true,
);

final $KeeperSeveralRequests = _state(
  'Keeper, several requests',
  role: EntryRole.keeper,
  phase: DetailsPhase.inProgress,
  waiting: 3,
  panelOpen: true,
);

final $KeeperPanelClosed = _state(
  'Keeper, panel closed',
  role: EntryRole.keeper,
  phase: DetailsPhase.inProgress,
  waiting: 3,
);
