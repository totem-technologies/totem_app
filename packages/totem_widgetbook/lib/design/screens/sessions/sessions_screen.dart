import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../components/button/button.dart';
import '../../components/session_card/session_card.dart';
import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/sessions';

/// Unmapped: Sessions page fill. Not a Totem variable.
const _peach = Color(0xFFFCEFE4);

/// Unmapped: day number and "Today" on the date rail.
const _railInk = Color(0xFF7D8287);

/// Unmapped: month band on a future day, and its label.
const _railBand = Color(0xB3C4C4C4);
const _railBandInk = Color(0xFF444444);

/// Unmapped: Figma "Black" style, used for the home indicator.
const _homeBar = Color(0xFF232327);

/// The phone status bar is drawn by the device, not the screen.
const _statusBarHeight = 44.0;

/// The quick filters in the chip row, in Figma order.
enum SessionsFilter {
  all('All'),
  lgbtq('LGBTQ+'),
  mothers('Mothers'),
  selfDev('Self-Dev');

  const SessionsFilter(this.label);

  final String label;
}

/// One day on the left rail. [today] swaps the month band for the date
/// and the date for "Today".
typedef _Day = ({String month, int date, String weekday, bool today});

typedef _Listing = ({
  String id,
  _Day day,
  SessionsFilter space,
  String spaceName,
  String sessionName,
  String photo,
  String keeper,
  String avatar,
  String time,
  int seatsLeft,
  bool attending,
});

const _today = (month: 'NOV', date: 21, weekday: 'WED', today: true);
const _nov9 = (month: 'NOV', date: 9, weekday: 'WED', today: false);
const _nov13 = (month: 'NOV', date: 13, weekday: 'WED', today: false);

/// Catalog data. Same photos, Keepers, times and seats as the Figma frame.
const List<_Listing> _listings = [
  (
    id: 'weight-of-expectations',
    day: _today,
    space: SessionsFilter.mothers,
    spaceName: 'Thriving in Motherhood',
    sessionName: 'The Weight of Expectations and the Days We Put Them Down',
    photo: '$_assets/photo-mother.jpg',
    keeper: 'Maria',
    avatar: '$_assets/avatar-maria.png',
    time: '4:00',
    seatsLeft: 4,
    attending: true,
  ),
  (
    id: 'coming-out-again',
    day: _nov9,
    space: SessionsFilter.lgbtq,
    spaceName: 'Queer Joy',
    sessionName: 'Coming Out, Again and Again: Who We Tell and Why',
    photo: '$_assets/photo-couch.jpg',
    keeper: 'Vanessa Rae',
    avatar: '$_assets/avatar-vanessa.png',
    time: '6:30',
    seatsLeft: 2,
    attending: false,
  ),
  (
    id: 'burnout',
    day: _nov9,
    space: SessionsFilter.selfDev,
    spaceName: 'Growing on Purpose',
    sessionName: 'Burnout Is Not a Badge: Resting Without Guilt',
    photo: '$_assets/photo-desk.jpg',
    keeper: 'Vanessa Rae',
    avatar: '$_assets/avatar-vanessa.png',
    time: '8:00',
    seatsLeft: 3,
    attending: true,
  ),
  (
    id: 'play-again',
    day: _nov13,
    space: SessionsFilter.mothers,
    spaceName: 'Thriving in Motherhood',
    sessionName: 'Learning to Play Again With Our Kids and Ourselves',
    photo: '$_assets/photo-toy.jpg',
    keeper: 'Maria',
    avatar: '$_assets/avatar-maria.png',
    time: '4:00',
    seatsLeft: 4,
    attending: false,
  ),
];

