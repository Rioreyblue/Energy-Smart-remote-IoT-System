# Local Chat Alerts with Awesome Notifications
1. dependency-review — Removed OneSignal/FCM chat dependencies (pubspec, Android/iOS manifests).
2. notification-service — Refactored `NotificationService` to manage local Awesome Notifications (foreground/background friendly) and expose helpers for chat badges.
3. chat-service — On new messages, `ChatService` now triggers the local chat notification helper after the initial sync.
4. background-monitor — Added a Workmanager-based chat monitor task that polls for unread messages and raises local alerts while the app is backgrounded or quit.
5. cleanup-cloud — Simplified `functions/index.js` chat trigger to just log inserts (no remote push plumbing).
6. verify — Analyzer clean for modified files; full project still has existing warning noise in debug examples.

### To-dos

- [x] Remove OneSignal packages/config from Flutter and native projects.
- [x] Refactor NotificationService/ChatNotificationService to rely on Awesome Notifications for local alerts.
- [x] Add background Workmanager task to poll chats and generate local notifications.
- [x] Update Cloud Functions to remove chat push logic (local handling only).
- [x] Document/testing: chat alerts now surface locally; deployment no longer depends on Firebase billing for pushes.
