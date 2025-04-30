## Totem App Authentication System Specification

### 1. Overview
The Totem App will use a secure, PIN-based authentication process. This system will issue a standard refresh token + JWT token pair after successful authentication. The JWT token (valid for 60 minutes) will be used for API requests while the refresh token enables obtaining new JWT tokens without re-authentication. The system is designed for ease of use while maintaining strong security, using Flutter's secure storage to hold credentials on the client side.

### 2. Authentication Flow
#### 2.1. Requesting a PIN
- **User Initiation:**
  - A user enters their email address to begin authentication.
  - The backend (Django with django-ninja) generates a unique PIN code.
- **Rate Limiting:**
  - Login and PIN request attempts are limited to 5 per minute per IP address.
  - When rate limit is exceeded, users will see error message [RATE_LIMIT_EXCEEDED].
- **PIN Delivery:**
  - The user receives an email containing:
    - A numeric PIN that serves as their authentication code.
  - Optionally, users can choose to subscribe to newsletters during this process.

#### 2.2. PIN-based Authentication Flow
- **PIN Entry:**
  - Users enter the provided PIN into the app to authenticate.
- **Rate Limiting:**
  - PIN validation attempts are limited to 5 per minute per email address.
  - When rate limit is exceeded, users will see error message [RATE_LIMIT_EXCEEDED].
- **Expiration & Validity:**
  - PINs are valid for 30 minutes.
  - If a user enters an expired PIN, the app displays error message [PIN_EXPIRED].
- **Attempt Limitation:**
  - Users are allowed up to five incorrect PIN entries total.
  - After five failed attempts, all active PINs for that user are reset, and the user must request a new PIN.
  - The app will display error message [TOO_MANY_ATTEMPTS].
- **Account Status Check:**
  - After successful PIN validation but before issuing tokens, the system will check if the user's account is deactivated.
  - If the account has been deactivated for community guidelines violations, the app will display error message [ACCOUNT_DEACTIVATED].

### 3. Token Management
#### 3.1. JWT and Refresh Token Issuance
- **Upon Successful Authentication:**
  - Once the user's PIN is validated and account status is confirmed as active, the backend generates:
    1. A JWT token for API requests (valid for exactly 60 minutes)
    2. A refresh token (long-lived, for obtaining new JWT tokens)
  - Both tokens are device-specific, bound to the device identifier
- **Device-Specific Enforcement:**
  - Tokens are bound to a unique device identifier (collected via Flutter's device APIs) to prevent reuse on unauthorized devices.
  - Each new login (even on the same device) triggers the issuance of a new token pair.

#### 3.2. Token Security & Storage
- **Secure Storage:**
  - Both tokens are stored on the device using Flutter's `flutter_secure_storage`, ensuring that sensitive data is kept safe.
- **Session Management:**
  - The refresh token will remain valid until the user logs out, or it is revoked.
  - The JWT token has a 60-minute lifespan and must be refreshed periodically.
  - When the JWT token expires, the app uses the refresh token to obtain a new JWT without requiring the user to re-authenticate.

#### 3.3. Token Refresh Process
- **Automatic Refresh:**
  - The app will automatically detect when a JWT token is about to expire (ideally 5 minutes before expiration).
  - It will use the refresh token to obtain a new JWT token from the backend.
- **Rate Limiting:**
  - Token refresh operations are also rate-limited to 5 per minute per device.
  - When exceeded, the app will display error message [RATE_LIMIT_EXCEEDED].
- **Refresh Failure Handling:**
  - If the refresh token is invalid or expired, the user will be prompted to log in again with error message [REAUTH_REQUIRED].
- **Account Status Validation:**
  - During token refresh, the system will also check if the user's account has been deactivated since their last authentication.
  - If the account is found to be deactivated, the refresh will fail and display error message [ACCOUNT_DEACTIVATED].

### 4. Error Messages
All error messages are deliberately vague to avoid providing attackers with useful information. The following error messages will be used throughout the app:

- **[RATE_LIMIT_EXCEEDED]**: "Too many attempts. Please try again later."
- **[PIN_EXPIRED]**: "Please request a new code."
- **[INCORRECT_PIN]**: "Incorrect code."
- **[TOO_MANY_ATTEMPTS]**: "Too many attempts. Please request a new code."
- **[REAUTH_REQUIRED]**: "Please sign in again."
- **[NETWORK_ERROR]**: "Please check your connection."
- **[SERVER_ERROR]**: "Something went wrong. Please try again later."
- **[ACCOUNT_DEACTIVATED]**: "This account has been deactivated for violating our community guidelines. Please contact support for more information."

When a PIN is incorrect, the app will show [INCORRECT_PIN] without revealing how many attempts remain or other specific information that could help an attacker.

### 5. Security Considerations
- **PIN Generation:**
  - Unique and securely generated PINs ensure that codes cannot be predicted or reused.
- **Rate Limiting & Brute Force Protection:**
  - A limit of five incorrect PIN attempts total mitigates brute force attacks.
  - Rate limiting of 5 attempts per minute for login attempts, PIN requests, PIN validations, and token refreshes provides additional protection.
- **JWT Configuration:**
  - JWTs will be configured with a 60-minute expiration time and secure signing algorithms.
  - JWTs will contain the necessary claims (user ID, device ID, scopes, etc.) but minimize sensitive information.
- **Refresh Token Security:**
  - Refresh tokens will be securely hashed in the database.
  - Each refresh token is associated with a specific device and user.
- **Secure Communication:**
  - All communications between the app and the backend will occur over HTTPS, ensuring encrypted data transmission.
- **Logging & Monitoring:**
  - The backend will log authentication attempts and failures to monitor for unusual activity.
  - Rate limit breaches will be logged to detect potential attacks.
- **Token Revocation:**
  - In the event of suspicious activity, there will be backend mechanisms to revoke both JWT and refresh tokens.
  - Users can manually log out from all devices if needed, which invalidates all refresh tokens.
  - When an account is deactivated, all associated refresh tokens will be automatically revoked.
- **Error Messages:**
  - All error messages are deliberately vague to avoid providing attackers with useful information.
  - Error messages do not reveal whether an email exists, if a token is invalid, or specific reasons for authentication failures.

### 6. Integration with Backend
- **Django-ninja & OpenAPI:**
  - The authentication endpoints will be defined within the existing OpenAPI definition provided by django-ninja.
  - The endpoints include:
    - Request PIN
    - Validate PIN and Issue Token Pair
    - Refresh JWT using Refresh Token
    - Logout (to revoke the refresh token)
- **Rate Limiting Implementation:**
  - The backend will implement rate limiting using IP addresses and user identifiers.
  - Caching system will be used to track rate limit counters.
- **Account Status Checks:**
  - The backend will implement a system to check user account status during authentication and token refresh.
  - Account deactivation status will be checked after PIN validation but before token issuance.
- **Django Admin for Sensitive Data:**
  - Sensitive user data and authentication flows can be monitored and managed via Django Admin, providing a central control point for administrators.
  - Rate limit breaches and authentication attempts will be viewable in the admin interface.
  - Administrators can deactivate accounts when users violate community guidelines.
