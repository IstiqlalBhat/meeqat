const express = require('express');
const fetch = require('node-fetch');
const multer = require('multer');
const path = require('path');
const { supabase } = require('../db/supabase');
const { bucket, bucketName, getAccessToken } = require('../db/firebase');
const { requireAuth, loadMasjid, requireMasjid } = require('../middleware/auth');
const { calculateIqamahFromRule } = require('../utils/iqamah');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 4 * 1024 * 1024 } });

router.use(requireAuth);
router.use(loadMasjid);

// ─── Dashboard ───────────────────────────────────────────────

router.get('/', async (req, res) => {
  // No masjid yet -> show setup wizard
  if (!req.masjid) {
    return res.render('setup-wizard', { error: null });
  }

  try {
    const m = req.masjid;

    const { count: overrideCount } = await supabase
      .from('prayer_overrides')
      .select('*', { count: 'exact', head: true })
      .eq('masjid_id', m.id);

    const { count: announcementCount } = await supabase
      .from('announcements')
      .select('*', { count: 'exact', head: true })
      .eq('masjid_id', m.id)
      .eq('active', 1);

    const { data: jumuah } = await supabase
      .from('jumuah_times')
      .select('id')
      .eq('masjid_id', m.id)
      .limit(1)
      .maybeSingle();

    // Count images for this masjid
    let imageCount = 0;
    try {
      const [files] = await bucket.getFiles({ prefix: `${m.id}/` });
      imageCount = files.filter(f => !f.name.endsWith('/')).length;
    } catch (err) {
      console.error('Image count error:', err.message);
    }

    // Recent announcements for dashboard
    const { data: recentAnnouncements } = await supabase
      .from('announcements')
      .select('*')
      .eq('masjid_id', m.id)
      .order('created_at', { ascending: false })
      .limit(5);

    res.render('dashboard', {
      masjid: m,
      stats: {
        overrideCount: overrideCount || 0,
        announcementCount: announcementCount || 0,
        hasJumuah: !!jumuah,
        imageCount
      },
      recentAnnouncements: recentAnnouncements || []
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.render('dashboard', {
      masjid: req.masjid,
      stats: { overrideCount: 0, announcementCount: 0, hasJumuah: false, imageCount: 0 },
      recentAnnouncements: []
    });
  }
});

// ─── Setup Wizard (first-time masjid creation) ──────────────

router.post('/setup', upload.single('image'), async (req, res) => {
  if (req.masjid) {
    return res.redirect('/admin');
  }

  const { name, address, city, state, country, latitude, longitude, calculation_method } = req.body;

  if (!name || !name.trim()) {
    return res.render('setup-wizard', { error: 'Masjid name is required' });
  }

  try {
    const insertData = {
      name: name.trim(),
      address: address || null,
      city: city || 'Clemson',
      state: state || 'South Carolina',
      country: country || 'US',
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      calculation_method: calculation_method ? parseInt(calculation_method) : 2,
      firebase_uid: req.session.firebase_uid
    };

    const { data: newMasjid, error } = await supabase
      .from('masjids')
      .insert(insertData)
      .select('id')
      .single();

    if (error) throw error;

    // Save profile image URL (from direct upload) or fallback to file upload
    if (req.body.image_url && newMasjid) {
      await supabase.from('masjids').update({ image_url: req.body.image_url }).eq('id', newMasjid.id);
    } else if (req.file && newMasjid) {
      const imageUrl = await uploadImage(req.file, newMasjid.id, 'profile');
      if (imageUrl) {
        await supabase.from('masjids').update({ image_url: imageUrl }).eq('id', newMasjid.id);
      }
    }

    req.session.flash = { type: 'success', message: 'Masjid created! Welcome to Meeqat.' };
    res.redirect('/admin');
  } catch (err) {
    console.error('Setup error:', err);
    res.render('setup-wizard', { error: err.message });
  }
});

// ─── Masjid Edit ─────────────────────────────────────────────

router.get('/edit', requireMasjid, (req, res) => {
  res.render('masjid-form', { masjid: req.masjid, error: null });
});

router.post('/edit', requireMasjid, upload.single('image'), async (req, res) => {
  const { name, address, city, state, country, latitude, longitude, calculation_method } = req.body;

  if (!name || !name.trim()) {
    return res.render('masjid-form', { masjid: { ...req.body, id: req.masjid.id }, error: 'Name is required' });
  }

  try {
    const updateData = {
      name: name.trim(),
      address: address || null,
      city: city || 'Clemson',
      state: state || 'South Carolina',
      country: country || 'US',
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      calculation_method: calculation_method ? parseInt(calculation_method) : 2,
      updated_at: new Date().toISOString()
    };

    if (req.body.image_url) {
      updateData.image_url = req.body.image_url;
    } else if (req.file) {
      updateData.image_url = await uploadImage(req.file, req.masjid.id, 'profile');
    }

    await supabase.from('masjids').update(updateData).eq('id', req.masjid.id);

    req.session.flash = { type: 'success', message: 'Masjid updated successfully' };
    res.redirect('/admin');
  } catch (err) {
    res.render('masjid-form', { masjid: { ...req.body, id: req.masjid.id }, error: err.message });
  }
});

// ─── Timings ─────────────────────────────────────────────────

router.get('/timings', requireMasjid, async (req, res) => {
  const masjid = req.masjid;
  const date = req.query.date || new Date().toISOString().split('T')[0];
  const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'sunset', 'maghrib', 'isha'];

  const lat = masjid.latitude || 34.6834;
  const lng = masjid.longitude || -82.8374;
  let apiTimes = {};

  try {
    const [year, month, day] = date.split('-');
    const url = `https://api.aladhan.com/v1/timings/${day}-${month}-${year}?latitude=${lat}&longitude=${lng}&method=${masjid.calculation_method}`;
    const response = await fetch(url);
    const data = await response.json();
    if (data.code === 200) {
      const t = data.data.timings;
      apiTimes = {
        fajr: t.Fajr, sunrise: t.Sunrise, dhuhr: t.Dhuhr,
        asr: t.Asr, sunset: t.Sunset, maghrib: t.Maghrib, isha: t.Isha
      };
    }
  } catch (err) {
    console.error('API fetch error:', err.message);
  }

  const { data: dateOverrides } = await supabase
    .from('prayer_overrides')
    .select('prayer, athan_time, iqamah_time')
    .eq('masjid_id', masjid.id)
    .eq('date', date);

  const { data: permanentOverrides } = await supabase
    .from('prayer_overrides')
    .select('prayer, athan_time, iqamah_time')
    .eq('masjid_id', masjid.id)
    .is('date', null);

  const overrideMap = {};
  for (const o of (permanentOverrides || [])) overrideMap[o.prayer] = { ...o, type: 'permanent' };
  for (const o of (dateOverrides || [])) overrideMap[o.prayer] = { ...o, type: 'date' };

  res.render('timings', { masjid, date, prayers, apiTimes, overrideMap });
});

router.post('/timings', requireMasjid, async (req, res) => {
  const { date, override_type } = req.body;
  const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'sunset', 'maghrib', 'isha'];
  const dateValue = override_type === 'permanent' ? null : (date || null);
  const masjidId = req.masjid.id;

  try {
    for (const prayer of prayers) {
      const athan = req.body[`athan_${prayer}`] || null;
      const iqamah = req.body[`iqamah_${prayer}`] || null;
      const useApi = req.body[`useapi_${prayer}`];

      if (useApi) {
        await supabase
          .from('prayer_overrides')
          .delete()
          .eq('masjid_id', masjidId)
          .eq('prayer', prayer);
      } else if (athan || iqamah) {
        if (dateValue === null) {
          await supabase
            .from('prayer_overrides')
            .delete()
            .eq('masjid_id', masjidId)
            .is('date', null)
            .eq('prayer', prayer);
        } else {
          await supabase
            .from('prayer_overrides')
            .delete()
            .eq('masjid_id', masjidId)
            .eq('date', dateValue)
            .eq('prayer', prayer);
        }

        await supabase.from('prayer_overrides').insert({
          masjid_id: masjidId,
          date: dateValue,
          prayer,
          athan_time: athan,
          iqamah_time: iqamah
        });
      }
    }

    req.session.flash = { type: 'success', message: 'Prayer times saved successfully' };
  } catch (err) {
    console.error('Save timings error:', err);
    req.session.flash = { type: 'error', message: 'Failed to save prayer times' };
  }

  res.redirect(`/admin/timings?date=${date || new Date().toISOString().split('T')[0]}`);
});

