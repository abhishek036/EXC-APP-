import admin from 'firebase-admin';
import fs from 'fs';

let initialized = false;

const JSON_ENV_CANDIDATES = [
  'FIREBASE_SERVICE_ACCOUNT_JSON',
  'FIREBASE_ADMIN_SDK_JSON',
  'FIREBASE_SERVICE_ACCOUNT',
] as const;

const BASE64_ENV_CANDIDATES = [
  'FIREBASE_SERVICE_ACCOUNT_BASE64',
  'FIREBASE_ADMIN_SDK_BASE64',
  'FIREBASE_SERVICE_ACCOUNT_B64',
] as const;

const FILE_ENV_CANDIDATES = [
  'GOOGLE_APPLICATION_CREDENTIALS',
  'FIREBASE_SERVICE_ACCOUNT_FILE',
] as const;

function normalizePrivateKey(key?: string): string | undefined {
  if (!key) return undefined;
  const trimmed = key.trim();
  const unquoted =
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
      ? trimmed.slice(1, -1)
      : trimmed;
  return unquoted.replace(/\\n/g, '\n');
}

function tryParseServiceAccount(raw: string): admin.ServiceAccount | null {
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;

    const projectId =
      (parsed.projectId as string | undefined)?.trim() ||
      (parsed.project_id as string | undefined)?.trim();
    const clientEmail =
      (parsed.clientEmail as string | undefined)?.trim() ||
      (parsed.client_email as string | undefined)?.trim();
    const privateKeyRaw =
      (parsed.privateKey as string | undefined) ||
      (parsed.private_key as string | undefined);
    const privateKey = normalizePrivateKey(privateKeyRaw);

    if (!projectId || !clientEmail || !privateKey) {
      return null;
    }

    return {
      projectId,
      clientEmail,
      privateKey,
    } as admin.ServiceAccount;
  } catch {
    return null;
  }
}

function getServiceAccount(): admin.ServiceAccount | null {
  for (const key of JSON_ENV_CANDIDATES) {
    const raw = process.env[key];
    if (!raw || raw.trim().length === 0) continue;
    const parsed = tryParseServiceAccount(raw);
    if (parsed) return parsed;
    console.error(`❌ Invalid ${key} (must be service-account JSON with projectId/clientEmail/privateKey)`);
  }

  for (const key of BASE64_ENV_CANDIDATES) {
    const raw = process.env[key];
    if (!raw || raw.trim().length === 0) continue;
    try {
      const decoded = Buffer.from(raw, 'base64').toString('utf8');
      const parsed = tryParseServiceAccount(decoded);
      if (parsed) return parsed;
      console.error(`❌ Invalid ${key} (base64 decoded value is not a valid service-account JSON)`);
    } catch (error) {
      console.error(`❌ Failed to decode ${key}`, error);
    }
  }

  for (const key of FILE_ENV_CANDIDATES) {
    const filePath = process.env[key];
    if (!filePath || filePath.trim().length === 0) continue;
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const parsed = tryParseServiceAccount(content);
      if (parsed) return parsed;
      console.error(`❌ Invalid Firebase service-account file from ${key}: ${filePath}`);
    } catch (error) {
      console.error(`❌ Failed to read Firebase service-account file from ${key}: ${filePath}`, error);
    }
  }

  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL || process.env.GCP_CLIENT_EMAIL;
  const privateKey =
    normalizePrivateKey(process.env.FIREBASE_PRIVATE_KEY) ||
    normalizePrivateKey(process.env.GCP_PRIVATE_KEY) ||
    (() => {
      const b64 = process.env.FIREBASE_PRIVATE_KEY_BASE64 || process.env.GCP_PRIVATE_KEY_BASE64;
      if (!b64) return undefined;
      try {
        return normalizePrivateKey(Buffer.from(b64, 'base64').toString('utf8'));
      } catch {
        return undefined;
      }
    })();

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
    console.warn('⚠️ Firebase Admin not initialized: missing/invalid service account configuration');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  initialized = true;
  console.log(`✅ Firebase Admin initialized (${serviceAccount.projectId || 'unknown-project'})`);
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
