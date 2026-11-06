import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_disconnected.stories.g.dart';

/// `RouteNames.session(':slug')` once the participant leaves the session.
const component = ComponentMeta(path: 'Screens/session/:slug');

/// Custom args: the promoted session is catalog data, so the knobs are the
/// disconnect reason, which promo shows, and the card text that changes
/// the layout.
const meta = Meta(
  SessionDisconnectedView.new,
  argsType: SessionDisconnectedInput.new,
);

enum NextSessionVariant { nextSession, recommended, none }

class SessionDisconnectedInput {
  const SessionDisconnectedInput({
    this.reason = SessionDisconnectedReason.keeperEnded,
    this.background = RoomStatus.ended,
    this.nextSession = NextSessionVariant.nextSession,
    this.showFeedback = true,
    this.spaceTitle = 'Community Connections',
    this.sessionTitle = 'Finding Home in New Places',
    this.keeperName = 'Daisy Mccoy',
    this.seatsLeft = 10,
  });

  final SessionDisconnectedReason reason;

  /// `ended` is the slate room. `waitingRoom` is the cream gradient the
  /// screen sits on when the room drops the participant.
  final RoomStatus background;
  final NextSessionVariant nextSession;

  /// The thumbs up/down bar. The app shows it only after the Keeper ends
  /// the session.
  final bool showFeedback;
  final String spaceTitle;
  final String sessionTitle;
  final String keeperName;
  final int seatsLeft;
}

/// The keeper avatar on the card reads the signed-in user.
class _SignedOutAuthController extends AuthController {
  @override
  AuthState build() => AuthState.unauthenticated();

  @override
  bool get isAuthenticated => false;

  @override
  UserSchema? get user => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> checkExistingAuth() async {}
}

MobileSpaceDetailSchema _space(SessionDisconnectedInputArgs args) {
  return MobileSpaceDetailSchema(
    slug: 'community-connections',
    title: args.spaceTitle,
    imageLink: null,
    shortDescription: '',
    content: '',
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: DateTime.utc(2024),
      name: Omittable(args.keeperName),
      slug: const Omittable('daisy-mccoy'),
    ),
    category: null,
    subscribers: 0,
    recurring: null,
    price: 0,
    nextEvents: [
      NextSessionSchema(
        slug: 'next-session',
        start: DateTime(2026, 11, 4, 18),
        link: '',
        title: args.sessionTitle,
        seatsLeft: args.seatsLeft,
        duration: 60,
        meetingProvider: MeetingProviderEnum.livekit,
        calLink: '',
        attending: false,
        cancelled: false,
        open: true,
        joinable: true,
      ),
    ],
  );
}

final defaults = _Defaults(
  setup: (context, child, args) => Story.defaultSetup(
    context,
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedOutAuthController.new),
      ],
      child: RoomBackground(
        status: args.background,
        child: SizedBox.expand(child: child),
      ),
    ),
    args,
  ),
  builder: (context, args) => SessionDisconnectedView(
    reason: args.reason,
    nextSession: switch (args.nextSession) {
      NextSessionVariant.none => null,
      NextSessionVariant.nextSession => NextSessionPromo(
        space: _space(args),
        onTap: noop,
      ),
      NextSessionVariant.recommended => NextSessionPromo(
        space: _space(args),
        recommended: true,
        onTap: noop,
      ),
    },
    onLike: args.showFeedback ? asyncNoop : null,
    onDislike: args.showFeedback ? (_) => asyncNoop() : null,
    onGoHome: noop,
  ),
);

/// One screen. The reason, the promo and the card text are args. Phone,
/// tablet, desktop and the short windows from TOT-1439 are scenarios.
final $Default = _Story(
  modes: [ViewportMode(TotemViewports.desktop)],
  scenarios: [
    for (final viewport in [
      TotemViewports.phone,
      TotemViewports.phoneLandscape,
      TotemViewports.tablet,
      TotemViewports.tabletLandscape,
      TotemViewports.desktop,
      TotemViewports.shortDesktop,
      TotemViewports.shortTablet,
      TotemViewports.shortLandscape,
    ])
      _Scenario(name: viewport.name, modes: [ViewportMode(viewport)]),
  ],
);