/// Figma "Sessions" (2315:8056): every upcoming Session, grouped by day.
///
/// The chip row narrows the list to one kind of Space. "My Sessions"
/// narrows it to the ones the member is attending. When both leave
/// nothing, an empty note offers to show everything again.
///
/// Fills the viewport height. The list scrolls under a fixed bottom
/// navigation bar.
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({
    super.key,
    this.filter = SessionsFilter.all,
    this.mySessions = false,
    this.onFilter,
    this.onMySessions,
    this.onShowAll,
    this.onAddToCalendar,
  });

  final SessionsFilter filter;

  /// Only the Sessions the member is attending.
  final bool mySessions;

  final ValueChanged<SessionsFilter>? onFilter;
  final VoidCallback? onMySessions;

  /// From the empty state: clear the filter and "My Sessions".
  final VoidCallback? onShowAll;

  /// Calendar button on a card. Receives the Session id.
  final ValueChanged<String>? onAddToCalendar;

  List<_Listing> get _visible => [
    for (final listing in _listings)
      if ((filter == SessionsFilter.all || listing.space == filter) &&
          (!mySessions || listing.attending))
        listing,
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final days = <_Day, List<_Listing>>{};
    for (final listing in visible) {
      (days[listing.day] ??= []).add(listing);
    }

    return ColoredBox(
      color: _peach,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s20,
                _statusBarHeight + Spacing.s20,
                Spacing.s20,
                Spacing.s24,
              ),
              children: [
                _Header(mySessions: mySessions, onMySessions: onMySessions),
                const SizedBox(height: Spacing.s24),
                _FilterBar(selected: filter, onSelect: onFilter),
                const SizedBox(height: Spacing.s24),
                if (days.isEmpty)
                  _Empty(filter: filter, onShowAll: onShowAll)
                else
                  Column(
                    spacing: Spacing.s24,
                    children: [
                      for (final MapEntry(key: day, value: listings)
                          in days.entries)
                        _DayGroup(
                          day: day,
                          listings: listings,
                          onAddToCalendar: onAddToCalendar,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const _BottomNav(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mySessions, required this.onMySessions});

  final bool mySessions;
  final VoidCallback? onMySessions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Sessions',
            style: TotemText.h1.copyWith(color: const Color(0xFF000000)),
          ),
        ),
        _MySessionsPill(on: mySessions, onTap: onMySessions),
      ],
    );
  }
}

