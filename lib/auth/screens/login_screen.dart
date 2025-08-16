import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    if (value == null || value.isEmpty) {
      return l10n.pleaseEnterEmail;
    }
    // Simple email regex validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return l10n.pleaseEnterValidEmail;
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
          showError: false,
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
        ErrorHandler.showErrorSnackBar(
          context,
          ErrorHandler.getUserFriendlyErrorMessage(current.error!),
        );
      }
    });

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return CardScreen(
      isLoading: _isLoading,
      formKey: _formKey,
      children: [
        Text(
          l10n.getStarted,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.enterEmailDescription,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email input
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(hintText: l10n.email),
          validator: _validateEmail,
          enabled: !_isLoading,
          restorationId: 'auth_email_input',
          onFieldSubmitted: (_) => _requestPin(),
          autofocus: true,
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
                  l10n.yesReceiveEmailUpdates,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        RichText(
          text: TextSpan(
            text: l10n.byContinuingYouAgree,
            style: theme.textTheme.bodySmall,
            children: [
              TextSpan(
                text: l10n.termsOfService,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: theme.colorScheme.primary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(AppConfig.termsOfServiceUrl);
                  },
              ),
              TextSpan(text: l10n.and),
              TextSpan(
                text: l10n.privacyPolicy,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: theme.colorScheme.primary,
                ),
                recognizer: TapGestureRecognizer()
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
            child: _isLoading ? const LoadingIndicator() : Text(l10n.signIn),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          l10n.wellSendSixDigitPin,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
