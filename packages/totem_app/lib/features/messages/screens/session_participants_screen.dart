import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/shared/router.dart';

// Shared purple used for accents on this screen (accent bar, joined text, button).
const _purple = Color(0xFF8C7AA8);

// Mock participants — same data pool as new_message_screen.dart.
// Swapped for real API data when the backend ships.
typedef _Participant = ({
  String id,
  String name,
  String email,
  String joinedSessions,
  int sessions,
  int reviews,
});

const _mockParticipants = <_Participant>[
  (
    id: 'conv_emily',
    name: 'Emily',
    email: 'emily@gmail.com',
    joinedSessions: 'Joined Mar 12 · 8 sessions',
    sessions: 8,
    reviews: 2,
  ),
  (
    id: 'conv_rafael',
    name: 'Rafael',
    email: 'rafael@gmail.com',
    joinedSessions: 'Joined Mar 5 · 12 sessions',
    sessions: 12,
    reviews: 4,
  ),
  (
    id: 'conv_tanya',
    name: 'Tanya',
    email: 'tanya@gmail.com',
    joinedSessions: 'Joined Feb 22 · 15 sessions',
    sessions: 15,
    reviews: 3,
  ),
  (
    id: 'conv_derek',
    name: 'Kai',
    email: 'kai@gmail.com',
    joinedSessions: 'Joined Mar 18 · 5 sessions',
    sessions: 5,
    reviews: 1,
  ),
  (
    id: 'conv_leila',
    name: 'Nina',
    email: 'nina@gmail.com',
    joinedSessions: 'Joined Feb 14 · 20 sessions',
    sessions: 20,
    reviews: 6,
  ),
];

/// Keeper-only screen showing a session's registered participants.
///
/// Lets the keeper message individual participants or trigger a bulk message
/// to everyone in the session. Participant data is mocked until the backend
/// ships the relevant endpoint.
class SessionParticipantsScreen extends StatelessWidget {
  const SessionParticipantsScreen({required this.session, super.key});

  final SessionDetailSchema session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const participants = _mockParticipants;
    final date = DateFormat(
      "EEEE, MMM d · h:mm a",
    ).format(session.start.toLocal());
    final subtitle =
        '${participants.length} participants  ·  ${session.duration} min';

    return Scaffold(
      backgroundColor: AppTheme.surfaceCard,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavBar(),
          const Divider(height: 1, thickness: 1, color: AppTheme.divider),

          // Session header
          Container(
            width: double.infinity,
            color: AppTheme.surfaceCard,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        session.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textHeading,
                          fontWeight: FontWeight.w600,
                          fontSize: 28,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  date,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppTheme.divider),

          // Participants list
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 32),
              children: [
                _SectionLabel('PARTICIPANTS · ${participants.length}'),
                const SizedBox(height: 12),

                // Bulk message button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(
                      RouteNames.composeToParticipants(session.slug),
                      extra: session,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mauve,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      shadowColor: AppTheme.mauve.withValues(alpha: 0.15),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamilySans,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    child: const Text('Message All Participants'),
                  ),
                ),

                const SizedBox(height: 16),

                for (var i = 0; i < participants.length; i++) ...[
                  _ParticipantCard(
                    participant: participants[i],
                    color: AppTheme
                        .avatarPalette[i % AppTheme.avatarPalette.length],
                    onTap: () => _showParticipantDialog(
                      context,
                      participants[i],
                      AppTheme.avatarPalette[i % AppTheme.avatarPalette.length],
                    ),
                  ),
                  if (i != participants.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showParticipantDialog(
    BuildContext context,
    _Participant participant,
    Color color,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: _ParticipantDialog(
          participant: participant,
          color: color,
          onSendMessage: () {
            Navigator.of(context).pop();
            _openThread(context, participant);
          },
        ),
      ),
    );
  }

  void _openThread(BuildContext context, _Participant participant) {
    final conversation = Conversation(
      id: participant.id,
      peer: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime.now(),
        name: participant.name,
        slug: participant.id,
        profileAvatarSeed: '${participant.id}-seed',
      ),
      updatedAt: DateTime.now(),
    );
    context.push(RouteNames.messageThread(participant.id), extra: conversation);
  }
}

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: AppTheme.surfaceCard,
        height: 52,
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
              'Session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textHeading,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.participant,
    required this.color,
    required this.onTap,
  });

  final _Participant participant;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 88,
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
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  participant.name.substring(0, 1).toUpperCase(),
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
                  spacing: 2,
                  children: [
                    Text(
                      participant.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textHeading,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      participant.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      participant.joinedSessions,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _purple,
                        fontSize: 12,
                      ),
                    ),
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
        ),
      ),
    );
  }
}

class _ParticipantDialog extends StatelessWidget {
  const _ParticipantDialog({
    required this.participant,
    required this.color,
    required this.onSendMessage,
  });

  final _Participant participant;
  final Color color;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Text(
              participant.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Name
          Text(
            participant.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textHeading,
              fontWeight: FontWeight.w600,
              fontSize: 21,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Text(
            participant.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  value: '${participant.sessions}',
                  label: 'Sessions',
                ),
              ),
              Expanded(
                child: _StatCell(
                  value: '${participant.reviews}',
                  label: 'Reviews',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Send message button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSendMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
              label: const Text('Send message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(50),
                elevation: 0,
                shadowColor: _purple.withValues(alpha: 0.32),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamilySans,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      spacing: 2,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.textHeading,
            fontWeight: FontWeight.w600,
            fontSize: 28,
            height: 1.2,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
