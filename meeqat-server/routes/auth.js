const express = require('express');
const { auth } = require('../db/firebase');

const router = express.Router();

router.get('/login', (req, res) => {
  if (req.session && req.session.firebase_uid) {
    return res.redirect('/admin');
  }
  res.render('login', {
    error: null,
    firebaseApiKey: process.env.FIREBASE_WEB_API_KEY || '',
    firebaseAuthDomain: process.env.FIREBASE_AUTH_DOMAIN || ''
  });
});

router.post('/login', async (req, res) => {
  const { idToken } = req.body;

  if (!idToken) {
    return res.status(400).json({ error: 'Missing ID token' });
  }

  try {
    const decoded = await auth.verifyIdToken(idToken);
    req.session.firebase_uid = decoded.uid;
    req.session.admin_email = decoded.email || null;
    return res.json({ ok: true });
  } catch (err) {
    console.error('Firebase token verification error:', err.message);
    return res.status(401).json({ error: 'Invalid credentials' });
  }
});

router.get('/logout', (req, res) => {
  req.session = null;
  res.redirect('/admin/login');
});

module.exports = router;
