-- Tambah lapangan untuk semua 7 cabor
INSERT INTO venues (name, sport, address, description) VALUES
  ('Voli Senayan', 'Voli', 'Gelora Bung Karno, Senayan, Jakarta Pusat', 'Lapangan voli outdoor dan indoor berstandar PBVSI dengan pencahayaan malam hari.'),
  ('Padel Kemang', 'Padel', 'Kemang, Jakarta Selatan', 'Klub padel modern dengan 4 lapangan panoramik dan penyewaan raket serta bola.'),
  ('Badminton Kuningan', 'Bulu Tangkis', 'Kuningan, Jakarta Selatan', 'GOR bulutangkis berlantai karpet vinyl dengan 6 lapangan.'),
  ('Mini Soccer BSD', 'Sepak Bola', 'BSD City, Tangerang Selatan', 'Lapangan mini soccer 7v7 berumput sintetis standar FIFA.')
ON CONFLICT (name) DO NOTHING;

-- Tambah pemain untuk cabor lainnya
INSERT INTO players (id, name, handle, sport, city, level, initials) VALUES
  ('budi', 'Budi Santoso', '@budi.voli', 'Voli', 'Jakarta Selatan', 'Mahir', 'BS'),
  ('clara', 'Clara Wijaya', '@clara.padel', 'Padel', 'Jakarta Selatan', 'Pemula', 'CW'),
  ('hendra', 'Hendra Setiawan', '@hendra.badminton', 'Bulu Tangkis', 'Jakarta Selatan', 'Mahir', 'HS'),
  ('dimas', 'Dimas Anggara', '@dimas.soccer', 'Sepak Bola', 'Jakarta Selatan', 'Menengah', 'DA')
ON CONFLICT (id) DO NOTHING;

-- Tambah aktivitas untuk semua 7 cabor
INSERT INTO activities (id, kind, title, sport, venue, city, mode, starts_at, duration_minutes, capacity, occupied, price, owner, description, demo) VALUES
  ('room-voli', 'room', 'Voli Sore GBK', 'Voli', 'Voli Senayan', 'Jakarta Pusat', 'Kasual',
   NOW() + INTERVAL '2 days' + INTERVAL '16 hours', 120, 12, 4, 20000, 'Budi Santoso',
   'Main voli santai sore. Campur cowok-cewek, semua level boleh ikutan.', true),

  ('room-padel', 'room', 'Padel Friendly Match', 'Padel', 'Padel Kemang', 'Jakarta Selatan', 'Kasual',
   NOW() + INTERVAL '3 days' + INTERVAL '18 hours', 90, 4, 2, 85000, 'Clara Wijaya',
   'Sparing padel 2v2. Raket sudah disediakan di lokasi jika belum punya.', true),

  ('room-badminton', 'room', 'Mabar Badminton Kuningan', 'Bulu Tangkis', 'Badminton Kuningan', 'Jakarta Selatan', 'Berperingkat',
   NOW() + INTERVAL '2 days' + INTERVAL '19 hours', 120, 8, 3, 30000, 'Hendra Setiawan',
   'Sparing ganda bulutangkis. Shuttlecock disediakan panitia.', true),

  ('room-soccer', 'room', 'Mini Soccer 7v7 Malam', 'Sepak Bola', 'Mini Soccer BSD', 'Tangerang Selatan', 'Kasual',
   NOW() + INTERVAL '4 days' + INTERVAL '20 hours', 120, 14, 8, 45000, 'Dimas Anggara',
   'Fun football 7v7. Rompi dan bola sudah disiapkan.', true)
ON CONFLICT (id) DO NOTHING;

-- Tambah leaderboard rankings untuk cabor lain
INSERT INTO rankings (sport, type, rank, initials, name, detail, points, highlight) VALUES
  ('Basket', 'Tim', 1, 'BB', 'Bulungan Ballers', '18/22 menang - 81%', '1.450', false),
  ('Basket', 'Tim', 2, 'JK', 'Jakarta Knights', '15/20 menang - 75%', '1.280', false),
  ('Bulu Tangkis', 'Individu', 1, 'HS', 'Hendra S.', '32/35 menang - 91%', '2.100', false),
  ('Bulu Tangkis', 'Individu', 2, 'TH', 'Taufik H.', '29/34 menang - 85%', '1.920', false),
  ('Sepak Bola', 'Tim', 1, 'FC', 'Garuda Muda', '12/15 menang - 80%', '1.150', false)
ON CONFLICT DO NOTHING;