// ─── Monthly Timings Grid ─────────────────────────────────────

router.get('/monthly-timings', requireMasjid, async (req, res) => {
  const masjid = req.masjid;
  const now = new Date();
  const month = parseInt(req.query.month) || (now.getMonth() + 1);
  const year = parseInt(req.query.year) || now.getFullYear();
  const daysInMonth = new Date(year, month, 0).getDate();
  const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  const lat = masjid.latitude || 34.6834;
  const lng = masjid.longitude || -82.8374;

  // Fetch full month of API times in one call
  let apiMonth = {}; // { "2026-03-01": { fajr: "05:30", ... }, ... }
  try {
    const url = `https://api.aladhan.com/v1/calendar/${year}/${month}?latitude=${lat}&longitude=${lng}&method=${masjid.calculation_method}`;
    const response = await fetch(url);
    const data = await response.json();
    if (data.code === 200 && data.data) {
      for (const dayData of data.data) {
        const t = dayData.timings;
        const dateStr = dayData.date.gregorian.date; // "DD-MM-YYYY"
        const [dd, mm, yyyy] = dateStr.split('-');
        const isoDate = `${yyyy}-${mm}-${dd}`;
        apiMonth[isoDate] = {
          fajr: (t.Fajr || '').replace(/ \(.*\)/, ''),
          sunrise: (t.Sunrise || '').replace(/ \(.*\)/, ''),
          dhuhr: (t.Dhuhr || '').replace(/ \(.*\)/, ''),
          asr: (t.Asr || '').replace(/ \(.*\)/, ''),
          sunset: (t.Sunset || '').replace(/ \(.*\)/, ''),
          maghrib: (t.Maghrib || '').replace(/ \(.*\)/, ''),
          isha: (t.Isha || '').replace(/ \(.*\)/, '')
        };
      }
    }
  } catch (err) {
    console.error('Monthly API fetch error:', err.message);
  }

  // Fetch all date-specific overrides for this month range
  const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
  const endDate = `${year}-${String(month).padStart(2, '0')}-${String(daysInMonth).padStart(2, '0')}`;

  const { data: dateOverrides } = await supabase
    .from('prayer_overrides')
    .select('date, prayer, athan_time, iqamah_time')
    .eq('masjid_id', masjid.id)
    .gte('date', startDate)
    .lte('date', endDate);

  // Fetch permanent overrides (date IS NULL)
  const { data: permanentOverrides } = await supabase
    .from('prayer_overrides')
    .select('prayer, athan_time, iqamah_time')
    .eq('masjid_id', masjid.id)
    .is('date', null);

  // Build overrideMap[date][prayer] = { athan_time, iqamah_time }
  const overrideMap = {};
  for (const o of (dateOverrides || [])) {
    if (!overrideMap[o.date]) overrideMap[o.date] = {};
    overrideMap[o.date][o.prayer] = { athan_time: o.athan_time, iqamah_time: o.iqamah_time };
  }

  // Build permanentMap[prayer] = { athan_time, iqamah_time }
  const permanentMap = {};
  for (const o of (permanentOverrides || [])) {
    permanentMap[o.prayer] = { athan_time: o.athan_time, iqamah_time: o.iqamah_time };
  }

  // Fetch iqamah rules and compute rule-based iqamah for each day/prayer
  const { data: iqamahRules } = await supabase
    .from('iqamah_rules')
    .select('prayer, rule_type, value, reference_prayer')
    .eq('masjid_id', masjid.id);

  const ruleMap = {};
  for (const r of (iqamahRules || [])) ruleMap[r.prayer] = r;

  // ruleIqamahMap[date][prayer] = computed iqamah time (or null)
  const ruleIqamahMap = {};
  for (let d = 1; d <= daysInMonth; d++) {
    const dateStr = year + '-' + String(month).padStart(2, '0') + '-' + String(d).padStart(2, '0');
    const dayApi = apiMonth[dateStr] || {};
    ruleIqamahMap[dateStr] = {};
    for (const prayer of prayers) {
      ruleIqamahMap[dateStr][prayer] = calculateIqamahFromRule(ruleMap[prayer], dayApi, prayer);
    }
  }

  res.render('monthly-timings', { masjid, month, year, daysInMonth, prayers, apiMonth, overrideMap, permanentMap, ruleIqamahMap });
});

