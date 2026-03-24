import admin from 'firebase-admin';

let initialized = false;

function getServiceAccount(): admin.ServiceAccount | null {
  const rawJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (rawJson && rawJson.trim().length > 0) {
    try {
      const parsed = JSON.parse(rawJson) as admin.ServiceAccount;
      return parsed;
    } catch (error) {
      console.error('❌ Invalid FIREBASE_SERVICE_ACCOUNT_JSON', error);
      return null;
    }
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    return {
      projectId,
      clientEmail,
      privateKey,
    } as admin.ServiceAccount;
  }

  return null;
}

export const initializeFirebaseAdmin = () => {
  if (initialized || admin.apps.length > 0) {
    initialized = true;
    return;
  }

  const serviceAccount = getServiceAccount();
  if (!serviceAccount) {
    console.warn('⚠️ Firebase Admin not initialized: missing service account environment variables');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialized = true;
  console.log('✅ Firebase Admin initialized');
};

export const firebaseMessaging = () => {
  if (!initialized && admin.apps.length === 0) {
    initializeFirebaseAdmin();
  }

  if (admin.apps.length === 0) {
    return null;
  }

  return admin.messaging();
};
