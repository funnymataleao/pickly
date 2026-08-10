begin;

-- These product facts were imported from Open Food Facts on 2026-08-09.
-- Scores and explanations remain client-derived until a row is deliberately
-- curated for the current deterministic scoring policy.
with catalog as (
  select *
  from jsonb_to_recordset($catalog$
[
  {
    "barcode": "20047559",
    "name": "Greek Style Yogurt",
    "brand": "Pilos",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/000/002/004/7559/front_fr.20.400.jpg",
    "ingredients": [
      "cream",
      "skimmed milk retentate",
      "microbial cultures"
    ],
    "nutrition": {
      "sugars100g": 3.2,
      "salt100g": 0.13,
      "saturatedFat100g": 6.6,
      "proteins100g": 4.6,
      "fiber100g": 0.5
    }
  },
  {
    "barcode": "3124480184344",
    "name": "Orangina",
    "brand": "Orangina",
    "category": "Soft drinks",
    "image_url": "https://images.openfoodfacts.org/images/products/312/448/018/4344/front_fr.170.400.jpg",
    "ingredients": [
      "Eau gazéifiée",
      "jus d'agrumes à base de concentrés",
      "sucre",
      "pulpe d'orange",
      "mandarine",
      "extrait de zeste d'orange",
      "arômes naturels d'orange",
      "orange",
      "citron",
      "mandarine",
      "pamplemousse"
    ],
    "nutrition": {
      "sugars100g": 8.9,
      "salt100g": 0.1,
      "saturatedFat100g": 0,
      "proteins100g": 0.1
    }
  },
  {
    "barcode": "3478820600651",
    "name": "Spaghetti au quinoa, ail et persil",
    "brand": "Jardin Bio",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.net/images/products/347/882/060/0651/front_fr.75.400.jpg",
    "ingredients": [
      "Semoule semi-complète de BLE dur",
      "farine de quinoa royal",
      "persil",
      "ail"
    ],
    "nutrition": {
      "sugars100g": 2.1,
      "salt100g": 0.03,
      "saturatedFat100g": 0.4,
      "proteins100g": 12,
      "fiber100g": 4.7
    }
  },
  {
    "barcode": "42105220",
    "name": "Coca-Cola",
    "brand": "Coca-Cola",
    "category": "Soft drinks",
    "image_url": "https://images.openfoodfacts.net/images/products/000/004/210/5220/front_en.54.400.jpg",
    "ingredients": [
      "water",
      "sugar",
      "carbonic acid",
      "e150d",
      "e338",
      "natural flavors including caffeine"
    ],
    "nutrition": {
      "sugars100g": 10.6,
      "salt100g": 0,
      "saturatedFat100g": 0,
      "proteins100g": 0
    }
  },
  {
    "barcode": "5053990156009",
    "name": "Pringles Original",
    "brand": "Pringles",
    "category": "Potato chips",
    "image_url": "https://images.openfoodfacts.org/images/products/505/399/015/6009/front_fr.288.400.jpg",
    "ingredients": [
      "Pommes de terre",
      "huiles végétales",
      "farine de blé",
      "farine de mais",
      "farine de riz",
      "maltodextrine",
      "e471",
      "sel",
      "norbixine de rocou",
      "tournesol",
      "palme",
      "mais"
    ],
    "nutrition": {
      "sugars100g": 0.9,
      "salt100g": 1,
      "saturatedFat100g": 3,
      "proteins100g": 6.2,
      "fiber100g": 4.1
    }
  },
  {
    "barcode": "54022263",
    "name": "Schweppes Cola",
    "brand": "Schweppes",
    "category": "Soft drinks",
    "image_url": "https://images.openfoodfacts.org/images/products/000/005/402/2263/front_fr.3.400.jpg",
    "ingredients": [
      "ماء غازي",
      "سكر",
      "محمض",
      "نكهة",
      "محليات",
      "e950",
      "كافيين",
      "e330",
      "e955"
    ],
    "nutrition": {
      "sugars100g": 4.56,
      "salt100g": 0.05,
      "saturatedFat100g": 0,
      "proteins100g": 0
    }
  },
  {
    "barcode": "5449000000286",
    "name": "Coca-Cola Original",
    "brand": "Coca-Cola",
    "category": "Soft drinks",
    "image_url": "https://images.openfoodfacts.net/images/products/544/900/000/0286/front_en.167.400.jpg",
    "ingredients": [
      "Voda",
      "fruktozo-glukózový sirup",
      "Oxid uhličitý",
      "barvivo",
      "kyselina",
      "přirodni aromata",
      "aroma kofein",
      "Minimalni trvanlivost do",
      "Uchovávejte v chladu a suchu",
      "Nevystavujte přiměmu slunečnímu světlu",
      "e150d",
      "kyselina fosforečná",
      "viz hrdlo lahve"
    ],
    "nutrition": {
      "sugars100g": 10.6,
      "salt100g": 0,
      "saturatedFat100g": 0,
      "proteins100g": 0,
      "fiber100g": 0
    }
  },
  {
    "barcode": "5449000008046",
    "name": "Coca-Cola Slim 250 ml",
    "brand": "Coca-Cola",
    "category": "Soft drinks",
    "image_url": "https://images.openfoodfacts.org/images/products/544/900/000/8046/front_fr.62.400.jpg",
    "ingredients": [
      "water",
      "sugar",
      "carbon dioxide",
      "color",
      "phosphoric acid",
      "caffeine",
      "natural flavors",
      "e150d"
    ],
    "nutrition": {
      "sugars100g": 10.6,
      "salt100g": 0.0208,
      "saturatedFat100g": 0,
      "proteins100g": 0,
      "fiber100g": 0
    }
  },
  {
    "barcode": "5449000131836",
    "name": "Coca-Cola Zero 500 ml",
    "brand": "Coca-Cola",
    "category": "Soft drinks",
    "image_url": "https://images.openfoodfacts.net/images/products/544/900/013/1836/front_en.673.400.jpg",
    "ingredients": [
      "water",
      "carbonic acid",
      "colouring",
      "e150 sweeteners",
      "acesulfame k",
      "aspartame",
      "acidifiers",
      "acidity regulator",
      "natural flavourings",
      "flavouring caffeine",
      "cyclamate",
      "e338",
      "sodium citrates"
    ],
    "nutrition": {
      "sugars100g": 0,
      "salt100g": 0.05,
      "saturatedFat100g": 0,
      "proteins100g": 0,
      "fiber100g": 0
    }
  },
  {
    "barcode": "6111032009443",
    "name": "Activia ananas fraise",
    "brand": "Danone",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/611/103/200/9443/front_en.4.400.jpg",
    "ingredients": [
      "حليب بدون قشدة",
      "مسحوق الحليب بدون قشدة",
      "سكر",
      "قشدة",
      "زبدة",
      "مخثر",
      "نكهة",
      "خمائر حليبية لليوغورت تحتوي على بيفيدوباكتيريوم",
      "م.د",
      "نشا",
      "1‚2٪"
    ],
    "nutrition": {
      "sugars100g": 5.5,
      "salt100g": 0,
      "saturatedFat100g": 0.8,
      "proteins100g": 2.7,
      "fiber100g": 0
    }
  },
  {
    "barcode": "6111242102187",
    "name": "Ghani",
    "brand": "Jaouda",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/611/124/210/2187/front_fr.17.400.jpg",
    "ingredients": [
      "حليب طري جزئي الدهن",
      "مسحوق الحليب بدون قشدة",
      "سكر",
      "كاكاو",
      "شوكولاتة",
      "مخثر",
      "كاراگينان",
      "نكهة",
      "أملاح معدنية",
      "ڤيتامينات",
      "AوD3"
    ],
    "nutrition": {
      "sugars100g": 12,
      "salt100g": 0.2,
      "saturatedFat100g": 0.6,
      "proteins100g": 3.2
    }
  },
  {
    "barcode": "6111242102552",
    "name": "Dessert gourmand choco",
    "brand": "Jaouda",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/611/124/210/2552/front_fr.9.400.jpg",
    "ingredients": [
      "lait entier",
      "crème",
      "sucre",
      "épaississant",
      "carraghénane",
      "caramel",
      "arôme",
      "colorant naturel",
      "Matière grasse",
      "amidon"
    ],
    "nutrition": {
      "sugars100g": 10,
      "salt100g": 0,
      "saturatedFat100g": 0.833333333333333,
      "proteins100g": 3.33333333333333,
      "fiber100g": 1.66666666666667
    }
  },
  {
    "barcode": "6111242102941",
    "name": "Yogurt Bnine Banana",
    "brand": "Jaouda",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/611/124/210/2941/front_en.47.400.jpg",
    "ingredients": [
      "Lait Frais Partiellement Écrémé",
      "Poudre De Lait Écrémé",
      "Sucre",
      "Arôme",
      "Ferments Lactiques"
    ],
    "nutrition": {
      "sugars100g": 9.3,
      "salt100g": 0,
      "saturatedFat100g": 1.2,
      "proteins100g": 3.9
    }
  },
  {
    "barcode": "6111266962576",
    "name": "ديليسيوس بيرلي",
    "brand": "COPAG",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/611/126/696/2576/front_en.53.400.jpg",
    "ingredients": [
      "حليب طرى كامل الدسم",
      "قشدة سكر",
      "مسحوق الحليب بدون قشدة",
      "مخثر",
      "خمائر حليبية مختار",
      "نشا"
    ],
    "nutrition": {
      "sugars100g": 8.5,
      "salt100g": 0,
      "saturatedFat100g": 4.9,
      "proteins100g": 6.4,
      "fiber100g": 0
    }
  },
  {
    "barcode": "7613034626844",
    "name": "Chocapic Cereals",
    "brand": "Nestlé",
    "category": "Breakfast cereals",
    "image_url": "https://images.openfoodfacts.org/images/products/761/303/462/6844/front_fr.355.400.jpg",
    "ingredients": [
      "Blé complet",
      "chocolat en poudre",
      "farine de blé",
      "semoule de maïs",
      "sirop de glucose",
      "sucre",
      "extrait de malt d'orge",
      "contient de l'huile",
      "carbonate de calcium",
      "lécithines",
      "sel",
      "arômes naturels",
      "fer",
      "vitamines",
      "vitamine B3",
      "vitamine B5",
      "vitamine D",
      "vitamine B6",
      "vitamine B1",
      "vitamine B2",
      "vitamine B9",
      "sucre",
      "cacao en poudre",
      "orge",
      "orge malté",
      "huile de tournesol",
      "huile de palme"
    ],
    "nutrition": {
      "sugars100g": 22.4,
      "salt100g": 0.22,
      "saturatedFat100g": 2,
      "proteins100g": 8.8,
      "fiber100g": 7.5
    }
  },
  {
    "barcode": "8076800105056",
    "name": "Spaghetti N°5",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.net/images/products/807/680/010/5056/front_fr.1304.400.jpg",
    "ingredients": [
      "Semoule de BLÉ dur"
    ],
    "nutrition": {
      "sugars100g": 3.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.5,
      "proteins100g": 13,
      "fiber100g": 3
    }
  },
  {
    "barcode": "8076800105735",
    "name": "Penne Rigate N°73",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.net/images/products/807/680/010/5735/front_en.156.400.jpg",
    "ingredients": [
      "Semola di grano duro",
      "acqua"
    ],
    "nutrition": {
      "sugars100g": 3.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.5,
      "proteins100g": 13,
      "fiber100g": 3
    }
  },
  {
    "barcode": "8076800376999",
    "name": "Lasagne all’Uovo N°199",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.org/images/products/807/680/037/6999/front_it.330.400.jpg",
    "ingredients": [
      "Semola di grano duro",
      "uova fresche di categoria A"
    ],
    "nutrition": {
      "sugars100g": 3,
      "salt100g": 0.08,
      "saturatedFat100g": 1,
      "proteins100g": 14,
      "fiber100g": 3
    }
  },
  {
    "barcode": "8076802085738",
    "name": "Penne Rigate N°73",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.org/images/products/807/680/208/5738/front_en.3506.400.jpg",
    "ingredients": [
      "_Hartweizengrieß_",
      "Wasser"
    ],
    "nutrition": {
      "sugars100g": 3.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.5,
      "proteins100g": 13,
      "fiber100g": 3
    }
  },
  {
    "barcode": "8076802085981",
    "name": "Fusilli N°98",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.org/images/products/807/680/208/5981/front_en.44.400.jpg",
    "ingredients": [
      "Hartweizengrieß",
      "Wasser"
    ],
    "nutrition": {
      "sugars100g": 3.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.5,
      "proteins100g": 13,
      "fiber100g": 3
    }
  },
  {
    "barcode": "8076809529419",
    "name": "Whole Wheat Spaghetti",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.org/images/products/807/680/952/9419/front_fr.1666.400.jpg",
    "ingredients": [
      "Semoule complète de BLÉ dur"
    ],
    "nutrition": {
      "sugars100g": 3.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.5,
      "proteins100g": 13,
      "fiber100g": 8
    }
  },
  {
    "barcode": "8076809529433",
    "name": "Whole Wheat Penne Rigate",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.org/images/products/807/680/952/9433/front_en.451.400.jpg",
    "ingredients": [
      "_durumhvede_",
      "Vand"
    ],
    "nutrition": {
      "sugars100g": 3.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.5,
      "proteins100g": 13,
      "fiber100g": 8
    }
  },
  {
    "barcode": "8076809545440",
    "name": "Gluten-Free Spaghetti",
    "brand": "Barilla",
    "category": "Dry pasta",
    "image_url": "https://images.openfoodfacts.org/images/products/807/680/954/5440/front_en.245.400.jpg",
    "ingredients": [
      "Wit maïsmeel",
      "geel maïsmeel",
      "volkoren rijstmeel",
      "water",
      "emulgator",
      "mono- en diglyceriden van vetzuren"
    ],
    "nutrition": {
      "sugars100g": 0.5,
      "salt100g": 0.01,
      "saturatedFat100g": 0.3,
      "proteins100g": 6.5,
      "fiber100g": 1.1
    }
  },
  {
    "barcode": "8480000213587",
    "name": "Griego Ligero Natural",
    "brand": "Hacendado",
    "category": "Yogurt",
    "image_url": "https://images.openfoodfacts.org/images/products/848/000/021/3587/front_es.127.400.jpg",
    "ingredients": [
      "_Leche_ pasteurizada parcialmente desnatada",
      "_leche_ en polvo desnatada",
      "proteínas de la _leche_",
      "fermentos _lácticos_",
      "Origen"
    ],
    "nutrition": {
      "sugars100g": 4.7,
      "salt100g": 0.16,
      "saturatedFat100g": 1.4,
      "proteins100g": 5.8
    }
  }
]
$catalog$::jsonb) as catalog_row(
    barcode text,
    name text,
    brand text,
    category text,
    image_url text,
    ingredients jsonb,
    nutrition jsonb
  )
)
insert into public.products (
  barcode,
  name,
  brand,
  category,
  image_url,
  ingredients,
  nutrition,
  score,
  verdict,
  summary,
  reasons,
  warnings,
  positives,
  confidence,
  source,
  score_version,
  is_published
)
select
  catalog.barcode,
  catalog.name,
  catalog.brand,
  catalog.category,
  catalog.image_url,
  array(
    select jsonb_array_elements_text(catalog.ingredients)
  ),
  catalog.nutrition,
  null,
  'limited_data',
  '',
  '{}'::text[],
  '{}'::text[],
  '{}'::text[],
  'low',
  'openFoodFacts',
  'unversioned',
  true
