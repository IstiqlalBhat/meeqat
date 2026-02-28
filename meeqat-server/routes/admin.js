const express = require('express');
const fetch = require('node-fetch');
const multer = require('multer');
const path = require('path');
const { supabase } = require('../db/supabase');
const { bucket } = require('../db/firebase');
const { requireAuth, loadMasjid, requireMasjid } = require('../middleware/auth');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

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

    // Upload profile image if provided
    if (req.file && newMasjid) {
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

    if (req.file) {
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

// ─── Announcements ───────────────────────────────────────────

router.get('/announcements', requireMasjid, async (req, res) => {
  const { data: announcements } = await supabase
    .from('announcements')
    .select('*')
    .eq('masjid_id', req.masjid.id)
    .order('created_at', { ascending: false });

  res.render('announcements', { masjid: req.masjid, announcements: announcements || [] });
});

router.post('/announcements', requireMasjid, upload.single('image'), async (req, res) => {
  const { title, body } = req.body;

  if (title && title.trim()) {
    let image_url = null;
    if (req.file) {
      image_url = await uploadImage(req.file, req.masjid.id, 'announcements');
    }

    await supabase.from('announcements').insert({
      masjid_id: req.masjid.id,
      title: title.trim(),
      body: body || null,
      image_url
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
    // Delete announcement image from storage if it exists
    if (ann.image_url) {
      try {
        const filePath = extractFilePath(ann.image_url);
        if (filePath) await bucket.file(filePath).delete();
      } catch (err) {
        console.error('Image delete error:', err.message);
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
    await firebaseFile.makePublic();
    return getFirebasePublicUrl(filename);
  } catch (error) {
    console.error('Upload error:', error);
    return null;
  }
}

module.exports = router;
