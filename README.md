# exercise_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firestore Security Rules

This project ships with opinionated rules in `firestore.rules`:

- Authenticated users can read their own documents and subcollections.
- Only the document owner can create or update their personal data; admins can override.
- Admin-only documents live under the `admin` collection.
- Public, read-only documents live under `public`.

### Deploying Rules

```bash
firebase deploy --only firestore:rules
```

### Granting Admin Privileges

Set a custom claim (`role: "admin"`) for the desired user:

```bash
firebase auth:users:update <UID> --set-custom-claims '{"role":"admin"}'
```

After setting the claim, have the user refresh their ID token (sign out/in) so the new privileges apply.