router.post('/monthly-timings', requireMasjid, express.json(), async (req, res) => {
  const { changes } = req.body;
  const masjidId = req.masjid.id;

  if (!Array.isArray(changes) || changes.length === 0) {
    return res.json({ ok: false, message: 'No changes provided' });
  }

  try {
    let saved = 0;
    for (const change of changes) {
      const { date, prayer, athan_time, iqamah_time } = change;
      if (!date || !prayer) continue;

      // Delete existing override for this date+prayer
      await supabase
        .from('prayer_overrides')
        .delete()
        .eq('masjid_id', masjidId)
        .eq('date', date)
        .eq('prayer', prayer);

      // If both are empty, just delete (revert to API)
      const athan = athan_time || null;
      const iqamah = iqamah_time || null;
      if (athan || iqamah) {
        await supabase.from('prayer_overrides').insert({
          masjid_id: masjidId,
          date,
          prayer,
          athan_time: athan,
          iqamah_time: iqamah
        });
      }
      saved++;
    }

    res.json({ ok: true, message: `Saved ${saved} changes` });
  } catch (err) {
    console.error('Monthly timings save error:', err);
    res.status(500).json({ ok: false, message: 'Failed to save changes' });
  }
});

// ─── Direct Upload (signed URL) ──────────────────────────────

