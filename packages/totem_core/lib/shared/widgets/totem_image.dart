import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/network.dart';

class TotemImage extends StatelessWidget {
  const TotemImage({
    super.key,
    this.imageUrl,
    this.loadingPlaceholder,
    this.errorWidget = const Image(
      image: AssetImage(
        TotemImageAssets.genericBackground,
        package: 'totem_core',
      ),
      fit: BoxFit.cover,
    ),
    this.color,
    this.colorBlendMode,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? imageUrl;

  final Widget? loadingPlaceholder;

  /// The widget used when an error occurs while loading the image.
  ///
  /// Defaults to an image asset of the generic background.
  final Widget errorWidget;

  final Color? color;
  final BlendMode? colorBlendMode;

  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getFullUrl(imageUrl!),
        fit: BoxFit.cover,
        color: color,
        colorBlendMode: colorBlendMode,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        // TODO(totem): Create custom totem loading placeholder
        // We can make a custom animation with the totem logo
        placeholder: (context, url) =>
            loadingPlaceholder ?? Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => errorWidget,
      );
    } else {
      return errorWidget;
    }
  }
}
