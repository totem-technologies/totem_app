import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../components/button/button.dart';
import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/session_details';

/// Unmapped: Session details page fill. Not a Totem variable.
const _peach = Color(0xFFFCEFE4);

/// The phone status bar is drawn by the device, not the screen. The hero
/// photo runs under it.
const _statusBarHeight = 44.0;

/// Where the member stands with this Session.
///
/// Figma draws [open] (2379:2498) and [ended] (3200:8158). [attending] and
/// [full] only change the Attend button.
enum SessionDetailsStatus { open, attending, full, ended }

/// Figma "Session Details (Latest)" (2379:2497): one Session of a Space.
///
/// Hero photo with back and share, the Space and Session names, a card of
/// facts with the date and Attend, the description, a similar Session, and
/// the Keeper. An ended Session is covered by a dialog that points to the
/// next one.
///
/// Fills the viewport height and scrolls.
class SessionDetailsPage extends StatelessWidget {
  const SessionDetailsPage({
    super.key,
    this.status = SessionDetailsStatus.open,
    this.seatsLeft = 9,
    this.recurring = true,
    this.free = true,
    this.showSimilar = true,
    this.onBack,
    this.onShare,
    this.onAttend,
    this.onLeave,
    this.onSignUpNext,
    this.onReturnHome,
    this.onViewKeeper,
  });

  final SessionDetailsStatus status;

  /// Ignored when [status] is full, which always shows none.
  final int seatsLeft;

  /// Shows "Twice a month" in the facts.
  final bool recurring;

  /// "No Cost" when true, otherwise the price.
  final bool free;

  final bool showSimilar;

  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onAttend;

  /// Tapping "Attending" gives the seat back.
  final VoidCallback? onLeave;
  final VoidCallback? onSignUpNext;
  final VoidCallback? onReturnHome;
  final VoidCallback? onViewKeeper;

  @override
  Widget build(BuildContext context) {
    final ended = status == SessionDetailsStatus.ended;

    return ColoredBox(
      color: _peach,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: ended,
            child: ListView(
              padding: const EdgeInsets.only(bottom: Spacing.s40),
              children: [
                _Hero(onBack: onBack, onShare: onShare),
                const SizedBox(height: Spacing.s24),
                const _Heading(),
                const SizedBox(height: Spacing.s24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
                  child: _FactsCard(
                    status: status,
                    seatsLeft: status == SessionDetailsStatus.full
                        ? 0
                        : seatsLeft,
                    recurring: recurring,
                    free: free,
                    onAttend: onAttend,
                    onLeave: onLeave,
                  ),
                ),
                const SizedBox(height: Spacing.s24),
                const _About(),
                if (showSimilar) ...[
                  const SizedBox(height: Spacing.s24),
                  const _Similar(),
                ],
                const SizedBox(height: Spacing.s24),
                _MeetTheKeeper(onViewProfile: onViewKeeper),
              ],
            ),
          ),
          if (ended)
            _EndedDialog(
              onSignUpNext: onSignUpNext,
              onReturnHome: onReturnHome,
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onBack, required this.onShare});

