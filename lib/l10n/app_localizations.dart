import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @communityGuidelinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Guidelines'**
  String get communityGuidelinesTitle;

  /// No description provided for @communityGuidelinesConfidentialityText.
  ///
  /// In en, this message translates to:
  /// **'In order to keep Totem safe, we require everyone adhere to '**
  String get communityGuidelinesConfidentialityText;

  /// No description provided for @confidentiality.
  ///
  /// In en, this message translates to:
  /// **'confidentiality'**
  String get confidentiality;

  /// No description provided for @communityGuidelinesConfidentialityWarning.
  ///
  /// In en, this message translates to:
  /// **'. Breaking confidentiality can be grounds for account removal.'**
  String get communityGuidelinesConfidentialityWarning;

  /// No description provided for @communityGuidelinesPersonalExperienceText.
  ///
  /// In en, this message translates to:
  /// **'We also encourage you to only speak about '**
  String get communityGuidelinesPersonalExperienceText;

  /// No description provided for @yourOwnExperience.
  ///
  /// In en, this message translates to:
  /// **'your own experience'**
  String get yourOwnExperience;

  /// No description provided for @communityGuidelinesPersonalExperienceWarning.
  ///
  /// In en, this message translates to:
  /// **', and not to share other people\'s information or stories.'**
  String get communityGuidelinesPersonalExperienceWarning;

  /// No description provided for @communityGuidelinesFullText.
  ///
  /// In en, this message translates to:
  /// **'For more details, see the full '**
  String get communityGuidelinesFullText;

  /// No description provided for @communityGuidelinesLink.
  ///
  /// In en, this message translates to:
  /// **'Community Guidelines'**
  String get communityGuidelinesLink;

  /// No description provided for @agreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and Continue'**
  String get agreeAndContinue;

  /// No description provided for @letsGetToKnowYou.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get to know you'**
  String get letsGetToKnowYou;

  /// No description provided for @profileSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'We just to know more about you. some final question and you\'ll be good to go.'**
  String get profileSetupDescription;

  /// No description provided for @whatToBeCalledQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you like to be called?'**
  String get whatToBeCalledQuestion;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterName;

  /// No description provided for @nameHelpText.
  ///
  /// In en, this message translates to:
  /// **'Other people will see this, but you don\'t have to use your real name. Add any pronounce is parentheses if you\'d like.'**
  String get nameHelpText;

  /// No description provided for @howOldAreYouQuestion.
  ///
  /// In en, this message translates to:
  /// **'How old are you?'**
  String get howOldAreYouQuestion;

  /// No description provided for @enterYourAge.
  ///
  /// In en, this message translates to:
  /// **'Enter your age'**
  String get enterYourAge;

  /// No description provided for @ageHelpText.
  ///
  /// In en, this message translates to:
  /// **'You must be over 13 to join. Age is for verification only, no one will see it.'**
  String get ageHelpText;

  /// No description provided for @howDidYouHearAboutUsQuestion.
  ///
  /// In en, this message translates to:
  /// **'How did you hear about us?'**
  String get howDidYouHearAboutUsQuestion;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// No description provided for @referralHelpText.
  ///
  /// In en, this message translates to:
  /// **'This helps us understand how to reach more people like you.'**
  String get referralHelpText;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @whichCommunityFeelsLikeHome.
  ///
  /// In en, this message translates to:
  /// **'Which community feels like home to you?'**
  String get whichCommunityFeelsLikeHome;

  /// No description provided for @pickFewSpacesDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick a few — we\'ll help you connect with the right spaces.'**
  String get pickFewSpacesDescription;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @suggestedSpaces.
  ///
  /// In en, this message translates to:
  /// **'Suggested Spaces'**
  String get suggestedSpaces;

  /// No description provided for @suggestedSpacesDescription.
  ///
  /// In en, this message translates to:
  /// **'We\'ve found some spaces that might be a good fit for you.'**
  String get suggestedSpacesDescription;

  /// No description provided for @noSuggestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No suggestions yet. Try selecting a few topics.'**
  String get noSuggestionsYet;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @couldntLoadSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load suggestions.'**
  String get couldntLoadSuggestions;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterVerificationCode;

  /// No description provided for @weSentSixDigitPinTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit PIN to '**
  String get weSentSixDigitPinTo;

  /// No description provided for @yourEmail.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get yourEmail;

  /// No description provided for @pleaseEnterItBelow.
  ///
  /// In en, this message translates to:
  /// **'\nPlease enter it below to.'**
  String get pleaseEnterItBelow;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enterSixDigitCode;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyCode;

  /// No description provided for @needNewCode.
  ///
  /// In en, this message translates to:
  /// **'Need a new code? '**
  String get needNewCode;

  /// No description provided for @sendAgain.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get sendAgain;

  /// No description provided for @attemptsOf.
  ///
  /// In en, this message translates to:
  /// **'Attempts: {current} of {max}'**
  String attemptsOf(int current, int max);

  /// No description provided for @pleaseEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Please enter the PIN from your email'**
  String get pleaseEnterPin;

  /// No description provided for @pinMustBeSixDigits.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 6 digits'**
  String get pinMustBeSixDigits;

  /// No description provided for @pinMustContainOnlyDigits.
  ///
  /// In en, this message translates to:
  /// **'PIN must contain only digits'**
  String get pinMustContainOnlyDigits;

  /// No description provided for @invalidPinTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN. Please try again.'**
  String get invalidPinTryAgain;

  /// No description provided for @tooManyFailedAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please request a new magic link.'**
  String get tooManyFailedAttempts;

  /// No description provided for @invalidPinAttemptsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN. {remaining} attempts remaining.'**
  String invalidPinAttemptsRemaining(int remaining);

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Totem provides online discussion groups where you can cultivate your voice, and be a better listener.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingPromiseTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Promise'**
  String get onboardingPromiseTitle;

  /// No description provided for @onboardingPromiseDescription.
  ///
  /// In en, this message translates to:
  /// **'We provide a moderated space you can safely express yourself and learn from others.'**
  String get onboardingPromiseDescription;

  /// No description provided for @onboardingAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Ask'**
  String get onboardingAskTitle;

  /// No description provided for @onboardingAskDescription.
  ///
  /// In en, this message translates to:
  /// **'We ask that you keep everything confidential, and that you only speak from your experience.'**
  String get onboardingAskDescription;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @logInButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Log in button'**
  String get logInButtonLabel;

  /// No description provided for @onboardingTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Onboarding title'**
  String get onboardingTitleLabel;

  /// No description provided for @onboardingDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Onboarding description'**
  String get onboardingDescriptionLabel;

  /// No description provided for @nextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPageLabel;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @enterEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to create an account or access your existing one.'**
  String get enterEmailDescription;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterValidEmail;

  /// No description provided for @yesReceiveEmailUpdates.
  ///
  /// In en, this message translates to:
  /// **'Yes, receive email updates'**
  String get yesReceiveEmailUpdates;

  /// No description provided for @byContinuingYouAgree.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get byContinuingYouAgree;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @wellSendSixDigitPin.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a 6-digit PIN to your email.'**
  String get wellSendSixDigitPin;

  /// No description provided for @turnConversationsIntoCommunity.
  ///
  /// In en, this message translates to:
  /// **'Turn Conversations Into Community'**
  String get turnConversationsIntoCommunity;

  /// No description provided for @keeper.
  ///
  /// In en, this message translates to:
  /// **'Keeper'**
  String get keeper;

  /// No description provided for @withPrefix.
  ///
  /// In en, this message translates to:
  /// **'With '**
  String get withPrefix;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @seatsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} seats left'**
  String seatsLeft(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
