import 'package:flutter/material.dart';
import 'package:totem_app/api/models/referral_choices.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';

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
class ReferralSourceModal extends StatefulWidget {
  const ReferralSourceModal({super.key});

  @override
  State<ReferralSourceModal> createState() => _ReferralSourceModalState();
}

class _ReferralSourceModalState extends State<ReferralSourceModal> {
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
