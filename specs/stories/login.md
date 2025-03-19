User Story: Existing User Login via Magic Link and Backup PIN

Title:
Existing User Login

Narrative:
As an existing user, I want to log in using a magic link sent to my email so that I can securely access the Totem App without having to remember a password. If the magic link does not work, I want the option to use a backup PIN to complete my login, ensuring a smooth and secure authentication experience.

Acceptance Criteria:

    Email Login Request:
        Given that the user is on the login screen,
        When they enter their registered email address and tap "Send Magic Link,"
        Then the backend generates and sends a magic link and a backup PIN to that email.

    Magic Link Authentication:
        Given that the user receives the magic link email,
        When they click the magic link,
        Then the Totem App should open via deep linking, automatically validate the token, and log the user in.

    Backup PIN Authentication:
        Given that the magic link fails or the user opts to use the backup PIN,
        When the user enters the backup PIN into the app,
        Then the app validates the PIN, allowing up to five attempts before all active PINs are reset.

    API Key Generation and Storage:
        Given that the login is successful (via magic link or PIN),
        When the user is authenticated,
        Then the backend issues a new, device-specific API key, which is securely stored using Flutter's flutter_secure_storage and remains active until the user logs out.

    Error Handling and Feedback:
        Given that the magic link is expired (after 30 minutes) or the entered PIN is incorrect,
        When these issues occur,
        Then clear error messages are displayed to the user, indicating the problem and instructing them on how to request a new magic link or reattempt the PIN entry.

This story ensures that existing users can securely and seamlessly log in to the Totem App using the defined authentication flow.
