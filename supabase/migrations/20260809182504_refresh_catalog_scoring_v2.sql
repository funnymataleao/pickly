begin;

-- New or manually curated rows must opt in to the scoring version explicitly.
-- The iOS client recomputes unversioned/legacy rows with its deterministic
-- ScoringService instead of trusting stale server copy.
alter table public.products
alter column score_version set default 'unversioned';

update public.products
set
  nutrition = '{"sugars100g":10.6,"salt100g":0.0,"saturatedFat100g":0.0,"proteins100g":0.0}'::jsonb,
  score = 62,
  verdict = 'okay',
  summary = 'An okay option, though its sugar level makes it better as an occasional choice.',
  reasons = array[
    'Added sugar data is not available, so this uses total sugar',
    'Ingredient list is reasonably short'
  ],
  warnings = array['Contains more sugar than ideal for everyday use'],
  positives = array['Low salt per 100g', 'Low saturated fat per 100g'],
  confidence = 'high',
  score_version = 'mvp-v2',
  updated_at = now()
where barcode = '5449000000996';

update public.products
set
  nutrition = '{"sugars100g":32.0,"salt100g":0.51,"saturatedFat100g":5.6,"proteins100g":6.3,"fiber100g":3.0}'::jsonb,
  score = 51,
  verdict = 'okay',
  summary = 'An okay option, though some nutrition details may make it better as an occasional choice.',
  reasons = array[
    'Added sugar data is not available, so this uses total sugar',
    'Moderate sodium level per 100g',
    'Ingredient list is reasonably short'
  ],
  warnings = array[
    'High sugar level per 100g',
    'Saturated fat is higher than ideal for everyday use'
  ],
  positives = array['Contains some protein', 'Contains some fiber'],
  confidence = 'high',
  score_version = 'mvp-v2',
  updated_at = now()
where barcode = '7622210449283';

commit;
