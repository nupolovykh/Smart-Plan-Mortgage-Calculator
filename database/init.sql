-- Database initialization script for Smart Plan Mortgage Calculator
-- Run with: sqlite3 database.sqlite < database/init.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS promos (
    id INTEGER PRIMARY KEY,
    discount_value REAL NOT NULL,
    discount_type TEXT NOT NULL CHECK(discount_type IN ('%', 'rub'))
);

CREATE TABLE IF NOT EXISTS areas (
    id INTEGER PRIMARY KEY,
    price REAL NOT NULL,
    promo_id INTEGER,
    address TEXT,
    FOREIGN KEY (promo_id) REFERENCES promos(id)
);

CREATE TABLE IF NOT EXISTS payment_methods (
    id INTEGER PRIMARY KEY,
    estimated_rate REAL NOT NULL,
    bank_name TEXT NOT NULL,
    logo TEXT
);

CREATE TABLE IF NOT EXISTS requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_method_id INTEGER NOT NULL,
    maternal_capital REAL NOT NULL DEFAULT 0,
    monthly_payment REAL NOT NULL,
    initial_payment REAL NOT NULL,
    mortgage_term INTEGER NOT NULL CHECK(mortgage_term > 0),
    realty_id INTEGER NOT NULL,
    promo_id INTEGER,
    price REAL NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
    FOREIGN KEY (realty_id) REFERENCES areas(id),
    FOREIGN KEY (promo_id) REFERENCES promos(id)
);
