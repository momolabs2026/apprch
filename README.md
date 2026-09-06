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
- Write an NFC tag and tap it to log
- See a GitHub-style heatmap plus a short history
- Invite people with a group code
- See group members as chips
- Edit your name, password, and profile photo

**Still open — good work for the repo:**

- Android trigger / space UI to match iOS
- Push when someone else logs (FCM tokens exist; fan-out is not reliable yet)
- Universal Links (`https://apprch.web.app/t/...`) — needs a paid Apple Developer account
- Leave a group / remove a member
- Widgets, streaks, and extra visualizations
- Tests

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and how PRs land.

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

SwiftUI: sign in → Solo plus Groups → Trigger list. Tapping an NFC tag opens `apprch://open?id={triggerId}` and logs that Trigger.

### NFC flow

1. Create a Trigger
2. Edit it and write the tag (or copy the link)
3. Tap the tag later — the app opens and logs
4. Home shows a filled circle for today; the detail page shows the heatmap

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
- [ ] Phase 3 — Android trigger / space redesign
- [x] Phase 4 — NFC write / read in the iOS app
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
