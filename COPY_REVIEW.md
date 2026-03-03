# Totem App — Copy Review

> **How to use:** Review each string in the "Current Copy" column. Write your proposed replacement in the "Proposed Change" column. Leave blank if the copy is fine as-is. Strings marked with `{variable}` are dynamic placeholders — keep them intact.

---

## App Metadata

| Location | Current Copy | Proposed Change |
|---|---|---|
| App title | Totem | |
| pubspec.yaml description | Guided introspection groups. | |

---

## Welcome Screen
`lib/auth/screens/welcome_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Turn Conversations Into Community | |
| Get Started | Start Sharing |

---

## Onboarding Screen
`lib/auth/screens/onboarding_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Log in | Sign in |
| Welcome | |
| Totem provides online discussion groups where you can cultivate your voice, and be a better listener. | Totem is where you find your people, and share your story. |
| Our Promise | |
| We provide moderated spaces where you can safely express yourself and learn from others. | |
| Our Ask | |
| We ask that you keep everything confidential, and that you only speak from your own experience. | Keep everything confidential, and you only speak from your own experience. |
| Create account | |
| Next page *(accessibility label)* | |
| Previous page *(accessibility label)* | |

---

## Login Screen
`lib/auth/screens/login_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Get Started | |
| Enter your email to create an account or access your existing one. | |
| Email | |
| Please enter your email | |
| Please enter a valid email address | |
| By continuing, you agree to our | |
| Terms of Service | |
| Privacy Policy | |
| Sign in | *(already correct)* |
| We'll send you a 6-digit PIN to your email. | We'll send a 6-digit PIN to your email. |

---

## PIN Entry Screen
`lib/auth/screens/pin_entry_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Enter verification code | |
| We've sent a 6-digit PIN to | |
| your email | |
| Please enter it below to. | Please enter it below. |
| Enter 6-digit code | |
| Verify Code | |
| Need a new code? | |
| Send again | |
| Please enter the PIN from your email | |
| PIN must be 6 digits | |
| PIN must contain only digits | |
| Invalid PIN. Please try again. | |
| Too many failed attempts. Please request a new PIN. | |
| Invalid PIN.\n{attempts} attempts remaining. | |
| Attempts: {attempts} of {maxAttempts} | |

---

## Profile Setup / Community Guidelines
`lib/auth/screens/profile_setup_screen.dart`

### Community Guidelines Step

| Current Copy | Proposed Change |
|---|---|
| Community Guidelines | |
| In order to keep Totem safe, we require everyone adhere to confidentiality. Breaking confidentiality can be grounds for account removal. | |
| We also encourage you to only speak about your own experience, and not to share other people's information or stories. | |
| For more details, see the full Community Guidelines. | |
| Agree and Continue | |

### Name & Age Step

| Current Copy | Proposed Change |
|---|---|
| Let's get to know you | |
| We just to know more about you. Some final question and you'll be good to go. | A few final questions and you'll be good to go. |
| What do you like to be called? | |
| Enter name | |
| Other people will see this, but you don't have to use your real name. Add any pronounce is parentheses if you'd like. | Other people will see this. You don't have to use your real name. Add any pronouns in parentheses if you'd like. |
| How old are you? | |
| Enter your age | |
| You must be over 13 to join. Age is for verification only, no one will see it. | You must be over 13 to join. This is only for a legal requirement, no one will see it. |
| Please enter your first name | |
| Please enter your age | |
| Please enter a valid age | |
| You must be at least 13 years old | |

### Referral Step

| Current Copy | Proposed Change |
|---|---|
| How did you hear about us? | |
| Tap to select | |
| This helps us understand how to reach more people like you. | |
| I want to receive Totem Updates and Spaces Announcements. | I want to receive updates about Totem. |
| Continue | |

### Topics Step

| Current Copy | Proposed Change |
|---|---|
| Which community feels like home to you? | Topics |
| Pick a few — we'll help you connect with the right spaces. | Pick a few. We'll help you connect with the right people. |
| Love & Emotions | |
| Mothers | |
| Queer | |
| Self-improvement | |
| Other | |
| Next | |

### Suggested Spaces Step

| Current Copy | Proposed Change |
|---|---|
| Suggested Spaces | Suggested Sessions |
| We've found some spaces that might be a good fit for you. | We've found some sessions that might be a good fit for you. |
| No suggestions yet. Try selecting a few topics. | |
| See all | See all sessions |
| Couldn't load suggestions. | |
| See all spaces | See all sessions |

---

## Home Screen
`lib/features/home/screens/home_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Your Next Session | |
| View All | |
| Upcoming Sessions | |
| Blogs | |
| Totem is a nonprofit creating online Spaces for connection and support. We believe these gatherings can help build a more thoughtful, caring world. | Welcome to Totem! Get stated by signing up for your first session. Below you can find the next upcoming sessions, or use the Sessions tab to see everything. |

---

## Spaces Discovery Screen
`lib/features/spaces/screens/spaces_discovery_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| No sessions available yet. | |
| My Sessions | |
| No sessions in "{filterName}" | |
| You haven't joined any sessions yet | |
| Try selecting a different category | |

---

## Subscribed Spaces Screen
`lib/features/spaces/screens/subcribed_spaces.dart`

| Current Copy | Proposed Change |
|---|---|
| Subscribed Spaces | |
| You are not subscribed to any Spaces. | |
| Browse Spaces | |
| These are the Spaces you will get notifications for when new sessions are coming up. | These are the Spaces you will get notifications for when new sessions come up. |

---

## Session History Screen
`lib/features/spaces/screens/session_history.dart`

