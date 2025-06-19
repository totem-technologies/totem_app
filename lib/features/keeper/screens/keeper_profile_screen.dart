import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/keeper/repositories/keeper_repository.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class KeeperProfileScreen extends ConsumerWidget {
  const KeeperProfileScreen({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(keeperProfileProvider(username));
    return Scaffold(
      appBar: AppBar(),
      body: async.when(
        data: (keeper) {
          return ListView(
            children: [],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorScreen(error: error),
      ),
    );
  }
}
