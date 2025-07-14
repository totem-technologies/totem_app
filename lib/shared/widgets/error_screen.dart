import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({this.title, this.error, super.key});

  final String? title;

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Scaffold.maybeOf(context)?.hasAppBar ?? false ? null : AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 32),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: SvgPicture.asset(
                    'assets/images/error_indicator.svg',
                    semanticsLabel: 'Error Indicator',
                  ),
                ),
              ),
              Text(
                error != null
                    ? ErrorHandler.getUserFriendlyErrorMessage(error!)
                    : 'Oops! Something went wrong.',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
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
          ),
        ),
      ),
    );
  }
}
