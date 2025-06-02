import 'package:flutter/material.dart';
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
      appBar: AppBar(title: title != null ? Text(title!) : null),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error != null
                    ? ErrorHandler.getUserFriendlyErrorMessage(error!)
                    : 'Oops! Something went wrong.',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.go(RouteNames.spaces);
                },
                child: const Text('Explore Spaces'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
