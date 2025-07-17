import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(spacesSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: summary.when(
        data: (summary) {
          return CustomScrollView(
            slivers: [],
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
