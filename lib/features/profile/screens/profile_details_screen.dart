import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  var _loading = false;
  XFile? _pickedImage;

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

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() {
      _pickedImage = image;
    });
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
    });

    setState(() {
      _loading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CardScreen(
      showLogoOnLargeScreens: false,
      showBackground: false,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Center(
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                FutureBuilder<Uint8List?>(
                  future: _pickedImage?.readAsBytes(),
                  builder: (context, asyncSnapshot) {
                    return UserAvatar(
                      radius: 50,
                      image:
                          asyncSnapshot.hasData
                              ? MemoryImage(asyncSnapshot.data!)
                              : null,
                    );
                  },
                ),
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
          onPressed: _loading ? null : _save,
          child: _loading ? const LoadingIndicator() : const Text('Update'),
        ),
      ],
    );
  }
}
