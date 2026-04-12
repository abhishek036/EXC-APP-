# Excellence Production Setup (Android + Web)

This app is now wired for real Firebase-backed auth/profile flows.

## 1) Firebase project setup

- Create one Firebase project (Production)
- Enable Authentication:
  - Email/Password
  - Phone (optional, if using SMS OTP)
- Create Firestore database (production mode)
- Add Android app package: `excellence.academy`
- Add Web app and copy Firebase config values

## 2) Android app (downloaded APK)

- Ensure `android/app/google-services.json` is from your Firebase project
- Build:
  - `flutter pub get`
  - `flutter build apk --release`

## 3) Web app (browser)

Web needs Firebase options passed via dart-define. Run with:

`flutter run -d chrome --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_AUTH_DOMAIN=... --dart-define=FIREBASE_STORAGE_BUCKET=... --dart-define=FIREBASE_MEASUREMENT_ID=...`

Build web for hosting:

`flutter build web --release --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... --dart-define=FIREBASE_AUTH_DOMAIN=... --dart-define=FIREBASE_STORAGE_BUCKET=... --dart-define=FIREBASE_MEASUREMENT_ID=...`

## 4) Firestore data model used by auth

Collection: `users`
Document ID: Firebase Auth UID
Fields:
- `name` (string)
- `username` (string, lowercased)
- `phone` (string)
- `email` (string)
- `role` (admin/teacher/student/parent)
- `isActive` (bool)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 5) Critical production notes

- Current register/login uses Firebase Email/Password under the hood with username mapping.
- Forgot password sends reset link to registered email mapping.
- If you require phone-only reset or WhatsApp OTP reset, add backend API/Cloud Functions.
- For true production security, do not trust role from client UI; enforce role checks in Firestore rules and backend APIs.

## 6) Minimum Firestore rules (starter)

Use strict rules and test carefully before release:

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 7) Release checklist

- [ ] Firebase Android + Web both configured
- [ ] Web launched with all dart-define Firebase vars
- [ ] Register/Login/Forgot password tested on Android and Web
- [ ] Firestore rules hardened
- [ ] Crashlytics enabled and tested
- [ ] WhatsApp integrations moved to backend before launch

