-- =========================================================
-- AI-Driven Smart Inventory Management System — DB Schema
-- Target: PostgreSQL 14+
-- =========================================================

-- ---------- USERS ----------
CREATE TABLE users (
    user_id         SERIAL PRIMARY KEY,
    username        VARCHAR(50)  NOT NULL UNIQUE,
    email           VARCHAR(120) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            VARCHAR(20)  NOT NULL DEFAULT 'staff', -- admin, manager, staff
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ---------- SUPPLIERS ----------
CREATE TABLE suppliers (
    supplier_id     SERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    contact_email   VARCHAR(120),
    contact_phone   VARCHAR(30),
    address         TEXT,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ---------- CATEGORIES ----------
CREATE TABLE categories (
    category_id     SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    parent_id       INT REFERENCES categories(category_id) ON DELETE SET NULL
);

-- ---------- WAREHOUSES / LOCATIONS ----------
CREATE TABLE warehouses (
    warehouse_id    SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    location        VARCHAR(200),
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ---------- PRODUCTS ----------
CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(50)  NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    category_id     INT REFERENCES categories(category_id) ON DELETE SET NULL,
    supplier_id     INT REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    unit_price      NUMERIC(10,2) NOT NULL DEFAULT 0,
    unit_cost       NUMERIC(10,2) NOT NULL DEFAULT 0,
    reorder_point   INT NOT NULL DEFAULT 10,   -- threshold that triggers low-stock alert
    reorder_qty     INT NOT NULL DEFAULT 50,   -- suggested reorder amount (can be AI-updated)
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_supplier ON products(supplier_id);

-- ---------- CURRENT STOCK (per product, per warehouse) ----------
CREATE TABLE inventory (
    inventory_id    SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id    INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    quantity_on_hand INT NOT NULL DEFAULT 0,
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, warehouse_id)
);

CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inventory_warehouse ON inventory(warehouse_id);

-- ---------- STOCK TRANSACTIONS (the ledger — source of truth for forecasting) ----------
CREATE TABLE stock_transactions (
    transaction_id  SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id    INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    user_id         INT REFERENCES users(user_id) ON DELETE SET NULL,
    transaction_type VARCHAR(20) NOT NULL, -- 'inbound', 'outbound', 'adjustment', 'return'
    quantity        INT NOT NULL,          -- positive number; direction implied by type
    reference_note  VARCHAR(255),
    transaction_date TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Critical indexes: forecasting queries and Power BI will filter/group by these constantly
CREATE INDEX idx_txn_product_date ON stock_transactions(product_id, transaction_date);
CREATE INDEX idx_txn_warehouse_date ON stock_transactions(warehouse_id, transaction_date);
CREATE INDEX idx_txn_type ON stock_transactions(transaction_type);

-- ---------- DAILY INVENTORY SNAPSHOTS (pre-aggregated for fast forecasting/reporting) ----------
-- Populate this via a nightly job: one row per product per warehouse per day.
CREATE TABLE inventory_snapshots (
    snapshot_id     SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id    INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    snapshot_date   DATE NOT NULL,
    quantity_on_hand INT NOT NULL,
    units_sold      INT NOT NULL DEFAULT 0,   -- outbound qty that day, precomputed
    units_received  INT NOT NULL DEFAULT 0,   -- inbound qty that day, precomputed
    UNIQUE (product_id, warehouse_id, snapshot_date)
);

CREATE INDEX idx_snapshot_date ON inventory_snapshots(snapshot_date);
CREATE INDEX idx_snapshot_product_date ON inventory_snapshots(product_id, snapshot_date);

-- ---------- DEMAND FORECASTS (AI model output) ----------
CREATE TABLE demand_forecasts (
    forecast_id     SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id    INT REFERENCES warehouses(warehouse_id) ON DELETE CASCADE, -- NULL = all warehouses combined
    forecast_date   DATE NOT NULL,        -- the future date being predicted
    predicted_demand NUMERIC(10,2) NOT NULL,
    lower_bound     NUMERIC(10,2),        -- confidence interval, optional
    upper_bound     NUMERIC(10,2),
    model_version   VARCHAR(50) NOT NULL, -- e.g. 'prophet_v1', 'sarima_2026-08-01'
    generated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, warehouse_id, forecast_date, model_version)
);

CREATE INDEX idx_forecast_product_date ON demand_forecasts(product_id, forecast_date);

-- ---------- LOW STOCK / REORDER ALERTS (optional but useful for the app UI) ----------
CREATE TABLE alerts (
    alert_id        SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id    INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    alert_type      VARCHAR(30) NOT NULL,  -- 'low_stock', 'reorder_suggested'
    message         VARCHAR(255),
    is_resolved     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alerts_unresolved ON alerts(is_resolved) WHERE is_resolved = FALSE;
