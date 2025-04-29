import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  bool _isLoading = false;
  File? _profileImage;

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  // Field validation
  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your first name';
    }
    return null;
  }

  // Upload profile image (mock implementation)
  Future<void> _selectProfileImage() async {
    // In a real implementation, you would use image_picker package
    // For now, we'll just set a flag to simulate image selection
    setState(() {
      // Mock a file selection
      _profileImage = File('');
    });
  }

  // Submit profile setup
  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(
            firstName: _firstNameController.text.trim(),
            profileImagePath: _profileImage?.path,
          );
      if (mounted) {
        // Navigate to home
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            context.go('/spaces');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        await ErrorHandler.handleApiError(context, e, onRetry: _submitProfile);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Profile'),
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to Totem!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Let's set up your profile to get started",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Profile image selection
                Center(
                  child: GestureDetector(
                    onTap: _selectProfileImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child:
                          _profileImage != null
                              ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40,
                              )
                              : Icon(
                                Icons.add_a_photo,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _selectProfileImage,
                    child: Text(
                      _profileImage != null
                          ? 'Change Photo'
                          : 'Add Profile Photo (Optional)',
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // First name input
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    hintText: 'Enter your first name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _validateFirstName,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 32),

                // Submit button
                if (_isLoading)
                  const LoadingIndicator()
                else
                  ElevatedButton(
                    onPressed: _submitProfile,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Complete Profile'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
