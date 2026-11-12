import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
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
    context: context,
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
  final _restoringIdentities = <String>{};
  Set<String>? _knownIdentities;

  DeclinedSessionParticipantsProvider get _provider =>
      declinedSessionParticipantsProvider(
        widget.sessionSlug,
        widget.keeperIdentity,
      );

  Future<void> _allow(String identity, String? name) async {
    if (_restoringIdentities.isNotEmpty) return;
    setState(() => _restoringIdentities.add(identity));
    try {
      await ref.read(_provider.notifier).allow(identity);
    } catch (error, stackTrace) {
      ErrorHandler.report(
        error,
        stackTrace: stackTrace,
        message: 'Failed to allow declined participant',
      );
      if (mounted) {
        await ErrorHandler.showErrorDialog(
          context,
          message: 'Failed to allow ${name ?? identity}',
        );
      }
    } finally {
      if (mounted) setState(() => _restoringIdentities.remove(identity));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final declined = ref.watch(_provider);
    final identities = switch (declined) {
      AsyncData<Set<String>>(:final value) => _knownIdentities = value,
      AsyncError<Set<String>>() => _knownIdentities,
      AsyncLoading<Set<String>>() => null,
    };

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
        Flexible(
          child: identities == null
              ? declined.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                  error: (error, stackTrace) => ErrorScreen(
                    hideAppBar: true,
                    showHomeButton: false,
                    title: 'Failed to load declined participants',
                    onRetry: () async => ref.invalidate(_provider),
                  ),
                  data: (_) => const SizedBox.shrink(),
                )
              : Builder(
                  builder: (context) {
                    final participants = identities.toList()..sort();
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
                                    key: ValueKey(participants[index]),
                                    identity: participants[index],
                                    disabled: _restoringIdentities.isNotEmpty,
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
  }
}

class _DeclinedParticipantItem extends ConsumerWidget {
  const _DeclinedParticipantItem({
    required this.identity,
    required this.disabled,
    required this.onAllow,
    super.key,
  });

  final String identity;
  final bool disabled;
  final Future<void> Function(String identity, String? name) onAllow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider(identity));
    final name = user.value?.name.value;

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
              onPressed: disabled ? null : () => onAllow(identity, name),
              child: const Text('Allow'),
            ),
          ),
        ),
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
    );
  }
}
