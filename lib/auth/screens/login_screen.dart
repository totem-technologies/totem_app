import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  var _isLoading = false;
  var _newsletterConsent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Simple email regex validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Request magic link
  Future<void> _requestPin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPin(_emailController.text.trim(), _newsletterConsent);

      if (mounted) {
        // Navigate to PIN entry screen
        context.go(
          RouteNames.pinEntry,
          extra: {'email': _emailController.text.trim()},
        );
      }
    } catch (error, stackTrace) {
      if (mounted) {
        await ErrorHandler.handleApiError(
          context,
          error,
          stackTrace: stackTrace,
          onRetry: _requestPin,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes
    ref.listen<AuthState>(authControllerProvider, (previous, current) {
      if (current.status == AuthStatus.error && current.error != null) {
        ErrorHandler.showErrorSnackBar(context, current.error!);
      }
    });

    final theme = Theme.of(context);

    return CardScreen(
      isLoading: _isLoading,
      formKey: _formKey,
      children: [
        Text(
          'Get Started',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email to create an account or access your '
          'existing one.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email input
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(hintText: 'Email'),
          validator: _validateEmail,
          enabled: !_isLoading,
          restorationId: 'auth_email_input',
          onFieldSubmitted: (_) => _requestPin(),
        ),
        Row(
          children: [
            Checkbox(
              value: _newsletterConsent,
              onChanged: (_) {
                setState(() {
                  _newsletterConsent = !_newsletterConsent;
                });
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _newsletterConsent = !_newsletterConsent;
                  });
                },
                child: Text(
                  'Yes, receive email updates',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        RichText(
          text: TextSpan(
            text: 'By continuing, you agree to our ',
            style: theme.textTheme.bodySmall,
            children: [
              TextSpan(
                text: 'Terms of Service',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: theme.colorScheme.primary,
                ),
                recognizer:
                    TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(AppConfig.termsOfServiceUrl);
                      },
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: theme.colorScheme.primary,
                ),
                recognizer:
                    TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(AppConfig.privacyPolicyUrl);
                      },
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestPin,
            child:
                _isLoading ? const LoadingIndicator() : const Text('Sign in'),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          "We'll send you a 6-digit PIN to your email.",
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
