import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CardScreen(
      showLogoOnLargeScreens: false,
      showBackground: false,
      children: [
        GestureDetector(
          onTap: () {
            // TODO(bdlukaa): Upload new profile picture
          },
          child: Center(
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                const UserAvatar(radius: 50),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          onPressed: () {},
          child: _loading ? const LoadingIndicator() : const Text('Update'),
        ),
      ],
    );
  }
}
