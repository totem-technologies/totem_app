import 'package:flutter/material.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';

extension ReferralChoicesNames on ReferralChoices {
  String get name {
    return switch (this) {
      ReferralChoices.search => 'Search Engine',
      ReferralChoices.chatgpt => 'ChatGPT',
      ReferralChoices.keeper => 'Keeper',
      ReferralChoices.social => 'Social Media',
      ReferralChoices.physicalMedia => 'Physical Media',
      ReferralChoices.blog => 'Blog or Article',
      ReferralChoices.friend => 'A friend',
      ReferralChoices.$other => 'Other',
      ReferralChoices.$default => "I'm not sure",
      ReferralChoices.pamphlet => 'Pamphlet',
      ReferralChoices.newsletter => 'Newsletter',
      ReferralChoices.dream => '✨A Dream✨',
      _ => 'Other',
    };
  }
}

final List<ReferralChoices> _orderedSources = [
  ReferralChoices.search,
  ReferralChoices.chatgpt,
  ReferralChoices.keeper,
  ReferralChoices.social,
  ReferralChoices.physicalMedia,
  ReferralChoices.blog,
  ReferralChoices.friend,
  ReferralChoices.$other,
];

/// Modal for selecting a single referral source.
/// Returns a `(ReferralChoices, String?)` record where the second element
/// is the write-in text when "Other" is selected.
class ReferralSourceModal extends StatefulWidget {
  const ReferralSourceModal({super.key});

  @override
  State<ReferralSourceModal> createState() => _ReferralSourceModalState();
}

class _ReferralSourceModalState extends State<ReferralSourceModal> {
  ReferralChoices? _selectedSource;
  final TextEditingController _otherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _otherController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _selectedSource != null &&
      !(_selectedSource == ReferralChoices.$other &&
          _otherController.text.trim().isEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);


    return CardScreen(
      children: [
        Semantics(
          header: true,
          child: Text(
            'How did you hear about us?',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us understand how to reach more people like you.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        RadioGroup<ReferralChoices>(
          groupValue: _selectedSource,
          onChanged: (value) {
            setState(() {
              _selectedSource = value;
            });
          },
          child: Column(
            children: _orderedSources.map((source) {
              final isSelected = _selectedSource == source;
              return Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadioListTile<ReferralChoices>(
                      title: Text(source.name),
                      value: source,
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
                    if (source == ReferralChoices.$other && isSelected) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 16),
                        child: TextField(
                          controller: _otherController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Please tell us more...',
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _canSave
              ? () {
                  final otherText = _selectedSource == ReferralChoices.$other
                      ? _otherController.text.trim()
                      : null;
                  Navigator.of(context).pop((_selectedSource!, otherText));
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
