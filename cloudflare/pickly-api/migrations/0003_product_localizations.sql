-- Localized catalog presentation is kept separate from the canonical product
-- facts. A missing translation never changes the score or the source data.
CREATE TABLE IF NOT EXISTS product_localizations (
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  language TEXT NOT NULL CHECK (language IN ('en', 'fr', 'de', 'es', 'it', 'pt', 'da', 'pl', 'cs')),
  name TEXT,
  category TEXT,
  ingredients TEXT,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (product_id, language)
);

CREATE INDEX IF NOT EXISTS product_localizations_language_idx
  ON product_localizations(language, product_id);
