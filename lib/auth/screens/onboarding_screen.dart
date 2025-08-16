import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/l10n/app_localizations.dart';
import 'package:totem_app/navigation/route_names.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  List<_OnboardingData> _getOnboardingData(AppLocalizations l10n) {
    return [
      _OnboardingData(
        title: l10n.onboardingWelcomeTitle,
        description: l10n.onboardingWelcomeDescription,
        image: 'assets/images/onboarding_1.jpg',
      ),
      _OnboardingData(
        title: l10n.onboardingPromiseTitle,
        description: l10n.onboardingPromiseDescription,
        image: 'assets/images/onboarding_2.jpg',
      ),
      _OnboardingData(
        title: l10n.onboardingAskTitle,
        description: l10n.onboardingAskDescription,
        image: 'assets/images/onboarding_3.jpg',
      ),
    ];
  }

  int currentPage = 0;
  final PageController _backgroundPageController = PageController();
  final PageController _contentPageController = PageController();

  /// Flag to ensure images are preloaded only once
  bool _imagesPreloaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Preload images only once when dependencies are available
    if (!_imagesPreloaded) {
      _preloadImages();
      _imagesPreloaded = true;
    }
  }

  /// Preloads all onboarding images into memory for smooth transitions
  /// Called from didChangeDependencies to ensure MediaQuery is available
  void _preloadImages() {
    const images = [
      'assets/images/onboarding_1.jpg',
      'assets/images/onboarding_2.jpg',
      'assets/images/onboarding_3.jpg',
    ];
    for (final image in images) {
      precacheImage(AssetImage(image), context);
    }
  }

  void _onNext() {
    if (currentPage < 3 - 1) {
      _contentPageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _backgroundPageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _onSkip();
    }
  }

  /// Complete the welcome onboarding and navigate to login
  /// This marks that the user has seen the intro screens
  Future<void> _onSkip() async {
    // Mark welcome onboarding as completed so user won't see it again
    await ref
        .read(authControllerProvider.notifier)
        .markWelcomeOnboardingCompleted();

    if (mounted) {
      context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _backgroundPageController.dispose();
    _contentPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onboardingData = _getOnboardingData(l10n);

    return Material(
      // Use a Stack to layer the fixed top bar and the paged content
      child: Stack(
        children: [
          PageView.builder(
            itemCount: onboardingData.length,
            controller: _backgroundPageController,
            onPageChanged: (index) => setState(() => currentPage = index),
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Image.asset(
                onboardingData[index].image,
                fit: BoxFit.cover,
              );
            },
          ),

          /// Fixed Top Container (logo, skip button, gradient)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.slate,
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                minimum: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SvgPicture.asset(
                      'assets/logo/logo-black.svg',
                      colorFilter: const ColorFilter.mode(
                        AppTheme.white,
                        BlendMode.srcIn,
                      ),
                      width: 100,
                    ),
                    const Spacer(),
                    Semantics(
                      label: l10n.logInButtonLabel,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.white,
                        ),
                        onPressed: _onSkip,
                        child: Text(l10n.logIn),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.slate,
                  ],
                ),
              ),
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.slate,
                    ],
                  ),
                ),
                child: SafeArea(
                  minimum: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Onboarding title
                      Expanded(
                        child: PageView.builder(
                          itemCount: onboardingData.length,
                          controller: _contentPageController,
                          onPageChanged: (index) =>
                              setState(() => currentPage = index),
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final onboarding = onboardingData[index];
                            final textTheme = Theme.of(context).textTheme;
                            return Column(
                              children: [
                                Semantics(
                                  label: l10n.onboardingTitleLabel,
                                  child: Text(
                                    onboarding.title,
                                    style: textTheme.headlineMedium?.copyWith(
                                      color: AppTheme.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Onboarding description
                                Semantics(
                                  label: l10n.onboardingDescriptionLabel,
                                  child: Text(
                                    onboarding.description,
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.white,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ///Page indicator: selected page is pill-shaped
                          ...List.generate(
                            onboardingData.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              width: index == currentPage ? 30 : 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: index == currentPage
                                    ? AppTheme.mauve
                                    : AppTheme.white,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Semantics(
                            label: l10n.nextPageLabel,
                            child: GestureDetector(
                              onTap: _onNext,
                              child: const CircleAvatar(
                                radius: 27,
                                backgroundColor: AppTheme.mauve,
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppTheme.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.description,
    required this.image,
  });
  final String title;
  final String description;
  final String image;
}
