const express = require('express');
const fetch = require('node-fetch');
const { supabase } = require('../db/supabase');

const router = express.Router();

// In-memory cache for Aladhan API responses
const apiCache = new Map();

function getCacheKey(lat, lng, method, date) {
  return `${lat}_${lng}_${method}_${date}`;
}

async function fetchAladhanTimes(lat, lng, method, date) {
  const key = getCacheKey(lat, lng, method, date);
  if (apiCache.has(key)) {
    return apiCache.get(key);
  }

  const [year, month, day] = date.split('-');
  const url = `https://api.aladhan.com/v1/timings/${day}-${month}-${year}?latitude=${lat}&longitude=${lng}&method=${method}`;

  try {
    const response = await fetch(url);
    const data = await response.json();

    if (data.code === 200 && data.data && data.data.timings) {
      const timings = data.data.timings;
      const result = {
        fajr: timings.Fajr,
        sunrise: timings.Sunrise,
        dhuhr: timings.Dhuhr,
        asr: timings.Asr,
        sunset: timings.Sunset,
        maghrib: timings.Maghrib,
        isha: timings.Isha
      };
      apiCache.set(key, result);
      setTimeout(() => apiCache.delete(key), 24 * 60 * 60 * 1000);
      return result;
    }
  } catch (err) {
    console.error('Aladhan API error:', err.message);
  }

  return null;
}

// GET /api/masjids
router.get('/masjids', async (req, res) => {
  const { data: masjids, error } = await supabase
    .from('masjids')
    .select('id, name, city, state, image_url')
    .order('name');

  if (error) return res.status(500).json({ error: error.message });
  res.json({ masjids: masjids || [] });
});

// GET /api/masjids/:id
router.get('/masjids/:id', async (req, res) => {
  const { data: masjid, error } = await supabase
    .from('masjids')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (error || !masjid) return res.status(404).json({ error: 'Masjid not found' });
  res.json({ masjid });
});

// GET /api/masjids/:id/times?date=YYYY-MM-DD
router.get('/masjids/:id/times', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('*')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.status(404).json({ error: 'Masjid not found' });

  const date = req.query.date || new Date().toISOString().split('T')[0];
  const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'sunset', 'maghrib', 'isha'];

  const lat = masjid.latitude || 34.6834;
  const lng = masjid.longitude || -82.8374;
  const apiTimes = await fetchAladhanTimes(lat, lng, masjid.calculation_method, date);

  // Get overrides
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

  // Build override maps (date-specific takes priority)
  const overrideMap = {};
  for (const o of (permanentOverrides || [])) overrideMap[o.prayer] = o;
  for (const o of (dateOverrides || [])) overrideMap[o.prayer] = o;

  // Merge times
  const times = {};
  for (const prayer of prayers) {
    const override = overrideMap[prayer];
    const apiTime = apiTimes ? apiTimes[prayer] : null;

    times[prayer] = {
      athan: override && override.athan_time ? override.athan_time : (apiTime || null),
      iqamah: override && override.iqamah_time ? override.iqamah_time : null,
      source: override && override.athan_time ? 'override' : 'api'
    };
  }

  res.json({
    masjid_id: masjid.id,
    masjid_name: masjid.name,
    date,
    times
  });
});

// GET /api/masjids/:id/jumuah
router.get('/masjids/:id/jumuah', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('id')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.status(404).json({ error: 'Masjid not found' });

  const { data: jumuah } = await supabase
    .from('jumuah_times')
    .select('khutbah_time, first_jamaat, second_jamaat')
    .eq('masjid_id', req.params.id)
    .maybeSingle();

  res.json({ jumuah: jumuah || null });
});

// GET /api/masjids/:id/announcements
router.get('/masjids/:id/announcements', async (req, res) => {
  const { data: masjid } = await supabase
    .from('masjids')
    .select('id')
    .eq('id', req.params.id)
    .single();

  if (!masjid) return res.status(404).json({ error: 'Masjid not found' });

  const { data: announcements } = await supabase
    .from('announcements')
    .select('id, title, body, image_url, created_at')
    .eq('masjid_id', req.params.id)
    .eq('active', 1)
    .order('created_at', { ascending: false });

  res.json({ announcements: announcements || [] });
});

module.exports = router;
