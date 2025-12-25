import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:uuid/uuid.dart';

Future<void> showProfileImagePicker(BuildContext context) async {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (context) => const ProfileImagePicker(),
  );
}

class ProfileImagePicker extends ConsumerStatefulWidget {
  const ProfileImagePicker({super.key});

  @override
  ConsumerState<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends ConsumerState<ProfileImagePicker> {
  ProfileAvatarTypeEnum? __state;
  ProfileAvatarTypeEnum get _state => __state!;
  var _loading = false;

  final _imagePicker = ImagePicker();
  XFile? _pickedImage;

  static const _uuid = Uuid();
  String? _tieDyeSeed;

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() {
      _pickedImage = image;
    });
  }

  void _randomizeTieDyeSeed() {
    setState(() => _tieDyeSeed = _uuid.v4());
  }

  Future<void> _onSave() async {
    setState(() => _loading = true);

    final updated = await ref
        .read(authControllerProvider.notifier)
        .updateUserProfile(
          profileAvatarType: _state,
          profileImage:
              _pickedImage != null && _state == ProfileAvatarTypeEnum.im
              ? File(_pickedImage!.path)
              : null,
          avatarSeed: _state == ProfileAvatarTypeEnum.td ? _tieDyeSeed : null,
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
    final user = ref.watch(
      authControllerProvider.select((auth) => auth.user),
    );
    __state ??= user?.profileAvatarType ?? ProfileAvatarTypeEnum.td;

    return PopScope(
      canPop: !_loading,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    switch (_state) {
                      case ProfileAvatarTypeEnum.$unknown:
                      case ProfileAvatarTypeEnum.td:
                        _randomizeTieDyeSeed();
                      case ProfileAvatarTypeEnum.im:
                        await _pickImage();
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: AlignmentDirectional.center,
                    children: [
                      IgnorePointer(
                        child: FutureBuilder<Uint8List?>(
                          future: _pickedImage?.readAsBytes(),
                          builder: (context, asyncSnapshot) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              child: UserAvatar(
                                key: ValueKey(_tieDyeSeed ?? 'default'),
                                radius: 50,
                                seed: _tieDyeSeed,
                                image:
                                    () {
                                          if (_state ==
                                              ProfileAvatarTypeEnum.im) {
                                            return asyncSnapshot.hasData
                                                ? MemoryImage(
                                                    asyncSnapshot.data!,
                                                  )
                                                : user?.profileImage != null
                                                ? CachedNetworkImageProvider(
                                                    getFullUrl(
                                                      user!.profileImage!,
                                                    ),
                                                  )
                                                : null;
                                          }
                                        }()
                                        as ImageProvider?,
                              ),
                            );
                          },
                        ),
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
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            child: Center(
                              key: ValueKey(_state),
                              child: switch (_state) {
                                ProfileAvatarTypeEnum.im => const TotemIcon(
                                  TotemIcons.upload,
                                ),
                                ProfileAvatarTypeEnum.td || _ => const Icon(
                                  Icons.shuffle,
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    __state = _state == ProfileAvatarTypeEnum.td
                        ? ProfileAvatarTypeEnum.im
                        : ProfileAvatarTypeEnum.td;
                  });
                },
                child: Center(
                  child: Container(
                    height: 43,
                    width: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsetsDirectional.all(5),
                    child: Stack(
                      children: [
                        AnimatedPositionedDirectional(
                          start: _state == ProfileAvatarTypeEnum.td
                              ? 0
                              : 260 / 2,
                          end: _state == ProfileAvatarTypeEnum.td ? 260 / 2 : 0,
                          top: 0,
                          bottom: 0,
                          curve: Curves.easeInOut,
                          duration: const Duration(milliseconds: 200),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Row(
                            spacing: 10,
                            children: [
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _state == ProfileAvatarTypeEnum.td
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                  child: const Text('Tie Dye'),
                                ),
                              ),
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _state == ProfileAvatarTypeEnum.im
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                  child: const Text('Image'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _loading ? () {} : _onSave,
                child: _loading
                    ? const LoadingIndicator(
                        size: 24,
                        color: Colors.white,
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
