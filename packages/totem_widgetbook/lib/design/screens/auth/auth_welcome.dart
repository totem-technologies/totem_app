part of 'auth_flow.dart';

typedef _Slide = ({String photo, String title, String body});

/// Figma Welcome Screen 4, 5 and 6.
const List<_Slide> _slides = [
  (
    photo: '$_assets/welcome-1.jpg',
    title: 'Welcome',
    body:
        'Totem provides online discussion groups where you can cultivate '
        'your voice, and be a better listener.',
  ),
  (
    photo: '$_assets/welcome-2.jpg',
    title: 'Our Promise',
    body:
        'We provide a moderated space you can safely express yourself and '
        'learn from others.',
  ),
  (
    photo: '$_assets/welcome-3.jpg',
    title: 'Our Ask',
    body:
        'We ask that you keep everything confidential, and that you only '
        'speak from your experience.',
  ),
];

/// Full-bleed photo with the logo and Skip on a top fade, and the slide's
/// message, page dots and next arrow on a bottom fade.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.slide,
    required this.page,
    required this.onNext,
    required this.onSkip,
  });

  final _Slide slide;
  final int page;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    const white = TotemColors.coreWhite;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(slide.photo, fit: BoxFit.cover),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 148,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TotemColors.coreSlate, fade(TotemColors.coreSlate, 0)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _statusBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The wordmark is stored upside down in the file.
                Transform.flip(
                  flipY: true,
                  child: SvgPicture.asset(
                    '$_assets/logo.svg',
                    width: 93.6338,
                    height: 21.0545,
                    semanticsLabel: 'Totem',
                  ),
                ),
                Pressable(
                  onTap: onSkip,
                  focusColor: white,
                  focusRadius: BorderRadius.circular(Radii.sm),
                  builder: (context, states) => Text(
                    'Skip',
                    style:
                        TotemText.raw(
                          size: 16,
                          weight: FontWeight.w600,
                          color: white,
                        ).copyWith(
                          // Slide one shows it plain, the others underlined.
                          decoration: page == 0
                              ? TextDecoration.none
                              : TextDecoration.underline,
                          decorationColor: white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 322,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fade(TotemColors.coreSlate, 0), TotemColors.coreSlate],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 10,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Column(
                      // "Our Ask" sets its title further from the body.
                      spacing: page == 2 ? Spacing.s20 : 10,
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: TotemText.h1.copyWith(color: white),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 344),
                          child: Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: TotemText.h2.copyWith(color: white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Semantics(
                          label: 'Slide ${page + 1} of ${_slides.length}',
                          child: SvgPicture.asset(
                            '$_assets/dots-${page + 1}.svg',
                            width: 65,
                            height: 10,
                          ),
                        ),
                        Pressable(
                          onTap: onNext,
                          pressedScale: 0.92,
                          focusColor: white,
                          focusRadius: BorderRadius.circular(Radii.full),
                          semanticLabel: 'Next',
                          builder: (context, states) => SizedBox.square(
                            dimension: 54,
                            child: Stack(
                              children: [
                                SvgPicture.asset(
                                  '$_assets/next-circle.svg',
                                  width: 54,
                                  height: 54,
                                ),
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: SvgPicture.asset(
                                    '$_assets/next-arrow.svg',
                                    width: 38,
                                    height: 38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
