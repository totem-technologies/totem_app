import 'dart:ui' show ImageFilter;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/home';

/// Unmapped: Figma "Black" style, used for the home indicator.
const _homeBar = Color(0xFF232327);

/// The phone status bar is drawn by the device, not the screen.
const _statusBarHeight = 44.0;

/// Who is looking at Home.
///
/// A new member has no Session yet, so the top of the page explains Totem
/// (Figma 2316:7123). A returning member sees their next Session there
/// (Figma 2316:7032).
enum HomeUser { newUser, returning }

typedef _Upcoming = ({
  String id,
  String photo,
  String date,
  String time,
  int seatsLeft,
  String spaceName,
  String sessionName,
  String keeper,
  String avatar,
});

/// Catalog data. Same photos, Keepers, dates and seats as the Figma frame.
const List<_Upcoming> _upcoming = [
  (
    id: 'witness',
    photo: '$_assets/photo-buildings.jpg',
    date: 'Today',
    time: '4:00',
    seatsLeft: 4,
    spaceName: 'Transition: Panic. Pause. Pivot. Repeat',
    sessionName: 'Learning to Witness Yourself When Things Change',
    keeper: 'Maria',
    avatar: '$_assets/avatar-maria-small.png',
  ),
  (
    id: 'fear-of-being-loved',
    photo: '$_assets/photo-lake.jpg',
    date: '5 Feb',
    time: '8:30',
    seatsLeft: 2,
    spaceName: 'What is Love?',
    sessionName: 'The Fear of Being Loved',
    keeper: 'Heather',
    avatar: '$_assets/avatar-heather.png',
  ),
  (
    id: 'origins-of-performance',
    photo: '$_assets/photo-pink.jpg',
    date: '8 Feb',
    time: '6:10',
    seatsLeft: 6,
    spaceName: 'Taking Up Space',
    sessionName: 'Origins of Performance: What we were told to be',
    keeper: 'Gabe',
    avatar: '$_assets/avatar-gabe.png',
  ),
  (
    id: 'unmet-needs',
    photo: '$_assets/photo-friends.jpg',
    date: '14 Feb',
    time: '6:00',
    seatsLeft: 3,
    spaceName: 'Self-Sabotage',
    sessionName: 'Unmet Needs',
    keeper: 'Vanessa',
    avatar: '$_assets/avatar-vanessa.png',
  ),
  (
    id: 'holding-what-remains',
    photo: '$_assets/photo-couch.jpg',
    date: 'Today',
    time: '4:00',
    seatsLeft: 4,
    spaceName: 'Grief & Loss',
    sessionName: 'Holding What Remains After Someone Is Gone',
    keeper: 'Claire',
    avatar: '$_assets/avatar-claire.png',
  ),
];

/// Figma "Home Page" (2316:7031).
///
/// Top to bottom: the member's next Session (or, for a new member, a card
/// about Totem), upcoming Sessions as compact rows, then the latest blog
/// post. The bottom navigation stays fixed with Home selected.
///
/// [live] turns the next Session into the "Now / Join Session" card
/// (Figma 2403:2424). It has no effect for a new member.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.user = HomeUser.returning,
    this.live = false,
    this.upcomingCount = 5,
    this.showBlog = true,
    this.onJoin,
    this.onAttend,
    this.onReadMission,
    this.onReadBlog,
  });

  final HomeUser user;

  /// The next Session has started.
  final bool live;

  /// Rows under "Upcoming Sessions", 0 to 5. Zero shows a short note.
  final int upcomingCount;

  final bool showBlog;

  final VoidCallback? onJoin;

  /// Attend on a row. Receives the Session id.
  final ValueChanged<String>? onAttend;
  final VoidCallback? onReadMission;
  final VoidCallback? onReadBlog;

  @override
  Widget build(BuildContext context) {
    final rows = _upcoming.take(upcomingCount.clamp(0, _upcoming.length));
    final returning = user == HomeUser.returning;

    return ColoredBox(
      color: TotemColors.coreCream,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                Spacing.s20,
                _statusBarHeight + (returning ? 8 : 12),
                Spacing.s20,
                Spacing.s32,
              ),
              children: [
                if (returning) ...[
                  const _SectionHeader('Your Next session'),
                  const SizedBox(height: Spacing.s20),
                  _NextSessionCard(live: live, onJoin: onJoin),
                ] else
                  _MissionCard(onReadMore: onReadMission),
                const SizedBox(height: Spacing.s32),
                const _SectionHeader('Upcoming Sessions'),
                const SizedBox(height: Spacing.s20),
                if (rows.isEmpty)
                  Text(
                    'No upcoming Sessions right now. New ones open every '
                    'week.',
                    style: TotemText.bodySmall.copyWith(
                      color: TotemColors.coreGray,
                    ),
                  )
                else
                  Column(
                    spacing: Spacing.s20,
                    children: [
                      for (final row in rows)
                        _SessionRow(
                          session: row,
                          onAttend: onAttend == null
                              ? null
                              : () => onAttend!(row.id),
                        ),
                    ],
                  ),
                if (showBlog) ...[
                  const SizedBox(height: Spacing.s32),
                  const _SectionHeader('Blogs', underline: false),
                  const SizedBox(height: Spacing.s20),
                  _BlogCard(onReadMore: onReadBlog),
                ],
              ],
            ),
          ),
          const _BottomNav(),
        ],
      ),
    );
  }
}

