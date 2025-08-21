import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class ErrorScreen extends StatefulWidget {
  const ErrorScreen({
    this.title,
    this.error,
    this.showHomeButton,
    this.onRetry,
    super.key,
  });

  final String? title;

  final Object? error;

  final bool? showHomeButton;

  final Future<void> Function()? onRetry;

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final showHomeButton =
        (widget.showHomeButton ?? true) && ErrorHandler.is404(widget.error);

    return Scaffold(
      appBar: Scaffold.maybeOf(context)?.hasAppBar ?? false
          ? null
          : AppBar(
              leading: showHomeButton
                  ? null
                  : BackButton(onPressed: () => popOrHome(context)),
            ),
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 32,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: SvgPicture.asset(
                      'assets/images/error_indicator.svg',
                      semanticsLabel: 'Error Indicator',
                    ),
                  ),
                ),
              ),
              Text(
                widget.error != null
                    ? ErrorHandler.getUserFriendlyErrorMessage(widget.error!)
                    : 'Oops! Something went wrong.',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null && !showHomeButton) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _loading = true;
                    });
                    try {
                      await widget.onRetry!();
                    } catch (e) {
                      if (context.mounted) {
                        await ErrorHandler.handleApiError(
                          context,
                          e,
                          showError: false,
                        );
                      }
                    }
                    setState(() {
                      _loading = false;
                    });
                  },
                  child: Center(
                    child: _loading
                        ? LoadingIndicator(
                            size: 24,
                            color: theme.colorScheme.onPrimary,
                          )
                        : const Text('Retry'),
                  ),
                ),
              ],
              if (showHomeButton) ...[
                const SizedBox(height: 20),
                const Text(
                  'You might be a little off path and that’s okay. Let’s help '
                  'you find your way back to the circle.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go(RouteNames.spaces);
                    },
                    child: const Text('Return to Home'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showErrorDialog(BuildContext context, [String? error]) {
  return showDialog(
    context: context,
    builder: (context) => ErrorDialog(message: error),
  );
}

class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    super.key,
    this.title = 'Something went wrong!\nPlease try later',
    this.message,
  });

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1EC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE53935), width: 2.5),
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFFE53935),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),

            if (message != null) ...[
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Ok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showErrorPopup(
  BuildContext context, {
  required TotemIconData icon,
  required String title,
  required String message,
}) {
  final overlay = Overlay.of(context);

  late OverlayEntry popup;
  popup = OverlayEntry(
    builder: (context) => Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: AnimatedPopup(
          onDismissed: () {
            if (popup.mounted) {
              popup.remove();
            }
          },
          popup: ErrorPopup(
            icon: icon,
            title: title,
            message: message,
          ),
        ),
      ),
    ),
  );

  overlay.insert(popup);
}

class ErrorPopup extends StatelessWidget {
  const ErrorPopup({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final TotemIconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          boxShadow: kElevationToShadow[2],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF44336),
                shape: BoxShape.circle,
              ),
              child: TotemIcon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedPopup extends StatefulWidget {
  const AnimatedPopup({
    required this.onDismissed,
    required this.popup,
    super.key,
  });
  final VoidCallback onDismissed;
  final Widget popup;

  @override
  State<AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation =
        Tween<Offset>(
          begin: const Offset(0, -2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOut,
          ),
        );

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.popup,
    );
  }
}
