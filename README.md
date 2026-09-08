# Apprch

A tap-to-log app for yourself or a group. Create a Trigger, write its link to an NFC tag, and check it off when you tap — as a private reminder, or as a shared log everyone in the group can see.

---

## The problem

In a shared household, small tasks turn into “did anyone do it yet?” conversations. There’s no lightweight way to log that something happened and instantly let everyone else know.

## The solution

Create a Trigger — a named event with its own icon, accent color, and history. Use it solo as a visual reminder, or invite a group so everyone sees the same check and heatmap.

---

## iOS MVP (ready for contributors)

This is the slice people can use and build on. It is not the finished product.

**You can already:**

- Sign in with email and password
- Keep a private **Solo** space and one or more **Groups**
- Create, edit, and move Triggers between spaces
- Check a Trigger for today (the circle resets each day)
- Write an NFC tag on iOS and tap it to log on iOS or Android
- See a GitHub-style heatmap plus a short history
- Pin a Trigger heatmap to the Home Screen as a widget
- Invite people by search or share code
- See group members as chips
- Edit your name, password, profile photo, and appearance

**Still open — good work for the repo:**

- Android NFC write
- Push when someone else logs (FCM tokens exist; fan-out is not reliable yet)
- Universal Links (`https://apprch.web.app/t/...`) — needs a paid Apple Developer account
- Leave a group / remove a member
- Calendar, streak, and checklist visualizations
- Tests

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and how PRs land. Contributions are welcome — fork, open a PR into `staging`, and `@momolabs2026` will review.

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
- **Firestore** — groups (spaces), users, triggers, and events
- **Hosting** — web fallback at `https://apprch.web.app`
- **Cloud Functions** — older create/join/log paths; iOS now writes groups and events from the client

### iOS

SwiftUI: sign in → Solo plus Groups → Trigger list. Tapping an NFC tag opens `apprch://open?id={triggerId}` and logs that Trigger. The heatmap widget extension reads a snapshot the app writes to the App Group `group.com.momo-labs.Apprch`.

### Android

Jetpack Compose mirrors the iOS spaces and Triggers. A Glance Home Screen widget shows the same heatmap; pin it from a Trigger’s detail page.

### NFC flow

1. Create a Trigger
2. Edit it and write the tag (or copy the link)
3. Tap the tag later — the app opens and logs
4. Home shows a filled circle for today; the detail page shows the heatmap
5. Open a Trigger and add its heatmap widget to keep it on the Home Screen

On a Personal Team debug build, iOS cannot claim Universal Links, so tags use the custom `apprch://` scheme.

### Data model

```
groups/{groupId}        name, solo, inviteCode?, memberUids[]
users/{uid}             displayName, photoBase64?, groupIds[], personalGroupId, activeGroupId
triggers/{triggerId}    groupId, name, icon, notificationMessage, visualizationType, accentColorHex?, eventCount, lastTriggeredAt
events/{eventId}        groupId, triggerId, triggeredByUid, timestamp
inviteCodes/{code}      groupId
```

Visualization types in v1: **Log** and **Counter**.

---

## Roadmap

- [x] Phase 1 — Firebase backend
- [x] Phase 2 — iOS Triggers, spaces, heatmap, profile
- [x] Phase 3 — Android trigger / space redesign
- [x] Phase 4 — NFC write / read in the iOS app
- [x] Phase 5 — Heatmap Home Screen widgets
- [ ] Phase 6 — Calendar / streak / checklist visualizations

---

## Running locally

You’ll need Firebase config files (`GoogleService-Info.plist` and `google-services.json` are gitignored).

iOS: open `ios/Apprch.xcodeproj`, pick an iPhone simulator, press **⌘R**.

Mac: in the same Xcode project, pick **My Mac (Designed for iPad)** and press **⌘R**. That runs this same iOS app in a Mac window. NFC tags and Home Screen widgets stay on iPhone.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup.

Changes go through a PR into `staging`. `@momolabs2026` reviews and merges in GitHub — agents and collaborators do not merge.

---

## License

MIT
