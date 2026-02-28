const admin = require('firebase-admin');

const bucketName = process.env.FIREBASE_STORAGE_BUCKET;
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

if (!bucketName || !serviceAccountJson) {
  console.error('Missing FIREBASE_STORAGE_BUCKET or FIREBASE_SERVICE_ACCOUNT_JSON environment variables.');
  console.error('Set FIREBASE_STORAGE_BUCKET to your bucket name (e.g., your-project.appspot.com)');
  console.error('Set FIREBASE_SERVICE_ACCOUNT_JSON to the stringified service account JSON key.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
    storageBucket: bucketName,
  });
}

const bucket = admin.storage().bucket();

module.exports = { bucket };
