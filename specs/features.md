## Totem App Specification

### 1. Overview
The Totem App is a cross-platform Flutter application (desktop, Android, iOS) designed for Totem.org, a non-profit promoting third spaces on the internet. It enables users to discover, join, and manage Totem Spaces—video groups where people discuss sensitive topics (e.g., LGBTQ issues, motherhood). Video sessions will be powered by LiveKit, and the app will include robust routing and a comprehensive notification system.

### 2. Objectives
- **Community Engagement:** Facilitate safe, meaningful discussions within Totem Spaces.
- **Seamless Experience:** Provide an intuitive user experience across desktop and mobile.
- **Robust Communication:** Enable high-quality, real-time video sessions with integrated LiveKit.
- **Future-proofing:** Build with an eye toward accessibility and scalability.

### 3. Target Users & Roles
- **Regular Users:**
  - Sign up, discover spaces, join video sessions, manage notifications, and modify their profile.
- **Keepers:**
  - Specially trained users who manage and moderate spaces.
  - Activated by an admin via the backend.
- **Administrators:**
  - Oversee Keeper activations and overall system management.

### 4. User Experience & Flow
#### Authentication
- **Magic Link Sign-In:**
  - Users authenticate using email magic links.
  - Define magic link lifecycle: expiration, re-sending, and error handling.
- **User Onboarding:**
  - Clear flow from sign-up to profile setup.

#### Spaces & Session Discovery
- **Space Information:**
  - Display metadata for each space (e.g., title, description, topics).
  - Categorize and filter spaces for easy discovery.
- **Subscription/Sign-up:**
  - Allow users to subscribe to spaces to receive notifications when new sessions or events are added.
- **Multiple Sessions:**
  - Each space may host multiple sessions.
  - Sessions include key details such as scheduled time, duration, and any participant limits.

#### Video Sessions (LiveKit Integration)
- **Joining Sessions:**
  - Simple, one-click joining process for video sessions.
- **LiveKit Requirements:**
  - Address technical needs like video quality, latency, and error handling.
  - Moderator/host controls (e.g., muting participants).

#### Notifications
- **Types of Notifications:**
  - Email notifications.
  - Push notifications.
  - (Potential in-app notifications for immediate updates.)
- **Triggers:**
  - New space events or sessions.
  - Session reminders.
  - Updates from subscribed spaces.
- **User Control:**
  - Settings to manage notification preferences across types.

#### Profile Management
- **Editable User Profiles:**
  - Allow users to update personal information.
  - Include privacy settings to safeguard sensitive topics.

#### Routing & Navigation
- **Robust Router:**
  - Using type-safe GoRouter
  - Manage transitions between sign-up, discovery, video sessions, profile, and settings.
  - Support deep linking for sharing or returning directly to specific spaces or sessions.
  - Ensure consistent navigation patterns across desktop and mobile platforms.

### 5. Technical Requirements
#### Frontend & Framework
- **Technology:**
  - Built using Flutter to support desktop, Android, and iOS platforms.
  - GoRouter
  - RiverPod for state
  - LiveKit for video groups
  - All the normal popular Flutter packages, as needed.
  - "forui" for widgets
- **Responsive Design:**
  - Ensure UI components are flexible to accommodate future accessibility improvements.

#### Backend & Integration
- **Authentication API:**
  - Integration with Totem.org’s backend for magic link sign-in and user data.
- **Spaces & Sessions API:**
  - Endpoints to fetch space details, session schedules, and subscription statuses.
- **Notification Service:**
  - Backend system to handle email and push notifications.
- **LiveKit Integration:**
  - Configure and manage video sessions via LiveKit with appropriate quality and scalability settings.

#### Data Security & Privacy
- **Sensitive Data Handling:**
  - Ensure encryption and secure communication for video streams and personal data.
- **Compliance:**
  - Meet necessary data protection regulations (e.g., GDPR) given the sensitive nature of discussions.

### 6. Milestones & Timeline
#### Phase 1: Core Functionality
- Finalize detailed requirements and stakeholder sign-off.
- Implement user authentication (magic links) and profile management.
- Develop space discovery and basic session joining features.
- Integrate initial notification mechanisms (email and push).

#### Phase 2: Enhanced Features
- Integrate LiveKit for robust video sessions with moderator controls.
- Develop comprehensive routing and deep linking.
- Build the Keeper management flow and admin backend for activations.
- Prepare the groundwork for accessibility enhancements.

#### Phase 3: Testing & Launch
- Conduct cross-platform testing and QA.
- User acceptance testing with community feedback.
- Soft launch and iterate based on user and moderator (Keeper) feedback.
- Full public launch with monitoring of KPIs.

### 7. Success Metrics
- **User Engagement:**
  - Active users, frequency of session participation, and space subscriptions.
- **Notification Effectiveness:**
  - Open and click-through rates for email and push notifications.
- **Video Session Quality:**
  - Latency, drop rates, and user-reported video quality.
- **Feedback from Keepers and Admins:**
  - Usability and effectiveness of management tools.
- **Cross-Platform Performance:**
  - App stability, load times, and crash analytics.

### 8. Risks & Mitigation Strategies
- **Data Privacy Risks:**
  - Mitigation: Use strong encryption, secure APIs, and strict compliance measures.
- **Cross-Platform Consistency:**
  - Mitigation: Extensive testing on each platform with Flutter’s testing tools.
- **LiveKit Integration Issues:**
  - Mitigation: In-depth review of LiveKit documentation and performance testing before rollout.
