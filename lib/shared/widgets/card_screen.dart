import 'dart:math' as math;

import 'package:flutter/material.dart';

class CardScreen extends StatefulWidget {
  /// Creates a card screen.
  const CardScreen({
    required this.children,
    this.isLoading = false,
    this.formKey,
    super.key,
    this.showBackground,
    this.showLogoOnLargeScreens = true,
    this.onPopInvokedWithResult,
    this.appBar,
  });

  /// The children to be displayed on the screen.
  final List<Widget> children;

  /// The form key to be used for the form.
  final GlobalKey<FormState>? formKey;

  /// Whether the screen is loading or not.
  ///
  /// If true, the screen will not be able to pop.
  final bool isLoading;

  /// Whether to show the background image or not.
  ///
  /// By default, the image is shown on larger screens.
  final bool? showBackground;

  /// Whether to show the logo on large screens or not.
  ///
  /// By default, the logo is shown on larger screens.
  final bool showLogoOnLargeScreens;

  final PopInvokedWithResultCallback<void>? onPopInvokedWithResult;

  /// An optional app bar to be displayed on the screen.
  final AppBar? appBar;

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope<void>(
      canPop: !widget.isLoading,
      child: Scaffold(
        appBar: widget.appBar,
        extendBodyBehindAppBar: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 600;
            final showBackground = widget.showBackground == null
                ? !isPhone
                : widget.showBackground!;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (showBackground) ...[
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        const Color gradientColor = Color.fromRGBO(
                          38,
                          47,
                          55,
                          0.3,
                        );
                        return const LinearGradient(
                          colors: [gradientColor, gradientColor],
                          stops: [0.3, 1.0],
                          transform: GradientRotation(168.14 * math.pi / 180),
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.darken,
                      child: Image.asset(
                        'assets/images/welcome_background.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (constraints.maxHeight >= 900 &&
                      widget.showLogoOnLargeScreens)
                    Positioned.fill(
                      top: 96,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/logo/logo-black.png',
                              fit: BoxFit.fitHeight,
                              color: Colors.white,
                              height: 70,
                            ),
                            const Text(
                              'Turn Conversations Into Community',
                              style: TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Card(
                            child: Form(
                              key: widget.formKey,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.all(24),
                                child: DefaultTextStyle.merge(
                                  textAlign: TextAlign.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: widget.children,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
