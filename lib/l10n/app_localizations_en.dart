// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get communityGuidelinesTitle => 'Community Guidelines';

  @override
  String get communityGuidelinesConfidentialityText =>
      'In order to keep Totem safe, we require everyone adhere to ';

  @override
  String get confidentiality => 'confidentiality';

  @override
  String get communityGuidelinesConfidentialityWarning =>
      '. Breaking confidentiality can be grounds for account removal.';

  @override
  String get communityGuidelinesPersonalExperienceText =>
      'We also encourage you to only speak about ';

  @override
  String get yourOwnExperience => 'your own experience';

  @override
  String get communityGuidelinesPersonalExperienceWarning =>
      ', and not to share other people\'s information or stories.';

  @override
  String get communityGuidelinesFullText => 'For more details, see the full ';

  @override
  String get communityGuidelinesLink => 'Community Guidelines';

  @override
  String get agreeAndContinue => 'Agree and Continue';

  @override
  String get letsGetToKnowYou => 'Let\'s get to know you';

  @override
  String get profileSetupDescription =>
      'We just to know more about you. some final question and you\'ll be good to go.';

  @override
  String get whatToBeCalledQuestion => 'What do you like to be called?';

  @override
  String get enterName => 'Enter name';

  @override
  String get nameHelpText =>
      'Other people will see this, but you don\'t have to use your real name. Add any pronounce is parentheses if you\'d like.';

  @override
  String get howOldAreYouQuestion => 'How old are you?';

  @override
  String get enterYourAge => 'Enter your age';

  @override
  String get ageHelpText =>
      'You must be over 13 to join. Age is for verification only, no one will see it.';

  @override
  String get howDidYouHearAboutUsQuestion => 'How did you hear about us?';

  @override
  String get tapToSelect => 'Tap to select';

  @override
  String get referralHelpText =>
      'This helps us understand how to reach more people like you.';

  @override
  String get continueButton => 'Continue';

  @override
  String get whichCommunityFeelsLikeHome =>
      'Which community feels like home to you?';

  @override
  String get pickFewSpacesDescription =>
      'Pick a few — we\'ll help you connect with the right spaces.';

  @override
  String get nextButton => 'Next';

  @override
  String get suggestedSpaces => 'Suggested Spaces';

  @override
  String get suggestedSpacesDescription =>
      'We\'ve found some spaces that might be a good fit for you.';

  @override
  String get noSuggestionsYet =>
      'No suggestions yet. Try selecting a few topics.';

  @override
  String get seeAll => 'See all';

  @override
  String get couldntLoadSuggestions => 'Couldn\'t load suggestions.';

  @override
  String get retry => 'Retry';

  @override
  String get enterVerificationCode => 'Enter verification code';

  @override
  String get weSentSixDigitPinTo => 'We\'ve sent a 6-digit PIN to ';

  @override
  String get yourEmail => 'your email';

  @override
  String get pleaseEnterItBelow => '\nPlease enter it below to.';

  @override
  String get enterSixDigitCode => 'Enter 6-digit code';

  @override
  String get verifyCode => 'Verify Code';

  @override
  String get needNewCode => 'Need a new code? ';

  @override
  String get sendAgain => 'Send again';

  @override
  String attemptsOf(int current, int max) {
    return 'Attempts: $current of $max';
  }

  @override
  String get pleaseEnterPin => 'Please enter the PIN from your email';

  @override
  String get pinMustBeSixDigits => 'PIN must be 6 digits';

  @override
  String get pinMustContainOnlyDigits => 'PIN must contain only digits';

  @override
  String get invalidPinTryAgain => 'Invalid PIN. Please try again.';

  @override
  String get tooManyFailedAttempts =>
      'Too many failed attempts. Please request a new magic link.';

  @override
  String invalidPinAttemptsRemaining(int remaining) {
    return 'Invalid PIN. $remaining attempts remaining.';
  }

  @override
  String get onboardingWelcomeTitle => 'Welcome';

  @override
  String get onboardingWelcomeDescription =>
      'Totem provides online discussion groups where you can cultivate your voice, and be a better listener.';

  @override
  String get onboardingPromiseTitle => 'Our Promise';

  @override
  String get onboardingPromiseDescription =>
      'We provide a moderated space you can safely express yourself and learn from others.';

  @override
  String get onboardingAskTitle => 'Our Ask';

  @override
  String get onboardingAskDescription =>
      'We ask that you keep everything confidential, and that you only speak from your experience.';

  @override
  String get logIn => 'Log in';

  @override
  String get logInButtonLabel => 'Log in button';

  @override
  String get onboardingTitleLabel => 'Onboarding title';

  @override
  String get onboardingDescriptionLabel => 'Onboarding description';

  @override
  String get nextPageLabel => 'Next page';

  @override
  String get getStarted => 'Get Started';

  @override
  String get enterEmailDescription =>
      'Enter your email to create an account or access your existing one.';

  @override
  String get email => 'Email';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email address';

  @override
  String get yesReceiveEmailUpdates => 'Yes, receive email updates';

  @override
  String get byContinuingYouAgree => 'By continuing, you agree to our ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get and => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get signIn => 'Sign in';

  @override
  String get wellSendSixDigitPin =>
      'We\'ll send you a 6-digit PIN to your email.';

  @override
  String get turnConversationsIntoCommunity =>
      'Turn Conversations Into Community';
}
