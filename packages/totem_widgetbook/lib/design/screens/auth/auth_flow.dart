import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

part 'auth_parts.dart';
part 'auth_prompts.dart';
part 'auth_sheets.dart';
part 'auth_steps.dart';
part 'auth_welcome.dart';

const _assets = 'assets/design/auth';

/// The phone status bar is drawn by the device, not the screen.
const _statusBarHeight = 44.0;

/// One screen of Figma "User Auth Flow" (2427:790), in the order a new
/// member meets them.
enum AuthStep {
  /// Three photo slides: Welcome, Our Promise, Our Ask.
  welcome,

  /// Email entry (2427:791).
  getStarted,

  /// Six-digit code (2427:904).
  verifyCode,

  /// Community Guidelines (2427:804).
  guidelines,

  /// Notification permission ask (2427:1354).
  notifications,

  /// Name, age and how they heard about Totem (2427:918).
  profile,

  /// Communities that feel like home (2427:1058).
  communities,

  /// Spaces picked for them (2427:998).
  spaces,
}

/// Bottom sheet over the profile step.
enum AuthSheet {
  none,

  /// Avatar picker (2427:939).
  avatar,

  /// "How did you hear about us?" (2427:971).
  referral,
}

/// The system dialog that follows "Allow" on the notifications step.
enum NotificationPrompt {
  none,

  /// Figma 2428:1418.
  ios,

  /// Figma 2428:9895.
  android,
}

/// Avatar source in the avatar sheet.
enum AvatarStyle {
  tieDye('Tie Dye'),
  image('Image');

  const AvatarStyle(this.label);

  final String label;
}

/// Answers to "How did you hear about us?", in Figma order.
enum Referral {
  friendOrFamily('Friend or Family'),
  socialMedia('Social Media'),
  searchEngine('Google/Search Engine'),
  event('Event'),
  blog('Blog or Article'),
  other('Other');

  const Referral(this.label);

  final String label;
}

/// Communities on the "feels like home" step, in Figma order.
enum Community {
  love('Love & Emotions'),
  mothers('Mothers'),
  queer('Queer'),
  selfImprovement('Self-Improvement'),
  other('Other');

  const Community(this.label);

  final String label;
}

/// Figma "User Auth Flow" (2427:790): welcome slides, sign in by email
/// code, guidelines, notifications, then onboarding.
///
/// Every field shows what it is given; nothing is typed here. Callbacks
/// report what the member tapped, and the caller decides what changes.
/// [onNext] is the main button of whichever step is showing.
///
/// Fonts: Figma mixes Poppins and Work Sans into a few frames. The
/// catalog only ships Montserrat, so everything is set in it.
class AuthFlow extends StatelessWidget {
  const AuthFlow({
    super.key,
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
    this.communities = const {},
    this.onNext,
    this.onSkip,
    this.onResendCode,
    this.onPromptAnswer,
    this.onSheet,
    this.onAvatarStyle,
    this.onReferral,
    this.onNewsletter,
    this.onToggleCommunity,
  });

  final AuthStep step;

  /// Welcome slide, 0 to 2.
  final int welcomePage;

  final String email;

  /// Shown under the email field.
  final String? emailError;

  /// Digits typed so far, up to six.
  final String code;

  /// The code was wrong. The boxes turn red.
  final bool codeError;

  final NotificationPrompt notificationPrompt;

  final String name;
  final String age;
  final Referral? referral;
  final bool newsletter;
  final AuthSheet sheet;
  final AvatarStyle avatarStyle;
  final Set<Community> communities;

  /// The main button of the current step.
  final VoidCallback? onNext;

  /// "Skip" on the welcome slides, "Maybe later" on notifications.
  final VoidCallback? onSkip;
  final VoidCallback? onResendCode;

  /// Answer to the system dialog. True is Allow.
  final ValueChanged<bool>? onPromptAnswer;

  /// Opens a sheet, or closes it with [AuthSheet.none].
  final ValueChanged<AuthSheet>? onSheet;
  final ValueChanged<AvatarStyle>? onAvatarStyle;
  final ValueChanged<Referral>? onReferral;
  final ValueChanged<bool>? onNewsletter;
  final ValueChanged<Community>? onToggleCommunity;

  @override
  Widget build(BuildContext context) {
    final welcome = step == AuthStep.welcome;
    final page = welcomePage.clamp(0, _slides.length - 1);
    final covered =
        (step == AuthStep.profile && sheet != AuthSheet.none) ||
        (step == AuthStep.notifications &&
            notificationPrompt != NotificationPrompt.none);

    return ColoredBox(
      color: TotemColors.coreCream,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: covered,
            child: switch (step) {
              AuthStep.welcome => _Welcome(
                slide: _slides[page],
                page: page,
                onNext: onNext,
                onSkip: onSkip,
              ),
              AuthStep.getStarted => _GetStarted(
                email: email,
                error: emailError,
                onContinue: onNext,
              ),
              AuthStep.verifyCode => _VerifyCode(
                email: email.isEmpty ? 'your@email.com' : email,
                code: code,
                error: codeError,
                onVerify: onNext,
                onResend: onResendCode,
              ),
              AuthStep.guidelines => _Guidelines(onAgree: onNext),
              AuthStep.notifications => _Notifications(
                onAllow: onNext,
                onLater: onSkip,
              ),
              AuthStep.profile => _Profile(
                name: name,
                age: age,
                referral: referral,
                newsletter: newsletter,
                avatarStyle: avatarStyle,
                onAvatar: onSheet == null
                    ? null
                    : () => onSheet!(AuthSheet.avatar),
                onReferral: onSheet == null
                    ? null
                    : () => onSheet!(AuthSheet.referral),
                onNewsletter: onNewsletter,
                onContinue: onNext,
              ),
              AuthStep.communities => _Communities(
                selected: communities,
                onToggle: onToggleCommunity,
                onNext: onNext,
              ),
              AuthStep.spaces => _Spaces(onSeeMore: onNext),
            },
          ),
          if (step == AuthStep.profile && sheet != AuthSheet.none)
            _Sheet(
              onDismiss: onSheet == null
                  ? null
                  : () => onSheet!(AuthSheet.none),
              child: switch (sheet) {
                AuthSheet.avatar => _AvatarSheet(
                  style: avatarStyle,
                  onStyle: onAvatarStyle,
                  onSave: onSheet == null
                      ? null
                      : () => onSheet!(AuthSheet.none),
                ),
                _ => _ReferralSheet(
                  selected: referral,
                  onSelect: onReferral,
                  onSave: onSheet == null
                      ? null
                      : () => onSheet!(AuthSheet.none),
                ),
              },
            ),
          if (step == AuthStep.notifications)
            switch (notificationPrompt) {
              NotificationPrompt.none => const SizedBox.shrink(),
              NotificationPrompt.ios => _IosPrompt(onAnswer: onPromptAnswer),
              NotificationPrompt.android => _AndroidPrompt(
                onAnswer: onPromptAnswer,
              ),
            },
          // Phone home indicator. White over the photos, slate elsewhere,
          // and hidden while a sheet owns the bottom edge.
          if (!(step == AuthStep.profile && sheet != AuthSheet.none))
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: Spacing.homebarWidth,
                    height: 5,
                    decoration: BoxDecoration(
                      color: welcome
                          ? TotemColors.coreWhite
                          : const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
