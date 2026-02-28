const express = require('express');
const fetch = require('node-fetch');
const multer = require('multer');
const path = require('path');
const { supabase } = require('../db/supabase');
const { bucket } = require('../db/firebase');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

router.use(requireAuth);

// ─── Dashboard ───────────────────────────────────────────────

router.get('/', async (req, res) => {
  try {
    const { data: masjids } = await supabase
      .from('masjids')
      .select('*')
      .order('name');

    const stats = await Promise.all((masjids || []).map(async (m) => {
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

      return { ...m, overrideCount: overrideCount || 0, announcementCount: announcementCount || 0, hasJumuah: !!jumuah };
    }));

    // Count total images across all storage folders
    let imageCount = 0;
    for (const folder of ['masjids', 'announcements', 'gallery']) {
      const [files] = await bucket.getFiles({ prefix: folder + '/' });
      imageCount += files.filter(f => !f.name.endsWith('/')).length;
    }

    res.render('dashboard', { masjids: stats, imageCount });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.render('dashboard', { masjids: [], imageCount: 0 });
  }
});

// ─── Masjid CRUD ─────────────────────────────────────────────

router.get('/masjids/new', (req, res) => {
  res.render('masjid-form', { masjid: null, error: null });
});

router.post('/masjids', upload.single('image'), async (req, res) => {
  const { name, address, city, state, country, latitude, longitude, calculation_method } = req.body;

  if (!name || !name.trim()) {
    return res.render('masjid-form', { masjid: req.body, error: 'Name is required' });
  }

  try {
    let image_url = null;
    if (req.file) {
      image_url = await uploadImage(req.file, 'masjids');
    }

    await supabase.from('masjids').insert({
      name: name.trim(),
      address: address || null,
      city: city || 'Clemson',
      state: state || 'South Carolina',
      country: country || 'US',
      latitude: latitude ? parseFloat(latitude) : null,
      longitude: longitude ? parseFloat(longitude) : null,
      calculation_method: calculation_method ? parseInt(calculation_method) : 2,
      image_url
    });

    req.session.flash = { type: 'success', message: 'Masjid created successfully' };
    res.redirect('/admin');
  } catch (err) {
    res.render('masjid-form', { masjid: req.body, error: err.message });
  }
});

router.get('/masjids/:id/edit', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.redirect('/admin');
  res.render('masjid-form', { masjid, error: null });
});

router.post('/masjids/:id', upload.single('image'), async (req, res) => {
  const { name, address, city, state, country, latitude, longitude, calculation_method } = req.body;

  if (!name || !name.trim()) {
    return res.render('masjid-form', { masjid: { ...req.body, id: req.params.id }, error: 'Name is required' });
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
      updateData.image_url = await uploadImage(req.file, 'masjids');
    }

    await supabase.from('masjids').update(updateData).eq('id', req.params.id);

    req.session.flash = { type: 'success', message: 'Masjid updated successfully' };
    res.redirect('/admin');
  } catch (err) {
    res.render('masjid-form', { masjid: { ...req.body, id: req.params.id }, error: err.message });
  }
});

router.post('/masjids/:id/delete', async (req, res) => {
  await supabase.from('masjids').delete().eq('id', req.params.id);
  req.session.flash = { type: 'success', message: 'Masjid deleted' };
  res.redirect('/admin');
});

// ─── Timings ─────────────────────────────────────────────────

router.get('/masjids/:id/timings', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.redirect('/admin');

  const date = req.query.date || new Date().toISOString().split('T')[0];
  const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'sunset', 'maghrib', 'isha'];

  // Fetch API times
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

  // Get date-specific overrides
  const { data: dateOverrides } = await supabase
    .from('prayer_overrides')
    .select('prayer, athan_time, iqamah_time')
    .eq('masjid_id', masjid.id)
    .eq('date', date);

  // Get permanent overrides
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

// Save timings — FIXED: "Use API" now correctly removes all override types
router.post('/masjids/:id/timings', async (req, res) => {
  const { date, override_type } = req.body;
  const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'sunset', 'maghrib', 'isha'];
  const dateValue = override_type === 'permanent' ? null : (date || null);
  const masjidId = parseInt(req.params.id);

  try {
    for (const prayer of prayers) {
      const athan = req.body[`athan_${prayer}`] || null;
      const iqamah = req.body[`iqamah_${prayer}`] || null;
      const useApi = req.body[`useapi_${prayer}`];

      if (useApi) {
        // FIX: Delete BOTH date-specific AND permanent overrides for this prayer
        await supabase
          .from('prayer_overrides')
          .delete()
          .eq('masjid_id', masjidId)
          .eq('prayer', prayer);
      } else if (athan || iqamah) {
        // Delete existing override for this type, then insert new one
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

  res.redirect(`/admin/masjids/${req.params.id}/timings?date=${date || new Date().toISOString().split('T')[0]}`);
});

// ─── Jumu'ah ─────────────────────────────────────────────────

router.get('/masjids/:id/jumuah', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.redirect('/admin');

  const { data: jumuah } = await supabase
    .from('jumuah_times')
    .select('*')
    .eq('masjid_id', masjid.id)
    .maybeSingle();

  res.render('jumuah', { masjid, jumuah });
});

router.post('/masjids/:id/jumuah', async (req, res) => {
  const { khutbah_time, first_jamaat, second_jamaat } = req.body;
  const masjidId = parseInt(req.params.id);

  // Delete existing, then insert (upsert workaround)
  await supabase.from('jumuah_times').delete().eq('masjid_id', masjidId);
  await supabase.from('jumuah_times').insert({
    masjid_id: masjidId,
    khutbah_time: khutbah_time || null,
    first_jamaat: first_jamaat || null,
    second_jamaat: second_jamaat || null
  });

  req.session.flash = { type: 'success', message: "Jumu'ah times saved" };
  res.redirect(`/admin/masjids/${req.params.id}/jumuah`);
});

// ─── Announcements ───────────────────────────────────────────

router.get('/masjids/:id/announcements', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.redirect('/admin');

  const { data: announcements } = await supabase
    .from('announcements')
    .select('*')
    .eq('masjid_id', masjid.id)
    .order('created_at', { ascending: false });

  res.render('announcements', { masjid, announcements: announcements || [] });
});

