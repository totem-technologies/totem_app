import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Spaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Spaces Discovery Screen',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),
            // Stub for spaces list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildSpaceCard(context, 'space-1', 'Wellness Space'),
                  _buildSpaceCard(context, 'space-2', 'Tech Talks'),
                  _buildSpaceCard(context, 'space-3', 'Book Club'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceCard(BuildContext context, String spaceId, String title) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.group),
        title: Text(title),
        subtitle: const Text('Tap to view details'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          context.push('/spaces/$spaceId');
        },
      ),
    );
  }
}
