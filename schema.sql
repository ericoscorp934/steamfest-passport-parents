-- ============================================================
-- STEAMFest Passport 2026 (Parents) — Supabase SQL Schema
-- Paste into your Supabase project SQL Editor and run.
-- This is a SEPARATE Supabase project from the kids app.
-- ============================================================

-- 1. WEEKS — Admin-editable festival calendar
CREATE TABLE IF NOT EXISTS weeks (
  id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  week_number  INTEGER NOT NULL UNIQUE CHECK (week_number BETWEEN 1 AND 16),
  title        TEXT    NOT NULL,
  start_date   DATE    NOT NULL,
  end_date     DATE    NOT NULL
);

-- 2. BOOTHS — Admin-editable booth list (varies per week)
CREATE TABLE IF NOT EXISTS booths (
  id         UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT    NOT NULL,
  week_id    UUID    REFERENCES weeks(id) ON DELETE CASCADE,
  pin        CHAR(6) NOT NULL UNIQUE,
  active     BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PARTICIPANTS — Parent/visitor registrations (separate from kids app)
CREATE TABLE IF NOT EXISTS participants (
  id         UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT    NOT NULL,
  phone      TEXT    NOT NULL UNIQUE,
  email      TEXT,
  qr_token   UUID    DEFAULT gen_random_uuid() NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. CHECKINS — Booth stamp records (DB-enforced deduplication)
--    Includes week_id so same booth record can be reused across weeks safely
CREATE TABLE IF NOT EXISTS checkins (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
  booth_id       UUID NOT NULL REFERENCES booths(id) ON DELETE CASCADE,
  week_id        UUID NOT NULL REFERENCES weeks(id) ON DELETE CASCADE,
  scanned_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(participant_id, booth_id, week_id)  -- prevents double-stamping
);

-- 5. WEEKLY CHOPS — One row per participant per week (earned + redemption state)
--    UNIQUE constraint physically prevents two chops in same week for same parent.
--    redeemed/redeemed_at track the one-time weekly gift redemption.
CREATE TABLE IF NOT EXISTS weekly_chops (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  participant_id UUID NOT NULL REFERENCES participants(id) ON DELETE CASCADE,
  week_id        UUID NOT NULL REFERENCES weeks(id) ON DELETE CASCADE,
  earned_at      TIMESTAMPTZ DEFAULT NOW(),
  redeemed       BOOLEAN DEFAULT false NOT NULL,
  redeemed_at    TIMESTAMPTZ,
  UNIQUE(participant_id, week_id)  -- prevents double chop; enforced at DB level
);

-- 6. SETTINGS — App config (admin PIN, redemption PIN)
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Default PINs (change in-app after first login)
INSERT INTO settings (key, value) VALUES ('admin_pin', '000000')
ON CONFLICT (key) DO NOTHING;

INSERT INTO settings (key, value) VALUES ('redemption_pin', '000001')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- Row-Level Security — permissive anon_all policies
-- ============================================================
ALTER TABLE weeks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE booths         ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants   ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkins       ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_chops   ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings       ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all" ON weeks          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON booths         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON participants   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON checkins       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON weekly_chops   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all" ON settings       FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- Optional: seed sample weeks for testing
-- ============================================================
-- Uncomment and adjust dates as needed:
/*
INSERT INTO weeks (week_number, title, start_date, end_date) VALUES
  (1,  'Week 1',  '2026-01-03', '2026-01-04'),
  (2,  'Week 2',  '2026-01-10', '2026-01-11'),
  (3,  'Week 3',  '2026-01-17', '2026-01-18'),
  (4,  'Week 4',  '2026-01-24', '2026-01-25'),
  (5,  'Week 5',  '2026-01-31', '2026-02-01'),
  (6,  'Week 6',  '2026-02-07', '2026-02-08'),
  (7,  'Week 7',  '2026-02-14', '2026-02-15'),
  (8,  'Week 8',  '2026-02-21', '2026-02-22'),
  (9,  'Week 9',  '2026-02-28', '2026-03-01'),
  (10, 'Week 10', '2026-03-07', '2026-03-08'),
  (11, 'Week 11', '2026-03-14', '2026-03-15'),
  (12, 'Week 12', '2026-03-21', '2026-03-22'),
  (13, 'Week 13', '2026-03-28', '2026-03-29'),
  (14, 'Week 14', '2026-04-04', '2026-04-05'),
  (15, 'Week 15', '2026-04-11', '2026-04-12'),
  (16, 'Week 16', '2026-04-18', '2026-04-19');
*/

-- ============================================================
-- Lucky Draw Query (run in admin — never store the result)
-- ============================================================
-- Every 3 chops = 1 lucky draw entry (always a live calculation):
--
-- SELECT p.name, p.phone, COUNT(wc.id) as total_chops,
--        FLOOR(COUNT(wc.id) / 3) as entries
-- FROM weekly_chops wc
-- JOIN participants p ON p.id = wc.participant_id
-- GROUP BY p.id, p.name, p.phone
-- HAVING COUNT(wc.id) >= 3
-- ORDER BY entries DESC;
