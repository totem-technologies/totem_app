import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';

import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/shared/network.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';
import 'package:uuid/uuid.dart';

bool isHeifImageHeader(List<int> header) {
  if (header.length < 12 ||
      String.fromCharCodes(header.sublist(4, 8)) != 'ftyp') {
    return false;
  }

  const heifBrands = {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1'};
  return heifBrands.contains(String.fromCharCodes(header.sublist(8, 12)));
}

Future<bool> _isHeifImage(XFile image) async {
  final mimeType = image.mimeType?.toLowerCase();
  if (mimeType == 'image/heic' || mimeType == 'image/heif') return true;

  final extension = image.name.split('.').last.toLowerCase();
  if (extension == 'heic' || extension == 'heif') return true;

  final header = await image
      .openRead(0, 12)
      .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
  return isHeifImageHeader(header);
}

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
  var _picking = false;
  var _uploadInProgress = false;

  final _imagePicker = ImagePicker();
  final _convertedImagePaths = <String>{};
  final _deletingImagePaths = <String>{};
  File? _pickedImage;
  Uint8List? _pickedImageBytes;

  static const _uuid = Uuid();
  String? _tieDyeSeed;

  Future<void> _deleteConvertedImages({String? keep}) async {
    for (final path in _convertedImagePaths.toList()) {
      if (path == keep || !_deletingImagePaths.add(path)) continue;
      try {
        await File(path).delete();
        _convertedImagePaths.remove(path);
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to delete converted profile image',
        );
      } finally {
        _deletingImagePaths.remove(path);
      }
    }
  }

  @override
  void dispose() {
    // An in-flight upload still needs its file; its completion handles cleanup.
    if (!_uploadInProgress) unawaited(_deleteConvertedImages());
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_picking || _loading) return;
    setState(() => _picking = true);
    String? convertedPath;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      var pickedFile = File(image.path);
      if ((Platform.isAndroid || Platform.isIOS) && await _isHeifImage(image)) {
        try {
          final converted = await FlutterImageCompress.compressAndGetFile(
            image.path,
            '${image.path}.${_uuid.v7()}.jpg',
            format: CompressFormat.jpeg,
            quality: 95,
            autoCorrectionAngle: true,
          );
          if (converted != null) {
            pickedFile = File(converted.path);
            convertedPath = converted.path;
          }
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to convert HEIC profile image',
          );
          // Keep the original; the upload endpoint may accept HEIC/HEIF.
        }
      }

      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pickedImage = pickedFile;
        _pickedImageBytes = bytes;
      });
      if (convertedPath != null) {
        _convertedImagePaths.add(convertedPath);
        convertedPath = null;
      }
      unawaited(_deleteConvertedImages(keep: pickedFile.path));
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to prepare profile image',
      );
      if (!mounted) return;
      ErrorHandler.showErrorSnackBar(
        context,
        'Could not prepare this image. Try selecting another photo.',
      );
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      } else {
        _picking = false;
      }
      if (convertedPath != null) {
        _convertedImagePaths.add(convertedPath);
        unawaited(
          _deleteConvertedImages(keep: mounted ? _pickedImage?.path : null),
        );
      }
    }
  }

  void _randomizeTieDyeSeed() {
    setState(() => _tieDyeSeed = _uuid.v7());
  }

  Future<void> _onSave() async {
    if (_picking || _loading) return;
    setState(() => _loading = true);
    _uploadInProgress = true;
    var updated = false;
    try {
      updated = await ref
          .read(userProfileControllerProvider.notifier)
          .updateUserProfile(
            profileAvatarType: _state,
            profileImage: _state == ProfileAvatarTypeEnum.im
                ? _pickedImage
                : null,
            avatarSeed: _state == ProfileAvatarTypeEnum.td ? _tieDyeSeed : null,
          );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update profile avatar',
      );
    } finally {
      _uploadInProgress = false;
      if (mounted) {
        setState(() => _loading = false);
      } else {
        unawaited(_deleteConvertedImages());
      }
    }
    if (!mounted) return;

    if (updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.of(context).pop();
    } else {
      ErrorHandler.showErrorSnackBar(
        context,
        'Could not update your profile avatar. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));
    __state ??= user?.profileAvatarType ?? ProfileAvatarTypeEnum.td;
    _tieDyeSeed ??= user?.profileAvatarSeed;

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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: UserAvatar.custom(
                            key: ValueKey(_tieDyeSeed ?? 'default'),
                            radius: 50,
                            seed: _tieDyeSeed,
                            image: _state == ProfileAvatarTypeEnum.im
                                ? _pickedImageBytes != null
                                      ? MemoryImage(_pickedImageBytes!)
                                      : user?.profileImage.value != null
                                      ? CachedNetworkImageProvider(
                                          getFullUrl(user!.profileImage.value!),
                                        )
                                      : null
                                : null,
                          ),
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
                                ProfileAvatarTypeEnum.td ||
                                _ => const Icon(Icons.shuffle),
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
                onPressed: _loading || _picking ? () {} : _onSave,
                child: _loading || _picking
                    ? const LoadingIndicator(size: 24, color: Colors.white)
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
