import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PreJoinScreen extends ConsumerWidget {
  const PreJoinScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Session')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Pre-Join Session Screen',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              'Session ID: $sessionId',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            // Camera preview placeholder
            Container(
              width: 200,
              height: 150,
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.camera_alt, size: 40, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            // Audio and video toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic),
                  onPressed: () {},
                  tooltip: 'Toggle Microphone',
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.videocam),
                  onPressed: () {},
                  tooltip: 'Toggle Camera',
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.push('/sessions/$sessionId');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Join Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
