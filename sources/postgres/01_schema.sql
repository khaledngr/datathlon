-- Datathlon · web shop database (PostgreSQL), adapted from TD 2 01_create_merch_db.sql
-- Runs automatically on the container's first start (docker-entrypoint-initdb.d).
-- Changes from TD 2: schema merch -> datathlon, GBP -> EUR, stores table, fulfilment + store_id
-- (click & collect), is_test flag (UC1 exclusion), product status (UC3 exclusion).
-- The data is loaded by generate_orders.py from sources/catalogue/*.csv.

CREATE SCHEMA IF NOT EXISTS datathlon;

CREATE TABLE datathlon.products (
    sku          text PRIMARY KEY,
    name         text NOT NULL,
    category     text NOT NULL,
    price_eur    numeric(8,2) NOT NULL CHECK (price_eur > 0),
    status       text NOT NULL CHECK (status IN ('active', 'discontinued'))
);

CREATE TABLE datathlon.stores (
    store_id     text PRIMARY KEY,
    name         text NOT NULL,
    city         text NOT NULL,
    country      text NOT NULL,
    latitude     numeric(8,4) NOT NULL,
    longitude    numeric(8,4) NOT NULL
);

CREATE TABLE datathlon.orders (
    order_id     integer PRIMARY KEY,
    customer_ref text        NOT NULL,                -- a code only: no personal data (GDPR)
    fulfilment   text        NOT NULL CHECK (fulfilment IN ('home_delivery', 'click_collect')),
    store_id     text REFERENCES datathlon.stores(store_id), -- pick-up store, click & collect only
    status       text        NOT NULL CHECK (status IN ('paid', 'cancelled', 'refunded')),
    is_test      boolean     NOT NULL DEFAULT false,  -- QA orders on the live site: excluded from revenue
    order_ts     timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    CHECK ((fulfilment = 'click_collect') = (store_id IS NOT NULL))
);

CREATE TABLE datathlon.order_lines (
    order_id       integer REFERENCES datathlon.orders(order_id) ON DELETE CASCADE,
    line_no        integer NOT NULL,
    sku            text    NOT NULL REFERENCES datathlon.products(sku),
    qty            integer NOT NULL CHECK (qty > 0),
    unit_price_eur numeric(8,2) NOT NULL,
    PRIMARY KEY (order_id, line_no)
);

-- Every UPDATE refreshes updated_at: this is the cursor (watermark) of the incremental load (step 5). From TD 2.
-- One change from TD 2: if the UPDATE sets updated_at itself, it is kept. Only the generator's --init uses this,
-- to write the history of past refunds at their real date instead of "now".
CREATE OR REPLACE FUNCTION datathlon.touch_updated_at() RETURNS trigger AS $$
BEGIN
    IF NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at THEN
        NEW.updated_at := clock_timestamp();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_touch BEFORE UPDATE ON datathlon.orders
    FOR EACH ROW EXECUTE FUNCTION datathlon.touch_updated_at();

CREATE INDEX orders_updated_at ON datathlon.orders (updated_at); -- the incremental query filters on it
