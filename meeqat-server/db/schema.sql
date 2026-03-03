-- Meeqat Prayer Times - Supabase PostgreSQL Schema

CREATE TABLE IF NOT EXISTS masjids (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  city TEXT DEFAULT 'Clemson',
  state TEXT DEFAULT 'South Carolina',
  country TEXT DEFAULT 'US',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  calculation_method INTEGER DEFAULT 2,
  image_url TEXT,
  firebase_uid TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS masjids_firebase_uid_unique
  ON masjids (firebase_uid) WHERE firebase_uid IS NOT NULL;

CREATE TABLE IF NOT EXISTS prayer_overrides (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  date TEXT,
  prayer TEXT NOT NULL,
  athan_time TEXT,
  iqamah_time TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS prayer_overrides_unique
  ON prayer_overrides (masjid_id, COALESCE(date, ''), prayer);

CREATE TABLE IF NOT EXISTS jumuah_times (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  khutbah_time TEXT,
  first_jamaat TEXT,
  second_jamaat TEXT,
  UNIQUE(masjid_id)
);

CREATE TABLE IF NOT EXISTS iqamah_rules (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  prayer TEXT NOT NULL,
  rule_type TEXT NOT NULL,
  value TEXT NOT NULL,
  reference_prayer TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS iqamah_rules_unique ON iqamah_rules (masjid_id, prayer);

CREATE TABLE IF NOT EXISTS announcements (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  image_url TEXT,
  active INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tv_devices (
  id SERIAL PRIMARY KEY,
  device_id TEXT UNIQUE NOT NULL,
  pair_code TEXT UNIQUE,
  masjid_id INTEGER REFERENCES masjids(id) ON DELETE SET NULL,
  name TEXT DEFAULT 'TV Display',
  paired_at TIMESTAMPTZ,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tv_devices_pair_code ON tv_devices(pair_code);
CREATE INDEX IF NOT EXISTS idx_tv_devices_device_id ON tv_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_tv_devices_masjid_id ON tv_devices(masjid_id);
