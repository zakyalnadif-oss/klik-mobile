-- ============================================================
-- KLIK Mobile — PostgreSQL Database Schema
-- Jalankan: psql -U postgres -d klik_db -f init.sql
-- ============================================================

-- 1. USERS (autentikasi)
CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  email         VARCHAR(255) UNIQUE NOT NULL,
  password      VARCHAR(255) NOT NULL,
  display_name  VARCHAR(100),
  avatar_url    TEXT,
  city          VARCHAR(80) DEFAULT 'Jakarta Selatan',
  sport         VARCHAR(50) DEFAULT 'Futsal',
  level         VARCHAR(20) DEFAULT 'Menengah' CHECK (level IN ('Pemula','Menengah','Mahir')),
  theme         VARCHAR(10) DEFAULT 'system' CHECK (theme IN ('system','light','dark')),
  created_at    TIMESTAMP DEFAULT NOW()
);

-- 2. PLAYERS (profil pemain yang bisa dicari)
CREATE TABLE IF NOT EXISTS players (
  id          VARCHAR(50) PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  handle      VARCHAR(100) UNIQUE NOT NULL,
  sport       VARCHAR(50) NOT NULL,
  city        VARCHAR(80) NOT NULL,
  level       VARCHAR(20) NOT NULL CHECK (level IN ('Pemula','Menengah','Mahir')),
  initials    VARCHAR(5) NOT NULL,
  user_id     INT REFERENCES users(id) ON DELETE SET NULL
);

-- 3. VENUES (lapangan / lokasi)
CREATE TABLE IF NOT EXISTS venues (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(200) UNIQUE NOT NULL,
  sport       VARCHAR(50) NOT NULL,
  address     VARCHAR(300) NOT NULL,
  description TEXT DEFAULT '',
  latitude DOUBLE PRECISION CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION CHECK (longitude BETWEEN -180 AND 180),
  owner_user_id INT REFERENCES users(id) ON DELETE SET NULL
);

-- 4. ACTIVITIES (room & event)
CREATE TABLE IF NOT EXISTS activities (
  id                VARCHAR(100) PRIMARY KEY,
  kind              VARCHAR(10) NOT NULL CHECK (kind IN ('room','event')),
  title             VARCHAR(80) NOT NULL,
  sport             VARCHAR(50) NOT NULL,
  venue             VARCHAR(200) NOT NULL,
  venue_id          INT REFERENCES venues(id) ON DELETE SET NULL,
  city              VARCHAR(80) NOT NULL,
  mode              VARCHAR(20) NOT NULL CHECK (mode IN ('Kasual','Berperingkat')),
  starts_at         TIMESTAMP NOT NULL,
  duration_minutes  INT NOT NULL DEFAULT 120 CHECK (duration_minutes BETWEEN 15 AND 1440),
  capacity          INT NOT NULL CHECK (capacity BETWEEN 2 AND 100),
  occupied          INT NOT NULL DEFAULT 0,
  price             INT NOT NULL DEFAULT 0 CHECK (price BETWEEN 0 AND 100000000),
  owner             VARCHAR(100) NOT NULL,
  description       TEXT DEFAULT '',
  demo              BOOLEAN DEFAULT FALSE,
  owner_user_id     INT REFERENCES users(id) ON DELETE SET NULL,
  created_at        TIMESTAMP DEFAULT NOW()
);

-- 5. ACTIVITY_PARTICIPANTS (siapa yang gabung di aktivitas mana)
CREATE TABLE IF NOT EXISTS activity_participants (
  id          SERIAL PRIMARY KEY,
  activity_id VARCHAR(100) NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE(activity_id, user_id)
);

-- 6. TEAMS (tim untuk pertandingan berperingkat)
CREATE TABLE IF NOT EXISTS teams (
  id            VARCHAR(100) PRIMARY KEY,
  name          VARCHAR(60) NOT NULL,
  captain_id    VARCHAR(50) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  captain_name  VARCHAR(100) NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW()
);

-- 7. RANKED_MATCHES (pertandingan berperingkat — team A vs team B)
CREATE TABLE IF NOT EXISTS ranked_matches (
  id            SERIAL PRIMARY KEY,
  activity_id   VARCHAR(100) UNIQUE NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  team_a_id     VARCHAR(100) NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  team_b_id     VARCHAR(100) REFERENCES teams(id) ON DELETE SET NULL,
  created_at    TIMESTAMP DEFAULT NOW()
);

-- 8. MATCH_RESULTS (hasil pertandingan)
CREATE TABLE IF NOT EXISTS match_results (
  id            SERIAL PRIMARY KEY,
  activity_id   VARCHAR(100) UNIQUE NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  score_a       INT NOT NULL DEFAULT 0 CHECK (score_a BETWEEN 0 AND 999),
  score_b       INT NOT NULL DEFAULT 0 CHECK (score_b BETWEEN 0 AND 999),
  status        VARCHAR(30) NOT NULL DEFAULT 'Menunggu konfirmasi'
                CHECK (status IN ('Menunggu konfirmasi','Skor berbeda','Disahkan')),
  confirmed_at  TIMESTAMP,
  created_at    TIMESTAMP DEFAULT NOW()
);

