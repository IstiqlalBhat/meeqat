const express = require('express');
const fetch = require('node-fetch');
const { supabase } = require('../db/supabase');
const { calculateIqamahFromRule } = require('../utils/iqamah');

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

// Haversine distance in km between two lat/lng points
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180)
    * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// GET /api/masjids
router.get('/masjids', async (req, res) => {
  const { data: masjids, error } = await supabase
    .from('masjids')
    .select('id, name, address, city, state, country, latitude, longitude, image_url')
    .order('name');

  if (error) return res.status(500).json({ error: error.message });
  res.json({ masjids: masjids || [] });
});

// GET /api/masjids/nearby?lat=X&lng=Y&radius=50
// Returns masjids sorted by distance from the given coordinates
router.get('/masjids/nearby', async (req, res) => {
  const { lat, lng, radius } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({ error: 'lat and lng query parameters are required' });
  }

  const userLat = parseFloat(lat);
  const userLng = parseFloat(lng);
  const maxRadius = parseFloat(radius) || 50; // default 50 km

  if (isNaN(userLat) || isNaN(userLng)) {
    return res.status(400).json({ error: 'lat and lng must be valid numbers' });
  }

  const { data: masjids, error } = await supabase
    .from('masjids')
    .select('id, name, address, city, state, country, latitude, longitude, image_url');

  if (error) return res.status(500).json({ error: error.message });

  const results = (masjids || [])
    .filter(m => m.latitude != null && m.longitude != null)
    .map(m => ({
      ...m,
      distance_km: Math.round(haversineKm(userLat, userLng, m.latitude, m.longitude) * 10) / 10
    }))
    .filter(m => m.distance_km <= maxRadius)
    .sort((a, b) => a.distance_km - b.distance_km);

  res.json({ masjids: results });
});

// GET /api/masjids/:id
router.get('/masjids/:id', async (req, res) => {
  const { data: masjid, error } = await supabase
    .from('masjids')
    .select('id, name, address, city, state, country, latitude, longitude, image_url')
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

  // Fetch iqamah rules for this masjid
  const { data: iqamahRules } = await supabase
    .from('iqamah_rules')
    .select('prayer, rule_type, value, reference_prayer')
    .eq('masjid_id', masjid.id);

  const ruleMap = {};
  for (const r of (iqamahRules || [])) ruleMap[r.prayer] = r;

  // Merge times
  const times = {};
  for (const prayer of prayers) {
    const override = overrideMap[prayer];
    const apiTime = apiTimes ? apiTimes[prayer] : null;

    let iqamah = null;
    if (override && override.iqamah_time) {
      iqamah = override.iqamah_time;
    } else if (ruleMap[prayer]) {
      iqamah = calculateIqamahFromRule(ruleMap[prayer], apiTimes, prayer);
    }

    times[prayer] = {
      athan: override && override.athan_time ? override.athan_time : (apiTime || null),
      iqamah,
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
    .select('id, title, body, image_url, video_url, media_type, created_at')
    .eq('masjid_id', req.params.id)
    .eq('active', 1)
    .order('created_at', { ascending: false });

  // Also fetch slideshow_duration from the masjid
  const { data: masjidSettings } = await supabase
    .from('masjids')
    .select('slideshow_duration')
    .eq('id', req.params.id)
    .single();

  res.json({
    announcements: announcements || [],
    slideshow_duration: (masjidSettings && masjidSettings.slideshow_duration) || 10
  });
});

// ============================================================
// TV Display Device Endpoints
// ============================================================

// POST /api/tv/register - TV registers itself with a pair code
router.post('/tv/register', async (req, res) => {
  const { device_id, pair_code } = req.body;

  if (!device_id || !pair_code) {
    return res.status(400).json({ error: 'device_id and pair_code are required' });
  }

  // Upsert the device record
  const { data: existing } = await supabase
    .from('tv_devices')
    .select('*')
    .eq('device_id', device_id)
    .maybeSingle();

  if (existing) {
    // Update pair code and last_seen
    const { error } = await supabase
      .from('tv_devices')
      .update({ pair_code, last_seen: new Date().toISOString() })
      .eq('device_id', device_id);

    if (error) return res.status(500).json({ error: error.message });
    return res.json({ status: 'updated', device_id, pair_code });
  }

  const { error } = await supabase
    .from('tv_devices')
    .insert({ device_id, pair_code });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ status: 'registered', device_id, pair_code });
});

// GET /api/tv/:deviceId/config - TV polls for its configuration
router.get('/tv/:deviceId/config', async (req, res) => {
  const { data: device, error } = await supabase
    .from('tv_devices')
    .select('*, masjids(id, name, address, city, state, country, latitude, longitude, image_url, calculation_method, slideshow_duration)')
    .eq('device_id', req.params.deviceId)
    .maybeSingle();

  if (error) return res.status(500).json({ error: error.message });
  if (!device) return res.status(404).json({ error: 'Device not found' });

  // Update last_seen
  await supabase
    .from('tv_devices')
    .update({ last_seen: new Date().toISOString() })
    .eq('device_id', req.params.deviceId);

  if (!device.masjid_id) {
    return res.json({ paired: false, device_id: device.device_id, pair_code: device.pair_code });
  }

  res.json({
    paired: true,
    device_id: device.device_id,
    masjid: device.masjids
  });
});

// POST /api/tv/pair - Mobile app pairs a TV device with a masjid
router.post('/tv/pair', async (req, res) => {
  const { pair_code, masjid_id } = req.body;

  if (!pair_code || !masjid_id) {
    return res.status(400).json({ error: 'pair_code and masjid_id are required' });
  }

  const { data: device } = await supabase
    .from('tv_devices')
    .select('*')
    .eq('pair_code', pair_code)
    .maybeSingle();

  if (!device) {
    return res.status(404).json({ error: 'Invalid pair code. Please check the code on your TV display.' });
  }

  const { data: masjid } = await supabase
    .from('masjids')
    .select('id, name')
    .eq('id', masjid_id)
    .maybeSingle();

  if (!masjid) {
    return res.status(404).json({ error: 'Masjid not found' });
  }

  const { error } = await supabase
    .from('tv_devices')
    .update({
      masjid_id,
      paired_at: new Date().toISOString(),
      pair_code: null // Clear pair code after successful pairing
    })
    .eq('device_id', device.device_id);

  if (error) return res.status(500).json({ error: error.message });

  res.json({
    status: 'paired',
    device_id: device.device_id,
    masjid: { id: masjid.id, name: masjid.name }
  });
});

// POST /api/tv/:deviceId/unpair - Unpair a TV device
router.post('/tv/:deviceId/unpair', async (req, res) => {
  const { error } = await supabase
    .from('tv_devices')
    .update({ masjid_id: null, paired_at: null })
    .eq('device_id', req.params.deviceId);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ status: 'unpaired' });
});

module.exports = router;
