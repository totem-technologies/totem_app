import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'auth.stories.g.dart';

/// One flow across `RouteNames.welcome`, `login`, `pinEntry` and
/// `onboarding`, so it sits under one `Screens/auth` entry.
const component = ComponentMeta(path: 'Screens/auth');

/// Custom args: every field and choice is a knob, and the buttons write
/// back to them, so the story can be clicked through end to end.
const meta = Meta(AuthFlow.new, argsType: AuthInput.new);

class AuthInput {
  const new({
    this.step = AuthStep.welcome,
    this.welcomePage = 0,
    this.email = '',
    this.emailError,
    this.code = '',
    this.codeError = false,
    this.notificationPrompt = NotificationPrompt.none,
    this.name = '',
    this.age = '',
    this.referral,
    this.newsletter = false,
    this.sheet = AuthSheet.none,
    this.avatarStyle = AvatarStyle.tieDye,
    this.communities = const [],
  });

  final AuthStep step;

  /// Welcome slide, 0 to 2.
  final int welcomePage;
  final String email;
  final String? emailError;

  /// Digits typed so far, up to six.
  final String code;
  final bool codeError;
  final NotificationPrompt notificationPrompt;
  final String name;
  final String age;
  final Referral? referral;
  final bool newsletter;
  final AuthSheet sheet;
  final AvatarStyle avatarStyle;
  final Iterable<Community> communities;
}

final defaults = _Defaults(
  setup: (context, child, args) => SizedBox.expand(child: child),
  builder: (context, args) {
    void go(AuthStep step) => args.stepArg.update(context, step);

    return AuthFlow(
      step: args.step,
      welcomePage: args.welcomePage,
      email: args.email,
      emailError: args.emailError,
      code: args.code,
      codeError: args.codeError,
      notificationPrompt: args.notificationPrompt,
      name: args.name,
      age: args.age,
      referral: args.referral,
      newsletter: args.newsletter,
      sheet: args.sheet,
      avatarStyle: args.avatarStyle,
      communities: args.communities.toSet(),
      onNext: () => switch (args.step) {
        AuthStep.welcome when args.welcomePage < 2 =>
          args.welcomePageArg.update(context, args.welcomePage + 1),
        AuthStep.welcome => go(AuthStep.getStarted),
        AuthStep.getStarted => go(AuthStep.verifyCode),
        AuthStep.verifyCode => go(AuthStep.guidelines),
        AuthStep.guidelines => go(AuthStep.notifications),
        AuthStep.notifications => args.notificationPromptArg.update(
          context,
          NotificationPrompt.ios,
        ),
        AuthStep.profile => go(AuthStep.communities),
        AuthStep.communities => go(AuthStep.spaces),
        AuthStep.spaces => null,
      },
      onSkip: () => go(
        args.step == AuthStep.welcome ? AuthStep.getStarted : AuthStep.profile,
      ),
      onResendCode: () {
        args.codeArg.update(context, '');
        args.codeErrorArg.update(context, false);
      },
      onPromptAnswer: (_) {
        args.notificationPromptArg.update(context, NotificationPrompt.none);
        go(AuthStep.profile);
      },
      onSheet: (sheet) => args.sheetArg.update(context, sheet),
      onAvatarStyle: (style) => args.avatarStyleArg.update(context, style),
      onReferral: (referral) => args.referralArg?.update(context, referral),
      onNewsletter: (value) => args.newsletterArg.update(context, value),
      onToggleCommunity: (community) {
        final selected = args.communities.toSet();
        if (!selected.remove(community)) selected.add(community);
        args.communitiesArg.update(context, selected);
      },
    );
  },
);

