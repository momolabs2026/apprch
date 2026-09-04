# Fresh Scoop 🐱

A family app that sends everyone a push notification when Momo's litter box gets cleaned. Tap an NFC tag → the app opens → confirm → your whole family's phones buzz.

Built to grow: the litter box feature is just the first event type. The same architecture supports any family notification (chores, reminders, shared calendar events) without re-architecting anything.

---

## The problem

In a shared household, small tasks like cleaning a litter box turn into "did anyone do it yet?" conversations throughout the day. There's no lightweight, frictionless way to log that something happened and instantly let everyone else know — without opening a chat app, typing a message, and hoping people see it.

## The solution

A physical NFC tag lives next to Momo's litter box. Tap it with your phone → a confirmation screen appears → tap Send → every family member with the app installed gets a native push notification in seconds. No typing, no group chats, no wondering.

---

## Architecture

```
fresh-scoop/
├── backend/       # Firebase: Cloud Functions, Firestore, Hosting
├── ios/           # Native iOS app — Swift + SwiftUI
└── android/       # Native Android app — Kotlin + Jetpack Compose
```

### Backend (Firebase)
- **Authentication** — email/password sign-in
- **Firestore** — families, users, and events collections
- **Cloud Functions** — `createFamily`, `joinFamily`, `logEvent` (fans out FCM push notifications)
- **Hosting** — serves Universal Link (`apple-app-site-association`) and App Link (`assetlinks.json`) verification files

### iOS
SwiftUI app with a state machine: sign in → create or join a family → home screen showing the event feed. Universal Links handle the NFC tap and open a confirmation sheet.

### Android
Jetpack Compose app, feature-identical to iOS. App Links handle the NFC tap and show a confirmation dialog.

### NFC flow
1. NFC tag is written with `https://fresh-scoop.web.app/trigger/litter-cleaned`
2. Tapping the tag on any phone opens the app directly (no browser)
3. User confirms → app calls `logEvent` Cloud Function
4. Cloud Function writes to Firestore and sends FCM push to all family members

### Data model
```
families/{familyId}     name, inviteCode, memberUids[]
users/{uid}             displayName, familyId, fcmTokens[]
events/{eventId}        familyId, type, triggeredByUid, timestamp
```

---

## Roadmap

- [x] Phase 1 — Firebase backend (Auth, Firestore, Functions, Hosting)
- [x] Phase 2 — iOS MVP
- [x] Phase 3 — Android MVP
- [ ] Phase 4 — NFC tag setup + end-to-end test
- [ ] Phase 5 — Shared family calendar + home screen widget (WidgetKit / Glance)
- [ ] Phase 6 — Multiple event types (chores, reminders, custom tags)

---

## Tech stack

| Layer | Technology |
|---|---|
| Backend | Firebase (Auth, Firestore, Cloud Functions, FCM, Hosting) |
| iOS | Swift, SwiftUI, Firebase iOS SDK |
| Android | Kotlin, Jetpack Compose, Firebase Android SDK |
| NFC | URL-based (no on-device scanning code needed) |

---

## Running locally

You'll need your own Firebase project to run this app (the `GoogleService-Info.plist` and `google-services.json` config files are gitignored for security).

See [CONTRIBUTING.md](CONTRIBUTING.md) for full setup instructions.

---

## Contributing

Fresh Scoop is open source and contributions are welcome — bug fixes, new event types, UI improvements, or anything on the roadmap.

1. Fork the repo
2. Create a branch from `main`
3. Open a pull request with a clear description

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed setup and guidelines.

---

## License

MIT
