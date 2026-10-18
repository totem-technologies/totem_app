part of 'auth_flow.dart';

class _GetStarted extends StatelessWidget {
  const _GetStarted({
    required this.email,
    required this.error,
    required this.onContinue,
  });

  final String email;
  final String? error;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final fine = TotemText.raw(size: 8, color: _fine);
    final link = fine.copyWith(
      color: TotemColors.coreMauve,
      decoration: TextDecoration.underline,
      decorationColor: TotemColors.coreMauve,
    );

    return _CardPage(
      children: [
        const SizedBox(height: Spacing.s24),
        Text(
          'Get Started',
          textAlign: TextAlign.center,
          style: TotemText.raw(size: 32, weight: FontWeight.w600, color: _ink),
        ),
        Text(
          'Enter your email here to receive a verification code.',
          textAlign: TextAlign.center,
          style: TotemText.raw(size: 12, weight: FontWeight.w300, color: _ink),
        ),
        const SizedBox(height: Spacing.s8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            _Field(value: email, placeholder: 'Email', error: error != null),
            if (error case final error?)
              Text(
                error,
                style: TotemText.raw(
                  size: 10,
                  weight: FontWeight.w500,
                  color: TotemColors.semanticError,
                ),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text.rich(
              TextSpan(
                style: fine,
                children: [
                  const TextSpan(text: 'By continuing, you agree to our\n'),
                  TextSpan(text: 'Terms of Service', style: link),
                  const TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy Policies', style: link),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            _AuthButton(label: 'Continue', onTap: onContinue),
          ],
        ),
        const SizedBox(height: Spacing.s24),
      ],
    );
  }
}

class _VerifyCode extends StatelessWidget {
  const _VerifyCode({
    required this.email,
    required this.code,
    required this.error,
    required this.onVerify,
    required this.onResend,
  });

  final String email;
  final String code;
  final bool error;
  final VoidCallback? onVerify;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final body = TotemText.raw(size: 14, color: _body);
    final digits = code.characters.take(6).toList();

    return _CardPage(
      spacing: 40,
      children: [
        Column(
          spacing: 10,
          children: [
            Text(
              'Enter verification\ncode',
              textAlign: TextAlign.center,
              style: TotemText.raw(
                size: 28,
                weight: FontWeight.w600,
                height: 1.25,
                color: const Color(0xFF000000),
              ),
            ),
            Text.rich(
              TextSpan(
                style: body,
                children: [
                  const TextSpan(
                    text: 'We sent a 6-digit code to your email at ',
                  ),
                  TextSpan(
                    text: email,
                    style: body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '. Please enter it below.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4.665,
          children: [
            Text(
              'Enter 6-digit code',
              style: TotemText.raw(
                size: 13.06,
                weight: FontWeight.w500,
                color: const Color(0xFF000000),
              ),
            ),
            Semantics(
              textField: true,
              label: 'Verification code',
              value: code,
              child: ExcludeSemantics(
                child: Row(
                  spacing: 1.866,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _fieldFill,
                              borderRadius: BorderRadius.circular(Radii.lg),
                              border: error
                                  ? Border.all(
                                      color: TotemColors.semanticError,
                                      width: 2,
                                    )
                                  : i == digits.length
                                  ? Border.all(
                                      color: TotemColors.coreMauve,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              i < digits.length ? digits[i] : '0',
                              style: TotemText.raw(
                                size: 18.66,
                                weight: FontWeight.w500,
                                color: i < digits.length
                                    ? TotemColors.coreSlate
                                    : _placeholder,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (error)
              Text(
                "That code didn't work. Check it and try again.",
                style: TotemText.raw(
                  size: 10,
                  weight: FontWeight.w500,
                  color: TotemColors.semanticError,
                ),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _AuthButton(
              label: 'Verify Code',
              onTap: digits.length == 6 ? onVerify : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Need a new code? ',
                  style: TotemText.raw(
                    size: 12,
                    weight: FontWeight.w500,
                    color: const Color(0xFF000000),
                  ),
                ),
                Pressable(
                  onTap: onResend,
                  focusColor: _violet,
                  focusRadius: BorderRadius.circular(Radii.sm),
                  builder: (context, states) => Text(
                    'Send again',
                    style:
                        TotemText.raw(
                          size: 12,
                          weight: FontWeight.w500,
                          color: _violet,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: _violet,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Guidelines extends StatelessWidget {
  const _Guidelines({required this.onAgree});

  final VoidCallback? onAgree;

  @override
  Widget build(BuildContext context) {
    final body = TotemText.raw(size: 12, weight: FontWeight.w300, color: _ink);
    final bold = body.copyWith(fontWeight: FontWeight.w700);

    return _CardPage(
      children: [
        const SizedBox(height: Spacing.s16),
        Text(
          'Community Guidelines',
          textAlign: TextAlign.center,
          style: TotemText.h2.copyWith(color: _ink),
        ),
        Text.rich(
          TextSpan(
            style: body,
            children: [
              const TextSpan(
                text:
                    'In order to keep Totem safe, we require everyone adhere '
                    'to ',
              ),
              TextSpan(text: 'confidentiality', style: bold),
              const TextSpan(
                text:
                    '. Breaking confidentiality can be grounds for account '
                    'removal.\n\nWe also encourage you to only speak about ',
              ),
              TextSpan(text: 'your own experience', style: bold),
              const TextSpan(
                text:
                    ", and not to share other people's information or "
                    'stories.\n\nFor more details, see the full ',
              ),
              TextSpan(
                text: 'Community Guidelines',
                style: body.copyWith(
                  color: _violet,
                  decoration: TextDecoration.underline,
                  decorationColor: _violet,
                ),
              ),
              TextSpan(
                text: '.',
                style: body.copyWith(color: _violet),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.s4),
        _AuthButton(label: 'Agree and Continue', onTap: onAgree),
        const SizedBox(height: Spacing.s16),
      ],
    );
  }
}

class _Notifications extends StatelessWidget {
  const _Notifications({required this.onAllow, required this.onLater});

  final VoidCallback? onAllow;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    return _CardPage(
      children: [
        SvgPicture.asset('$_assets/icon-bell.svg', width: 60, height: 60),
        Text(
          'Want to stay update to date?',
          textAlign: TextAlign.center,
          style: TotemText.h2.copyWith(color: _ink),
        ),
        Text(
          'Allow Totem to send you notification about session, new blog and '
          'more.',
          textAlign: TextAlign.center,
          style: TotemText.body1.copyWith(color: _ink),
        ),
        _AuthButton(label: 'Allow', onTap: onAllow),
        Center(
          child: Pressable(
            onTap: onLater,
            focusColor: TotemColors.coreGray,
            focusRadius: BorderRadius.circular(Radii.sm),
            builder: (context, states) => Text(
              'Maybe later',
              style: TotemText.raw(
                size: 12,
                weight: FontWeight.w500,
                color: TotemColors.coreGray,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Round avatar with a 41px badge on its lower right.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.style, required this.badge, this.onTap});

  final AvatarStyle style;

  /// Edit on the profile card, shuffle in the avatar sheet.
  final Widget badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox.square(
      dimension: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: style == AvatarStyle.tieDye
                ? SvgPicture.asset(
                    '$_assets/avatar-tie-dye.svg',
                    width: 100,
                    height: 100,
                  )
                : Image.asset(
                    '$_assets/avatar-maria.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
          ),
          badge,
        ],
      ),
    );

    return Center(
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.96,
        focusColor: TotemColors.coreMauve,
        focusRadius: BorderRadius.circular(Radii.full),
        semanticLabel: 'Change avatar',
        builder: (context, states) => avatar,
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.name,
    required this.age,
    required this.referral,
    required this.newsletter,
    required this.avatarStyle,
    required this.onAvatar,
    required this.onReferral,
    required this.onNewsletter,
    required this.onContinue,
  });

  final String name;
  final String age;
  final Referral? referral;
  final bool newsletter;
  final AvatarStyle avatarStyle;
  final VoidCallback? onAvatar;
  final VoidCallback? onReferral;
  final ValueChanged<bool>? onNewsletter;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _CardPage(
      spacing: Spacing.s20,
      children: [
        const _Heading(
          title: 'Let’s get to know you',
          subtitle:
              'We just to know more about you. some final question and '
              'you’ll be good to go.',
        ),
        _Avatar(
          style: avatarStyle,
          onTap: onAvatar,
          badge: Positioned(
            left: 62,
            top: 70,
            child: SvgPicture.asset(
              '$_assets/badge-edit.svg',
              width: 41,
              height: 41,
            ),
          ),
        ),
        _LabeledField(
          label: 'What do you like to be called?',
          value: name,
          placeholder: 'Enter name',
          hint:
              'Other people will see this, but you don’t have to use your '
              'real name. Add any pronounce is parentheses if you’d like.',
        ),
        _LabeledField(
          label: 'How old are you?',
          value: age,
          placeholder: 'Enter your age',
          hint:
              'You must be over 13 to join. Age is for verification only, no '
              'one will see it.',
        ),
        _LabeledField(
          label: 'How did you hear about us?',
          value: referral?.label ?? '',
          placeholder: 'Tap to select',
          hint: 'This helps us understand how to reach more people like you.',
          onTap: onReferral,
        ),
        Pressable(
          onTap: onNewsletter == null ? null : () => onNewsletter!(!newsletter),
          focusColor: TotemColors.coreMauve,
          focusRadius: BorderRadius.circular(Radii.sm),
          toggled: newsletter,
          builder: (context, states) => Row(
            spacing: 10,
            children: [
              SvgPicture.asset(
                newsletter
                    ? '$_assets/radio-on.svg'
                    : '$_assets/checkbox-off.svg',
                width: 20,
                height: 20,
              ),
              Expanded(
                child: Text(
                  'Yes, receive our awesome newsletter',
                  style: TotemText.raw(size: 12, color: _ink),
                ),
              ),
            ],
          ),
        ),
        _AuthButton(label: 'Continue', onTap: onContinue),
      ],
    );
  }
}

class _Communities extends StatelessWidget {
  const _Communities({
    required this.selected,
    required this.onToggle,
    required this.onNext,
  });

  final Set<Community> selected;
  final ValueChanged<Community>? onToggle;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return _CardPage(
      spacing: Spacing.s20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            const _Heading(
              title: 'Which community feels like home to you?',
              subtitle:
                  'Pick a few — we’ll help you connect with the right '
                  'spaces.',
              subtitleSize: 16,
            ),
            for (final community in Community.values)
              _Selector(
                label: community.label,
                selected: selected.contains(community),
                onTap: onToggle == null ? null : () => onToggle!(community),
              ),
          ],
        ),
        _AuthButton(label: 'Next', onTap: selected.isEmpty ? null : onNext),
      ],
    );
  }
}

typedef _SpacePick = ({String photo, String title, String keeper});

const List<_SpacePick> _picks = [
  (
    photo: '$_assets/space-1.jpg',
    title: 'Setting the Tone for May',
    keeper: 'Maria',
  ),
  (
    photo: '$_assets/space-2.jpg',
    title: 'Thriving in Motherhood',
    keeper: 'Maria',
  ),
  (photo: '$_assets/space-3.jpg', title: 'Queer Joy', keeper: 'Maria'),
];

class _Spaces extends StatelessWidget {
  const _Spaces({required this.onSeeMore});

  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.lg);

    return _CardPage(
      spacing: Spacing.s20,
      children: [
        const _Heading(
          title: 'Spaces you’ll love',
          subtitle: 'We’ve found some spaces that might be a good fit for you.',
        ),
        for (final pick in _picks) _SpaceCard(pick: pick),
        Center(
          child: Pressable(
            onTap: onSeeMore,
            focusColor: TotemColors.coreMauve,
            focusRadius: radius,
            builder: (context, states) => Container(
              width: 250,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: states.contains(WidgetState.hovered)
                    ? fade(TotemColors.coreMauve, 0.06)
                    : null,
                border: Border.all(color: TotemColors.coreMauve),
                borderRadius: radius,
              ),
              child: Text(
                'See More',
                style: TotemText.body1.copyWith(color: TotemColors.coreMauve),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Figma "space card 5" (2427:1004): photo, time chip, and a fade with
/// the title, Keeper, Join and seats.
class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.pick});

  final _SpacePick pick;

  @override
  Widget build(BuildContext context) {
    const white = TotemColors.coreWhite;
    final radius = BorderRadius.circular(Radii.lg);

    return Container(
      height: 119,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 4,
            color: Color(0x40000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(pick.photo, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 79,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      fade(TotemColors.coreSlate, 0),
                      TotemColors.coreSlate,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 11, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 5,
                    children: [
                      Text(
                        pick.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TotemText.raw(
                          size: 14,
                          weight: FontWeight.w600,
                          color: white,
                        ),
                      ),
                      Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              '$_assets/avatar-maria.png',
                              width: 25,
                              height: 25,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'with ',
                            style: TotemText.raw(size: 10, color: white),
                          ),
                          Text(
                            pick.keeper,
                            style: TotemText.raw(
                              size: 10,
                              weight: FontWeight.w600,
                              color: white,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            spacing: 2,
                            children: [
                              Container(
                                height: 20,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: TotemColors.coreMauve,
                                  borderRadius: BorderRadius.circular(Radii.lg),
                                ),
                                child: Text(
                                  'Join',
                                  style: TotemText.body2.copyWith(color: white),
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  style: TotemText.raw(size: 8, color: white),
                                  children: const [
                                    TextSpan(
                                      text: '4 ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: 'seats left'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: TotemColors.overlaySlate60,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Text(
                  'Today, 4:00 PM',
                  style: TotemText.raw(
                    size: 8,
                    weight: FontWeight.w700,
                    color: white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