/// Section title with a "View All" link. The first two sections keep
/// 10px of air under the row, Blogs does not.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.underline = true});

  final String title;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: underline ? 10 : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TotemText.h2.copyWith(color: const Color(0xFF000000)),
            ),
          ),
          Semantics(
            link: true,
            child: Row(
              spacing: 5,
              children: [
                Text(
                  'View All',
                  style: TotemText.body1.copyWith(color: TotemColors.coreGray),
                ),
                // The file draws a down chevron and turns it.
                RotatedBox(
                  quarterTurns: 3,
                  child: SvgPicture.asset(
                    '$_assets/icon-chevron.svg',
                    width: 15,
                    height: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 353 square card: photo on top, the Session below. Upcoming shows date,
/// time and seats. Live swaps them for a glowing "Now" chip and adds
/// Join Session.
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.live, required this.onJoin});

  final bool live;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    const radius = 28.24;
    final fact = TotemText.raw(size: 12.708, color: ink);

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: TotemColors.coreWhite,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    child: Image.asset(
                      '$_assets/photo-buildings.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14.12, 7.06, 14, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (live)
                          const _NowChip()
                        else
                          Row(
                            spacing: 28.24,
                            children: [
                              _Fact(
                                icon: SvgPicture.asset(
                                  '$_assets/icon-calendar.svg',
                                  width: 14.685,
                                  height: 14.685,
                                ),
                                children: [
                                  Text(
                                    'Today',
                                    style: fact.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              _Fact(
                                icon: Transform.flip(
                                  flipY: true,
                                  child: SvgPicture.asset(
                                    '$_assets/icon-clock.svg',
                                    width: 14.12,
                                    height: 14.12,
                                  ),
                                ),
                                children: [
                                  Text(
                                    '4:00',
                                    style: TotemText.raw(
                                      size: 11.296,
                                      weight: FontWeight.w700,
                                      height: 1,
                                      color: ink,
                                    ),
                                  ),
                                  Text('PM', style: fact),
                                ],
                              ),
                              _Fact(
                                icon: Transform.flip(
                                  flipX: true,
                                  child: SvgPicture.asset(
                                    '$_assets/icon-seats.svg',
                                    width: 13.414,
                                    height: 13.414,
                                  ),
                                ),
                                children: [
                                  Text(
                                    '4',
                                    style: fact.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text('seats left', style: fact),
                                ],
                              ),
                            ],
                          ),
                        Text(
                          'Transition: Panic. Pause. Pivot. Repeat',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TotemText.raw(
                            size: 14.12,
                            weight: FontWeight.w600,
                            height: 1.1,
                            color: fade(ink, 0.7),
                          ),
                        ),
                        Text(
                          'Learning to Witness Yourself',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TotemText.raw(
                            size: 22.592,
                            weight: FontWeight.w600,
                            height: 1.25,
                            color: ink,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _Keeper(
                                name: 'Maria',
                                avatar: '$_assets/avatar-maria.png',
                                size: 35,
                                gap: 5,
                                withStyle: TotemText.raw(
                                  size: 14.12,
                                  color: ink,
                                ),
                                nameStyle: TotemText.raw(
                                  size: 14.12,
                                  weight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                            if (live) _JoinButton(onTap: onJoin),
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
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.children});

  final Widget icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3.671,
      children: [icon, ...children],
    );
  }
}

class _NowChip extends StatelessWidget {
  const _NowChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TotemColors.coreWhite,
        border: Border.all(color: TotemColors.coreMauve),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: const [
          BoxShadow(
            offset: Offset(2, 2),
            blurRadius: 8,
            color: TotemColors.coreMauve,
          ),
        ],
      ),
      child: _Fact(
        icon: Transform.flip(
          flipY: true,
          child: SvgPicture.asset(
            '$_assets/icon-clock-live.svg',
            width: 14.12,
            height: 14.12,
          ),
        ),
        children: [
          Text(
            'Now',
            style: TotemText.raw(
              size: 11.296,
              weight: FontWeight.w700,
              height: 1.2,
              color: TotemColors.coreMauve,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(17.5);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      builder: (context, states) => Container(
        height: 35,
        width: 97,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? mix(TotemColors.coreSlate, 0.12, TotemColors.coreMauve)
              : TotemColors.coreMauve,
          borderRadius: radius,
        ),
        child: Text(
          'Join Session',
          style: TotemText.raw(
            size: 10,
            weight: FontWeight.w600,
            color: TotemColors.coreWhite,
          ),
        ),
      ),
    );
  }
}

/// Round photo, "with", and the Keeper's name.
class _Keeper extends StatelessWidget {
  const _Keeper({
    required this.name,
    required this.avatar,
    required this.size,
    required this.gap,
    required this.withStyle,
    required this.nameStyle,
  });

  final String name;
  final String avatar;
  final double size;
  final double gap;
  final TextStyle withStyle;
  final TextStyle nameStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: gap,
      children: [
        ClipOval(
          child: Image.asset(
            avatar,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        Text('with', style: withStyle),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
      ],
    );
  }
}

/// Figma "Session Home Screen Card" (2252:1202): 131px row, photo on the
/// left, details and an Attend pill on the right.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onAttend});

  final _Upcoming session;
  final VoidCallback? onAttend;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    const quiet = TotemColors.coreGray;
    final meta = TotemText.raw(size: 10, color: quiet);

    return SizedBox(
      height: 131,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: ColoredBox(
          color: TotemColors.coreWhite,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 130,
                child: Image.asset(session.photo, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MiniFact(
                            icon: SvgPicture.asset(
                              '$_assets/icon-calendar-sm.svg',
                              width: 10,
                              height: 10,
                            ),
                            children: [
                              Text(
                                session.date,
                                style: TotemText.raw(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          _MiniFact(
                            icon: Transform.flip(
                              flipY: true,
                              child: SvgPicture.asset(
                                '$_assets/icon-clock-sm.svg',
                                width: 10,
                                height: 10,
                              ),
                            ),
                            children: [
                              Text(
                                session.time,
                                style: TotemText.raw(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              Text('PM', style: meta),
                            ],
                          ),
                          _MiniFact(
                            icon: Transform.flip(
                              flipX: true,
                              child: SvgPicture.asset(
                                '$_assets/icon-seats-sm.svg',
                                width: 10,
                                height: 10,
                              ),
                            ),
                            children: [
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
                        children: [
                          Expanded(
                            child: _Keeper(
                              name: session.keeper,
                              avatar: session.avatar,
                              size: 28.24,
                              gap: 4,
                              withStyle: TotemText.raw(size: 10, color: ink),
                              nameStyle: TotemText.raw(
                                size: 12,
                                weight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          _AttendPill(onTap: onAttend),
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

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.icon, required this.children});

  final Widget icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2.396,
      children: [icon, ...children],
    );
  }
}

class _AttendPill extends StatelessWidget {
  const _AttendPill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.lg);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? mix(TotemColors.coreMauve, 0.08, TotemColors.coreWhite)
              : TotemColors.coreWhite,
          border: Border.all(color: TotemColors.coreMauve),
          borderRadius: radius,
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
    );
  }
}

/// New member's first card (Figma 2316:7126): painting with Totem's
/// mission over a slate fade, and Read more.
class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.onReadMore});

  final VoidCallback? onReadMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 304,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The painting is tall. Figma shows its lower part.
            Image.asset(
              '$_assets/hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 193,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.103, 1],
                    colors: [
                      fade(TotemColors.coreSlate, 0),
                      TotemColors.coreSlate,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 10,
                    children: [
                      Text(
                        'Totem is a nonprofit creating online Spaces for '
                        'connection and support. We believe these gatherings '
                        'can help build a more thoughtful, caring world.',
                        textAlign: TextAlign.center,
                        style:
                            TotemText.raw(
                              size: 16,
                              weight: FontWeight.w500,
                              color: TotemColors.coreWhite,
                            ).copyWith(
                              shadows: const [
                                Shadow(
                                  offset: Offset(2, 2),
                                  blurRadius: 8,
                                  color: Color(0xFF000000),
                                ),
                              ],
                            ),
                      ),
                      _PillButton(
                        label: 'Read more',
                        height: 38,
                        radius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        style: TotemText.raw(
                          size: 16,
                          weight: FontWeight.w600,
                          color: TotemColors.coreWhite,
                        ),
                        onTap: onReadMore,
                      ),
                    ],
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

/// Mauve pill used for Read more on the mission and blog cards.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.height,
    required this.radius,
    required this.padding,
    required this.style,
    required this.onTap,
    this.trailing,
    this.width,
  });

  final String label;
  final double height;
  final double radius;
  final EdgeInsets padding;
  final TextStyle style;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      focusColor: TotemColors.coreMauve,
      focusRadius: shape,
      builder: (context, states) => Container(
        height: height,
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: states.contains(WidgetState.hovered)
              ? mix(TotemColors.coreSlate, 0.12, TotemColors.coreMauve)
              : TotemColors.coreMauve,
          borderRadius: shape,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 5.06,
          children: [
            Text(label, style: style),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Figma blog card (2316:7100): cover with reading time, title, excerpt,
/// author, and Read More.
class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.onReadMore});

  final VoidCallback? onReadMore;

  @override
  Widget build(BuildContext context) {
    const ink = TotemColors.coreSlate;
    const radius = 25.3;

    return SizedBox(
      height: 316,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: TotemColors.coreWhite,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.65),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('$_assets/blog-fish.jpg', fit: BoxFit.cover),
                      Positioned(
                        left: 6.32,
                        top: 12.65,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22.029),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 1.1, sigmaY: 1.1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11.014,
                                vertical: 5.507,
                              ),
                              color: fade(ink, 0.3),
                              child: Text(
                                '12 min read',
                                style: TotemText.raw(
                                  size: 13.217,
                                  weight: FontWeight.w600,
                                  color: TotemColors.coreWhite,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.65, 10.12, 12.65, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Grounding Kits: Your Portable Anchor When Anxiety '
                          'Hits',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TotemText.raw(
                            size: 15.18,
                            weight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        Text(
                          'When panic strikes without warning, having the '
                          'right tools within reach can make all the '
                          'difference. Learn how to create a personalized '
                          'grounding kit that brings you back to the present '
                          'moment.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TotemText.raw(
                            size: 11.385,
                            color: fade(ink, 0.7),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.795),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: TotemColors.coreWhite,
                                    width: 1.054,
                                  ),
                                  image: const DecorationImage(
                                    image: AssetImage(
                                      '$_assets/avatar-lina.jpg',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6.325),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Lina',
                                      style: TotemText.raw(
                                        size: 15.18,
                                        weight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                    Text(
                                      'Dec 25, 2025',
                                      style: TotemText.raw(
                                        size: 8.855,
                                        height: 1,
                                        color: ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _PillButton(
                                label: 'Read More',
                                height: 36,
                                width: 110,
                                radius: radius,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.65,
                                ),
                                style: TotemText.raw(
                                  size: 11.385,
                                  weight: FontWeight.w600,
                                  color: TotemColors.coreWhite,
                                ),
                                trailing: SvgPicture.asset(
                                  '$_assets/icon-arrow.svg',
                                  width: 12.65,
                                  height: 12.65,
                                ),
                                onTap: onReadMore,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma "Navigation" (2316:7122) with Home selected, and the phone home
/// indicator under it.
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TotemColors.coreWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 75,
            child: Padding(
              padding: const EdgeInsets.only(left: 23, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavItem(
                    label: 'Home',
                    selected: true,
                    gap: 1,
                    icon: SvgPicture.asset(
                      '$_assets/nav-home.svg',
                      width: 25,
                      height: 25,
                    ),
                  ),
                  _NavItem(
                    label: 'Sessions',
                    // The ring overhangs its 25px slot by its stroke.
                    icon: SizedBox.square(
                      dimension: 25,
                      child: OverflowBox(
                        maxWidth: 26.6,
                        maxHeight: 26.6,
                        child: SvgPicture.asset(
                          '$_assets/nav-sessions.svg',
                          width: 26.6,
                          height: 26.6,
                        ),
                      ),
                    ),
                  ),
                  _NavItem(
                    label: 'Blog',
                    icon: SvgPicture.asset(
                      '$_assets/nav-blog.svg',
                      width: 25,
                      height: 25,
                    ),
                  ),
                  _NavItem(
                    label: 'Profile',
                    icon: SvgPicture.asset(
                      '$_assets/nav-profile.svg',
                      width: 25,
                      height: 25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: Spacing.homebarWidth,
                height: 5,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _homeBar,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    this.selected = false,
    this.gap = 5,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: 42,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            icon,
            Text(
              label,
              textAlign: TextAlign.center,
              style: TotemText.raw(
                size: 9,
                weight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? TotemColors.coreMauve : TotemColors.coreGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
