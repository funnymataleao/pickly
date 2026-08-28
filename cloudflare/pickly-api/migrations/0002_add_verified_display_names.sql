-- `name` preserves the imported catalog label. `display_name` is reserved for
-- reviewed English UI copy, so a source-language label is never presented as
-- if it had been translated or verified.
ALTER TABLE products ADD COLUMN display_name TEXT;

CREATE INDEX IF NOT EXISTS products_display_name_idx
  ON products(display_name COLLATE NOCASE);

-- Only backfill entries whose English descriptor was explicitly reviewed from
-- the product's already-curated brand and English category. Do not infer or
-- machine-translate product names that are not on this allowlist.
UPDATE products
SET display_name = CASE barcode
  WHEN '3478820600651' THEN 'Jardin Bio Dry Pasta'
  WHEN '6111032009443' THEN 'Danone Yogurt'
  WHEN '6111242102552' THEN 'Jaouda Yogurt'
  WHEN '6111266962576' THEN 'COPAG Yogurt'
  WHEN '8076800376999' THEN 'Barilla Dry Pasta'
  WHEN '8480000213587' THEN 'Hacendado Yogurt'
END
WHERE is_published = 1
  AND barcode IN (
    '3478820600651',
    '6111032009443',
    '6111242102552',
    '6111266962576',
    '8076800376999',
    '8480000213587'
  );
