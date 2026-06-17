-- Database initialization script for Smart Plan Mortgage Calculator
-- Run with: sqlite3 database.sqlite < database/init.sql

CREATE TABLE IF NOT EXISTS areas (
    id INTEGER PRIMARY KEY,
    price REAL,
    promo_id INTEGER,
    address TEXT
);

CREATE TABLE IF NOT EXISTS promos (
    id INTEGER PRIMARY KEY,
    discount_value REAL,
    discount_type TEXT
);

CREATE TABLE IF NOT EXISTS payment_methods (
    id INTEGER PRIMARY KEY,
    estimated_rate REAL,
    bank_name TEXT,
    logo TEXT
);

CREATE TABLE IF NOT EXISTS requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_method_id INTEGER,
    maternal_capital REAL,
    monthly_payment REAL,
    initial_payment REAL,
    mortgage_term INTEGER,
    realty_id INTEGER,
    promo_id INTEGER,
    price REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);