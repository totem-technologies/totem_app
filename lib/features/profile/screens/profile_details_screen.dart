import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/screens/profile_image_picker.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/info_text.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  var _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
    });

    final updated = await ref
        .read(authControllerProvider.notifier)
        .updateUserProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
        );

    if (!mounted) return;

    if (updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.of(context).pop();
    } else {
      ErrorHandler.showErrorSnackBar(
        context,
        'Failed to update profile. Try again later.',
      );
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CardScreen(
      showLogoOnLargeScreens: false,
      showBackground: false,
      isLoading: _loading,
      appBar: AppBar(),
      children: [
        GestureDetector(
          // onTap: _pickImage,
          onTap: () => showProfileImagePicker(context),
          child: Center(
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                UserAvatar.currentUser(radius: 50),
                PositionedDirectional(
                  bottom: -10,
                  end: -10,
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: AlignmentDirectional.center,
                    child: const TotemIcon(TotemIcons.edit),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Name',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: 'Enter name'),
          // validator: _validateFirstName,
          // enabled: !widget.isLoading,
          restorationId: 'first_name_onboarding_input',
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
        ),
        const InfoText('Your name will be visible to other people on Totem. '),
        const SizedBox(height: 24),
        Text(
          'Email address',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: 'Enter email address'),
          // validator: _validateFirstName,
          // enabled: !widget.isLoading,
          restorationId: 'email_onboarding_input',
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
        ),
        const InfoText('Your email will be private.'),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const LoadingIndicator() : const Text('Update'),
        ),
      ],
    );
  }
}
