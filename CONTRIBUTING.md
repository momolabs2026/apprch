# Contributing to Fresh Scoop

Thanks for your interest in contributing! Fresh Scoop is a family app built with Firebase, SwiftUI, and Jetpack Compose. All contributions are welcome — bug fixes, new features, and improvements.

## How to contribute

1. **Fork** the repo and create a branch from `main`
2. Make your changes
3. Open a **Pull Request** with a clear description of what you changed and why
4. I'll review it and merge if it looks good

## What to work on

Check the [Issues](https://github.com/momolabs2026/fresh-scoop/issues) tab for open tasks. Feel free to open a new issue to propose a feature or report a bug before writing code.

## Project structure

```
fresh-scoop/
├── backend/       # Firebase Cloud Functions + Firestore rules
├── ios/           # SwiftUI app
└── android/       # Jetpack Compose app
```

## Setup

### Backend
```bash
cd backend/functions
npm install
npm run build
```

### iOS
- Open the Xcode project in `ios/`
- Add your own `GoogleService-Info.plist` (download from Firebase console)
- Add Firebase SDK via Swift Package Manager

### Android
- Open `android/` in Android Studio
- Add your own `google-services.json` (download from Firebase console)

> **Note:** `GoogleService-Info.plist` and `google-services.json` are gitignored — you need your own Firebase project to run the app locally.

## Code style

- iOS: standard Swift conventions, SwiftUI
- Android: standard Kotlin conventions, Jetpack Compose
- Backend: TypeScript strict mode

## Questions?

Open an issue or reach out on Instagram.
