import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

Future<void> showUserFeedbackDialog(BuildContext context) async {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const UserFeedback(),
  );
}

class UserFeedback extends ConsumerStatefulWidget {
  const UserFeedback({super.key});

  @override
  ConsumerState<UserFeedback> createState() => _UserFeedbackState();
}

class _UserFeedbackState extends ConsumerState<UserFeedback> {
  var _loading = false;
  final _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitFeedback() async {
    // Validate the form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      // Submit feedback using the repository
      final success = await ref.read(
        submitFeedbackProvider(_feedbackController.text.trim()).future,
      );

      if (!mounted) return;

      if (success) {
        // Show success message and close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thank you for your feedback! We appreciate your input.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Handle case where API returns false but no exception
        ErrorHandler.showErrorSnackBar(
          context,
          'Failed to submit feedback. Please try again.',
        );
      }
    } catch (error, stackTrace) {
      if (mounted) {
        await ErrorHandler.handleApiError(
          context,
          error,
          stackTrace: stackTrace,
          onRetry: _onSubmitFeedback,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_loading,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + keyboardHeight,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Centered title
                  Text(
                    'Feedback',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Description text
                  Text(
                    'We love hearing about how we can improve Totem. If you have any feedback, please let us know!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Multi-line text field for feedback
                  TextFormField(
                    controller: _feedbackController,
                    maxLines: 6,
                    minLines: 4,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      hintText:
                          'Share your thoughts, suggestions, or report issues...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your feedback';
                      }
                      if (value.trim().length < 10) {
                        return 'Please provide more detailed feedback (at least 10 characters)';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _onSubmitFeedback,
                      child: _loading
                          ? const LoadingIndicator()
                          : const Text('Submit Feedback'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
