import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/referral_choices.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/page_indicator.dart';

// --- Main Screen Widget ---
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKeyTab1 = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _ageController = TextEditingController();

  final _selectedTopics = <String>{};
  ReferralChoices? _referralSource;
  var _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _handleTopicSelection(String topic, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedTopics.add(topic);
      } else {
        _selectedTopics.remove(topic);
      }
    });
  }

  void _handleReferralSourceSelection(ReferralChoices source) {
    setState(() => _referralSource = source);
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(
            firstName: _firstNameController.text.trim(),
            referralSource: _referralSource,
            interestTopics: _selectedTopics,
            age: int.tryParse(_ageController.text.trim()),
          );

      if (mounted) context.go(RouteNames.spaces);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          void navigateToNextTab() {
            if (tabController.index < 3 - 1) {
              tabController.animateTo(tabController.index + 1);
            }
          }

          return PopScope(
            canPop: tabController.index == 0 && !_isLoading,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (tabController.index > 0) {
                tabController.animateTo(tabController.index - 1);
              }
            },
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _NameAndAgeTab(
                  formKey: _formKeyTab1,
                  firstNameController: _firstNameController,
                  ageController: _ageController,
                  isLoading: _isLoading,
                  onContinue: () {
                    if (_formKeyTab1.currentState!.validate()) {
                      navigateToNextTab();
                    }
                  },
                ),
                _TopicsTab(
                  selectedTopics: _selectedTopics,
                  isLoading: _isLoading,
                  onTopicSelected: _handleTopicSelection,
                  onContinue: navigateToNextTab,
                ),
                _ReferralSourceTab(
                  selectedReferralSource: _referralSource,
                  isLoading: _isLoading,
                  onSourceSelected: _handleReferralSourceSelection,
                  onSubmit: _submitProfile,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Tab 1: Name and Age ---
class _NameAndAgeTab extends StatefulWidget {
  const _NameAndAgeTab({
    required this.formKey,
    required this.firstNameController,
    required this.ageController,
    required this.isLoading,
    required this.onContinue,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController ageController;
  final bool isLoading;
  final VoidCallback onContinue;

  @override
  State<_NameAndAgeTab> createState() => _NameAndAgeTabState();
}

class _NameAndAgeTabState extends State<_NameAndAgeTab>
    with AutomaticKeepAliveClientMixin {
  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your first name';
    }
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your age';
    } else if (int.tryParse(value) == null) {
      return 'Please enter a valid age';
    } else if (int.parse(value) < 13) {
      return 'You must be at least 13 years old';
    }
    return null;
  }

  Widget _buildInfoText(String text) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: theme.disabledColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.disabledColor,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return CardScreen(
      formKey: widget.formKey,
      isLoading: widget.isLoading,
      children: [
        Text(
          'Welcome',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We just to know more about you. some final question and you’ll be '
          'good to go.',
          style: theme.textTheme.bodyMedium,
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
          controller: widget.firstNameController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: 'Enter name'),
          validator: _validateFirstName,
          enabled: !widget.isLoading,
          restorationId: 'first_name_onboarding_input',
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
        ),
        _buildInfoText(
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
        TextFormField(
          controller: widget.ageController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Enter your age'),
          validator: _validateAge,
          enabled: !widget.isLoading,
          restorationId: 'age_onboarding_input',
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => widget.onContinue(),
        ),
        _buildInfoText(
          'You must be over 13 to join. Age is for verification only, no one '
          'will see it.',
        ),
        const SizedBox(height: 24),
        const PageIndicator(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onContinue,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// --- Tab 2: Topics ---
class _TopicsTab extends StatelessWidget {
  const _TopicsTab({
    required this.selectedTopics,
    required this.isLoading,
    required this.onTopicSelected,
    required this.onContinue,
  });
  final Set<String> selectedTopics;
  final bool isLoading;
  final void Function(String topic, bool isSelected) onTopicSelected;
  final VoidCallback onContinue;

  static const List<String> _availableTopics = [
    'Love & Emotions',
    'Mothers',
    'Queer',
    'Self-improvement',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CardScreen(
      isLoading: isLoading,
      children: [
        Text(
          'What topics would you like to explore?',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'You feedback here will help us about new topics to offer.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._availableTopics.map((topic) {
          final isSelected = selectedTopics.contains(topic);
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: CheckboxListTile(
              title: Text(topic),
              value: isSelected,
              onChanged:
                  isLoading
                      ? null
                      : (value) => onTopicSelected(topic, value ?? false),
              checkboxScaleFactor: 1.35,
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
            ),
          );
        }),
        const SizedBox(height: 14),
        const PageIndicator(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isLoading ? null : onContinue,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

// --- Tab 3: Referral Source ---
class _ReferralSourceTab extends StatelessWidget {
  const _ReferralSourceTab({
    required this.selectedReferralSource,
    required this.isLoading,
    required this.onSourceSelected,
    required this.onSubmit,
  });

  final ReferralChoices? selectedReferralSource;
  final bool isLoading;
  final ValueChanged<ReferralChoices> onSourceSelected;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final availableSources =
        ReferralChoices.values
            .where((source) => source != ReferralChoices.other)
            .map(
              (source) =>
                  MapEntry<ReferralChoices, String>(source, source.name),
            )
            .toSet();

    return CardScreen(
      isLoading: isLoading, // Pass isLoading if CardScreen uses it
      children: [
        Text(
          'How did you hear about us?',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us understand how to reach more people like you.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ...availableSources.map((source) {
          final sourceRef = source.key;
          final sourceName = source.value;
          final isSelected = selectedReferralSource == sourceRef;
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: CheckboxListTile(
              title: Text(sourceName),
              value: isSelected,
              onChanged:
                  isLoading ? null : (value) => onSourceSelected(sourceRef),
              checkboxScaleFactor: 1.35,
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
            ),
          );
        }),
        const SizedBox(height: 14),
        const PageIndicator(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isLoading ? null : onSubmit,
          child:
              isLoading ? const LoadingIndicator() : const Text('Get Started'),
        ),
      ],
    );
  }
}

extension on ReferralChoices {
  String get name {
    return switch (this) {
      ReferralChoices.blog => 'Blog or Article',
      ReferralChoices.dream => 'Dream',
      ReferralChoices.keeper => 'Keeper',
      ReferralChoices.newsletter => 'Newsletter',
      ReferralChoices.pamphlet => 'Pamphlet',
      ReferralChoices.search => 'Google',
      ReferralChoices.social => 'Social Media',
      ReferralChoices.other || _ => 'Other',
    };
  }
}