router.post('/masjids/:id/announcements', upload.single('image'), async (req, res) => {
  const { title, body } = req.body;

  if (title && title.trim()) {
    let image_url = null;
    if (req.file) {
      image_url = await uploadImage(req.file, 'announcements');
    }

    await supabase.from('announcements').insert({
      masjid_id: parseInt(req.params.id),
      title: title.trim(),
      body: body || null,
      image_url
    });

    req.session.flash = { type: 'success', message: 'Announcement posted' };
  }

  res.redirect(`/admin/masjids/${req.params.id}/announcements`);
});

router.post('/announcements/:id/toggle', async (req, res) => {
  const { data: ann } = await supabase
    .from('announcements')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (ann) {
    await supabase
      .from('announcements')
      .update({ active: ann.active ? 0 : 1 })
      .eq('id', ann.id);

    res.redirect(`/admin/masjids/${ann.masjid_id}/announcements`);
  } else {
    res.redirect('/admin');
  }
});

router.post('/announcements/:id/delete', async (req, res) => {
  const { data: ann } = await supabase
    .from('announcements')
    .select('masjid_id')
    .eq('id', req.params.id)
    .single();

  if (ann) {
    await supabase.from('announcements').delete().eq('id', req.params.id);
    req.session.flash = { type: 'success', message: 'Announcement deleted' };
    res.redirect(`/admin/masjids/${ann.masjid_id}/announcements`);
  } else {
    res.redirect('/admin');
  }
});

// ─── Media Library ──────────────────────────────────────────

router.get('/images', async (req, res) => {
  const filter = req.query.filter || 'all';
  const folders = filter === 'all'
    ? ['masjids', 'announcements', 'gallery']
    : [filter];

  try {
    // Collect all image URLs currently referenced in the database
    const { data: masjidRows } = await supabase.from('masjids').select('image_url');
    const { data: annRows } = await supabase.from('announcements').select('image_url');
    const usedUrls = new Set([
      ...(masjidRows || []).map(r => r.image_url).filter(Boolean),
      ...(annRows || []).map(r => r.image_url).filter(Boolean),
    ]);

    let images = [];

    for (const folder of folders) {
      try {
        const [files] = await bucket.getFiles({ prefix: folder + '/' });

        for (const file of files) {
          if (file.name.endsWith('/')) continue; // skip folder placeholders
          const fileName = file.name.split('/').pop();
          const publicUrl = getFirebasePublicUrl(file.name);
          const metadata = file.metadata;
          images.push({
            name: fileName,
            path: file.name,
            folder,
            url: publicUrl,
            createdAt: metadata.timeCreated || null,
            size: metadata.size ? parseInt(metadata.size) : null,
            inUse: usedUrls.has(publicUrl),
          });
        }
      } catch (err) {
        console.error(`Error listing ${folder}:`, err.message);
        continue;
      }
    }

    // Sort newest first
    images.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    res.render('images', { images, filter });
  } catch (err) {
    console.error('Images list error:', err);
    res.render('images', { images: [], filter });
  }
});

router.post('/images/upload', upload.array('images', 10), async (req, res) => {
  const folder = req.body.folder || 'gallery';
  let uploaded = 0;

  if (req.files && req.files.length > 0) {
    for (const file of req.files) {
      const url = await uploadImage(file, folder);
      if (url) uploaded++;
    }
  }

  req.session.flash = {
    type: uploaded > 0 ? 'success' : 'error',
    message: uploaded > 0
      ? `${uploaded} image${uploaded > 1 ? 's' : ''} uploaded`
      : 'Failed to upload images',
  };
  res.redirect(`/admin/images?filter=${folder}`);
});

router.post('/images/:path(*)/delete', async (req, res) => {
  const filePath = req.params.path;
  const folder = filePath.split('/')[0] || 'all';

  try {
    await bucket.file(filePath).delete();

    // Clear the reference from database rows that used this image
    const publicUrl = getFirebasePublicUrl(filePath);

    await supabase.from('masjids').update({ image_url: null }).eq('image_url', publicUrl);
    await supabase.from('announcements').update({ image_url: null }).eq('image_url', publicUrl);

    req.session.flash = { type: 'success', message: 'Image deleted' };
  } catch (err) {
    console.error('Image delete error:', err);
    req.session.flash = { type: 'error', message: 'Failed to delete image' };
  }

  res.redirect(`/admin/images?filter=${folder}`);
});

// ─── Firebase Storage Helpers ────────────────────────────────

function getFirebasePublicUrl(filePath) {
  return `https://storage.googleapis.com/${bucket.name}/${filePath}`;
}

async function uploadImage(file, folder) {
  const ext = path.extname(file.originalname) || '.jpg';
  const filename = `${folder}/${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`;

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
