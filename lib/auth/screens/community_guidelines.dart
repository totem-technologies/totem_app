import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/card_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityGuidelinesScreen extends ConsumerStatefulWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  ConsumerState<CommunityGuidelinesScreen> createState() =>
      _CommunityGuidelinesScreenState();
}

class _CommunityGuidelinesScreenState
    extends ConsumerState<CommunityGuidelinesScreen> {
  final _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return CardScreen(
      isLoading: _isLoading,
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

        // 2. Second paragraph with "your own experience" bolded
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

        // 3. Third paragraph with "Community Guidelines" as clickable text
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text: 'For more details, see the full ',
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://www.totem.org/guidelines/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(
                    'Community Guidelines',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const TextSpan(
                text: '.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              context.go(RouteNames.onboarding);
            },
            child: _isLoading
                ? const LoadingIndicator()
                : const Text('Agree and Continue'),
          ),
        ),
      ],
    );
  }
}