router.post('/get-upload-url', requireMasjid, express.json(), async (req, res) => {
  const { filename, contentType, category } = req.body;
  if (!filename || !contentType) {
    return res.status(400).json({ error: 'Missing filename or contentType' });
  }

  const masjidId = req.masjid.id;
  const ext = path.extname(filename) || '.jpg';

  let filePath;
  if (category === 'profile') {
    filePath = `${masjidId}/profile${ext}`;
    // Clean up old profile images
    try {
      const [files] = await bucket.getFiles({ prefix: `${masjidId}/profile` });
      for (const f of files) {
        if (f.name.startsWith(`${masjidId}/profile`)) {
          await f.delete().catch(() => {});
        }
      }
    } catch (err) { /* ignore cleanup errors */ }
  } else {
    filePath = `${masjidId}/announcements/${Date.now()}${ext}`;
  }

  try {
    // Get an OAuth2 access token for direct Firebase Storage REST API upload.
    // This avoids generateSignedUrl() which fails on Vercel.
    const accessToken = await getAccessToken();
    res.json({ accessToken, filePath, bucket: bucketName, contentType });
  } catch (err) {
    console.error('Access token error:', err);
    res.status(500).json({ error: 'Failed to generate upload credentials' });
  }
});

// After the browser finishes uploading, make the file publicly accessible
router.post('/finalize-upload', requireMasjid, express.json(), async (req, res) => {
  const { filePath } = req.body;
  if (!filePath) {
    return res.status(400).json({ error: 'Missing filePath' });
  }

  // Security: ensure the file belongs to this admin's masjid
  if (!filePath.startsWith(`${req.masjid.id}/`)) {
    return res.status(403).json({ error: 'Unauthorized file path' });
  }

  try {
    const file = bucket.file(filePath);

    // Try makePublic first; fall back to signed URL for uniform-access buckets
    try {
      await file.makePublic();
      return res.json({ url: getFirebasePublicUrl(filePath) });
    } catch (publicErr) {
      const [signedUrl] = await file.getSignedUrl({
        action: 'read',
        expires: '03-01-2030',
      });
      return res.json({ url: signedUrl });
    }
  } catch (err) {
    console.error('Finalize upload error:', err);
    res.status(500).json({ error: 'Failed to finalize upload' });
  }
});

// ─── Upload Spreadsheet ──────────────────────────────────────

router.get('/upload-timings', requireMasjid, (req, res) => {
  res.render('upload-timings', { masjid: req.masjid });
});

// ─── API Settings (location & calculation method) ───────────

router.get('/api-settings', requireMasjid, async (req, res) => {
  res.render('api-settings', { masjid: req.masjid, error: null, success: null });
});

