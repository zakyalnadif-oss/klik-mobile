-- ============================================================
-- KLIK Mobile — Seed Data (Data Awal dari Prototype Figma)
-- Jalankan: psql -U postgres -d klik_db -f seed.sql
-- ============================================================

-- Seed Venues
INSERT INTO venues (name, sport, address, description) VALUES
  ('Futsal Cilandak', 'Futsal', 'Cilandak, Jakarta Selatan', 'Lapangan futsal indoor. Lapangan berstandar dengan rumput sintetis berkualitas.'),
  ('Basket Bulungan', 'Basket', 'Kebayoran Baru, Jakarta Selatan', 'Lapangan basket semi-outdoor di kawasan Bulungan. Cocok untuk main kasual dan sparing.'),
  ('Biliar Fatmawati', 'Biliar', 'Fatmawati, Jakarta Selatan', 'Tempat bermain biliar dengan meja standar internasional. Suasana nyaman dan ber-AC.')
ON CONFLICT (name) DO NOTHING;

-- Seed Demo Players
INSERT INTO players (id, name, handle, sport, city, level, initials) VALUES
  ('adi', 'Adi Pratama', '@adi.pratama', 'Futsal', 'Jakarta Selatan', 'Menengah', 'AP'),
  ('rizky', 'Rizky Saputra', '@rizky', 'Futsal', 'Jakarta Selatan', 'Menengah', 'RS'),
  ('nanda', 'Nanda', '@nanda', 'Basket', 'Jakarta Selatan', 'Pemula', 'N')
ON CONFLICT (id) DO NOTHING;

-- Seed Rankings
INSERT INTO rankings (sport, type, rank, initials, name, detail, points, highlight) VALUES
  ('Futsal', 'Tim', 1, 'RP', 'Tim gacor', '28/35 menang • 80%', '1.680', false),
  ('Futsal', 'Tim', 2, 'NS', 'bobor squat', '24/32 menang • 75%', '1.520', false),
  ('Futsal', 'Tim', 3, 'WL', 'we are the campion', '21/30 menang • 70%', '1.360', false),
  ('Futsal', 'Tim', 4, 'AP', 'Kamu · Vokasi bogor', 'Posisi kamu · Futsal', '1.240', true)
ON CONFLICT DO NOTHING;

-- Seed Activities (waktu dibuat dinamis relatif terhadap hari ini)
INSERT INTO activities (id, kind, title, sport, venue, city, mode, starts_at, duration_minutes, capacity, occupied, price, owner, description, demo) VALUES
  ('event-cilandak', 'event', 'Futsal Cilandak Cup', 'Futsal', 'Futsal Cilandak', 'Jakarta Selatan', 'Berperingkat',
   NOW() + INTERVAL '7 days' + INTERVAL '9 hours', 360, 16, 6, 75000, 'Cilandak Sport Club',
   'Turnamen kompetitif. Datang 30 menit sebelum jadwal, gunakan sepatu futsal, dan junjung sportivitas.', true),

  ('room-cilandak', 'room', 'Futsal Cilandak Berperingkat', 'Futsal', 'Futsal Cilandak', 'Jakarta Selatan', 'Berperingkat',
   NOW() + INTERVAL '1 days' + INTERVAL '19 hours', 120, 10, 3, 35000, 'Tim Rizky',
   'Cari rekan main futsal. Semua pemain wajib hadir tepat waktu. Pembagian biaya lapangan dilakukan langsung di lokasi.', true),

  ('room-basket', 'room', 'Basket Jumat malam', 'Basket', 'Basket Bulungan', 'Jakarta Selatan', 'Kasual',
   NOW() + INTERVAL '3 days' + INTERVAL '20 hours', 120, 10, 6, 25000, 'Tim Bulungan',
   'Main basket kasual bersama. Terbuka untuk pemula dan menengah.', true),

  ('room-biliar', 'room', 'Biliar akhir pekan', 'Biliar', 'Biliar Fatmawati', 'Jakarta Selatan', 'Kasual',
   NOW() + INTERVAL '4 days' + INTERVAL '19 hours', 120, 4, 2, 50000, 'Bayu',
   'Latihan biliar santai, bergantian bermain dan saling belajar.', true)
ON CONFLICT (id) DO NOTHING;

-- Seed Team & Ranked Match untuk room-cilandak
INSERT INTO teams (id, name, captain_id, captain_name) VALUES
  ('example-team-rizky', 'Tim Rizky', 'rizky', 'Rizky Saputra')
ON CONFLICT (id) DO NOTHING;

INSERT INTO ranked_matches (activity_id, team_a_id) VALUES
  ('room-cilandak', 'example-team-rizky')
ON CONFLICT (activity_id) DO NOTHING;
