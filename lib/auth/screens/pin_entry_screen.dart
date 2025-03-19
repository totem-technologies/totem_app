import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../models/auth_state.dart';
import '../../core/errors/error_handler.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../core/config/app_config.dart';

class PinEntryScreen extends ConsumerStatefulWidget {
  final String email;

  const PinEntryScreen({super.key, required this.email});

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
          .verifyPin(widget.email, _pinController.text.trim());

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
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.go('/auth/login');
            }
          });
        }
      }
    }
  }

  // Request a new magic link
  void _requestNewMagicLink() {
    context.go('/auth/login');
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
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'We\'ve sent a 6-digit PIN to ${widget.email}. Please enter it below to sign in.',
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
                _isLoading
                    ? const LoadingIndicator()
                    : ElevatedButton(
                      onPressed: _attempts < _maxAttempts ? _verifyPin : null,
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
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
