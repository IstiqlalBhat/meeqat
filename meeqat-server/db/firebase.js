const admin = require('firebase-admin');
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

const bucket = admin.storage().bucket();
const auth = admin.auth();

// Get an OAuth2 access token for direct Firebase Storage REST API uploads.
// This avoids generateSignedUrl() which fails on Vercel due to private key issues.
async function getAccessToken() {
  const credential = admin.app().options.credential;
  const tokenResult = await credential.getAccessToken();
  return tokenResult.access_token;
}

module.exports = { bucket, auth, bucketName, getAccessToken };
