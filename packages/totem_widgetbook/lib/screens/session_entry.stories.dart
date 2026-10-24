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
