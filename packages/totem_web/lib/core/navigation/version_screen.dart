import 'package:flutter/material.dart';
import 'package:totem_web/core/services/build_info.dart';

/// Displays the exact build version and deployment metadata at `/_version`.
///
/// This is an internal diagnostic page — no navigation chrome, minimal
/// styling — so it works even when the router is in an error state.
class VersionScreen extends StatelessWidget {
  const VersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final info = BuildInfo.fromEnvironment();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Version'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Tile(label: 'Version', value: info.version),
          _Tile(label: 'Build number', value: info.buildNumber),
          _Tile(label: 'Environment', value: info.environment),
          _Tile(label: 'Commit SHA', value: info.commitSha),
          if (info.shortCommitSha != info.commitSha)
            _Tile(label: 'Commit (short)', value: info.shortCommitSha),
          _Tile(
            label: 'Deployed at',
            value: info.deploymentTimestamp.isNotEmpty
                ? info.deploymentTimestamp
                : 'Local development build',
          ),
          const SizedBox(height: 24),
          Text(
            'This information is automatically injected during deployment. '
            'Use it to verify which build is running in any environment.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
