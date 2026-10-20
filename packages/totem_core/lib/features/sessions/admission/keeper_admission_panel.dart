import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';

/// Queue controls are kept separate from the room's existing call controls.
class KeeperAdmissionPanel extends StatelessWidget {
  const new({
    required this.requests,
    required this.onDecision,
    required this.onAdmitAll,
    required this.onClose,
    required this.busy,
    required this.desktop,
    super.key,
  });

  final List<AdmissionRequest> requests;
  final Future<void> Function(AdmissionRequest request, bool approve)
  onDecision;
  final VoidCallback onAdmitAll;
  final VoidCallback onClose;
  final bool busy;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: desktop ? 340 : double.infinity,
        height: desktop ? height * 0.65 : height * 0.42,
        child: Column(
          children: [
            ListTile(
              title: Text('Waiting to join (${requests.length})'),
              trailing: IconButton(
                tooltip: 'Close admission queue',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final expires = MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(request.expiresAt));
                  return ListTile(
                    title: Text(request.displayName),
                    subtitle: Text('Expires at $expires'),
                    isThreeLine: true,
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Decline ${request.displayName}',
                          icon: const Icon(Icons.close),
                          onPressed: busy
                              ? null
                              : () => onDecision(request, false),
                        ),
                        IconButton(
                          tooltip: 'Admit ${request.displayName}',
                          icon: const Icon(Icons.check),
                          onPressed: busy
                              ? null
                              : () => onDecision(request, true),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy || requests.isEmpty ? null : onAdmitAll,
                  child: const Text('Admit all'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