/// Filled mauve when off, like the Figma frame. When on it inverts to an
/// outline so the list reads as narrowed.
class _MySessionsPill extends StatelessWidget {
  const _MySessionsPill({required this.on, required this.onTap});

  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = on ? TotemColors.coreMauve : TotemColors.coreWhite;
    final radius = BorderRadius.circular(Radii.lg);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      toggled: on,
      builder: (context, states) => Container(
        height: 39,
        padding: const EdgeInsets.only(left: 5, right: 15),
        decoration: BoxDecoration(
          color: on ? TotemColors.coreWhite : TotemColors.coreMauve,
          border: Border.all(color: TotemColors.coreMauve),
          borderRadius: radius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              '$_assets/icon-my-sessions.svg',
              width: 39,
              height: 39,
              colorFilter: on
                  ? const ColorFilter.mode(
                      TotemColors.coreMauve,
                      BlendMode.srcIn,
                    )
                  : null,
            ),
            Text(
              'My Sessions',
              style: TotemText.raw(
                size: 12,
                weight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White pill holding the quick filters. The row scrolls sideways and
/// fades out under a white disc at the right end (Figma "Ellipse 17").
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});

  final SessionsFilter selected;
  final ValueChanged<SessionsFilter>? onSelect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(25);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: TotemColors.coreWhite,
            borderRadius: radius,
            boxShadow: Shadows.elevation1,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 10, 47, 10),
              child: Row(
                spacing: 5,
                children: [
                  for (final filter in SessionsFilter.values)
                    _FilterChip(
                      label: filter.label,
                      selected: filter == selected,
                      onTap: onSelect == null ? null : () => onSelect!(filter),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SvgPicture.asset(
              '$_assets/filter-fade.svg',
              width: 47,
              height: 47,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(25);

    return Pressable(
      onTap: onTap,
      focusColor: TotemColors.coreMauve,
      focusRadius: radius,
      selected: selected,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? TotemColors.coreMauve
              : states.contains(WidgetState.hovered)
              ? mix(TotemColors.coreMauve, 0.12, TotemColors.coreCream)
              : TotemColors.coreCream,
          borderRadius: radius,
        ),
        child: Text(
          label,
          style: TotemText.raw(
            size: 14,
            weight: selected ? FontWeight.w500 : FontWeight.w400,
            height: 1.5,
            color: selected ? TotemColors.coreCream : TotemColors.coreSlate,
          ),
        ),
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.day,
    required this.listings,
    required this.onAddToCalendar,
  });

  final _Day day;
  final List<_Listing> listings;
  final ValueChanged<String>? onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _DateRail(day: day),
        Expanded(
          child: Column(
            spacing: Spacing.s20,
            children: [
              for (final listing in listings)
                SizedBox(
                  height: 250,
                  child: SessionCard(
                    photo: AssetImage(listing.photo),
                    photoAlignment: Alignment.center,
                    spaceName: listing.spaceName,
                    sessionName: listing.sessionName,
                    keeperName: listing.keeper,
                    keeperPhoto: AssetImage(listing.avatar),
                    time: listing.time,
                    meridiem: 'PM',
                    seatsLeft: listing.seatsLeft,
                    onAddToCalendar: () => onAddToCalendar?.call(listing.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 50 × 69 date tab. Today: mauve band with the date, "Today" below.
/// Later days: grey month band, date over weekday below.
class _DateRail extends StatelessWidget {
  const _DateRail({required this.day});

  final _Day day;

  @override
  Widget build(BuildContext context) {
    final band = TotemText.raw(
      size: 10,
      weight: FontWeight.w600,
      color: day.today ? TotemColors.coreWhite : _railBandInk,
    );

    return Semantics(
      label: day.today
          ? 'Today, ${day.weekday} ${day.date}'
          : '${day.weekday} ${day.month} ${day.date}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: TotemColors.coreWhite,
          child: SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  height: 20,
                  alignment: Alignment.center,
                  color: day.today ? TotemColors.coreMauve : _railBand,
                  child: Text(
                    day.today ? '${day.date} ${day.weekday}' : day.month,
                    style: band,
                  ),
                ),
                SizedBox(
                  height: 49,
                  child: Center(
                    child: day.today
                        ? Text(
                            'Today',
                            style: TotemText.raw(
                              size: 14,
                              weight: FontWeight.w600,
                              color: _railInk,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${day.date}',
                                style: TotemText.raw(
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: _railInk,
                                ),
                              ),
                              Text(
                                day.weekday,
                                style: TotemText.raw(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: _railInk,
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

/// Not in Figma: what the list shows when the filters leave nothing.
class _Empty extends StatelessWidget {
  const _Empty({required this.filter, required this.onShowAll});

  final SessionsFilter filter;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final where = filter == SessionsFilter.all ? '' : ' in ${filter.label}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.s48),
      child: Column(
        spacing: Spacing.s12,
        children: [
          Text(
            'No sessions$where yet',
            textAlign: TextAlign.center,
            style: TotemText.h3.copyWith(color: TotemColors.coreSlate),
          ),
          Text(
            'New Sessions open every week. Have a look at the others in '
            'the meantime.',
            textAlign: TextAlign.center,
            style: TotemText.bodySmall.copyWith(color: TotemColors.coreGray),
          ),
          const SizedBox(height: Spacing.s4),
          Button(
            variant: ButtonVariant.secondary,
            onPressed: onShowAll,
            child: const Text('Show all sessions'),
          ),
        ],
      ),
    );
  }
}

/// Figma "Navigation" (2315:8104): white tab bar with the phone home
/// indicator under it. Sessions is the current tab.
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TotemColors.coreWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            offset: Offset(2, 2),
            blurRadius: 4,
            color: Color(0x40000000),
          ),
        ],
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
                    icon: SvgPicture.asset(
                      '$_assets/nav-home.svg',
                      width: 25,
                      height: 25,
                    ),
                    ink: const Color(0xFF717171),
                  ),
                  _NavItem(
                    label: 'Sessions',
                    selected: true,
                    // The filled disc is drawn with room for its shadow.
                    // This offset puts the 25px circle on the icon slot.
                    icon: SizedBox.square(
                      dimension: 25,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -8,
                            top: -6,
                            child: SvgPicture.asset(
                              '$_assets/nav-sessions.svg',
                              width: 41,
                              height: 41,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ink: TotemColors.coreMauve,
                  ),
                  _NavItem(
                    label: 'Blog',
                    icon: SvgPicture.asset(
                      '$_assets/nav-blog.svg',
                      width: 25,
                      height: 25,
                    ),
                    ink: TotemColors.coreGray,
                  ),
                  _NavItem(
                    label: 'Profile',
                    icon: SvgPicture.asset(
                      '$_assets/nav-profile.svg',
                      width: 25,
                      height: 25,
                    ),
                    ink: TotemColors.coreGray,
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
    required this.ink,
    this.selected = false,
  });

  final String label;
  final Widget icon;
  final Color ink;
  final bool selected;

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
          spacing: 2,
          children: [
            icon,
            Text(
              label,
              textAlign: TextAlign.center,
              style: TotemText.raw(
                size: 9,
                weight: selected ? FontWeight.w700 : FontWeight.w400,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
