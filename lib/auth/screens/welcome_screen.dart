import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/navigation/route_names.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcome_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Container(
              alignment: Alignment.center,
              child: Card(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                    vertical: 40,
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/logo/logo-black.png'),
                        const Text('Turn Conversations Into Community'),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            context.go(RouteNames.login);
                          },
                          child: const Row(
                            children: [
                              Expanded(
                                // expands
                                child: Text(
                                  'Get Started',
                                  textAlign: TextAlign.center,
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
            ),
          ),
        ],
      ),
    );
  }
}
