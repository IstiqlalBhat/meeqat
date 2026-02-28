-- Migration: Firebase Auth & Single-Masjid-Per-Admin
-- Run this in Supabase SQL Editor to migrate from shared password auth to Firebase Auth

-- 1. Add firebase_uid column to link each masjid to one admin account
ALTER TABLE masjids ADD COLUMN IF NOT EXISTS firebase_uid TEXT;

-- 2. Unique constraint: one masjid per admin (allows NULL for unassigned masjids)
CREATE UNIQUE INDEX IF NOT EXISTS masjids_firebase_uid_unique
  ON masjids (firebase_uid) WHERE firebase_uid IS NOT NULL;

-- 3. Drop the old shared password table (no longer needed with Firebase Auth)
DROP TABLE IF EXISTS admin_settings;