router.post('/api-settings', requireMasjid, async (req, res) => {
  const { latitude, longitude, calculation_method } = req.body;

  try {
    await supabase.from('masjids').update({
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      calculation_method: calculation_method ? parseInt(calculation_method) : 2,
      updated_at: new Date().toISOString()
    }).eq('id', req.masjid.id);

    req.session.flash = { type: 'success', message: 'API settings updated. Prayer times will now use the new location.' };
    res.redirect('/admin/api-settings');
  } catch (err) {
    console.error('API settings error:', err);
    res.render('api-settings', { masjid: { ...req.masjid, ...req.body }, error: err.message, success: null });
  }
});

// ─── Jumu'ah ─────────────────────────────────────────────────

router.get('/jumuah', requireMasjid, async (req, res) => {
  const { data: jumuah } = await supabase
    .from('jumuah_times')
    .select('*')
    .eq('masjid_id', req.masjid.id)
    .maybeSingle();

  res.render('jumuah', { masjid: req.masjid, jumuah });
});

router.post('/jumuah', requireMasjid, async (req, res) => {
  const { khutbah_time, first_jamaat, second_jamaat } = req.body;
  const masjidId = req.masjid.id;

  await supabase.from('jumuah_times').delete().eq('masjid_id', masjidId);
  await supabase.from('jumuah_times').insert({
    masjid_id: masjidId,
    khutbah_time: khutbah_time || null,
    first_jamaat: first_jamaat || null,
    second_jamaat: second_jamaat || null
  });

  req.session.flash = { type: 'success', message: "Jumu'ah times saved" };
  res.redirect('/admin/jumuah');
});

// ─── Iqamah Standards ────────────────────────────────────────

router.get('/iqamah-standards', requireMasjid, async (req, res) => {
  const { data: rules } = await supabase
    .from('iqamah_rules')
    .select('*')
    .eq('masjid_id', req.masjid.id);

  const ruleMap = {};
  for (const r of (rules || [])) ruleMap[r.prayer] = r;

  res.render('iqamah-standards', { masjid: req.masjid, ruleMap });
});

router.post('/iqamah-standards', requireMasjid, async (req, res) => {
  const masjidId = req.masjid.id;
  const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  try {
    // Delete all existing rules for this masjid
    await supabase.from('iqamah_rules').delete().eq('masjid_id', masjidId);

    // Insert new rules
    for (const prayer of prayers) {
      const ruleType = req.body[`rule_type_${prayer}`];
      if (!ruleType || ruleType === 'none') continue;

      const value = req.body[`value_${prayer}`] || '';
      const reference = req.body[`reference_${prayer}`] || null;

      if (!value) continue;

      await supabase.from('iqamah_rules').insert({
        masjid_id: masjidId,
        prayer,
        rule_type: ruleType,
        value,
        reference_prayer: ruleType === 'after_reference' ? reference : null
      });
    }

    req.session.flash = { type: 'success', message: 'Iqamah standards saved' };
  } catch (err) {
    console.error('Iqamah standards save error:', err);
    req.session.flash = { type: 'error', message: 'Failed to save iqamah standards' };
  }

  res.redirect('/admin/iqamah-standards');
});

// ─── Announcements ───────────────────────────────────────────

router.get('/announcements', requireMasjid, async (req, res) => {
  const { data: announcements } = await supabase
    .from('announcements')
    .select('*')
    .eq('masjid_id', req.masjid.id)
    .order('created_at', { ascending: false });

  res.render('announcements', { masjid: req.masjid, announcements: announcements || [] });
});

// Save slideshow duration setting
router.post('/slideshow-settings', requireMasjid, async (req, res) => {
  const { slideshow_duration } = req.body;
  const duration = parseInt(slideshow_duration) || 10;

  await supabase.from('masjids').update({
    slideshow_duration: Math.max(3, Math.min(120, duration)),
    updated_at: new Date().toISOString()
  }).eq('id', req.masjid.id);

  req.session.flash = { type: 'success', message: 'Slideshow duration updated' };
  res.redirect('/admin/announcements');
});

