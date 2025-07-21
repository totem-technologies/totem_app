import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
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
