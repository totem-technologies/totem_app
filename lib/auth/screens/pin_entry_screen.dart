import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';
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
  bool _isLoading = false;
  int _attempts = 0;
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
    } catch (e) {
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
  void _requestNewMagicLink() {
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.all(24),
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),

                // Instructions
                Text(
                  'Enter the 6-digit PIN',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "We've sent a 6-digit PIN to ${widget.email}.\n"
                  'Please enter it below to sign in.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // PIN input
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'PIN Code',
                    hintText: '123456',
                    counterText: '',
                  ),
                  validator: _validatePin,
                  enabled: !_isLoading && _attempts < _maxAttempts,
                ),
                const SizedBox(height: 24),

                // Verify button
                if (_isLoading)
                  const LoadingIndicator()
                else
                  ElevatedButton(
                    onPressed: _attempts < _maxAttempts ? _verifyPin : null,
                    child: const Padding(
                      padding: EdgeInsetsDirectional.all(12),
                      child: Text('Verify PIN'),
                    ),
                  ),
                const SizedBox(height: 16),

                // Request new magic link
                TextButton(
                  onPressed: _requestNewMagicLink,
                  child: const Text('Request a new magic link'),
                ),

                if (_attempts > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Attempts: $_attempts of $_maxAttempts',
                    style: TextStyle(
                      color:
                          _attempts >= _maxAttempts - 1
                              ? Theme.of(context).colorScheme.error
                              : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