router.post('/announcements', requireMasjid, upload.single('image'), async (req, res) => {
  const { title, body, media_type, video_url } = req.body;

  if (title && title.trim()) {
    let image_url = null;
    if (req.body.image_url) {
      image_url = req.body.image_url;
    } else if (req.file) {
      image_url = await uploadImage(req.file, req.masjid.id, 'announcements');
    }

    const announcementType = media_type || 'text';
    // If media_type is 'image' and there's an image_url, or if media_type is 'video' and there's a video_url
    // Default to 'text' if no media provided
    let finalType = announcementType;
    if (finalType === 'image' && !image_url) finalType = 'text';
    if (finalType === 'video' && !video_url) finalType = 'text';

    await supabase.from('announcements').insert({
      masjid_id: req.masjid.id,
      title: title.trim(),
      body: body || null,
      image_url,
      video_url: video_url || null,
      media_type: finalType
    });

    req.session.flash = { type: 'success', message: 'Announcement posted' };
  }

  res.redirect('/admin/announcements');
});

router.post('/announcements/:id/toggle', requireMasjid, async (req, res) => {
  const { data: ann } = await supabase
    .from('announcements')
    .select('*')
    .eq('id', req.params.id)
    .eq('masjid_id', req.masjid.id)
    .single();

  if (ann) {
    await supabase
      .from('announcements')
      .update({ active: ann.active ? 0 : 1 })
      .eq('id', ann.id);
  }

  res.redirect('/admin/announcements');
});

router.post('/announcements/:id/delete', requireMasjid, async (req, res) => {
  const { data: ann } = await supabase
    .from('announcements')
    .select('*')
    .eq('id', req.params.id)
    .eq('masjid_id', req.masjid.id)
    .single();

  if (ann) {
    // Delete announcement media from storage if it exists
    if (ann.image_url) {
      try {
        const filePath = extractFilePath(ann.image_url);
        if (filePath) await bucket.file(filePath).delete();
      } catch (err) {
        console.error('Image delete error:', err.message);
      }
    }
    if (ann.video_url) {
      try {
        const filePath = extractFilePath(ann.video_url);
        if (filePath) await bucket.file(filePath).delete();
      } catch (err) {
        console.error('Video delete error:', err.message);
      }
    }
    await supabase.from('announcements').delete().eq('id', ann.id);
    req.session.flash = { type: 'success', message: 'Announcement deleted' };
  }

  res.redirect('/admin/announcements');
});

// ─── Firebase Storage Helpers ────────────────────────────────

function getFirebasePublicUrl(filePath) {
  return `https://storage.googleapis.com/${bucket.name}/${filePath}`;
}

function extractFilePath(publicUrl) {
  const prefix = `https://storage.googleapis.com/${bucket.name}/`;
  if (publicUrl && publicUrl.startsWith(prefix)) {
    return publicUrl.slice(prefix.length);
  }
  return null;
}

async function uploadImage(file, masjidId, category) {
  const ext = path.extname(file.originalname) || '.jpg';

  let filename;
  if (category === 'profile') {
    // Profile image: overwrite previous (one per masjid)
    filename = `${masjidId}/profile${ext}`;
    // Try to delete old profile image with different extension
    try {
      const [files] = await bucket.getFiles({ prefix: `${masjidId}/profile` });
      for (const f of files) {
        if (f.name.startsWith(`${masjidId}/profile`)) {
          await f.delete().catch(() => {});
        }
      }
    } catch (err) {
      // Ignore cleanup errors
    }
  } else {
    // Announcement images: timestamped
    filename = `${masjidId}/announcements/${Date.now()}${ext}`;
  }

  try {
    const firebaseFile = bucket.file(filename);
    await firebaseFile.save(file.buffer, {
      metadata: { contentType: file.mimetype },
    });

    // Try makePublic first; fall back to signed URL if bucket uses uniform access
    try {
      await firebaseFile.makePublic();
      return getFirebasePublicUrl(filename);
    } catch (publicErr) {
      // Uniform bucket-level access — use a long-lived signed URL instead
      const [signedUrl] = await firebaseFile.getSignedUrl({
        action: 'read',
        expires: '03-01-2030',
      });
      return signedUrl;
    }
  } catch (error) {
    console.error('Upload error:', error);
    return null;
  }
}

module.exports = router;
