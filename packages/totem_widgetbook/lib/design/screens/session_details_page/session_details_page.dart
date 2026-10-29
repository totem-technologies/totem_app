import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../components/button/button.dart';
import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/session_details';

/// The hero, back, share, repeat icon and similar photo are the same files
/// SessionEntry uses.
const _shared = 'assets/design/session_entry';

/// Unmapped: Session details page fill. Not a Totem variable.
const _peach = Color(0xFFFCEFE4);
const _black = Color(0xFF000000);

/// The phone status bar is drawn by the device, not the screen. The hero
/// photo runs under it. Becomes `MediaQuery.paddingOf(context).top` once
/// the screen moves to the app.
const _statusBarHeight = 44.0;

/// Where the member stands with this Session.
///
/// Figma draws [open] (2379:2498) and [ended] (3200:8158). [attending] and
/// [full] only change the Attend button.
enum SessionDetailsStatus { open, attending, full, ended }

/// The Session row under "Upcoming Similar Sessions".
class SimilarSession {
  const SimilarSession({
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
    required this.dateLabel,
    required this.time,
    required this.period,
    required this.seatsLeft,
  });

  final String spaceName;
  final String sessionName;
  final String keeperName;

  /// e.g. `5 Feb`.
  final String dateLabel;

  /// e.g. `8:30`, drawn bold before [period].
  final String time;

  /// `AM` or `PM`.
  final String period;
  final int seatsLeft;
}

/// Figma "Session Details (Latest)" (2379:2497): one Session of a Space,
/// reached from the Sessions list at `spaces/event/:slug`.
///
/// Not the same screen as `SessionDetails`, the pre-join landing inside
/// `session/:slug`. That one carries Join Session and the join phases;
/// this one is for browsing: Attend, seats, recurrence, cost, and an
/// ended state that points to the next Session.
///
/// Hero photo with back and share, the Space and Session names, a card of
/// facts with the date and Attend, the description, a similar Session, and
/// the Keeper. An ended Session is covered by a dialog that points to the
/// next one.
///
/// Fills the viewport height and scrolls. From 640 wide it becomes one
/// centered 560px column and the hero gets rounded corners.
class SessionDetailsPage extends StatelessWidget {
  const SessionDetailsPage({
    super.key,
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
    required this.keeperBio,
    required this.dateLabel,
    required this.timeLabel,
    required this.description,
    this.status = SessionDetailsStatus.open,
    this.seatsLeft = 9,
    this.recurring = true,
    this.free = true,
    this.similar,
    this.onBack,
    this.onShare,
    this.onAttend,
    this.onLeave,
    this.onSignUpNext,
    this.onReturnHome,
    this.onViewKeeper,
    this.onAttendSimilar,
  });

  final String spaceName;
  final String sessionName;
  final String keeperName;
  final String keeperBio;
  final String dateLabel;
  final String timeLabel;

  /// Paragraphs separated by blank lines.
  final String description;

  final SessionDetailsStatus status;

  /// Ignored when [status] is full, which always shows none. Zero while
  /// open reads as full.
  final int seatsLeft;

  /// Shows "Twice a month" in the facts.
  final bool recurring;

  /// "No Cost" when true, otherwise the price.
  final bool free;

  /// Hidden when null.
  final SimilarSession? similar;

  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onAttend;

  /// Tapping "Attending" gives the seat back. The catalog does it in one
  /// tap; the app should confirm first.
  final VoidCallback? onLeave;
  final VoidCallback? onSignUpNext;
  final VoidCallback? onReturnHome;
  final VoidCallback? onViewKeeper;
  final VoidCallback? onAttendSimilar;

