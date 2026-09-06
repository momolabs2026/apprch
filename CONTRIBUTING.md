# Contributing to Apprch

Thanks for your interest in contributing. Apprch is a household tap-to-notify app built with Firebase, SwiftUI, and Jetpack Compose.

## How to contribute

1. **Fork** the repo and create a branch from `main`
2. Make your changes
3. Open a **Pull Request** with a clear description of what you changed and why

## Project structure

```
apprch/
├── backend/       # Firebase Cloud Functions + Firestore rules
├── ios/           # SwiftUI app (`Apprch.xcodeproj`)
└── android/       # Jetpack Compose app
```

## Setup

### Backend

```bash
cd backend/functions
npm install
npm run build
```

Live hosting: `https://apprch.web.app`

Deploy after changing functions, rules, or hosting:

```bash
cd backend
firebase deploy --only functions,firestore,hosting
```

### iOS

- Open `ios/Apprch.xcodeproj`
- Bundle identifier: `com.momo-labs.Apprch`
- Add `GoogleService-Info.plist` from the Apprch Firebase project

### Android

- Package name: `com.apprch.app`
- Put `google-services.json` in `android/app/`
- Open `android/` in Android Studio and run on a Pixel emulator

> **Note:** `GoogleService-Info.plist` and `google-services.json` are gitignored.

## Code style

- iOS: standard Swift conventions, SwiftUI
- Android: standard Kotlin conventions, Jetpack Compose
- Backend: TypeScript strict mode
