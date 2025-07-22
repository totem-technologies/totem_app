import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  var _isLoading = false;
  var _attempts = 0;
  final int _maxAttempts = AppConfig.maxPinAttempts;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // PIN validation
  String? _validatePin(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the PIN from your email';
    }
    if (value.length != 6) {
      return 'PIN must be 6 digits';
    }
    // Check if PIN contains only digits
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'PIN must contain only digits';
    }
    return null;
  }

  // Verify PIN
  Future<void> _verifyPin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyPin(_pinController.text.trim());
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/');
        }
      });
      // If we reach here, PIN verification was successful
    } catch (error) {
      if (mounted) {
        setState(() {
          _attempts++;
          _isLoading = false;
        });

        String errorMessage = 'Invalid PIN. Please try again.';
        if (_attempts >= _maxAttempts) {
          errorMessage =
              'Too many failed attempts. Please request a new magic link.';
        } else {
          errorMessage =
              'Invalid PIN. ${_maxAttempts - _attempts} attempts remaining.';
        }

        ErrorHandler.showErrorSnackBar(context, errorMessage);

        if (_attempts >= _maxAttempts) {
          // Navigate back to login screen after max attempts
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go(RouteNames.login);
            }
          });
        }
      }
    }
  }

  // Request a new magic link
  void _requestNewPin() {
    context.go(RouteNames.login);
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
        // Instructions
        Text(
          'Enter verification code',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            text: "We've sent a 6-digit PIN to ",
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: widget.email.isEmpty ? 'your email' : widget.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '\nPlease enter it below to.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        Text(
          'Enter 6-digit code',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Pinput(
          controller: _pinController,
          defaultPinTheme: const PinTheme(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              color: Color(0xFFD9D9D9),
            ),
          ),
          separatorBuilder: (_) => const SizedBox(width: 4),
          length: 6,
          onCompleted: (_) => _verifyPin(),
          textInputAction: TextInputAction.done,
          restorationId: 'auth_pin_input',
          enabled: !_isLoading && _attempts < _maxAttempts,
          validator: _validatePin,
          autofocus: true,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: !_isLoading && _attempts < _maxAttempts
                ? _verifyPin
                : null,
            child: _isLoading
                ? const LoadingIndicator()
                : const Text('Verify Code'),
          ),
        ),
        const SizedBox(height: 16),

        RichText(
          text: TextSpan(
            text: 'Need a new code? ',
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: 'Send again',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                recognizer: TapGestureRecognizer()..onTap = _requestNewPin,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        if (_attempts > 0) ...[
          const SizedBox(height: 16),
          Text(
            'Attempts: $_attempts of $_maxAttempts',
            style: TextStyle(
              color: _attempts >= _maxAttempts - 1
                  ? theme.colorScheme.error
                  : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
