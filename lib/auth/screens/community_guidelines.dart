import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';

class CommunityGuidelinesScreen extends ConsumerStatefulWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  ConsumerState<CommunityGuidelinesScreen> createState() =>
      _CommunityGuidelinesScreenState();
}

class _CommunityGuidelinesScreenState
    extends ConsumerState<CommunityGuidelinesScreen> {
  final _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CardScreen(
      isLoading: _isLoading,
      children: [],
    );
  }
}
