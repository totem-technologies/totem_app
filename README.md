<div align="center">
<h1>Totem Client</h1>
<a href="https://github.com/totem-technologies/totem_app/actions/workflows/build.yaml"><img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/totem-technologies/totem_app/build.yaml?color=%2320A920"></a>
<a href="https://pub.dev/packages/flutter">
  <img alt="Flutter SDK" src="https://img.shields.io/badge/flutter-%3E%3D3.29-blue?logo=flutter&style=flat-square">
</a>
<a href="https://totem.org">
  <img alt="Website" src="https://img.shields.io/badge/visit-totem.org-orange?style=flat-square">
</a>
<p><em>Guided introspection groups at <a href="https://www.totem.org">totem.org</a></em></p>
</div>


## 🧭 Overview

Totem is a space for guided group introspection. This Flutter app is the **official open-source mobile client** for the Totem platform.  
It connects people through structured group sessions and authentic conversations, powered by a thoughtfully crafted UI and backend.

This client targets both **iOS** and **Android**, using **Flutter** and **Riverpod** for a fast, modern, and scalable development experience.

---

## 🚀 Features

- 📅 View and explore available Totem Circles
<!-- - 🔐 Secure authentication and onboarding -->
- 💬 Join guided group sessions (with in-app video coming soon!)
<!-- - 🧘 Personalized user profile and avatar -->
<!-- - 🔔 Push notification integration -->
<!-- - 🧪 CI/CD with GitHub Actions -->

---

## 🛠 Tech Stack

- **Flutter** 3.29+
- **Riverpod** for state management
- **json_serializable** + **Retrofit** for [typed API modeling](./swagger_parser.yaml)
- **GitHub Actions** for CI/CD

---

## 📦 Installation

Make sure you have [Flutter installed](https://docs.flutter.dev/get-started/install) and configured.

```bash
git clone https://github.com/totem-technologies/totem_app.git
cd totem_app
flutter pub get
```

### 📲 Running on Devices
For development:

```bash
flutter run -d chrome     # Web (temporary testing)
flutter run -d android    # Android
flutter run -d ios        # iOS
```

If testing on an iOS device, ensure you're using macOS and have Xcode installed.


### 🧪 Testing

Run all tests:

```bash
flutter test
```
_Coming soon: Widget tests and CI-integrated integration tests._

## ✍️ Project Structure

```
lib/
├── api/             # API clients & models (generated with Retrofit)
├── auth/            # Auth flow: login, profile setup, state
├── core/            # Config, theme, services, errors
├── features/        # Feature modules (spaces, profile, video_sessions, etc.)
├── navigation/      # Centralized routing and guards
├── shared/          # Reusable widgets
└── main.dart        # Entry point, app root
```

### 📐 Architecture

We follow a **feature-first modular structure**, powered by Riverpod for state management.
API communication is handled using Retrofit + json_serializable with code generation.

For example:

* Logic lives in `controllers/`
* API integration in `repositories/`
* UI in `screens/`
* State is exposed via Riverpod providers

## 👥 Community

Join the Totem movement at [totem.org](https://www.totem.org).
To discuss development or get involved, feel free to open an issue or pull request.


<div align="center"> ✨ Built with care by the Totem Technologies team ✨ </div>