_Story _state(
  String name, {
  required String node,
  AuthStep step = AuthStep.welcome,
  int welcomePage = 0,
  String email = '',
  String? emailError,
  String code = '',
  bool codeError = false,
  NotificationPrompt notificationPrompt = NotificationPrompt.none,
  String profileName = '',
  String age = '',
  Referral? referral,
  bool newsletter = false,
  AuthSheet sheet = AuthSheet.none,
  AvatarStyle avatarStyle = AvatarStyle.tieDye,
  List<Community> communities = const [],
}) {
  return _Story(
    name: name,
    designLink: figma(node),
    args: _Args(
      step: EnumArg(step, values: AuthStep.values),
      welcomePage: IntArg(welcomePage),
      email: StringArg(email),
      emailError: NullableStringArg(emailError),
      code: StringArg(code),
      codeError: BoolArg(codeError),
      notificationPrompt: EnumArg(
        notificationPrompt,
        values: NotificationPrompt.values,
      ),
      name: StringArg(profileName),
      age: StringArg(age),
      referral: NullableEnumArg(referral, values: Referral.values),
      newsletter: BoolArg(newsletter),
      sheet: EnumArg(sheet, values: AuthSheet.values),
      avatarStyle: EnumArg(avatarStyle, values: AvatarStyle.values),
      communities: IterableArg(communities, values: Community.values),
    ),
    modes: [ViewportMode(TotemViewports.phone)],
  );
}

// Welcome slides.

final $Welcome = _state('Welcome', node: '2427:814');

final $OurPromise = _state('Our Promise', node: '2427:844', welcomePage: 1);

final $OurAsk = _state('Our Ask', node: '2427:874', welcomePage: 2);

// Sign in.

final $GetStarted = _state(
  'Get started',
  node: '2427:791',
  step: AuthStep.getStarted,
);

/// Not in Figma. The address was rejected.
final $GetStartedError = _state(
  'Get started, invalid email',
  node: '2427:791',
  step: AuthStep.getStarted,
  email: 'maria@',
  emailError: 'Enter a valid email address.',
);

final $VerifyCode = _state(
  'Verify code',
  node: '2427:904',
  step: AuthStep.verifyCode,
  email: 'maria@totem.org',
);

final $VerifyCodeTyping = _state(
  'Verify code, typing',
  node: '2427:904',
  step: AuthStep.verifyCode,
  email: 'maria@totem.org',
  code: '482',
);

/// Not in Figma. All six digits in and rejected.
final $VerifyCodeError = _state(
  'Verify code, wrong code',
  node: '2427:904',
  step: AuthStep.verifyCode,
  email: 'maria@totem.org',
  code: '482913',
  codeError: true,
);

final $Guidelines = _state(
  'Community guidelines',
  node: '2427:804',
  step: AuthStep.guidelines,
);

// Notifications.

final $Notifications = _state(
  'Notifications',
  node: '2427:1354',
  step: AuthStep.notifications,
);

final $NotificationsIos = _state(
  'Notifications, iOS prompt',
  node: '2428:1418',
  step: AuthStep.notifications,
  notificationPrompt: NotificationPrompt.ios,
);

final $NotificationsAndroid = _state(
  'Notifications, Android prompt',
  node: '2428:9895',
  step: AuthStep.notifications,
  notificationPrompt: NotificationPrompt.android,
);

// Onboarding.

final $Profile = _state('Profile', node: '2427:918', step: AuthStep.profile);

final $ProfileFilled = _state(
  'Profile, filled in',
  node: '2427:918',
  step: AuthStep.profile,
  profileName: 'Maria (she/her)',
  age: '34',
  referral: Referral.socialMedia,
  newsletter: true,
);

final $AvatarSheet = _state(
  'Profile, avatar sheet',
  node: '2427:939',
  step: AuthStep.profile,
  sheet: AuthSheet.avatar,
);

final $ReferralSheet = _state(
  'Profile, how did you hear',
  node: '2427:971',
  step: AuthStep.profile,
  sheet: AuthSheet.referral,
  referral: Referral.socialMedia,
);

final $Communities = _state(
  'Communities',
  node: '2427:1058',
  step: AuthStep.communities,
  communities: [Community.mothers],
);

final $Spaces = _state(
  'Spaces you’ll love',
  node: '2427:998',
  step: AuthStep.spaces,
);