  final VoidCallback? onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _statusBarHeight + 262,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('$_assets/hero.jpg', fit: BoxFit.cover),
          Positioned(
            left: Spacing.s20,
            right: Spacing.s20,
            top: _statusBarHeight + 3.5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundButton(
                  asset: '$_assets/button-back.svg',
                  label: 'Back',
                  onTap: onBack,
                ),
                _RoundButton(
                  asset: '$_assets/button-share.svg',
                  label: 'Share',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 30px white disc from the file. The glyph is part of the SVG.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      focusColor: TotemColors.coreMauve,
      focusRadius: BorderRadius.circular(Radii.full),
      semanticLabel: label,
      builder: (context, states) =>
          SvgPicture.asset(asset, width: 30, height: 30),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'Transition: Panic. Pause. Pivot. Repeat — a Space for the '
            'moments everything shifts at once',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TotemText.body1.copyWith(color: fade(ink, 0.7)),
          ),
          Text(
            'Learning to Witness Yourself When the Ground Moves Under You',
            style: TotemText.h2.copyWith(color: ink),
          ),
          Row(
            spacing: 4,
            children: [
              ClipOval(
                child: Image.asset(
                  '$_assets/avatar-maria.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              Text('with', style: TotemText.body1.copyWith(color: ink)),
              Text(
                'Maria',
                style: TotemText.raw(
                  size: 18,
                  weight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White card with five facts in a 3 + 2 grid, then the date and the
/// Attend button.
class _FactsCard extends StatelessWidget {
  const _FactsCard({
    required this.status,
    required this.seatsLeft,
    required this.recurring,
    required this.free,
    required this.onAttend,
    required this.onLeave,
  });

  final SessionDetailsStatus status;
  final int seatsLeft;
  final bool recurring;
  final bool free;
  final VoidCallback? onAttend;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    const radius = 17.151;

    final facts = [
      _Fact(icon: 'icon-subscribers.svg', value: '9', label: 'subscribers'),
      const _Fact(icon: 'icon-duration.svg', value: '60', label: 'min'),
      _Fact(
        icon: 'icon-seats.svg',
        value: '$seatsLeft',
        label: seatsLeft == 1 ? 'seat left' : 'seats left',
      ),
      if (recurring)
        const _Fact(icon: 'icon-repeat.svg', label: 'Twice a month'),
      _Fact(icon: 'icon-cost.svg', label: free ? 'No Cost' : r'$15'),
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.s20),
      decoration: BoxDecoration(
        color: TotemColors.coreWhite,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        spacing: radius,
        children: [
          Column(
            spacing: 13.72,
            children: [
              for (var row = 0; row < facts.length; row += 3)
                Row(
                  children: [
                    for (var i = row; i < row + 3; i++)
                      Expanded(
                        child: i < facts.length
                            ? facts[i]
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8.575,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4.288,
                  children: [
                    Text(
                      'Wednesday, February 11th',
                      style: TotemText.raw(
                        size: 10.29,
                        weight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    Text(
                      '12:30 AM GMT+1',
                      style: TotemText.raw(
                        size: 10.29,
                        weight: FontWeight.w500,
                        color: fade(ink, 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _AttendButton(
                status: status,
                onAttend: onAttend,
                onLeave: onLeave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.value});

  final String icon;
  final String label;

  /// Bold number before [label], e.g. "9" subscribers.
  final String? value;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    final style = TotemText.raw(size: 7.409, weight: FontWeight.w600);

    return Row(
      spacing: 8.232,
      children: [
        SvgPicture.asset('$_assets/$icon', width: 16.465, height: 16.465),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                if (value case final value?)
                  TextSpan(
                    text: '$value ',
                    style: style.copyWith(color: ink),
                  ),
                TextSpan(
                  text: label,
                  style: style.copyWith(
                    color: value == null ? ink : fade(ink, 0.7),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Figma draws Attend only. Attending inverts it to an outline, Full
/// greys it out.
class _AttendButton extends StatelessWidget {
  const _AttendButton({
    required this.status,
    required this.onAttend,
    required this.onLeave,
  });

  final SessionDetailsStatus status;
  final VoidCallback? onAttend;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(42.877);
    final (label, onTap, fill, ink, border) = switch (status) {
      SessionDetailsStatus.attending => (
        'Attending',
        onLeave,
        TotemColors.coreWhite,
        TotemColors.coreMauve,
        TotemColors.coreMauve,
      ),
      SessionDetailsStatus.full => (
        'Full',
        null,
        fade(TotemColors.coreGray, 0.2),
        TotemColors.coreGray,
        fade(TotemColors.coreGray, 0.2),
      ),
      _ => (
        'Attend',
        onAttend,
        TotemColors.coreMauve,
        TotemColors.coreWhite,
        TotemColors.coreMauve,
      ),
    };

    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      toggled: status == SessionDetailsStatus.attending,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13.72, vertical: 6.86),
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? mix(TotemColors.coreSlate, 0.08, fill)
              : fill,
          border: Border.all(color: border),
          borderRadius: radius,
        ),
        child: Text(
          label,
          style: TotemText.raw(
            size: 10.29,
            weight: FontWeight.w600,
            color: ink,
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  static const _paragraphs = [
    'Change rarely arrives one piece at a time. A move, a loss, a new '
        'role, a body that feels different — they tend to land together, '
        'and the mind starts narrating before we have had a chance to feel '
        'anything.',
    'In this Session we practice noticing that narration. We will share '
        'one moment from the past month when things shifted, and listen '
        'without fixing, advising or comparing.',
    'You can keep your camera off and pass whenever you like. Come as you '
        'are; there is nothing to prepare.',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.s20,
        children: [
          Text(
            'About this Session',
            style: TotemText.raw(
              size: 14,
              weight: FontWeight.w600,
              color: const Color(0xB3000000),
            ),
          ),
          Text(
            _paragraphs.join('\n\n'),
            style: TotemText.body2.copyWith(color: const Color(0xFF000000)),
          ),
        ],
      ),
    );
  }
}

class _Similar extends StatelessWidget {
  const _Similar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Spacing.s20,
        children: [
          Text(
            'Upcoming Similar Sessions',
            style: TotemText.raw(
              size: 16,
              weight: FontWeight.w600,
              color: const Color(0xFF000000),
            ),
          ),
          const _SessionRow(),
        ],
      ),
    );
  }
}

/// Figma "Session Home Screen Card" (2252:1202): 131px row, photo on the
/// left, details and an Attend pill on the right.
class _SessionRow extends StatelessWidget {
  const _SessionRow();

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    final meta = TotemText.raw(size: 10, color: TotemColors.coreGray);

    Widget fact(Widget icon, List<Widget> children) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2.396,
      children: [icon, ...children],
    );

    return SizedBox(
      height: 131,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: ColoredBox(
          color: TotemColors.coreWhite,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.asset(
                  '$_assets/photo-lake.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(
                width: 224,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          fact(
                            SvgPicture.asset(
                              '$_assets/icon-calendar-sm.svg',
                              width: 10,
                              height: 10,
                            ),
                            [
                              Text(
                                '5 Feb',
                                style: TotemText.raw(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          fact(
                            Transform.flip(
                              flipY: true,
                              child: SvgPicture.asset(
                                '$_assets/icon-clock-sm.svg',
                                width: 10,
                                height: 10,
                              ),
                            ),
                            [
                              Text(
                                '8:30',
                                style: TotemText.raw(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              Text('PM', style: meta),
                            ],
                          ),
                          fact(
                            Transform.flip(
                              flipX: true,
                              child: SvgPicture.asset(
                                '$_assets/icon-seats-sm.svg',
                                width: 10,
                                height: 10,
                              ),
                            ),
                            [
                              Text(
                                '2',
                                style: TotemText.raw(
                                  size: 8.293,
                                  weight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              Text('seats left', style: meta),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'What is Love?',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TotemText.raw(
                          size: 10,
                          weight: FontWeight.w600,
                          height: 1.1,
                          color: fade(ink, 0.7),
                        ),
                      ),
                      Text(
                        'The Fear of Being Loved',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TotemText.raw(
                          size: 14,
                          weight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      Row(
                        spacing: 4,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              '$_assets/avatar-heather.png',
                              width: 28.24,
                              height: 28.24,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Text(
                            'with',
                            style: TotemText.raw(size: 10, color: ink),
                          ),
                          Expanded(
                            child: Text(
                              'Heather',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TotemText.raw(
                                size: 12,
                                weight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: TotemColors.coreWhite,
                              border: Border.all(color: TotemColors.coreMauve),
                              borderRadius: BorderRadius.circular(Radii.lg),
                            ),
                            child: Text(
                              'Attend',
                              style: TotemText.raw(
                                size: 12,
                                weight: FontWeight.w500,
                                color: TotemColors.coreMauve,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetTheKeeper extends StatelessWidget {
  const _MeetTheKeeper({required this.onViewProfile});

  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Spacing.s20,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Meet The Keeper',
                  style: TotemText.raw(
                    size: 16,
                    weight: FontWeight.w600,
                    color: const Color(0xFF000000),
                  ),
                ),
              ),
              Pressable(
                onTap: onViewProfile,
                focusColor: TotemColors.coreMauve,
                focusRadius: BorderRadius.circular(Radii.lg),
                builder: (context, states) => Row(
                  spacing: 5,
                  children: [
                    Text(
                      'View Profile',
                      style: TotemText.body2.copyWith(color: fade(ink, 0.7)),
                    ),
                    // The file draws a down chevron and turns it.
                    RotatedBox(
                      quarterTurns: 3,
                      child: SvgPicture.asset(
                        '$_assets/icon-chevron.svg',
                        width: 12,
                        height: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
            decoration: BoxDecoration(
              color: TotemColors.coreWhite,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    ClipOval(
                      child: Image.asset(
                        '$_assets/avatar-vanessa.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vanessa',
                          style: TotemText.raw(
                            size: 20,
                            weight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        Row(
                          children: [
                            SvgPicture.asset(
                              '$_assets/icon-location.svg',
                              width: 18,
                              height: 18,
                            ),
                            Text(
                              'Earth',
                              style: TotemText.raw(
                                size: 12,
                                weight: FontWeight.w500,
                                color: TotemColors.coreGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "Vanessa is a Los Angeles-based artist and recovering hot "
                  "mess. She's battled many challenges, from undiagnosed "
                  'depression to struggling with alcohol abuse, and knows '
                  'first hand how hard it is to face complex emotions alone.',
                  style: TotemText.body2.copyWith(color: fade(ink, 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma 3200:8206: the page dims and a card offers the next Session.
class _EndedDialog extends StatelessWidget {
  const _EndedDialog({required this.onSignUpNext, required this.onReturnHome});

  final VoidCallback? onSignUpNext;
  final VoidCallback? onReturnHome;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x40000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.s20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 351),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: 'This session has ended',
              child: Container(
                padding: const EdgeInsets.all(Spacing.s24),
                decoration: BoxDecoration(
                  color: TotemColors.coreWhite,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Spacing.s20,
                  children: [
                    Column(
                      spacing: 10,
                      children: [
                        SvgPicture.asset(
                          '$_assets/icon-ended.svg',
                          width: 60,
                          height: 60,
                        ),
                        Text(
                          'This session has ended',
                          textAlign: TextAlign.center,
                          style: TotemText.h2.copyWith(
                            color: TotemColors.coreSlate,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      spacing: 10,
                      children: [
                        Button(
                          block: true,
                          onPressed: onSignUpNext,
                          child: const Text('Sign Up for the Next Session'),
                        ),
                        Button(
                          block: true,
                          variant: ButtonVariant.secondary,
                          onPressed: onReturnHome,
                          child: const Text('Return Home'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
