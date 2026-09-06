# Apprch

A household app for tap-triggered events. Create a Trigger, write its link to an NFC tag, and everyone in the household gets a push when it’s tapped.

---

## The problem

In a shared household, small tasks turn into “did anyone do it yet?” conversations. There’s no lightweight way to log that something happened and instantly let everyone else know.

## The solution

Anyone in the household can create a Trigger — a named event with its own icon, notification message, and history. Write the generated link to an NFC tag. Tap the tag → confirm → every other member gets a native push with that Trigger’s message.

---

## Architecture

```
apprch/
├── backend/       # Firebase: Cloud Functions, Firestore, Hosting
├── ios/           # Native iOS app — Swift + SwiftUI
└── android/       # Native Android app — Kotlin + Jetpack Compose
```

### Backend (Firebase)

- **Authentication** — email/password sign-in
- **Firestore** — groups, users, `triggers`, and `events`
- **Cloud Functions** — `createGroup`, `joinGroup`, `logEvent` (looks up the Trigger, writes an event, fans out FCM)
- **Hosting** — Universal Link / App Link verification at `https://apprch.web.app/t/{triggerId}`

### iOS

SwiftUI: sign in → create or join a household → home list of Triggers. Universal Links use `/t/{triggerId}` and open a confirm sheet.

### NFC flow

1. Create a Trigger in the app and copy `https://apprch.web.app/t/{triggerId}`
2. Write that URL to a physical tag (NFC Tools or similar)
3. Tapping the tag opens Apprch to a confirm screen
4. Confirm calls `logEvent` with `triggerId`
5. The Cloud Function writes `events/{eventId}` and notifies the household with the Trigger’s custom message

### Data model

```
groups/{groupId}        name, inviteCode, memberUids[]
users/{uid}             displayName, groupId, fcmTokens[]
triggers/{triggerId}    groupId, name, icon, notificationMessage, visualizationType, createdByUid, createdAt, lastTriggeredAt, lastTriggeredByUid, eventCount
events/{eventId}        groupId, triggerId, triggeredByUid, timestamp
```

Visualization types in v1: **Log** and **Counter**.

---

## Roadmap

- [x] Phase 1 — Firebase backend
- [x] Phase 2 — iOS Triggers
- [ ] Phase 3 — Android trigger redesign
- [ ] Phase 4 — NFC tag setup + end-to-end test
- [ ] Phase 5 — Calendar / streak / checklist visualizations + widgets

---

## Running locally

You’ll need Firebase config files (`GoogleService-Info.plist` and `google-services.json` are gitignored).

iOS: open `ios/Apprch.xcodeproj`, pick an iPhone simulator, press **⌘R**.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup.

Changes go through a PR into `staging`. `@momolabs2026` reviews and merges in GitHub — agents and collaborators do not merge.

---

## License

MIT
