import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VideoRoomScreen extends ConsumerWidget {
  const VideoRoomScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Session'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              // Show participants list
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Video Room Screen',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            Text(
              'Session ID: $sessionId',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            // Participant grid placeholder
            GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey.shade400,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.mic_off, color: Colors.white),
                onPressed: () {},
                tooltip: 'Mute/Unmute',
              ),
              IconButton(
                icon: const Icon(Icons.videocam_off, color: Colors.white),
                onPressed: () {},
                tooltip: 'Video On/Off',
              ),
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.white),
                onPressed: () {},
                tooltip: 'Chat',
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
                onPressed: () {
                  // End call and navigate back
                  context.pop();
                },
                tooltip: 'Leave Session',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
