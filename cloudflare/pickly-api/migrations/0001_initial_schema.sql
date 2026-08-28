PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  display_name TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id TEXT PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  sensitive_digestion INTEGER NOT NULL DEFAULT 0,
  low_sugar INTEGER NOT NULL DEFAULT 0,
  low_sodium INTEGER NOT NULL DEFAULT 0,
  vegetarian INTEGER NOT NULL DEFAULT 0,
  vegan INTEGER NOT NULL DEFAULT 0,
  gluten_free INTEGER NOT NULL DEFAULT 0,
  lactose_free INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  barcode TEXT UNIQUE,
  name TEXT NOT NULL,
  brand TEXT,
  category TEXT NOT NULL DEFAULT 'Grocery',
  image_url TEXT,
  ingredients TEXT NOT NULL DEFAULT '[]',
  nutrition TEXT NOT NULL DEFAULT '{}',
  score INTEGER CHECK (score BETWEEN 0 AND 100),
  verdict TEXT NOT NULL DEFAULT 'limited_data' CHECK (verdict IN ('great', 'good', 'okay', 'not_great', 'limited_data')),
  summary TEXT NOT NULL DEFAULT '',
  reasons TEXT NOT NULL DEFAULT '[]',
  warnings TEXT NOT NULL DEFAULT '[]',
  positives TEXT NOT NULL DEFAULT '[]',
  confidence TEXT NOT NULL DEFAULT 'low' CHECK (confidence IN ('high', 'medium', 'low')),
  source TEXT NOT NULL DEFAULT 'manual',
  score_version TEXT NOT NULL DEFAULT 'mvp-v1',
  is_published INTEGER NOT NULL DEFAULT 1 CHECK (is_published IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_alternatives (
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  alternative_product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  rank INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (product_id, alternative_product_id),
  CHECK (product_id <> alternative_product_id)
);

CREATE TABLE IF NOT EXISTS saved_products (
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  saved_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, product_id)
);

CREATE TABLE IF NOT EXISTS scan_history (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  product_id TEXT REFERENCES products(id) ON DELETE SET NULL,
  barcode TEXT,
  source TEXT NOT NULL DEFAULT 'barcode' CHECK (source IN ('barcode', 'search', 'manual')),
  scanned_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS product_requests (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  barcode TEXT,
  name TEXT,
  brand TEXT,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'reviewing', 'added', 'rejected')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS products_published_updated_idx ON products(is_published, updated_at DESC);
CREATE INDEX IF NOT EXISTS products_name_idx ON products(name COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS products_brand_idx ON products(brand COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS products_category_idx ON products(category COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS product_alternatives_product_rank_idx ON product_alternatives(product_id, rank);
CREATE INDEX IF NOT EXISTS saved_products_user_saved_at_idx ON saved_products(user_id, saved_at DESC);
CREATE INDEX IF NOT EXISTS scan_history_user_scanned_at_idx ON scan_history(user_id, scanned_at DESC);
CREATE INDEX IF NOT EXISTS product_requests_user_created_at_idx ON product_requests(user_id, created_at DESC);
