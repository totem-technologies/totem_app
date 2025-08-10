import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/referral_choices.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/screens/profile_image_picker.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/info_text.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class ProfileSetupScreenV2 extends ConsumerStatefulWidget {
  const ProfileSetupScreenV2({super.key});

  @override
  ConsumerState<ProfileSetupScreenV2> createState() =>
      _ProfileSetupScreenV2State();
}

class _ProfileSetupScreenV2State extends ConsumerState<ProfileSetupScreenV2> {
  final PageController _pageController = PageController();

  final GlobalKey<FormState> _formKeyTab1 = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  final Set<String> _selectedTopics = <String>{};
  ReferralChoices? _referralSource;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
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
      _nextPage();
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
    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_pageController.hasClients &&
            _pageController.page != null &&
            _pageController.page! > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _GuidelinesPage(onContinue: _nextPage),
          _ProfileSetupTab(
            formKey: _formKeyTab1,
            firstNameController: _firstNameController,
            ageController: _ageController,
            isLoading: _isLoading,
            onReferralSourceSelected: (source) =>
                setState(() => _referralSource = source),
            referralSource: _referralSource,
            onContinue: () async {
              FocusScope.of(context).unfocus();
              if (_formKeyTab1.currentState!.validate()) {
                setState(() => _isLoading = true);
                await _submitProfile();
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
          _TopicsTab(
            selectedTopics: _selectedTopics,
            isLoading: _isLoading,
            onTopicSelected: _handleTopicSelection,
            onContinue: () async {
              _nextPage();
            },
          ),
          _SuggestedSpaces(
            selectedTopics: _selectedTopics,
            isLoading: _isLoading,
            onSeeAllSpaces: () {
              context.go(RouteNames.home);
            },
          ),
        ],
      ),
    );
  }
}

class _GuidelinesPage extends StatelessWidget {
  const _GuidelinesPage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return CardScreen(
      children: [
        Text(
          'Community Guidelines',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text:
                    'In order to keep Totem safe, we require everyone adhere to ',
              ),
              TextSpan(
                text: 'confidentiality',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text:
                    '. Breaking confidentiality can be grounds for account removal.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text: 'We also encourage you to only speak about ',
              ),
              TextSpan(
                text: 'your own experience',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text:
                    ', and not to share other people’s information or stories.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: const [
              TextSpan(text: 'For more details, see the full '),
              TextSpan(
                text: 'Community Guidelines',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onContinue,
            child: const Text('Agree and Continue'),
          ),
        ),
      ],
    );
  }
}

// --- Main Screen Widget ---
// Replace old implementation by aliasing to V2
typedef ProfileSetupScreen = ProfileSetupScreenV2;

