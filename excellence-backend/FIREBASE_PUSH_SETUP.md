# Firebase Push Setup (Backend)

Push notifications require Firebase Admin credentials on the backend.

## One-time setup

1. In Firebase Console, create/download a service-account JSON key for project `excellence-academy-9154a`.
2. Save it as:
   - `excellence-backend/firebase-admin-service-account.json`
3. Ensure backend `.env` has:
   - `FIREBASE_ADMIN_DISABLED=false`
   - `FIREBASE_PROJECT_ID=excellence-academy-9154a`

## Verify

From `excellence-backend/`:

```bash
npm run build
node -e "require('dotenv').config(); const mod=require('./dist/config/firebase-admin'); mod.initializeFirebaseAdmin(); console.log('firebaseMessagingAvailable=' + Boolean(mod.firebaseMessaging()));"
```

Expected:

- `firebaseMessagingAvailable=true`
- startup log includes: `Firebase Admin initialized (...)`

If false, verify the service-account file content and path.

