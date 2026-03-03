-- TV display devices pairing table
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

CREATE INDEX idx_tv_devices_pair_code ON tv_devices(pair_code);
CREATE INDEX idx_tv_devices_device_id ON tv_devices(device_id);
CREATE INDEX idx_tv_devices_masjid_id ON tv_devices(masjid_id);
