import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    show Participant;
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/session_button_style.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

Future<void> showDeclinedParticipantsModal(
  BuildContext context, {
  required String sessionSlug,
  required String keeperIdentity,
}) {
  return showResponsiveModal<void>(
    context: sessionNavigatorContext(context),
    useRootNavigator: false,
    showDragHandle: false,
    bottomSheetBackgroundColor: AppTheme.cream,
    dialogBackgroundColor: AppTheme.cream,
    bottomSheetBuilder: (context) => DeclinedParticipants(
      sessionSlug: sessionSlug,
      keeperIdentity: keeperIdentity,
    ),
    largeScreenBuilder: (context) => SizedBox(
      width: 400,
      child: DeclinedParticipants(
        sessionSlug: sessionSlug,
        keeperIdentity: keeperIdentity,
      ),
    ),
  );
}

class DeclinedParticipants extends ConsumerStatefulWidget {
  const DeclinedParticipants({
    required this.sessionSlug,
    required this.keeperIdentity,
    super.key,
  });

  final String sessionSlug;
  final String keeperIdentity;

  @override
  ConsumerState<DeclinedParticipants> createState() =>
      _DeclinedParticipantsState();
}

class _DeclinedParticipantsState extends ConsumerState<DeclinedParticipants> {
  Future<void> _allow(Participant participant) async {
    final service = ref.read(currentSessionProvider)?.admission;
    if (service?.mounted != true || service!.busy) return;
    try {
      await service.allow(participant);
    } catch (error, stackTrace) {
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to allow declined participant',
      );
      if (mounted) {
        await ErrorHandler.showErrorDialog(
          sessionNavigatorContext(context),
          useRootNavigator: false,
          message:
              'Failed to allow ${participant.user.name.value ?? participant.identity}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(currentSessionProvider)?.admission;
    if (service == null || !service.mounted) {
      return const Center(child: Text('Admission controls unavailable'));
    }
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final theme = Theme.of(context);
        final participants = service.declined;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetDragHandle(),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 20,
                bottom: 6,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      'Declined Participants',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      key: const Key('close-declined-participants-modal'),
                      icon: const TotemIcon(
                        TotemIcons.x,
                        size: 20,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            if (service.error case final error?)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Flexible(
              child: service.snapshot == null
                  ? service.error != null
                        ? Center(
                            child: TextButton(
                              onPressed: service.sync,
                              child: const Text('Retry'),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator.adaptive(),
                          )
                  : Builder(
                      builder: (context) {
                        return CustomScrollView(
                          shrinkWrap: true,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 20,
                                  end: 20,
                                  bottom: 20,
                                ),
                                child: Text(
                                  participants.isEmpty
                                      ? 'No participants have been declined'
                                      : 'Tap Allow to remove a declined participant',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            if (participants.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 20,
                                ),
                                sliver: SliverList.builder(
                                  itemCount: participants.length,
                                  itemBuilder: (context, index) =>
                                      _DeclinedParticipantItem(
                                        key: ValueKey(
                                          participants[index].identity,
                                        ),
                                        participant: participants[index],
                                        disabled: service.busy,
                                        onAllow: _allow,
                                      ),
                                ),
                              ),
                            const SliverSafeArea(
                              top: false,
                              bottom: true,
                              sliver: SliverToBoxAdapter(),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DeclinedParticipantItem extends StatelessWidget {
  const _DeclinedParticipantItem({
    required this.participant,
    required this.disabled,
    required this.onAllow,
    super.key,
  });

  final Participant participant;
  final bool disabled;
  final Future<void> Function(Participant) onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = participant.identity;
    final name = participant.user.name.value;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          height: 32,
          child: UserAvatar.slug(
            identity,
            borderRadius: BorderRadius.circular(20),
            borderWidth: 0,
            loading: const SizedBox.shrink(),
            error: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: TotemIcon(
                TotemIcons.person,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          name ?? identity,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: SizedBox(
          width: 100,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            child: OutlinedButton(
              style: SessionButtonStyle.outlined(
                compact: true,
                foregroundColor: theme.colorScheme.onSurface,
                side: BorderSide(color: theme.colorScheme.outline),
              ),
              onPressed: disabled ? null : () => onAllow(participant),
              child: const Text('Allow'),
            ),
          ),
        ),
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
    );
  }
}
