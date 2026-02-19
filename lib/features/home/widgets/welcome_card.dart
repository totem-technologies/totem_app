import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/assets.dart';

/// A welcome card displayed to new users who haven't attended any sessions.
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  static const double _borderRadius = 20;
  static const double _aspectRatio = 1;
  static const double _tabletMaxWidth = 400;
  static const double _tabletBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= _tabletBreakpoint;

    Widget card = AspectRatio(
      aspectRatio: _aspectRatio,
      child: Material(
        borderRadius: BorderRadius.circular(_borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => toHome(HomeRoutes.spaces),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackgroundImage(),
              _buildGradientOverlay(),
              _buildTextContent(context, isTablet: isTablet),
            ],
          ),
        ),
      ),
    );

    if (isTablet) {
      card = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _tabletMaxWidth),
          child: card,
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Welcome to Totem. Tap to explore sessions.',
      excludeSemantics: true,
      child: card,
    );
  }

  Widget _buildBackgroundImage() {
    return Image.asset(
      TotemAssets.welcomeCardImage,
      fit: BoxFit.cover,
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color.fromRGBO(0, 0, 0, 0.3),
            Color.fromRGBO(0, 0, 0, 0.5),
          ],
          stops: [0.0, 0.4, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context, {required bool isTablet}) {
    final fontSize = isTablet ? 14.0 : 16.0;
    final bottomPadding = isTablet ? 16.0 : 24.0;
    final buttonFontSize = isTablet ? 14.0 : 16.0;

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottomPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main message text
          Text(
            'Totem is a nonprofit creating online Spaces for connection and support. '
            'We believe these gatherings can help build a more thoughtful, caring world.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.4,
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 4,
                  color: Color.fromRGBO(0, 0, 0, 0.5),
                ),
              ],
            ),
          ),
          SizedBox(height: isTablet ? 12 : 20),
          _buildReadMoreButton(fontSize: buttonFontSize),
        ],
      ),
    );
  }

  // TODO(totem): Navigate to About Us page when implemented.
  Widget _buildReadMoreButton({double fontSize = 16}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.mauve.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => toHome(HomeRoutes.spaces),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Text(
              'Explore Sessions',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Color.fromRGBO(0, 0, 0, 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
