### 1. Overview
The Totem App will use a secure, PIN-based authentication process. This system will issue a device-specific, persistent API key after successful authentication that remains active until the user explicitly logs out. The system is designed for ease of use while maintaining strong security, using Flutter's secure storage to hold credentials on the client side.

### 2. Authentication Flow
#### 2.1. Requesting a PIN
- **User Initiation:**
  - A user enters their email address to begin authentication.
  - The backend (Django with django-ninja) generates a unique PIN code.
- **PIN Delivery:**
  - The user receives an email containing:
    - A numeric PIN that serves as their authentication code.
  - Optionally, users can choose to subscribe to newsletters during this process.

#### 2.2. PIN-based Authentication Flow
- **PIN Entry:**
  - Users enter the provided PIN into the app to authenticate.
- **Expiration & Validity:**
  - PINs are valid for 30 minutes.
  - If a user enters an expired PIN, the app displays an error message and prompts the user to request a new PIN.
- **Attempt Limitation:**
  - Users are allowed up to five incorrect PIN entries.
  - After five failed attempts, all active PINs for that user are reset, and the user must request a new PIN.
- **User Feedback:**
  - On reset, a clear notification instructs the user to request a new authentication email.

### 3. API Key Management
#### 3.1. API Key Issuance
- **Upon Successful Authentication:**
  - Once the user's PIN is validated, the backend generates a new, device-specific API key.
  - The API key is designed to remain valid until the user logs out, ensuring a persistent session.
- **Device-Specific Enforcement:**
  - The API key is bound to a unique device identifier (collected via Flutter's device APIs) to prevent reuse on unauthorized devices.
  - Each new login (even on the same device) triggers the issuance of a new API key.

#### 3.2. API Key Security & Storage
- **Secure Storage:**
  - The API key is stored on the device using Flutter's `flutter_secure_storage`, ensuring that sensitive data is kept safe.
- **Session Management:**
  - The API key will only be invalidated when the user logs out.
  - There is no built-in expiry period for the API key; however, a new API key is generated upon every login, and existing keys are revoked on logout.

### 4. Error Handling & User Feedback
#### 4.1. PIN Errors
- **Expired PIN:**
  - If the user enters an expired PIN, the app displays a clear error message with an option to request a new PIN.
- **Incorrect PIN Entry:**
  - Each failed PIN attempt will trigger an error message showing the number of remaining attempts.
  - After five incorrect attempts, the user is notified that their active PINs have been reset and that they must request a new authentication email.
- **Other Errors:**
  - The app should handle cases such as no internet connection with appropriate feedback.
  - The app should never reveal if an email is already in use or if email sending failed (for security reasons).

#### 4.2. API Key Issues
- **Device Mismatch:**
  - If an API key is attempted to be used on a different device than intended, the backend will reject the key, and the app will prompt the user to log in again.
- **Network or Server Errors:**
  - Standard error handling mechanisms will be in place to handle API request failures (e.g., displaying a retry option or appropriate error messages).

### 5. Security Considerations
- **PIN Generation:**
  - Unique and securely generated PINs ensure that codes cannot be predicted or reused.
- **Rate Limiting & Brute Force Protection:**
  - A limit of five incorrect PIN attempts per active set mitigates brute force attacks.
- **Secure Communication:**
  - All communications between the app and the backend will occur over HTTPS, ensuring encrypted data transmission.
- **Logging & Monitoring:**
  - The backend will log authentication attempts and failures to monitor for unusual activity.
- **API Key Revocation:**
  - In the event of suspicious activity, there will be backend mechanisms to revoke API keys, and users can manually log out from all devices if needed.

### 6. Integration with Backend
- **Django-ninja & OpenAPI:**
  - The authentication endpoints will be defined within the existing OpenAPI definition provided by django-ninja.
  - The endpoints include:
    - Request PIN
    - Validate PIN and Issue API Key
    - Logout (to revoke the API key)
- **Django Admin for Sensitive Data:**
  - Sensitive user data and authentication flows can be monitored and managed via Django Admin, providing a central control point for administrators.
