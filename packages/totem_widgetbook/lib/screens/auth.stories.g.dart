// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'auth.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<AuthFlow, StoryArgs<AuthFlow>>;
typedef _Scenario = AuthFlowScenario;
typedef _Defaults = AuthFlowDefaults;
typedef _Story = AuthFlowStory;
typedef _Args = AuthInputArgs;
final AuthFlowComponent = Component<AuthFlow, StoryArgs<AuthFlow>>(
  name: component.name ?? 'AuthFlow',
  path: component.path ?? 'screens',
  docsBuilder: component.docsBuilder,
  docComment:
      r'''Figma "User Auth Flow" (2427:790): welcome slides, sign in by email
code, guidelines, notifications, then onboarding.

Every field shows what it is given; nothing is typed here. Callbacks
report what the member tapped, and the caller decides what changes.
[onNext] is the main button of whichever step is showing.

Fonts: Figma mixes Poppins and Work Sans into a few frames. The
catalog only ships Montserrat, so everything is set in it.''',
  stories: [
    $Welcome..$generatedName = 'Welcome',
    $OurPromise..$generatedName = 'OurPromise',
    $OurAsk..$generatedName = 'OurAsk',
    $GetStarted..$generatedName = 'GetStarted',
    $GetStartedError..$generatedName = 'GetStartedError',
    $VerifyCode..$generatedName = 'VerifyCode',
    $VerifyCodeTyping..$generatedName = 'VerifyCodeTyping',
    $VerifyCodeError..$generatedName = 'VerifyCodeError',
    $Guidelines..$generatedName = 'Guidelines',
    $Notifications..$generatedName = 'Notifications',
    $NotificationsIos..$generatedName = 'NotificationsIos',
    $NotificationsAndroid..$generatedName = 'NotificationsAndroid',
    $Profile..$generatedName = 'Profile',
    $ProfileFilled..$generatedName = 'ProfileFilled',
    $AvatarSheet..$generatedName = 'AvatarSheet',
    $ReferralSheet..$generatedName = 'ReferralSheet',
    $Communities..$generatedName = 'Communities',
    $Spaces..$generatedName = 'Spaces',
  ],
);
typedef AuthFlowScenario = Scenario<AuthFlow, AuthInputArgs>;
typedef AuthFlowDefaults = Defaults<AuthFlow, AuthInputArgs>;

