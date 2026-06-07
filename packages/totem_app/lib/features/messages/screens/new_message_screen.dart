import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/providers/is_current_user_keeper_provider.dart';

/// A person row shown in the New Message screen (keeper or participant).
typedef _Person = ({String name, String? subtitle});

// Mock data — there is no backend for messaging yet.
const _keepers = <_Person>[
  (name: 'Vanessa', subtitle: null),
  (name: 'Marcus', subtitle: null),
  (name: 'Sarah', subtitle: null),
  (name: 'Jordan', subtitle: null),
  (name: 'Alex', subtitle: null),
];

const _recentParticipants = <_Person>[
  (name: 'Emily', subtitle: 'Anxiety & Coping · Mar 30'),
  (name: 'Rafael', subtitle: 'Recovery Circle · Mar 28'),
  (name: 'Tanya', subtitle: 'Grief Support · Mar 27'),
];

const _otherParticipants = <_Person>[
  (name: 'Derek', subtitle: 'Anxiety & Coping · Mar 24'),
  (name: 'Leila', subtitle: 'Recovery Circle · Mar 21'),
];

/// Screen for composing a new message. Shown when tapping the "+" button on the
/// Messages screen. Renders two role-based variants:
///  - normal user: a "Search keepers" field + a list of their keepers.
///  - keeper: a "Search participants" field + recent / other session
///    participants.
///
/// All data is mocked and row taps are no-ops until a backend exists.
class NewMessageScreen extends ConsumerWidget {
  const NewMessageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKeeper = ref.watch(isCurrentMessagingUserKeeperProvider);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavBar(),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 32),
                children: isKeeper
                    ? _keeperContent()
                    : _participantContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _participantContent() {
    return [
      const _SearchField(hint: 'Search keepers'),
      const SizedBox(height: 12),
      const _SectionLabel('YOUR KEEPERS'),
      const SizedBox(height: 16),
      ..._cardsFor(_keepers),
    ];
  }

  List<Widget> _keeperContent() {
    return [
      const _SearchField(hint: 'Search participants'),
      const SizedBox(height: 24),
      const _SectionLabel('YOUR SESSION PARTICIPANTS'),
      const SizedBox(height: 12),
      ..._cardsFor(_recentParticipants),
      const SizedBox(height: 12),
      const _SectionLabel('OTHER PARTICIPANTS'),
      const SizedBox(height: 12),
      ..._cardsFor(_otherParticipants, colorOffset: _recentParticipants.length),
    ];
  }

  List<Widget> _cardsFor(List<_Person> people, {int colorOffset = 0}) {
    return [
      for (var i = 0; i < people.length; i++) ...[
        _PersonCard(
          person: people[i],
          color: AppTheme.avatarPalette[(i + colorOffset) %
              AppTheme.avatarPalette.length],
        ),
        if (i != people.length - 1) const SizedBox(height: 10),
      ],
    ];
  }
}

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceCard,
      padding: EdgeInsetsDirectional.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: AppTheme.textHeading,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'New Message',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textHeading,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: AppTheme.fieldFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hint,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.color});

  final _Person person;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              person.name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textHeading,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (person.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    person.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.chevron,
            size: 24,
          ),
        ],
      ),
    );
  }
}
