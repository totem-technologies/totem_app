import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/providers/compose_to_participants_provider.dart';
import 'package:totem_core/shared/router.dart';

import '../mocks/message_mocks.dart';

/// Keeper-only compose screen for broadcasting a message to all (or a subset
/// of) participants in a session. All data is mocked; the send action is a
/// no-op until the backend ships the bulk-message endpoint.
class ComposeToParticipantsScreen extends ConsumerStatefulWidget {
  const ComposeToParticipantsScreen({required this.session, super.key});

  final SessionDetailSchema session;

  @override
  ConsumerState<ComposeToParticipantsScreen> createState() =>
      _ComposeToParticipantsScreenState();
}

class _ComposeToParticipantsScreenState
    extends ConsumerState<ComposeToParticipantsScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessages(BuildContext context) async {
    final notifier = ref.read(
      composeToParticipantsProvider(mockParticipantNames).notifier,
    );
    final success = await notifier.send(_messageController.text.trim());
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      builder: (_) {
        final selected = ref.read(
          composeToParticipantsProvider(mockParticipantNames),
        );
        return _SendResultDialog(
          success: success,
          sentCount: selected.selected.length,
          sessionName: widget.session.space.title,
          onGoToMessages: () {
            Navigator.of(context).pop();
            context.go(RouteNames.messages);
          },
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final composeState = ref.watch(
      composeToParticipantsProvider(mockParticipantNames),
    );
    final selectedCount = composeState.selected.length;
    final sessionName = widget.session.space.title;
    final totalCount = mockParticipantNames.length;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Column(
        children: [
          _NavBar(),
          const Divider(height: 1, thickness: 1, color: AppTheme.divider),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'This message will be sent to $totalCount participants '
                    'in $sessionName as individual conversations.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recipients card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TO',
                          style: TextStyle(
                            color: AppTheme.messagePurple,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: mockParticipantNames
                              .map(
                                (name) => _RecipientChip(
                                  label: name,
                                  selected: composeState.selected.contains(
                                    name,
                                  ),
                                  onTap: () => ref
                                      .read(
                                        composeToParticipantsProvider(
                                          mockParticipantNames,
                                        ).notifier,
                                      )
                                      .toggleRecipient(name),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Compose box
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 160),
                    padding: const EdgeInsetsDirectional.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textHeading,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Write your message…',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    spacing: 12,
                    children: [
                      // Cancel
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.mauve,
                          side: const BorderSide(color: AppTheme.mauve),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontFamily: AppTheme.fontFamilySans,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),

                      // Send
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedCount == 0
                              ? null
                              : () => _sendMessages(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.mauve,
                            foregroundColor: AppTheme.white,
                            disabledBackgroundColor: AppTheme.mauve.withValues(
                              alpha: 0.4,
                            ),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            elevation: 0,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontFamily: AppTheme.fontFamilySans,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                          child: Text('Send to $selectedCount participants'),
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
    );
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
              'Message Participants',
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

class _SendResultDialog extends StatelessWidget {
  const _SendResultDialog({
    required this.success,
    required this.sentCount,
    required this.sessionName,
    required this.onGoToMessages,
    required this.onDismiss,
  });

  final bool success;
  final int sentCount;
  final String sessionName;
  final VoidCallback onGoToMessages;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            _ResultIcon(success: success),

            const SizedBox(height: 16),

            // Title
            Text(
              success ? 'Messages Sent!' : 'Something Went Wrong',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textHeading,
                fontWeight: FontWeight.w600,
                fontSize: 21,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            // Body
            Text(
              success
                  ? 'Your message was sent to $sentCount participants '
                        'in $sessionName as individual conversations.'
                  : 'We couldn\'t send your message. Please check your '
                        'connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            const Divider(height: 1, thickness: 1, color: AppTheme.divider),

            const SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: success ? onGoToMessages : onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mauve,
                  foregroundColor: AppTheme.white,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(50),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamilySans,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                child: Text(success ? 'Go to Messages' : 'Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultIcon extends StatelessWidget {
  const _ResultIcon({required this.success});

  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: success ? AppTheme.messageSuccessBg : AppTheme.messageErrorBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        success ? Icons.check_rounded : Icons.close_rounded,
        color: success
            ? AppTheme.messageSuccessIcon
            : AppTheme.messageErrorIcon,
        size: 32,
      ),
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsetsDirectional.only(
          start: 10,
          end: 12,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? AppTheme.messagePurple : AppTheme.messagePurpleBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            if (selected)
              const Icon(Icons.check, color: AppTheme.white, size: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.white : AppTheme.messageChipText,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