  @override
  Widget build(BuildContext context) {
    final ended = status == SessionDetailsStatus.ended;
    final seats = status == SessionDetailsStatus.full
        ? 0
        : (seatsLeft < 0 ? 0 : seatsLeft);
    final effective = status == SessionDetailsStatus.open && seats == 0
        ? SessionDetailsStatus.full
        : status;

    return ColoredBox(
      color: _peach,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              final side = wide ? (constraints.maxWidth - 560) / 2 : 0.0;

              // Behind the ended dialog the page can't be read or reached.
              return ExcludeSemantics(
                excluding: ended,
                child: ExcludeFocus(
                  excluding: ended,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      side,
                      wide ? Spacing.s24 : 0,
                      side,
                      Spacing.s40,
                    ),
                    children: [
                      _Hero(wide: wide, onBack: onBack, onShare: onShare),
                      const SizedBox(height: Spacing.s24),
                      _Heading(
                        spaceName: spaceName,
                        sessionName: sessionName,
                        keeperName: keeperName,
                      ),
                      const SizedBox(height: Spacing.s24),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.s20,
                        ),
                        child: _FactsCard(
                          status: effective,
                          seatsLeft: seats,
                          recurring: recurring,
                          free: free,
                          dateLabel: dateLabel,
                          timeLabel: timeLabel,
                          onAttend: onAttend,
                          onLeave: onLeave,
                        ),
                      ),
                      const SizedBox(height: Spacing.s24),
                      _About(description: description),
                      if (similar case final similar?) ...[
                        const SizedBox(height: Spacing.s24),
                        _Similar(session: similar, onAttend: onAttendSimilar),
                      ],
                      const SizedBox(height: Spacing.s24),
                      _MeetTheKeeper(
                        name: keeperName,
                        bio: keeperBio,
                        onViewProfile: onViewKeeper,
                      ),
                    ],
                  ),
                ),
              );
            },
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
  const _Hero({
    required this.wide,
    required this.onBack,
    required this.onShare,
  });

  /// A rounded card in the centered column instead of running edge to
  /// edge under the status bar.
  final bool wide;
  final VoidCallback? onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final top = wide ? 0.0 : _statusBarHeight;

    // The buttons' 44px hit areas overhang the 30px discs by 7 each side,
    // so the discs land where Figma puts them.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? Spacing.s20 : 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(wide ? Radii.lg : 0),
        child: SizedBox(
          height: top + (wide ? 300 : 262),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('$_shared/hero.jpg', fit: BoxFit.cover),
              Positioned(
                left: Spacing.s20 - 7,
                right: Spacing.s20 - 7,
                top: top + 3.5 - 7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(
                      asset: '$_shared/back.svg',
                      label: 'Back',
                      onTap: onBack,
                    ),
                    _RoundButton(
                      asset: '$_shared/share.svg',
                      label: 'Share',
                      onTap: onShare,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 30px white disc from the file in a 44px hit area. The glyph is part of
/// the SVG.
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
      builder: (context, states) => SizedBox.square(
        dimension: 44,
        child: Center(child: SvgPicture.asset(asset, width: 30, height: 30)),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
  });

  final String spaceName;
  final String sessionName;
  final String keeperName;

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
            spaceName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TotemText.body1.copyWith(color: fade(ink, 0.7)),
          ),
          Text(sessionName, style: TotemText.h2.copyWith(color: ink)),
          Row(
            spacing: 4,
            children: [
              ClipOval(
                child: Image.asset(
                  '$_assets/avatar-vanessa.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              Text('with', style: TotemText.body1.copyWith(color: ink)),
              Text(
                keeperName,
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
///
/// Figma places the card as an instance scaled to 0.8575; these are the
/// unscaled sizes. Text has an 11px floor, as in SessionDetails, so
/// nothing drops below readable.
class _FactsCard extends StatelessWidget {
  const _FactsCard({
    required this.status,
    required this.seatsLeft,
    required this.recurring,
    required this.free,
    required this.dateLabel,
    required this.timeLabel,
    required this.onAttend,
    required this.onLeave,
  });

  final SessionDetailsStatus status;
  final int seatsLeft;
  final bool recurring;
  final bool free;
  final String dateLabel;
  final String timeLabel;
  final VoidCallback? onAttend;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;

    final facts = [
      const _Fact(
        icon: '$_assets/icon-subscribers.svg',
        value: '9',
        label: 'subscribers',
      ),
      const _Fact(
        icon: '$_assets/icon-duration.svg',
        value: '60',
        label: 'min',
      ),
      _Fact(
        icon: '$_assets/icon-seats.svg',
        value: '$seatsLeft',
        label: seatsLeft == 1 ? 'seat left' : 'seats left',
      ),
      if (recurring)
        const _Fact(icon: '$_shared/icon-repeat.svg', label: 'Twice a month'),
      _Fact(icon: '$_assets/icon-cost.svg', label: free ? 'No Cost' : r'$15'),
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.s20),
      decoration: BoxDecoration(
        color: TotemColors.coreWhite,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        spacing: Spacing.s20,
        children: [
          Column(
            spacing: Spacing.s16,
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
            spacing: 10,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    Text(
                      dateLabel,
                      style: TotemText.raw(
                        size: 12,
                        weight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: TotemText.raw(
                        size: 12,
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
    final style = TotemText.raw(size: 11, weight: FontWeight.w600);

    // Icon and gap stay compact so the 11px labels fit three across.
    return Row(
      spacing: 6,
      children: [
        SvgPicture.asset(icon, width: 16.465, height: 16.465),
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
    final radius = BorderRadius.circular(Radii.full);
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
      // The pill is drawn 32px tall inside a 44px hit area.
      builder: (context, states) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.s16,
              vertical: Spacing.s8,
            ),
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
                size: 12,
                weight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.description});

  final String description;

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
              color: fade(_black, 0.7),
            ),
          ),
          Text(description, style: TotemText.body2.copyWith(color: _black)),
        ],
      ),
    );
  }
}

class _Similar extends StatelessWidget {
  const _Similar({required this.session, required this.onAttend});

  final SimilarSession session;
  final VoidCallback? onAttend;

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
              color: _black,
            ),
          ),
          _SessionRow(session: session, onAttend: onAttend),
        ],
      ),
    );
  }
}

/// Figma "Session Home Screen Card" (2252:1202): 131px row, photo on the
/// left, details and an Attend pill on the right.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onAttend});

  final SimilarSession session;
  final VoidCallback? onAttend;

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
                child: Image.asset('$_shared/similar.jpg', fit: BoxFit.cover),
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
                                session.dateLabel,
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
                                session.time,
                                style: TotemText.raw(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              Text(session.period, style: meta),
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
                                '${session.seatsLeft}',
                                style: TotemText.raw(
                                  size: 8.293,
                                  weight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              Text(
                                session.seatsLeft == 1
                                    ? 'seat left'
                                    : 'seats left',
                                style: meta,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        session.spaceName,
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
                        session.sessionName,
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
                              session.keeperName,
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
                          Pressable(
                            onTap: onAttend,
                            pressedScale: 0.96,
                            focusColor: TotemColors.coreMauve,
                            focusRadius: BorderRadius.circular(Radii.lg),
                            builder: (context, states) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: states.contains(WidgetState.hovered)
                                    ? mix(
                                        TotemColors.coreMauve,
                                        0.08,
                                        TotemColors.coreWhite,
                                      )
                                    : TotemColors.coreWhite,
                                border: Border.all(
                                  color: TotemColors.coreMauve,
                                ),
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
  const _MeetTheKeeper({
    required this.name,
    required this.bio,
    required this.onViewProfile,
  });

  final String name;
  final String bio;
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
                    color: _black,
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
                          name,
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
                  bio,
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
      color: fade(_black, 0.25),
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
