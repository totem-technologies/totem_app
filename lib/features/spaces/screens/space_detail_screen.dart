import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SpaceDetailScreen extends ConsumerWidget {
  final String spaceId;

  const SpaceDetailScreen({Key? key, required this.spaceId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In a real app, you'd fetch space details based on the ID
    final spaceName = getSpaceName(spaceId);

    return Scaffold(
      appBar: AppBar(title: Text(spaceName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 80),
            const SizedBox(height: 16),
            Text(
              'Space Detail Screen for $spaceName',
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text('ID: $spaceId', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            // Stub for session list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildSessionCard(
                    context,
                    '$spaceId-session-1',
                    'Morning Session',
                  ),
                  _buildSessionCard(
                    context,
                    '$spaceId-session-2',
                    'Evening Discussion',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to generate a name based on ID (for demo)
  String getSpaceName(String id) {
    switch (id) {
      case 'space-1':
        return 'Wellness Space';
      case 'space-2':
        return 'Tech Talks';
      case 'space-3':
        return 'Book Club';
      default:
        return 'Space $id';
    }
  }

  Widget _buildSessionCard(
    BuildContext context,
    String sessionId,
    String title,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.video_call),
        title: Text(title),
        subtitle: const Text('Tap to join this session'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          context.push('/sessions/$sessionId/pre-join');
        },
      ),
    );
  }
}
