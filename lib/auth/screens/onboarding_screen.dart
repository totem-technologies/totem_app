import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final onboardingData = [
    const _OnboardingData(
      title: 'Welcome',
      description:
          'Totem provides online discussion groups where you can '
          'cultivate your voice, and be a better listener.',
      image: TotemAssets.onboarding1,
    ),
    const _OnboardingData(
      title: 'Our Promise',
      description:
          'We provide a moderated space you can safely express '
          'yourself and learn from others.',
      image: TotemAssets.onboarding2,
    ),
    const _OnboardingData(
      title: 'Our Ask',
      description:
          'We ask that you keep everything confidential, and that '
          'you only speak from your experience.',
      image: TotemAssets.onboarding3,
    ),
  ];

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
    for (final onboarding in onboardingData) {
      precacheImage(AssetImage(onboarding.image), context);
    }
  }

  void _onPrevious() {
    if (currentPage > 0) {
      _contentPageController.animateToPage(
        currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _backgroundPageController.animateToPage(
        currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onNext() {
    if (currentPage < onboardingData.length - 1) {
      _contentPageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _backgroundPageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 400),
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
    final bool isLastPage = currentPage >= onboardingData.length - 1;

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Material(
        // Use a Stack to layer the fixed top bar and the paged content
        child: Stack(
          children: [
            PageView.builder(
              hitTestBehavior: HitTestBehavior.translucent,
              itemCount: onboardingData.length,
              controller: _backgroundPageController,
              onPageChanged: (index) => setState(() => currentPage = index),
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
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IgnorePointer(
                        child: SvgPicture.asset(
                          'assets/logo/logo-black.svg',
                          colorFilter: const ColorFilter.mode(
                            AppTheme.white,
                            BlendMode.srcIn,
                          ),
                          width: 100,
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: 'Log in button',
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.white,
                          ),
                          onPressed: _onSkip,
                          child: const Text('Log in'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  height: MediaQuery.textScalerOf(context).scale(200),
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
                    top: false,
                    child: Column(
                      children: [
                        // Onboarding title
                        Expanded(
                          child: IgnorePointer(
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
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Semantics(
                                      label: 'Onboarding title',
                                      child: Text(
                                        onboarding.title,
                                        style: textTheme.headlineMedium
                                            ?.copyWith(
                                              color: AppTheme.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Onboarding description
                                    Semantics(
                                      label: 'Onboarding description',
                                      child: Text(
                                        onboarding.description,
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ...List.generate(
                              onboardingData.length,
                              (index) => IgnorePointer(
                                child: AnimatedContainer(
                                  key: ValueKey(index),
                                  duration: const Duration(milliseconds: 200),
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
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Visibility(
                                key: ValueKey(currentPage > 0),
                                visible: currentPage > 0,
                                child: Semantics(
                                  label: 'Previous page',
                                  child: GestureDetector(
                                    onTap: _onPrevious,
                                    child: const CircleAvatar(
                                      radius: 27,
                                      backgroundColor: AppTheme.mauve,
                                      child: Icon(
                                        Icons.arrow_back_ios_new,
                                        color: AppTheme.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeInOutCubic,
                              alignment: Alignment.centerRight,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final scale =
                                      Tween<double>(
                                        begin: 0.98,
                                        end: 1,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      );

                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: scale,
                                      child: child,
                                    ),
                                  );
                                },
                                child: isLastPage
                                    ? Semantics(
                                        key: const ValueKey(
                                          'create_account_cta',
                                        ),
                                        label: 'Create account',
                                        button: true,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 54,
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _onSkip,
                                            child: const Text('Create account'),
                                          ),
                                        ),
                                      )
                                    : Semantics(
                                        key: const ValueKey(
                                          'next_page_chevron',
                                        ),
                                        label: 'Next page',
                                        button: true,
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
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
