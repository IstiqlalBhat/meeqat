const { supabase } = require('../db/supabase');

// Requires a valid Firebase UID in the session
function requireAuth(req, res, next) {
  if (req.session && req.session.firebase_uid) {
    return next();
  }
  res.redirect('/admin/login');
}

// Pre-loads the admin's masjid onto req.masjid (null if none yet)
async function loadMasjid(req, res, next) {
  if (!req.session || !req.session.firebase_uid) {
    return next();
  }

  try {
    const { data: masjid } = await supabase
      .from('masjids')
      .select('*')
      .eq('firebase_uid', req.session.firebase_uid)
      .maybeSingle();

    req.masjid = masjid || null;
  } catch (err) {
    console.error('loadMasjid error:', err.message);
    req.masjid = null;
  }

  // Make masjid and admin email available to all views
  res.locals.masjid = req.masjid;
  res.locals.adminEmail = req.session.admin_email || null;
  next();
}

// Guard: requires that the admin already has a masjid
function requireMasjid(req, res, next) {
  if (req.masjid) {
    return next();
  }
  res.redirect('/admin');
}

module.exports = { requireAuth, loadMasjid, requireMasjid };
