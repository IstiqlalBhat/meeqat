-- Meeqat Prayer Times - Supabase PostgreSQL Schema
-- Run this in your Supabase SQL Editor to set up the database

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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS prayer_overrides (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  date TEXT,
  prayer TEXT NOT NULL,
  athan_time TEXT,
  iqamah_time TEXT,
  UNIQUE(masjid_id, COALESCE(date, ''), prayer)
);

CREATE TABLE IF NOT EXISTS jumuah_times (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  khutbah_time TEXT,
  first_jamaat TEXT,
  second_jamaat TEXT,
  UNIQUE(masjid_id)
);

CREATE TABLE IF NOT EXISTS announcements (
  id SERIAL PRIMARY KEY,
  masjid_id INTEGER NOT NULL REFERENCES masjids(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  image_url TEXT,
  active INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_settings (
  id SERIAL PRIMARY KEY,
  password_hash TEXT NOT NULL
);

-- Enable Row Level Security (optional, since we use service key server-side)
-- ALTER TABLE masjids ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE prayer_overrides ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE jumuah_times ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE admin_settings ENABLE ROW LEVEL SECURITY;

-- Create storage bucket for images (run this separately or via Supabase dashboard)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('meeqat-images', 'meeqat-images', true);
