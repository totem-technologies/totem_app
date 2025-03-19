User Story: New User Signup and Profile Configuration

Title:
New User Signup and Profile Setup

Narrative:
As a new user, I want to sign up using my email, authenticate via a magic link or backup PIN, and then configure my profile with a first name and an optional profile image so that I can personalize my account and securely access the Totem App.

Acceptance Criteria:

    Email Registration & Magic Link Request:
        Given the new user is on the signup screen,
        When they enter their email address and tap "Send Magic Link,"
        Then the backend generates and sends a magic link along with a backup PIN to the provided email.

    Magic Link Authentication:
        Given the new user receives the authentication email,
        When they click the magic link,
        Then the app should open via deep linking, automatically validate the token, and proceed with the signup process.

    Backup PIN Flow:
        Given the magic link fails or the user prefers not to use it,
        When the user manually enters the backup PIN into the app,
        Then the app validates the PIN, allowing up to five attempts before resetting the active PINs.

    Profile Configuration:
        Given successful authentication (via magic link or PIN),
        When the user is logged in for the first time,
        Then they are directed to a profile configuration screen where they must:
            Enter their first name (mandatory).
            Optionally upload a profile image.

    Profile Validation and Submission:
        Given the profile configuration screen,
        When the user submits their details,
        Then the app validates that the first name is provided and (if applicable) the profile image meets any specified requirements,
        And then the details are saved to the backend as part of the new user account.

    Successful Signup Completion:
        Given that the profile is configured and saved successfully,
        When the submission is confirmed,
        Then the user is navigated to the main app screen, fully logged in with their new profile settings applied.

    Error Handling & Feedback:
        Given any errors during the signup or profile configuration (e.g., missing first name, invalid image format),
        When the user submits the form,
        Then the app displays clear error messages indicating what needs to be corrected before proceeding.

This story ensures that new users have a seamless, secure signup experience while also enabling them to personalize their profile immediately after account creation.
