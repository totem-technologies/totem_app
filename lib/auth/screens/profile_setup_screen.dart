import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/page_indicator.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  bool _isLoading = false;
  var selectedTopics = <String>{};

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your first name';
    }
    return null;
  }

  // Submit profile setup
  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(firstName: _firstNameController.text.trim());
      if (mounted) {
        // Navigate to home
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            context.go(RouteNames.spaces);
          }
        });
      }
    } catch (error, stackTrace) {
      if (mounted) {
        await ErrorHandler.handleApiError(
          context,
          error,
          stackTrace: stackTrace,
          onRetry: _submitProfile,
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
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);

          void nextPage() {
            controller.animateTo(controller.index + 1);
          }

          return PopScope(
            canPop: !_isLoading,
            onPopInvokedWithResult: (_, _) {
              controller.animateTo(controller.index - 1);
            },
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                CardScreen(
                  formKey: _formKey,
                  isLoading: _isLoading,
                  children: [
                    Text(
                      'Welcome',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We just to know more about you. some final question and '
                      'you’ll be good to go.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'What do you like to be called?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _firstNameController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(hintText: 'Enter name'),
                      validator: _validateFirstName,
                      enabled: !_isLoading,
                      restorationId: 'first_name_onboarding_input',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    buildInfoText(
                      'Other people will see this, but you don’t have to use your real '
                      'name. Add any pronounce is parentheses if you’d like.',
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'How old are you?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_isLoading) return;
                        showDatePicker(
                          context: context,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          initialDate: DateTime.now(),
                          helpText: 'Select your date of birth',
                        );
                      },
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter your age',
                        ),
                        // validator: ,
                        enabled: !_isLoading,
                        restorationId: 'first_name_onboarding_input',
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.givenName],
                        onFieldSubmitted: (_) => nextPage(),
                      ),
                    ),

                    buildInfoText(
                      'You must be over 13 to join. Age is for verification '
                      'only, no one will see it.',
                    ),

                    const SizedBox(height: 24),

                    const PageIndicator(),

                    const SizedBox(height: 24),

                    Builder(
                      builder: (context) {
                        return ElevatedButton(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }
                            nextPage();
                          },
                          child: const Text('Continue'),
                        );
                      },
                    ),
                  ],
                ),
                CardScreen(
                  isLoading: _isLoading,
                  children: [
                    Text(
                      'What topics would you like to explore?',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You feedback here will help us about new topics to '
                      'offer.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ...{
                      'Love & Emotions',
                      'Mothers',
                      'Queer',
                      'Self-improvement',
                      'Other',
                    }.map((topic) {
                      final isSelected = selectedTopics.contains(topic);
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 10),
                        child: CheckboxListTile(
                          title: Text(topic),
                          value: isSelected,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primaryContainer,
                              width: 2,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                selectedTopics.add(topic);
                              } else {
                                selectedTopics.remove(topic);
                              }
                            });
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    const PageIndicator(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: nextPage,
                      child: const Text('Next'),
                    ),
                  ],
                ),
                Container(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildInfoText(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).disabledColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).disabledColor,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