from catalog
on conflict (barcode) do update
set
  name = excluded.name,
  brand = excluded.brand,
  category = excluded.category,
  image_url = excluded.image_url,
  ingredients = excluded.ingredients,
  nutrition = excluded.nutrition,
  score = null,
  verdict = 'limited_data',
  summary = '',
  reasons = '{}'::text[],
  warnings = '{}'::text[],
  positives = '{}'::text[],
  confidence = 'low',
  source = 'openFoodFacts',
  score_version = 'unversioned',
  is_published = true,
  updated_at = now();

with curated_relations(source_barcode, target_barcode, reason, rank) as (
  values
    ('3124480184344', '5449000131836', 'No sugar', 1),
    ('42105220', '5449000131836', 'No sugar', 1),
    ('54022263', '5449000131836', 'No sugar', 1),
    ('5449000000286', '5449000131836', 'No sugar', 1),
    ('5449000008046', '5449000131836', 'No sugar', 1),
    ('8076800195057', '8076809529419', 'More fiber', 1),
    ('8076800105056', '8076809529419', 'More fiber', 1),
    ('8076800105735', '8076809529433', 'More fiber', 1),
    ('8076802085738', '8076809529433', 'More fiber', 1),
    ('8076802085981', '8076809529433', 'More fiber', 1),
    ('8076800376999', '8076809529419', 'More fiber', 1),
    ('6111032009443', '8480000213587', 'Less sugar', 1),
    ('6111242102187', '8480000213587', 'Less sugar', 1),
    ('6111242102552', '8480000213587', 'Less sugar', 1),
    ('6111242102941', '8480000213587', 'Less sugar', 1),
    ('6111266962576', '8480000213587', 'Less sugar', 1)
)
insert into public.product_alternatives (
  product_id,
  alternative_product_id,
  reason,
  rank
)
select
  source_product.id,
  target_product.id,
  curated_relations.reason,
  curated_relations.rank
from curated_relations
join public.products source_product
  on source_product.barcode = curated_relations.source_barcode
join public.products target_product
  on target_product.barcode = curated_relations.target_barcode
on conflict (product_id, alternative_product_id) do update
set
  reason = excluded.reason,
  rank = excluded.rank;

commit;
