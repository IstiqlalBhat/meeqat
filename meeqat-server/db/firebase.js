const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

const bucketName = process.env.FIREBASE_STORAGE_BUCKET;

if (!bucketName) {
  console.error('Missing FIREBASE_STORAGE_BUCKET environment variable.');
  process.exit(1);
}

// Load service account: prefer JSON file, fall back to env var
let serviceAccount;
const jsonFilePath = path.join(__dirname, '..', 'firebase-admin-sdk.json');

if (fs.existsSync(jsonFilePath)) {
  serviceAccount = JSON.parse(fs.readFileSync(jsonFilePath, 'utf8'));
} else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
} else {
  console.error('Missing Firebase credentials. Provide firebase-admin-sdk.json or FIREBASE_SERVICE_ACCOUNT_JSON env var.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: bucketName,
  });
}

// Use @google-cloud/storage directly with explicit credentials
// so that generateSignedUrl() has access to the private key for signing.
// admin.storage().bucket() doesn't always propagate credentials properly
// on serverless platforms (Vercel), causing signed URL generation to fail.
const storage = new Storage({
  credentials: serviceAccount,
  projectId: serviceAccount.project_id,
});
const bucket = storage.bucket(bucketName);
const auth = admin.auth();

// Set CORS on the bucket so browsers can PUT files directly
(async () => {
  try {
    await bucket.setCorsConfiguration([{
      origin: ['*'],
      method: ['GET', 'PUT', 'OPTIONS'],
      responseHeader: ['Content-Type', 'Content-Length'],
      maxAgeSeconds: 3600
    }]);
  } catch (err) {
    // Non-fatal — CORS may already be set, or permissions may be limited
    console.warn('Could not set bucket CORS (may already be configured):', err.message);
  }
})();

module.exports = { bucket, auth };
