import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(listSpacesProvider);
    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: spaces.when(
        data: (spaces) {
          return ListView.builder(
            itemCount: spaces.length,
            itemBuilder: (context, index) {
              final space = spaces[index];
              return ListTile(
                title: Text(space.name),
                subtitle: Text(space.description),
              );
            },
          );
        },
        loading: LoadingScreen.new,
        error: (error, stackTrace) {
          return ErrorScreen(error: error);
        },
      ),
    );
  }
}
