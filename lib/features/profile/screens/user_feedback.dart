import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/sheet_drag_handle.dart';

typedef OnFeedbackSubmitted = Future<void> Function(String feedback);

Future<void> showUserFeedbackDialog(
  BuildContext context, {
  OnFeedbackSubmitted? onFeedbackSubmitted,
}) async {
  return showModalBottomSheet(
    context: context,
    showDragHandle: false,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => UserFeedback(
      onFeedbackSubmitted: onFeedbackSubmitted,
    ),
  );
}

class UserFeedback extends ConsumerStatefulWidget {
  const UserFeedback({required this.onFeedbackSubmitted, super.key});

  final OnFeedbackSubmitted? onFeedbackSubmitted;

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
    if (!_formKey.currentState!.validate()) return;

    final message = _feedbackController.text.trim();
    setState(() => _loading = true);

    try {
      if (widget.onFeedbackSubmitted != null) {
        await widget.onFeedbackSubmitted!(message);
      } else {
        await _submit(message);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thank you for your feedback!\nWe appreciate your input.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error, stackTrace) {
      if (mounted) {
        ErrorHandler.handleApiError(
          context,
          error,
          stackTrace: stackTrace,
          onRetry: _onSubmitFeedback,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(String message) async {
    final success = await ref.read(
      submitFeedbackProvider(message).future,
    );
    if (!success) {
      throw Exception('Failed to submit feedback. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_feedbackController.text.isNotEmpty) {
          return showDialog(
            context: context,
            builder: (context) {
              return ConfirmationDialog(
                title: 'Discard Feedback?',
                content:
                    'You have unsent feedback. Are you sure you want to discard it?',
                confirmButtonText: 'Discard',
                onConfirm: () async {
                  _feedbackController.clear();
                  if (mounted) {
                    Navigator.of(context).pop(); // close the dialog
                    Navigator.of(context).pop(); // close the feedback sheet
                  }
                },
              );
            },
          );
        }
        Navigator.of(context).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
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
                  const SheetDragHandle(),
                  Text(
                    'Feedback',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'We love hearing about how we can improve Totem. If you have any feedback, please let us know!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _feedbackController,
                    maxLines: 6,
                    minLines: 4,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      hintText:
                          'Share your thoughts, suggestions, or report issues...',
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
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