-- 9. SCORE_SUBMISSIONS (pengajuan skor oleh kapten)
CREATE TABLE IF NOT EXISTS score_submissions (
  id            SERIAL PRIMARY KEY,
  result_id     INT NOT NULL REFERENCES match_results(id) ON DELETE CASCADE,
  captain_id    VARCHAR(50) NOT NULL,
  score_a       INT NOT NULL CHECK (score_a BETWEEN 0 AND 999),
  score_b       INT NOT NULL CHECK (score_b BETWEEN 0 AND 999),
  submitted_at  TIMESTAMP DEFAULT NOW(),
  UNIQUE(result_id, captain_id)
);

-- 10. CHECKOUT_PREVIEWS (pratinjau pembayaran QRIS)
CREATE TABLE IF NOT EXISTS checkout_previews (
  id            SERIAL PRIMARY KEY,
  reference     VARCHAR(50) UNIQUE NOT NULL,
  activity_id   VARCHAR(100) NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id       INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount        INT NOT NULL CHECK (amount > 0 AND amount <= 100000000),
  status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','demo_confirmed','cancelled')),
  created_at    TIMESTAMP DEFAULT NOW(),
  expires_at    TIMESTAMP NOT NULL
);

-- 11. FRIENDS (pertemanan antar pemain)
CREATE TABLE IF NOT EXISTS friends (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id   INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      VARCHAR(20) NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','accepted','rejected')),
  created_at  TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- 12. COMMUNITIES (keanggotaan komunitas olahraga)
CREATE TABLE IF NOT EXISTS community_members (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sport       VARCHAR(50) NOT NULL,
  joined_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, sport)
);

-- 13. RANKINGS (papan peringkat)
CREATE TABLE IF NOT EXISTS rankings (
  id          SERIAL PRIMARY KEY,
  sport       VARCHAR(50) NOT NULL,
  type        VARCHAR(20) NOT NULL CHECK (type IN ('Tim','Individu')),
  rank        INT NOT NULL CHECK (rank >= 1),
  initials    VARCHAR(5) NOT NULL,
  name        VARCHAR(100) NOT NULL,
  detail      VARCHAR(200) DEFAULT '',
  points      VARCHAR(20) DEFAULT '0',
  highlight   BOOLEAN DEFAULT FALSE
);

-- 14. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS notifications (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       VARCHAR(200) NOT NULL,
  body        TEXT DEFAULT '',
  is_read     BOOLEAN DEFAULT FALSE,
  type        VARCHAR(40) NOT NULL DEFAULT 'general',
  action_id   VARCHAR(100),
  created_at  TIMESTAMP DEFAULT NOW()
);

-- Password reset tokens are stored as hashes and expire quickly.
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id          BIGSERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  CHAR(64) NOT NULL UNIQUE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_user_expiry
  ON password_reset_tokens(user_id, expires_at);

CREATE TABLE IF NOT EXISTS device_push_tokens (
  id          BIGSERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token       TEXT NOT NULL UNIQUE,
  platform    VARCHAR(20) NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_push_user ON device_push_tokens(user_id);

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS venue_bookings (
  id          BIGSERIAL PRIMARY KEY,
  venue_id    INT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  starts_at   TIMESTAMPTZ NOT NULL,
  ends_at     TIMESTAMPTZ NOT NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending','confirmed','rejected','cancelled')),
  notes       TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at > starts_at),
  EXCLUDE USING gist (
    venue_id WITH =,
    tstzrange(starts_at, ends_at, '[)') WITH &&
  ) WHERE (status IN ('pending','confirmed'))
);

CREATE INDEX IF NOT EXISTS idx_venue_bookings_time
  ON venue_bookings(venue_id, starts_at, ends_at)
  WHERE status IN ('pending','confirmed');

-- Idempotent upgrades for databases created by earlier app versions.
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE venues ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE venues ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE venues ADD COLUMN IF NOT EXISTS owner_user_id INT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS venue_id INT REFERENCES venues(id) ON DELETE SET NULL;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type VARCHAR(40) NOT NULL DEFAULT 'general';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_id VARCHAR(100);

UPDATE activities a SET venue_id = v.id
FROM venues v WHERE a.venue_id IS NULL AND LOWER(a.venue) = LOWER(v.name);

DO $$
BEGIN
  ALTER TABLE venue_bookings ADD CONSTRAINT venue_bookings_no_overlap EXCLUDE USING gist (
    venue_id WITH =,
    tstzrange(starts_at, ends_at, '[)') WITH &&
  ) WHERE (status IN ('pending','confirmed'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- INDEXES untuk performa query
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_activities_sport ON activities(sport);
CREATE INDEX IF NOT EXISTS idx_activities_city ON activities(city);
CREATE INDEX IF NOT EXISTS idx_activities_kind ON activities(kind);
CREATE INDEX IF NOT EXISTS idx_activities_starts ON activities(starts_at);
CREATE INDEX IF NOT EXISTS idx_participants_user ON activity_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_participants_activity ON activity_participants(activity_id);
CREATE INDEX IF NOT EXISTS idx_friends_user ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend ON friends(friend_id);
CREATE INDEX IF NOT EXISTS idx_rankings_sport ON rankings(sport);
CREATE INDEX IF NOT EXISTS idx_checkout_user ON checkout_previews(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