// --- Tab 1: Name and Age ---
class _ProfileSetupTab extends StatefulWidget {
  const _ProfileSetupTab({
    required this.formKey,
    required this.firstNameController,
    required this.ageController,
    required this.isLoading,
    required this.onContinue,
    required this.onReferralSourceSelected,
    required this.referralSource,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController ageController;
  final bool isLoading;
  final VoidCallback onContinue;
  final ValueChanged<ReferralChoices> onReferralSourceSelected;
  final ReferralChoices? referralSource;
  @override
  State<_ProfileSetupTab> createState() => _ProfileSetupTabState();
}

class _ProfileSetupTabState extends State<_ProfileSetupTab>
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return CardScreen(
      formKey: widget.formKey,
      isLoading: widget.isLoading,
      children: [
        Text(
          'Let’s get to know you',
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
        GestureDetector(
          // onTap: _pickImage,
          onTap: () => showProfileImagePicker(context),
          child: Center(
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                const UserAvatar(radius: 50),
                PositionedDirectional(
                  bottom: -10,
                  end: -10,
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: AlignmentDirectional.center,
                    child: const TotemIcon(TotemIcons.edit),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What do you like to be called?',
          textAlign: TextAlign.left,
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
        const InfoText(
          'Other people will see this, but you don’t have to use your real '
          'name. Add any pronounce is parentheses if you’d like.',
        ),
        const SizedBox(height: 20),
        Text(
          'How old are you?',
          textAlign: TextAlign.left,
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
        const InfoText(
          'You must be over 13 to join. Age is for verification only, no one '
          'will see it.',
        ),
        const SizedBox(height: 20),
        Text(
          'How did you hear about us?',
          textAlign: TextAlign.left,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            showModalBottomSheet<ReferralChoices>(
              isScrollControlled: true,
              context: context,
              builder: (context) => const _ReferralSourceModal(),
            ).then(
              (value) {
                if (value != null) {
                  widget.onReferralSourceSelected(value);
                }
              },
            );
          },
          child: Container(
            height: 53,
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xffD9D9D9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              maxLines: 1,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              widget.referralSource?.name ?? 'Tap to select',
              style: theme.textTheme.titleMedium?.copyWith(
                color: widget.referralSource == null
                    ? const Color(0xffA2A2A2)
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        const InfoText(
          'This helps us understand how to reach more people like you.',
        ),
        const SizedBox(height: 20),
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
          'Which community feels like home to you?',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Pick a few — we’ll help you connect with the right spaces.',
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
              onChanged: isLoading
                  ? null
                  : (value) => onTopicSelected(topic, value ?? false),
              checkboxScaleFactor: 1.35,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  width: 2,
                ),
              ),
            ),
          );
        }),
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
class _SuggestedSpaces extends StatefulWidget {
  const _SuggestedSpaces({
    required this.selectedTopics,
    required this.isLoading,
    required this.onSeeAllSpaces,
  });
  final Set<String> selectedTopics;
  final bool isLoading;
  final VoidCallback onSeeAllSpaces;

  @override
  State<_SuggestedSpaces> createState() => _SuggestedSpacesState();
}

class _SuggestedSpacesState extends State<_SuggestedSpaces> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = widget.selectedTopics.toList();

    return Consumer(
      builder: (context, ref, _) {
        final recommended = ref.watch(recommendedSpacesProvider(topics));

        return CardScreen(
          isLoading: widget.isLoading,
          children: [
            Text(
              'Suggested Spaces',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              'We’ve found some spaces that might be a good fit for you.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            recommended.when(
              data: (events) {
                if (events.isEmpty) {
                  return const InfoText(
                    'No suggestions yet. Try selecting a few topics.',
                  );
                }
                return Column(
                  children: [
                    for (final event in events) ...[
                      SuggestedSpaceCard(event: event),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: widget.onSeeAllSpaces,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                );
              },
              error: (error, stack) {
                return Column(
                  children: [
                    const InfoText('Couldn’t load suggestions.'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          ref.refresh(recommendedSpacesProvider(topics).future),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    );
  }
}

class SuggestedSpaceCard extends StatelessWidget {
  const SuggestedSpaceCard({
    required this.event,
    super.key,
  });

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundImage = event.space.image;
    final timeLabel = _buildTimeLabel(event.start);
    final title = event.title.isNotEmpty ? event.title : event.spaceTitle;
    final keeperName = event.space.author.name ?? 'Keeper';
    final seatsLeft = event.seatsLeft;

    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: backgroundImage == null
            ? null
            : DecorationImage(
                image: NetworkImage(backgroundImage),
                fit: BoxFit.cover,
              ),
        color: backgroundImage == null
            ? theme.colorScheme.primaryContainer
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(38, 47, 55, 0.60),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  timeLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontFamily: 'Albert Sans',
                    fontSize: 8,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontFamily: 'Albert Sans',
              fontSize: 14,
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
            textAlign: TextAlign.left,
          ),
          Row(
            children: [
              Container(
                height: 25,
                width: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontFamily: 'Albert Sans',
                    fontSize: 10,
                    fontStyle: FontStyle.normal,
                    height: 1,
                  ),
                  children: [
                    const TextSpan(
                      text: 'With ',
                      style: TextStyle(fontWeight: FontWeight.w400),
                    ),
                    TextSpan(
                      text: keeperName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF987AA5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Join',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'Albert Sans',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${seatsLeft} seats left',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontFamily: 'Albert Sans',
                      fontSize: 8,
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildTimeLabel(DateTime start) {
    final isToday =
        DateTime.now().day == start.day &&
        DateTime.now().month == start.month &&
        DateTime.now().year == start.year;
    final dateFormatter = DateFormat('E MMM dd');
    final timeFormatter = DateFormat('hh:mm a');
    if (isToday) return 'Today, ${timeFormatter.format(start)}';
    return '${dateFormatter.format(start)}, ${timeFormatter.format(start)}';
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

/// Modal for selecting a single referral source.
/// This widget manages the selected choice, updates the UI to reflect it,
/// and returns the selected one when the user clicks "Save".
class _ReferralSourceModal extends StatefulWidget {
  const _ReferralSourceModal();

  @override
  State<_ReferralSourceModal> createState() => _ReferralSourceModalState();
}

class _ReferralSourceModalState extends State<_ReferralSourceModal> {
  /// Holds the currently selected referral source (only one allowed).
  ReferralChoices? _selectedSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build a set of available sources, excluding 'Other'
    final availableSources = ReferralChoices.values
        .where((source) => source.name != ReferralChoices.other.name)
        .toSet();

    return CardScreen(
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
          final isSelected = _selectedSource == source;
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: RadioListTile<ReferralChoices>(
              title: Text(source.name),
              value: source,
              groupValue: _selectedSource,
              onChanged: (value) {
                setState(() {
                  _selectedSource = value;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  width: 2,
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _selectedSource != null
              ? () {
                  // Pop and return the selected source as a ReferralChoices
                  Navigator.of(context).pop(_selectedSource);
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
