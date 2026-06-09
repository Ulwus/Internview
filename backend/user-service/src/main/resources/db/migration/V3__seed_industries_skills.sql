-- Başlangıç sektör ve yetenek verileri.
-- Idempotent: tekrar çalıştırıldığında çakışmaları atlar.

-- industries
INSERT INTO industries (id, name, slug)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Yazılım', 'software'),
  ('11111111-1111-1111-1111-111111111112', 'FinTech', 'fintech'),
  ('11111111-1111-1111-1111-111111111113', 'E-ticaret', 'ecommerce'),
  ('11111111-1111-1111-1111-111111111114', 'Sağlık', 'healthcare'),
  ('11111111-1111-1111-1111-111111111115', 'Eğitim', 'education'),
  ('11111111-1111-1111-1111-111111111116', 'Oyun', 'gaming'),
  ('11111111-1111-1111-1111-111111111117', 'Telekom', 'telecom'),
  ('11111111-1111-1111-1111-111111111118', 'Siber Güvenlik', 'cybersecurity'),
  ('11111111-1111-1111-1111-111111111119', 'Yapay Zeka', 'ai'),
  ('11111111-1111-1111-1111-11111111111a', 'Ürün Yönetimi', 'product')
ON CONFLICT (slug) DO NOTHING;

-- skills
INSERT INTO skills (id, name, slug)
VALUES
  ('22222222-2222-2222-2222-222222222221', 'Flutter', 'flutter'),
  ('22222222-2222-2222-2222-222222222222', 'Dart', 'dart'),
  ('22222222-2222-2222-2222-222222222223', 'Java', 'java'),
  ('22222222-2222-2222-2222-222222222224', 'Spring Boot', 'spring-boot'),
  ('22222222-2222-2222-2222-222222222225', 'Node.js', 'nodejs'),
  ('22222222-2222-2222-2222-222222222226', 'TypeScript', 'typescript'),
  ('22222222-2222-2222-2222-222222222227', 'React', 'react'),
  ('22222222-2222-2222-2222-222222222228', 'Sistem Tasarımı', 'system-design'),
  ('22222222-2222-2222-2222-222222222229', 'Veritabanı', 'databases'),
  ('22222222-2222-2222-2222-22222222222a', 'Algoritmalar', 'algorithms')
ON CONFLICT (slug) DO NOTHING;