| Current Copy | Proposed Change |
|---|---|
| Session History | |
| You have not joined any Spaces yet. | You have not joined any sessions yet. |
| Browse Spaces | |
| Here are the recent sessions you have been a part of. | Here are the recent sessions you have participated in. |

---

## Profile Screen
`lib/features/profile/screens/profile_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Sessions joined | |
| Member Since | |
| Account | |
| Profile | |
| Subscribed Spaces | |
| Session history | |
| Logout | Sign out |
| Help | |
| Feedback | |
| Privacy Policy | |
| Terms | |
| Community Guidelines | |
| Delete account | |

---

## Profile Details Screen
`lib/features/profile/screens/profile_details_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Name | |
| Enter name | |
| Your name will be visible to other people on Totem. | |
| Email address | |
| Enter email address | |
| Your email will be private. | |
| Update | |
| Profile updated successfully | |
| Failed to update profile. Try again later. | |

---

## Feedback Screen
`lib/features/profile/screens/user_feedback.dart`

| Current Copy | Proposed Change |
|---|---|
| Feedback | |
| We love hearing about how we can improve Totem. If you have any feedback, please let us know! | We love hearing about how we can improve Totem. Leave any feedback you have here.  |
| Share your thoughts, suggestions, or report issues... | |
| Please enter your feedback | |
| Please provide more detailed feedback (at least 10 characters) | |
| Submit Feedback | |
| Thank you for your feedback!\nWe appreciate your input. | |
| Discard Feedback? | |
| You have unsent feedback. Are you sure you want to discard it? | |
| Discard | |

---

## Delete Account / Sign Out
`lib/features/profile/screens/delete_account.dart`

| Current Copy | Proposed Change |
|---|---|
| This action will permanently delete your account. Are you sure you want to continue? | This action will permanently delete your account and sign you out. Are you sure you want to continue? |
| Delete account | |
| Are you sure you want to log out? | Are you sure you want to sign out? |
| Log out | Sign out |

---

## Session — Pre-Join / Loading
`lib/features/sessions/screens/`

| Current Copy | Proposed Change |
|---|---|
| Connecting... | |

---

## Session — Error Screen
`lib/features/sessions/screens/error_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Something went wrong | |
| We couldn't connect you to this space. Please check your internet connection or try again. | We couldn't connect you to this session. Please check your internet connection or try again. |
| You have been banned from this space. | You have been permanently removed from this session. |
| You can still join other spaces, but you won't be able to access this one. | You can still join other sessions, but you won't be able to access this one. |
| This space has ended | This session has ended |
| This space has already ended. You can still join other spaces. | This session has already ended. You can still join other sessions. |
| This space is not joinable | This session cannot be joined |
| This space is not joinable. Please check if the link is correct or try again later. | You cannot join the session at this time. Please try again later. |
| Retry | |

---

## Session — Options Sheet
`lib/features/sessions/screens/options_sheet.dart`

| Current Copy | Proposed Change |
|---|---|
| Are you sure you want to leave the session? | |
| Yes | |
| Front | |
| Back | |
| Camera disabled | |
| Speaker | |
| Leave Session | |
| Keeper Options | |
| Start session | |
| Reorder Participants | |
| Banned Participants | |
| Mute everyone | |
| Force pass to {participantName} | |
| End Session | |
| Session State | |
| Session Status: {status} | |
| Totem Status: {status} | |
| Speaking now: {userName} | |
| Are you sure you want to start the session? | |
| Are you sure you want to force pass the totem? This will end {speaker}'s turn and give the totem to {participantName}. | |
| Failed to perform next totem action | |
| Are you sure you want to end the session? | |
| No Connected Device | |
| Default Device | |
| Microphone | |
| Unknown Device | |

---

## Error Handling (Global)
`lib/core/errors/error_handler.dart`

| Current Copy | Proposed Change |
|---|---|
| This page doesn't exist | |
| Oops! Something went wrong.\nPlease try again later. | |
| Authentication error. Please log in again. | Authentication error. Please sign in again. |
| There was an issue processing your data. Please try again. | There was an unexpected server error. The team has been notified. Please try again. |
| Oops! Something went wrong. | |

---

## Shared Widgets

### Confirmation Dialog — `lib/shared/widgets/confirmation_dialog.dart`

| Current Copy | Proposed Change |
|---|---|
| Are you sure? | |
| Cancel | |
| Something went wrong. Please try again. | |

### Empty Indicator — `lib/shared/widgets/empty_indicator.dart`

| Current Copy | Proposed Change |
|---|---|
| Nothing available yet | |
| Retry | |

### Offline Indicator — `lib/shared/widgets/offline_indicator.dart`

| Current Copy | Proposed Change |
|---|---|
| You are offline | |
| You're back online | |

### Error Screen (Generic) — `lib/shared/widgets/error_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| Oops! Something went wrong. | |
| Retry | |
| You might be a little off path and that's okay. Let's help you find your way back. | |
| Return to Home | |
| Something went wrong!\nPlease try later | |
| Ok | |

---

## Blog
`lib/features/blog/screens/blog_list_screen.dart`

| Current Copy | Proposed Change |
|---|---|
| No blog posts available yet | |

---

## Notes

**Potential issues spotted during extraction:**
1. **Typo:** "Please enter it below to." — incomplete sentence (PIN entry screen)
2. **Typo:** "We just to know more about you. Some final question and you'll be good to go." — missing word ("want"), "question" should be "questions"
3. **Typo:** "Add any pronounce is parentheses if you'd like." — should be "pronouns in parentheses"
4. **Inconsistency:** "Log out" vs "Logout" — standardizing to "Sign in" / "Sign out"
5. **Inconsistency:** "Delete account" casing varies across screens
