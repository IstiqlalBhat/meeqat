-- Migration: Iqamah Rules - Flexible rule-based iqamah calculation
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