class AuthFlowStory extends Story<AuthFlow, AuthInputArgs> {
  AuthFlowStory({
    super.name,
    super.designLink,
    SetupBuilder<AuthFlow, AuthInputArgs>? setup,
    super.modes,
    AuthInputArgs? args,
    StoryWidgetBuilder<AuthFlow, AuthInputArgs>? builder,
    super.scenarios,
    super.excludeFromTests,
  }) : super(
         args: args ?? AuthInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class AuthInputArgs extends StoryArgs<AuthFlow> {
  AuthInputArgs({
    Arg<AuthStep>? step,
    Arg<int>? welcomePage,
    Arg<String>? email,
    Arg<String?>? emailError,
    Arg<String>? code,
    Arg<bool>? codeError,
    Arg<NotificationPrompt>? notificationPrompt,
    Arg<String>? name,
    Arg<String>? age,
    Arg<Referral?>? referral,
    Arg<bool>? newsletter,
    Arg<AuthSheet>? sheet,
    Arg<AvatarStyle>? avatarStyle,
    Arg<Iterable<Community>>? communities,
  }) : this.stepArg = $initArg(
         'step',
         step,
         EnumArg<AuthStep>(AuthStep.welcome, values: AuthStep.values),
       )!,
       this.welcomePageArg = $initArg('welcomePage', welcomePage, IntArg(0))!,
       this.emailArg = $initArg('email', email, StringArg(''))!,
       this.emailErrorArg = $initArg(
         'emailError',
         emailError,
         NullableStringArg(null),
       )!,
       this.codeArg = $initArg('code', code, StringArg(''))!,
       this.codeErrorArg = $initArg('codeError', codeError, BoolArg(false))!,
       this.notificationPromptArg = $initArg(
         'notificationPrompt',
         notificationPrompt,
         EnumArg<NotificationPrompt>(
           NotificationPrompt.none,
           values: NotificationPrompt.values,
         ),
       )!,
       this.nameArg = $initArg('name', name, StringArg(''))!,
       this.ageArg = $initArg('age', age, StringArg(''))!,
       this.referralArg = $initArg(
         'referral',
         referral,
         NullableEnumArg<Referral>(null, values: Referral.values),
       )!,
       this.newsletterArg = $initArg('newsletter', newsletter, BoolArg(false))!,
       this.sheetArg = $initArg(
         'sheet',
         sheet,
         EnumArg<AuthSheet>(AuthSheet.none, values: AuthSheet.values),
       )!,
       this.avatarStyleArg = $initArg(
         'avatarStyle',
         avatarStyle,
         EnumArg<AvatarStyle>(AvatarStyle.tieDye, values: AvatarStyle.values),
       )!,
       this.communitiesArg = $initArg(
         'communities',
         communities,
         ConstArg(const []),
       )!;

  AuthInputArgs.fixed({
    AuthStep step = AuthStep.welcome,
    int welcomePage = 0,
    String email = '',
    String? emailError = null,
    String code = '',
    bool codeError = false,
    NotificationPrompt notificationPrompt = NotificationPrompt.none,
    String name = '',
    String age = '',
    Referral? referral = null,
    bool newsletter = false,
    AuthSheet sheet = AuthSheet.none,
    AvatarStyle avatarStyle = AvatarStyle.tieDye,
    Iterable<Community> communities = const [],
  }) : this.stepArg = $initArg('step', Arg.fixed(step), null)!,
       this.welcomePageArg = $initArg(
         'welcomePage',
         Arg.fixed(welcomePage),
         null,
       )!,
       this.emailArg = $initArg('email', Arg.fixed(email), null)!,
       this.emailErrorArg = $initArg(
         'emailError',
         emailError == null ? null : Arg.fixed(emailError),
         null,
       ),
       this.codeArg = $initArg('code', Arg.fixed(code), null)!,
       this.codeErrorArg = $initArg('codeError', Arg.fixed(codeError), null)!,
       this.notificationPromptArg = $initArg(
         'notificationPrompt',
         Arg.fixed(notificationPrompt),
         null,
       )!,
       this.nameArg = $initArg('name', Arg.fixed(name), null)!,
       this.ageArg = $initArg('age', Arg.fixed(age), null)!,
       this.referralArg = $initArg(
         'referral',
         referral == null ? null : Arg.fixed(referral),
         null,
       ),
       this.newsletterArg = $initArg(
         'newsletter',
         Arg.fixed(newsletter),
         null,
       )!,
       this.sheetArg = $initArg('sheet', Arg.fixed(sheet), null)!,
       this.avatarStyleArg = $initArg(
         'avatarStyle',
         Arg.fixed(avatarStyle),
         null,
       )!,
       this.communitiesArg = $initArg(
         'communities',
         Arg.fixed(communities),
         null,
       )!;

  final Arg<AuthStep> stepArg;

  final Arg<int> welcomePageArg;

  final Arg<String> emailArg;

  final Arg<String?>? emailErrorArg;

  final Arg<String> codeArg;

  final Arg<bool> codeErrorArg;

  final Arg<NotificationPrompt> notificationPromptArg;

  final Arg<String> nameArg;

  final Arg<String> ageArg;

  final Arg<Referral?>? referralArg;

  final Arg<bool> newsletterArg;

  final Arg<AuthSheet> sheetArg;

  final Arg<AvatarStyle> avatarStyleArg;

  final Arg<Iterable<Community>> communitiesArg;

  AuthStep get step => stepArg.value;

  int get welcomePage => welcomePageArg.value;

  String get email => emailArg.value;

  String? get emailError => emailErrorArg?.value;

  String get code => codeArg.value;

  bool get codeError => codeErrorArg.value;

  NotificationPrompt get notificationPrompt => notificationPromptArg.value;

  String get name => nameArg.value;

  String get age => ageArg.value;

  Referral? get referral => referralArg?.value;

  bool get newsletter => newsletterArg.value;

  AuthSheet get sheet => sheetArg.value;

  AvatarStyle get avatarStyle => avatarStyleArg.value;

  Iterable<Community> get communities => communitiesArg.value;

  @override
  List<Arg?> get list => [
    stepArg,
    welcomePageArg,
    emailArg,
    emailErrorArg,
    codeArg,
    codeErrorArg,
    notificationPromptArg,
    nameArg,
    ageArg,
    referralArg,
    newsletterArg,
    sheetArg,
    avatarStyleArg,
    communitiesArg,
  ];
}
