# Robust Flutter App Structure for Totem App (lib folder)

Based on the specifications and user stories provided, here's a well-structured organization for the Totem App's `lib` folder:

```
lib/
│
├── app/
│   ├── app.dart                    # Main app widget with routing setup
│   └── totem_app.dart              # App configuration and entry point
│
├── auth/
│   ├── controllers/                # Auth-related controllers
│   │   ├── auth_controller.dart    # Main auth controller with Riverpod
│   │   └── session_controller.dart # Manages API keys and sessions
│   ├── models/
│   │   ├── user.dart               # User model
│   │   └── auth_state.dart         # Auth state representation
│   ├── repositories/
│   │   └── auth_repository.dart    # Handles API calls for authentication
│   ├── screens/
│   │   ├── login_screen.dart       # Email input screen
│   │   ├── pin_entry_screen.dart   # Backup PIN entry
│   │   └── profile_setup_screen.dart # First-time user profile configuration
│   ├── widgets/
│   │   ├── magic_link_handler.dart # Deep link handler for magic links
│   │   └── auth_form.dart          # Reusable auth form components
│   └── auth_service.dart           # Core authentication service
│
├── core/
│   ├── config/
│   │   ├── app_config.dart         # App-wide configuration
│   │   └── theme.dart              # App theming
│   ├── constants/
│   │   ├── api_endpoints.dart      # API endpoint definitions
│   │   └── app_constants.dart      # App-wide constants
│   ├── errors/
│   │   ├── app_exceptions.dart     # Custom exceptions
│   │   └── error_handler.dart      # Centralized error handling
│   ├── services/
│   │   ├── api_service.dart        # Base API service with interceptors
│   │   ├── secure_storage.dart     # Wrapper for flutter_secure_storage
│   │   ├── deep_link_service.dart  # Handles app deep links
│   │   └── analytics_service.dart  # Usage analytics
│   └── utils/
│       ├── validators.dart         # Input validation utilities
│       └── formatters.dart         # Text/data formatting utilities
│
├── features/
│   ├── profile/
│   │   ├── controllers/
│   │   │   └── profile_controller.dart
│   │   ├── models/
│   │   │   └── profile.dart
│   │   ├── repositories/
│   │   │   └── profile_repository.dart
│   │   ├── screens/
│   │   │   └── profile_screen.dart
│   │   └── widgets/
│   │       ├── profile_avatar.dart
│   │       └── profile_form.dart
│   │
│   ├── spaces/
│   │   ├── controllers/
│   │   │   ├── spaces_controller.dart
│   │   │   └── space_detail_controller.dart
│   │   ├── models/
│   │   │   ├── space.dart
│   │   │   └── session.dart
│   │   ├── repositories/
│   │   │   └── spaces_repository.dart
│   │   ├── screens/
│   │   │   ├── spaces_discovery_screen.dart
│   │   │   └── space_detail_screen.dart
│   │   └── widgets/
│   │       ├── space_card.dart
│   │       └── session_list_item.dart
│   │
│   ├── video_sessions/
│   │   ├── controllers/
│   │   │   └── video_session_controller.dart
│   │   ├── models/
│   │   │   ├── participant.dart
│   │   │   └── video_session.dart
│   │   ├── repositories/
│   │   │   └── video_session_repository.dart
│   │   ├── screens/
│   │   │   ├── video_room_screen.dart
│   │   │   └── pre_join_screen.dart
│   │   ├── services/
│   │   │   └── livekit_service.dart  # LiveKit integration
│   │   └── widgets/
│   │       ├── video_controls.dart
│   │       └── participant_view.dart
│   │
│   └── notifications/
│       ├── controllers/
│       │   └── notification_controller.dart
│       ├── models/
│       │   └── notification.dart
│       ├── repositories/
│       │   └── notification_repository.dart
│       ├── screens/
│       │   └── notification_settings_screen.dart
│       ├── services/
│       │   ├── push_notification_service.dart
│       │   └── email_notification_service.dart
│       └── widgets/
│           └── notification_list_item.dart
│
├── navigation/
│   ├── app_router.dart             # GoRouter configuration
│   ├── route_names.dart            # Constants for route names
│   └── route_guards.dart           # Authentication-based route protection
│
├── shared/
│   ├── models/
│   │   └── api_response.dart       # Generic API response model
│   ├── widgets/
│   │   ├── app_bar.dart            # Customized app bar
│   │   ├── buttons.dart            # Reusable button styles
│   │   ├── loading_indicator.dart  # Loading states
│   │   ├── error_display.dart      # Error display components
│   │   └── form_fields.dart        # Custom form inputs
│   └── extensions/
│       ├── string_extensions.dart  # String utility extensions
│       └── context_extensions.dart # BuildContext extensions
│
└── main.dart                       # App entry point
```

### Key Design Principles:

1. **Feature-first organization**: Main functionality is organized by feature areas, with each feature having its own models, controllers, screens, and widgets.

2. **Clean architecture concepts**: Separation of UI, business logic, and data access through controllers, repositories, and services.

3. **Riverpod integration**: Controllers are designed to work with Riverpod for state management.

4. **Reusability**: Common functionality extracted into shared widgets and services.

5. **Authentication flow**: Complete structure for implementing magic link and PIN-based authentication.

6. **Video session management**: Dedicated structure for LiveKit integration.

7. **Navigation**: Type-safe routing with GoRouter.

8. **Scalability**: Structure allows easy addition of new features while maintaining organization.

This structure supports all the requirements specified in the Totem App specifications including authentication, spaces and session discovery, video sessions with LiveKit, notifications, and profile management.
