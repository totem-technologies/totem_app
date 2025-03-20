import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/space_repository.dart';

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var spaces = ref.watch(listSpacesProvider);
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
              child: switch (spaces) {
                AsyncData(:final value) => ListView(
                  shrinkWrap: true,
                  children:
                      value
                          .map(
                            (space) => _buildSpaceCard(
                              context,
                              space.slug,
                              space.title,
                            ),
                          )
                          .toList(),
                ),
                AsyncError() => const Text(
                  'Oops, something unexpected happened',
                ),
                _ => const CircularProgressIndicator(),
              },
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
