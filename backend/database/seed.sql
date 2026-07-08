-- Seed data for Smart Plan Mortgage Calculator

-- Areas
INSERT OR IGNORE INTO areas (id, price, promo_id, address) VALUES (42, 1649700.0, 7, '. ,  , . , . 42');
INSERT OR IGNORE INTO areas (id, price, promo_id, address) VALUES (131, 1623850.0, NULL, 'Новосибирская обл., Колыванский район, ДНП Рыбачий, ул. Озерная, уч. 131');
INSERT OR IGNORE INTO areas (id, price, promo_id, address) VALUES (205, 2450000.0, 8, 'г. Новосибирск, ДНП Ключевой, ул. Лесная, уч. 205');
INSERT OR IGNORE INTO areas (id, price, promo_id, address) VALUES (312, 3100000.0, 9, 'Новосибирская обл., Новосибирский район, с. Марусино, мкрн Благовещенка, уч. 312');
INSERT OR IGNORE INTO areas (id, price, promo_id, address) VALUES (501, 1200000.0, NULL, 'Новосибирская обл., Ордынский район, с. Красный Яр, ул. Береговая, уч. 501');

-- Promos
INSERT OR IGNORE INTO promos (id, discount_value, discount_type) VALUES (7, 10.0, '%');
INSERT OR IGNORE INTO promos (id, discount_value, discount_type) VALUES (8, 150000.0, 'rub');
INSERT OR IGNORE INTO promos (id, discount_value, discount_type) VALUES (9, 5.0, '%');

-- Payment methods
-- Logos are served from frontend/public/logos/ (self-hosted) rather than hotlinked
-- from bank websites, which change asset paths without notice and 404/403 hotlinks.
INSERT OR IGNORE INTO payment_methods (id, estimated_rate, bank_name, logo) VALUES (1, 8.5, 'СберБанк (Семейная ипотека)', '/logos/sberbank.svg');
INSERT OR IGNORE INTO payment_methods (id, estimated_rate, bank_name, logo) VALUES (2, 3.0, 'Россельхозбанк (Сельская ипотека)', '/logos/rosselkhozbank.svg');
INSERT OR IGNORE INTO payment_methods (id, estimated_rate, bank_name, logo) VALUES (3, 12.0, 'ВТБ (Базовая программа)', '/logos/vtb.svg');
INSERT OR IGNORE INTO payment_methods (id, estimated_rate, bank_name, logo) VALUES (4, 9.0, 'Альфа-Банк (Господдержка)', '/logos/alfabank.svg');