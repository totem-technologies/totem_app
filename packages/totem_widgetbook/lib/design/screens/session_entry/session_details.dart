import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../components/button/button.dart';
import '../../components/session_card/session_card.dart';
import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/session_entry';

enum DetailsPhase { tooEarly, joinWindow, inProgress }

/// Five facts, same order as the Figma grid: three up top, two below.
const _facts = [
  (icon: 'icon-subscribers', value: '9', label: 'subscribers'),
  (icon: 'icon-duration', value: '60', label: 'min'),
  (icon: 'icon-seats', value: '9', label: 'seats left'),
  (icon: 'icon-repeat', value: '', label: 'Twice a month'),
  (icon: 'icon-cost', value: '', label: 'No Cost'),
];

const _pageBackground = Color(0xFFFCEFE4);
const _ink = TotemColors.coreSlate;
final _inkSoft = fade(TotemColors.coreSlate, 0.7);
const _black = Color(0xFF000000);

/// The page someone lands on before a Session. The info card carries the
/// one action that matters: Join Session. Everything else is context —
/// what it is, who holds it, what's coming next.
///
/// Measurements follow the 402px Figma screen. The info card's small text
/// is raised to 11px so nothing drops below readable. From 640 wide it
/// becomes one centered column and the hero gets rounded corners.
class SessionDetails extends StatelessWidget {
  const SessionDetails({
    super.key,
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
    required this.dateLabel,
    required this.timeLabel,
    this.onJoin,
    this.onBack,
  });

  final String spaceName;
  final String sessionName;
  final String keeperName;
  final String dateLabel;
  final String timeLabel;
  final VoidCallback? onJoin;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 560 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: wide ? 24 : 0, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [
                      _hero(wide),
                      _intro(),
                      _card(),
                      _about(),
                      _similar(),
                      _keeper(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Hero photo with back and share floating over it.
  Widget _hero(bool wide) {
    Widget roundButton(String icon, String label, VoidCallback? onTap) {
      // Hit area stays 44pt; the drawn circle stays 30px.
      return Pressable(
        onTap: onTap ?? () {},
        pressedScale: 0.97,
        focusColor: TotemColors.coreMauve,
        focusRadius: BorderRadius.circular(Radii.full),
        semanticLabel: label,
        builder: (context, states) => SizedBox.square(
          dimension: 44,
          child: Center(
            child: SvgPicture.asset(
              '$_assets/$icon.svg',
              width: 30,
              height: 30,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(wide ? Radii.lg : 0),
        child: SizedBox(
          height: wide ? 300 : 262,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Image(
                image: AssetImage('$_assets/hero.jpg'),
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 10 - 3.5,
                left: 20 - 7,
                right: 20 - 7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    roundButton('back', 'Back to the Space', onBack),
                    roundButton('share', 'Share', null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Space, title, Keeper.
  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            spaceName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TotemText.raw(size: 16, color: _inkSoft),
          ),
          Semantics(
            header: true,
            child: Text(
              sessionName,
              style: TotemText.raw(
                size: 21,
                weight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Row(
            spacing: 4,
            children: [
              const ClipOval(
                child: Image(
                  image: AssetImage('$_assets/avatar-vanessa.png'),
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              Text('with', style: TotemText.raw(size: 16, color: _ink)),
              Flexible(
                child: Text(
                  keeperName,
                  style: TotemText.raw(
                    size: 18,
                    weight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Info card. Facts, when, and the Join action. Same shape in every
  /// phase — timeline copy lives on the overlay, not under the button.
  Widget _card() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TotemColors.coreWhite,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Semantics(
        container: true,
        label: 'Session info',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 17,
          children: [
            _factGrid(),
            IntrinsicHeight(
              child: Row(
                spacing: 9,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          dateLabel,
                          style: TotemText.raw(
                            size: 12,
                            weight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: TotemText.raw(
                            size: 12,
                            weight: FontWeight.w500,
                            color: _inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Button(
                      size: ButtonSize.compact,
                      onPressed: onJoin ?? () {},
                      child: const Text('Join Session'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Three across, hugging their content, spread edge to edge like Figma.
  /// Columns line up across rows, so the second row sits under the first.
  Widget _factGrid() {
    const columns = 3;
    final rows = <List<Widget>>[];
    for (var i = 0; i < _facts.length; i += columns) {
      final slice = _facts.skip(i).take(columns).map(_fact).toList();
      while (slice.length < columns) {
        slice.add(const SizedBox.shrink());
      }
      rows.add(slice);
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {1: FlexColumnWidth(), 3: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final (index, row) in rows.indexed)
          TableRow(
            children: [
              for (final (column, cell) in row.indexed) ...[
                if (column > 0) const SizedBox(width: 12),
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
                  child: cell,
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _fact(({String icon, String value, String label}) fact) {
    final style = TotemText.raw(size: 11, weight: FontWeight.w600, color: _ink);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        SvgPicture.asset(
          '$_assets/${fact.icon}.svg',
          width: 16.4646,
          height: 16.4646,
        ),
        // A squeezed column ellipsizes instead of overflowing the card.
        Flexible(
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                if (fact.value.isNotEmpty) TextSpan(text: '${fact.value} '),
                TextSpan(
                  text: fact.label,
                  style: fact.value.isEmpty ? null : TextStyle(color: _inkSoft),
                ),
              ],
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _about() {
    final paragraph = TotemText.raw(size: 12, color: _black);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Semantics(
            header: true,
            child: Text(
              'About this Session',
              style: TotemText.raw(
                size: 14,
                weight: FontWeight.w600,
                color: fade(_black, 0.7),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Text(
                'Shame is loud, and it lies. This circle is where you turn the volume '
                'down. Nobody fixes you, nobody gives advice, and nobody performs. You '
                "share when the talking piece reaches you and listen when it doesn't.",
                style: paragraph,
              ),
              Text(
                'Come as you are. Camera on is lovely. Camera off is fine. You can pass '
                'on any turn — that counts as a full turn.',
                style: paragraph,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final _heading = TotemText.raw(
    size: 16,
    weight: FontWeight.w600,
    color: _black,
  );

  /// Upcoming similar Sessions — same card as the declined offer.
  Widget _similar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Semantics(
            header: true,
            child: Text('Upcoming Similar Sessions', style: _heading),
          ),
          const SessionCard(
            photo: AssetImage('$_assets/similar.jpg'),
            spaceName: 'What is Love?',
            sessionName: 'The Fear of Being Loved',
            keeperName: 'Heather',
            keeperPhoto: AssetImage('$_assets/avatar-heather.png'),
            time: '8:30',
            meridiem: 'PM',
            seatsLeft: 2,
          ),
        ],
      ),
    );
  }

  Widget _keeper() {
    final soft = TotemText.raw(size: 12, color: _inkSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Meet The Keeper', style: _heading),
                ),
              ),
              Button(
                variant: ButtonVariant.text,
                size: ButtonSize.compact,
                onPressed: () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    const Text('View Profile'),
                    Transform.rotate(
                      angle: -1.5708,
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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    const ClipOval(
                      child: Image(
                        image: AssetImage('$_assets/avatar-vanessa.png'),
                        width: 60,
                        height: 60,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            keeperName,
                            style: TotemText.raw(
                              size: 20,
                              weight: FontWeight.w600,
                              color: _ink,
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
                    ),
                  ],
                ),
                Text(
                  "Vanessa is a Los Angeles-based artist and recovering hot mess. She's "
                  'battled many challenges, from undiagnosed depression to struggling with '
                  'alcohol abuse, and knows first hand how hard it is to face complex '
                  'emotions alone.',
                  style: soft,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
