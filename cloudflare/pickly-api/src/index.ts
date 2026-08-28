import { createRemoteJWKSet, jwtVerify } from "jose";

type ProductRow = Record<string, unknown> & {
	id: string;
	ingredients: string;
	nutrition: string;
	reasons: string;
	warnings: string;
	positives: string;
	is_published: number;
	localized_name?: string | null;
	localized_category?: string | null;
	localized_ingredients?: string | null;
};

type ProductLocalizationRow = {
	product_id: string;
	language: ProductLanguage;
	name: string | null;
	category: string | null;
	ingredients: string | null;
};

const MAX_PRODUCTS = 100;
const DEFAULT_GOAL_PAGE_SIZE = 24;
const MAX_GOAL_PAGE_SIZE = 50;
const GOAL_CACHE_CONTROL = "public, max-age=300, s-maxage=3600";
const OPEN_FOOD_FACTS_CACHE_SCHEMA = "5";
const DEFAULT_PRODUCT_LANGUAGE = "en";
const SUPPORTED_PRODUCT_LANGUAGES = ["en", "pt", "es", "fr", "de", "it", "da", "pl", "cs"] as const;
type ProductLanguage = typeof SUPPORTED_PRODUCT_LANGUAGES[number];
const OPEN_FOOD_FACTS_SEARCHALICIOUS_URL = "https://search.openfoodfacts.org/search";
const OPEN_FOOD_FACTS_SEARCH_URL = "https://world.openfoodfacts.org/api/v2/search";
const OPEN_FOOD_FACTS_LEGACY_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl";
const OPEN_FOOD_FACTS_USER_AGENT = "Pickly/1.0 (https://github.com/funnymataleao/pickly/issues)";
const OPEN_FOOD_FACTS_FIELDS = [
	"code",
	"product_name",
	"product_name_en",
	"product_name_pt",
	"product_name_es",
	"product_name_fr",
	"product_name_de",
	"product_name_it",
	"product_name_da",
	"product_name_pl",
	"product_name_cs",
	"generic_name",
	"generic_name_en",
	"generic_name_pt",
	"generic_name_es",
	"generic_name_fr",
	"generic_name_de",
	"generic_name_it",
	"generic_name_da",
	"generic_name_pl",
	"generic_name_cs",
	"lang",
	"languages_tags",
	"countries_tags",
	"brands",
	"categories",
	"categories_tags",
	"image_front_url",
	"image_url",
	"ingredients",
	"ingredients_text",
	"ingredients_text_en",
	"ingredients_text_pt",
	"ingredients_text_es",
	"ingredients_text_fr",
	"ingredients_text_de",
	"ingredients_text_it",
	"ingredients_text_da",
	"ingredients_text_pl",
	"ingredients_text_cs",
	"ingredients_lc",
	"ingredients_tags",
	"ingredients_n",
	"nutriments",
	"additives_tags",
	"labels_tags",
	"allergens_tags",
	"traces_tags",
	"nutrient_levels_tags",
].join(",");
const BROAD_ENGLISH_CATEGORY_TAGS = new Set([
	"en:foods",
	"en:groceries",
	"en:plant-based-foods-and-beverages",
	"en:plant-based-foods",
	"en:beverages",
	"en:dairies",
	"en:condiments",
	"en:sauces",
	"en:tomato-sauces",
	"en:snacks",
	"en:breakfasts",
	"en:cereals-and-potatoes",
]);

const GOAL_FILTERS = {
	lowSugar: ["nutrient_levels_tags", "en:sugars-in-low-quantity"],
	lowSodium: ["nutrient_levels_tags", "en:salt-in-low-quantity"],
	highProtein: ["nutrient_levels_tags", "en:proteins-in-high-quantity"],
	sensitiveDigestion: ["nutrient_levels_tags", "en:saturated-fat-in-low-quantity"],
	vegetarian: ["labels_tags", "en:vegetarian"],
	vegan: ["labels_tags", "en:vegan"],
	glutenFree: ["labels_tags", "en:no-gluten"],
	lactoseFree: ["labels_tags", "en:no-lactose"],
} as const;

type GoalID = keyof typeof GOAL_FILTERS;
const GOAL_SEARCH_QUERIES: Record<GoalID, string> = {
	lowSugar: "nutriments.sugars_100g:[0 TO 5]",
	lowSodium: "nutriments.salt_100g:[0 TO 0.8]",
	highProtein: "nutriments.proteins_100g:[8 TO *]",
	sensitiveDigestion: "nutriments.saturated-fat_100g:[0 TO 3] AND nutriments.sugars_100g:[0 TO 5] AND nutriments.salt_100g:[0 TO 0.8] AND ingredients_n:[1 TO 4]",
	vegetarian: 'labels_tags:"en:vegetarian"',
	vegan: 'labels_tags:"en:vegan"',
	glutenFree: 'labels_tags:("en:no-gluten" OR "en:gluten-free")',
	lactoseFree: 'labels_tags:("en:no-lactose" OR "en:lactose-free" OR "en:without-lactose")',
};
const jwksByProject = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

export default {
	async fetch(request, env, ctx): Promise<Response> {
		const url = new URL(request.url);
		const method = request.method.toUpperCase();

		if (method === "OPTIONS") return cors(new Response(null, { status: 204 }));
		if (method === "GET" && url.pathname === "/health") return json({ ok: true });

		try {
			const goalMatch = url.pathname.match(/^\/v1\/goals\/([^/]+)$/);
			if (method === "GET" && goalMatch) {
				return await listGoalProducts(url, goalMatch[1], ctx);
			}
			const categoryMatch = url.pathname.match(/^\/v1\/categories\/([^/]+)$/);
			if (method === "GET" && categoryMatch) {
				return await listCategoryProducts(url, categoryMatch[1], ctx);
			}
			const offProductMatch = url.pathname.match(/^\/v1\/off\/products\/([^/]+)$/);
			if (method === "GET" && offProductMatch) {
				return await openFoodFactsProductMetadata(url, offProductMatch[1], ctx);
			}
			if (method === "GET" && url.pathname === "/v1/products") {
				return await listProducts(url, env);
			}
			if (method === "GET" && url.pathname.startsWith("/v1/products/barcode/")) {
				return await productByBarcode(url, env);
			}
			if (method === "POST" && url.pathname === "/v1/product-requests") {
				return await createProductRequest(request, env);
			}
			if (method === "DELETE" && url.pathname === "/v1/account/data") {
				return await deleteAccountData(request, env);
			}

			return json({ error: "not_found" }, 404);
		} catch (error) {
			console.error("Pickly API request failed", error instanceof Error ? error.message : "unknown");
			return json({ error: "internal_error" }, 500);
		}
	},
} satisfies ExportedHandler<Env>;

async function listGoalProducts(
	requestURL: URL,
	encodedGoal: string,
	ctx: ExecutionContext,
): Promise<Response> {
	const goal = decodePathSegment(encodedGoal);
	if (!goal || !isGoalID(goal)) return json({ error: "invalid_goal" }, 400);

	const page = positiveIntegerQuery(requestURL, "page", 1);
	const pageSize = positiveIntegerQuery(requestURL, "page_size", DEFAULT_GOAL_PAGE_SIZE);
	if (page === null || pageSize === null || pageSize > MAX_GOAL_PAGE_SIZE) {
		return json({ error: "invalid_pagination" }, 400);
	}
	const language = productLanguageQuery(requestURL);
	if (!language) return json({ error: "invalid_language" }, 400);

	const cacheURL = new URL(`/v1/goals/${goal}`, requestURL.origin);
	cacheURL.searchParams.set("page", String(page));
	cacheURL.searchParams.set("page_size", String(pageSize));
	cacheURL.searchParams.set("lang", language);
	cacheURL.searchParams.set("schema", OPEN_FOOD_FACTS_CACHE_SCHEMA);
	const cacheKey = new Request(cacheURL.toString(), { method: "GET" });
	const cache = caches.default;

	try {
		const cachedResponse = await cache.match(cacheKey);
		if (cachedResponse) return cachedResponse;
	} catch (error) {
		console.warn("Pickly goal cache read failed", error instanceof Error ? error.message : "unknown");
	}

	const [filterName, filterValue] = GOAL_FILTERS[goal];
	const searchALiciousResponse = await searchALiciousGoalPage(goal, page, pageSize, language);
	if (searchALiciousResponse) {
		return cacheOpenFoodFactsResponse(searchALiciousResponse, cache, cacheKey, ctx);
	}

	const upstreamURL = new URL(OPEN_FOOD_FACTS_SEARCH_URL);
	upstreamURL.searchParams.set("product_type", "food");
	upstreamURL.searchParams.set(filterName, filterValue);
	upstreamURL.searchParams.set("page", String(page));
	upstreamURL.searchParams.set("page_size", String(pageSize));
	upstreamURL.searchParams.set("sort_by", "unique_scans_n");
	upstreamURL.searchParams.set("lc", language);
	upstreamURL.searchParams.set("fields", OPEN_FOOD_FACTS_FIELDS);

	let upstreamResponse: Response;
	try {
		upstreamResponse = await fetch(upstreamURL, {
			headers: {
				Accept: "application/json",
				"User-Agent": OPEN_FOOD_FACTS_USER_AGENT,
			},
		});
	} catch (error) {
		console.warn("Open Food Facts v2 goal request failed", error instanceof Error ? error.message : "unknown");
		upstreamResponse = new Response(null, { status: 503 });
	}

	if (!upstreamResponse.ok) {
		const legacyURL = new URL(OPEN_FOOD_FACTS_LEGACY_SEARCH_URL);
		legacyURL.searchParams.set("action", "process");
		legacyURL.searchParams.set("json", "1");
		legacyURL.searchParams.set(
			"tagtype_0",
			filterName === "labels_tags" ? "labels" : "nutrient_levels",
		);
		legacyURL.searchParams.set("tag_contains_0", "contains");
		legacyURL.searchParams.set("tag_0", filterValue.replace(/^en:/, ""));
		legacyURL.searchParams.set("page", String(page));
		legacyURL.searchParams.set("page_size", String(pageSize));
		legacyURL.searchParams.set("sort_by", "unique_scans_n");
		legacyURL.searchParams.set("lc", language);
		legacyURL.searchParams.set("fields", OPEN_FOOD_FACTS_FIELDS);

		try {
			upstreamResponse = await fetch(legacyURL, {
				headers: {
					Accept: "application/json",
					"User-Agent": OPEN_FOOD_FACTS_USER_AGENT,
				},
			});
		} catch (error) {
			console.error("Open Food Facts legacy goal request failed", error instanceof Error ? error.message : "unknown");
			return json({ error: "open_food_facts_unavailable" }, 503);
		}

		if (!upstreamResponse.ok) {
			console.error("Open Food Facts goal request failed", { status: upstreamResponse.status, goal });
			return json({ error: "open_food_facts_unavailable" }, 503);
		}
	}

	const normalizedResponse = await normalizeOpenFoodFactsPage(upstreamResponse, language);
	if (!normalizedResponse) {
		return json({ error: "open_food_facts_unavailable" }, 503);
	}
	return cacheOpenFoodFactsResponse(normalizedResponse, cache, cacheKey, ctx);
}

async function listCategoryProducts(
	requestURL: URL,
	encodedCategoryTag: string,
	ctx: ExecutionContext,
): Promise<Response> {
	const categoryTag = decodePathSegment(encodedCategoryTag);
	if (!categoryTag || !isTaxonomyTag(categoryTag)) {
		return json({ error: "invalid_category" }, 400);
	}

	const page = positiveIntegerQuery(requestURL, "page", 1);
	const pageSize = positiveIntegerQuery(requestURL, "page_size", DEFAULT_GOAL_PAGE_SIZE);
	if (page === null || pageSize === null || pageSize > MAX_GOAL_PAGE_SIZE) {
		return json({ error: "invalid_pagination" }, 400);
	}

	const country = optionalCountryQuery(requestURL);
	if (country === undefined) return json({ error: "invalid_country" }, 400);
	const language = productLanguageQuery(requestURL);
	if (!language) return json({ error: "invalid_language" }, 400);

	const cacheURL = new URL(`/v1/categories/${encodeURIComponent(categoryTag)}`, requestURL.origin);
	cacheURL.searchParams.set("page", String(page));
	cacheURL.searchParams.set("page_size", String(pageSize));
	if (country) cacheURL.searchParams.set("country", country);
	cacheURL.searchParams.set("lang", language);
	cacheURL.searchParams.set("schema", OPEN_FOOD_FACTS_CACHE_SCHEMA);
	const cacheKey = new Request(cacheURL.toString(), { method: "GET" });
	const cache = caches.default;

	try {
		const cachedResponse = await cache.match(cacheKey);
		if (cachedResponse) return cachedResponse;
	} catch (error) {
		console.warn("Pickly category cache read failed", error instanceof Error ? error.message : "unknown");
	}

	const categoryQuery = `categories_tags:"${categoryTag}"`;
	const query = country
		? `${categoryQuery} AND countries_tags:"${country}"`
		: categoryQuery;
	const searchALiciousResponse = await searchALiciousProductPage(query, page, pageSize, language);
	if (searchALiciousResponse) {
		return cacheOpenFoodFactsResponse(searchALiciousResponse, cache, cacheKey, ctx);
	}

	const upstreamURL = new URL(OPEN_FOOD_FACTS_SEARCH_URL);
	upstreamURL.searchParams.set("product_type", "food");
	upstreamURL.searchParams.set("categories_tags", categoryTag);
	if (country) upstreamURL.searchParams.set("countries_tags_en", country.slice("en:".length));
	upstreamURL.searchParams.set("page", String(page));
	upstreamURL.searchParams.set("page_size", String(pageSize));
	upstreamURL.searchParams.set("sort_by", "unique_scans_n");
	upstreamURL.searchParams.set("lc", language);
	upstreamURL.searchParams.set("fields", OPEN_FOOD_FACTS_FIELDS);

	let upstreamResponse: Response;
	try {
		upstreamResponse = await fetch(upstreamURL, {
			headers: {
				Accept: "application/json",
				"User-Agent": OPEN_FOOD_FACTS_USER_AGENT,
			},
		});
	} catch (error) {
		console.warn("Open Food Facts v2 category request failed", error instanceof Error ? error.message : "unknown");
		return json({ error: "open_food_facts_unavailable" }, 503);
	}

	if (!upstreamResponse.ok) {
		console.warn("Open Food Facts v2 category request failed", {
			status: upstreamResponse.status,
			categoryTag,
		});
		return json({ error: "open_food_facts_unavailable" }, 503);
	}

	const normalizedResponse = await normalizeOpenFoodFactsPage(upstreamResponse, language);
	if (!normalizedResponse) {
		return json({ error: "open_food_facts_unavailable" }, 503);
	}
	return cacheOpenFoodFactsResponse(normalizedResponse, cache, cacheKey, ctx);
}

async function openFoodFactsProductMetadata(
	requestURL: URL,
	encodedBarcode: string,
	ctx: ExecutionContext,
): Promise<Response> {
	const barcode = decodePathSegment(encodedBarcode)?.trim();
	if (!barcode || !/^\d{8,14}$/.test(barcode)) {
		return json({ error: "invalid_barcode" }, 400);
	}

	const language = productLanguageQuery(requestURL);
	if (!language) return json({ error: "invalid_language" }, 400);

	const cacheURL = new URL(`/v1/off/products/${barcode}`, requestURL.origin);
	cacheURL.searchParams.set("lang", language);
	cacheURL.searchParams.set("schema", OPEN_FOOD_FACTS_CACHE_SCHEMA);
	const cacheKey = new Request(cacheURL.toString(), { method: "GET" });
	const cache = caches.default;

	try {
		const cachedResponse = await cache.match(cacheKey);
		if (cachedResponse) return cachedResponse;
	} catch (error) {
		console.warn("Pickly OFF product cache read failed", error instanceof Error ? error.message : "unknown");
	}

	let response: Response;
	try {
		response = await fetch(OPEN_FOOD_FACTS_SEARCHALICIOUS_URL, {
			method: "POST",
			headers: {
				Accept: "application/json",
				"Content-Type": "application/json",
				"User-Agent": OPEN_FOOD_FACTS_USER_AGENT,
			},
			body: JSON.stringify({
				q: `code:"${barcode}"`,
				page: 1,
				page_size: 1,
				langs: searchLanguages(language),
				fields: OPEN_FOOD_FACTS_FIELDS.split(","),
			}),
		});
	} catch (error) {
		console.warn("Search-a-licious product request failed", error instanceof Error ? error.message : "unknown");
		return json({ error: "open_food_facts_unavailable" }, 503);
	}

	if (!response.ok) {
		console.warn("Search-a-licious product request failed", { status: response.status, barcode });
		return json({ error: "open_food_facts_unavailable" }, 503);
	}

	try {
		const payload = await response.json() as Record<string, unknown>;
		const hits = Array.isArray(payload.hits) ? payload.hits : [];
		const hit = hits
			.map(asRecord)
			.find((candidate) => cleanText(candidate.code) === barcode);
		if (!hit) return json({ error: "not_found" }, 404);

		const product = normalizeProductHit(hit, language);
		const normalizedResponse = Response.json({
			code: barcode,
			status: "success",
			product,
		});
		return cacheOpenFoodFactsResponse(normalizedResponse, cache, cacheKey, ctx);
	} catch (error) {
		console.warn("Search-a-licious product response decoding failed", error instanceof Error ? error.message : "unknown");
		return json({ error: "open_food_facts_unavailable" }, 503);
	}
}

async function searchALiciousGoalPage(
	goal: GoalID,
	page: number,
	pageSize: number,
	language: ProductLanguage,
): Promise<Response | null> {
	return searchALiciousProductPage(
		GOAL_SEARCH_QUERIES[goal],
		page,
		pageSize,
		language,
	);
}

async function searchALiciousProductPage(
	query: string,
	page: number,
	pageSize: number,
	language: ProductLanguage,
): Promise<Response | null> {
	let response: Response;
	try {
		response = await fetch(OPEN_FOOD_FACTS_SEARCHALICIOUS_URL, {
			method: "POST",
			headers: {
				Accept: "application/json",
				"Content-Type": "application/json",
				"User-Agent": OPEN_FOOD_FACTS_USER_AGENT,
			},
			body: JSON.stringify({
				q: query,
				page,
				page_size: pageSize,
				sort_by: "-unique_scans_n",
				langs: searchLanguages(language),
				fields: OPEN_FOOD_FACTS_FIELDS.split(","),
			}),
		});
	} catch (error) {
		console.warn("Search-a-licious goal request failed", error instanceof Error ? error.message : "unknown");
		return null;
	}

	if (!response.ok) {
		console.warn("Search-a-licious product page request failed", { status: response.status });
		return null;
	}

	try {
		const payload = await response.json() as Record<string, unknown>;
		const hits = Array.isArray(payload.hits) ? payload.hits : null;
		if (!hits) return null;

		const products = hits.map(asRecord).map((hit) => normalizeProductHit(hit, language));
		return Response.json({
			count: typeof payload.count === "number" ? payload.count : products.length,
			page: typeof payload.page === "number" ? payload.page : page,
			page_count: typeof payload.page_count === "number" ? payload.page_count : 1,
			page_size: typeof payload.page_size === "number" ? payload.page_size : pageSize,
			products,
		});
	} catch (error) {
		console.warn("Search-a-licious response decoding failed", error instanceof Error ? error.message : "unknown");
		return null;
	}
}

async function normalizeOpenFoodFactsPage(
	response: Response,
	language: ProductLanguage,
): Promise<Response | null> {
	try {
		const payload = await response.json() as Record<string, unknown>;
		const products = Array.isArray(payload.products)
			? payload.products.map(asRecord).map((product) => normalizeProductHit(product, language))
			: null;
		if (!products) return null;
		return Response.json({ ...payload, products });
	} catch (error) {
		console.warn("Open Food Facts page response decoding failed", error instanceof Error ? error.message : "unknown");
		return null;
	}
}

function normalizeProductHit(
	hit: Record<string, unknown>,
	language: ProductLanguage,
): Record<string, unknown> {
	const rawExplicitEnglishName = localizedText(hit.product_name_en, "en")
		?? nestedLocalizedText(hit.product_name, "en");
	const explicitEnglishName = verifiedEnglishCandidate(rawExplicitEnglishName, hit);
	const genericEnglishName = localizedText(hit.generic_name_en, "en")
		?? nestedLocalizedText(hit.generic_name, "en");
	const verifiedEnglishName = verifiedEnglishCandidate(
		englishSourceText(hit.product_name, hit),
		hit,
	);
	const productName = explicitEnglishName
		?? genericEnglishName
		?? verifiedEnglishName
		?? fallbackProductName(hit);
	const requestedName = language === DEFAULT_PRODUCT_LANGUAGE
		? productName
		: localizedText(hit[`product_name_${language}`], language)
			?? nestedLocalizedText(hit.product_name, language);
	const requestedGenericName = language === DEFAULT_PRODUCT_LANGUAGE
		? null
		: localizedText(hit[`generic_name_${language}`], language)
			?? nestedLocalizedText(hit.generic_name, language);
	const displayName = requestedName
		?? requestedGenericName
		?? (language === DEFAULT_PRODUCT_LANGUAGE ? productName : null)
		?? productName;
	const normalized: Record<string, unknown> = {
		...hit,
		product_name: displayName,
		brands: Array.isArray(hit.brands)
			? hit.brands.map(cleanText).filter((value): value is string => Boolean(value)).join(", ")
			: hit.brands,
	};

	// Downstream clients prefer `product_name_en`. Always expose the same
	// reviewed English candidate used for `product_name`, never the rejected raw
	// value from a mislabeled OFF field.
	normalized.product_name_en = productName;
	normalized.pickly_display_name = displayName;
	normalized.pickly_display_language = language;
	normalized.pickly_name_fallback = requestedName || requestedGenericName
		? "exact"
		: productName === fallbackProductName(hit) ? "taxonomy" : "english";
	if (genericEnglishName) {
		normalized.generic_name_en = genericEnglishName;
	} else {
		delete normalized.generic_name_en;
	}

	return normalized;
}

function verifiedEnglishCandidate(
	candidate: string | null,
	hit: Record<string, unknown>,
): string | null {
	if (!candidate || isBrandIdentity(candidate, hit.brands)) return candidate;

	const normalizedCandidate = comparableText(candidate);
	if (!normalizedCandidate) return null;

	const localizedProductName = asRecordOrNull(hit.product_name);
	const nonEnglishNames = ["pt", "es", "fr", "de", "it", "da", "pl", "cs"].flatMap((language) => [
		localizedText(hit[`product_name_${language}`], language),
		localizedProductName ? cleanText(localizedProductName[language]) : null,
	]);
	const duplicatesLocalizedName = nonEnglishNames.some((name) => (
		name !== null && comparableText(name) === normalizedCandidate
	));

	return duplicatesLocalizedName ? null : candidate;
}

function isBrandIdentity(candidate: string, brandsValue: unknown): boolean {
	const candidateKey = comparableText(candidate);
	if (!candidateKey) return false;

	const brands = Array.isArray(brandsValue)
		? brandsValue.map(cleanText).filter((value): value is string => Boolean(value))
		: (cleanText(brandsValue)?.split(",") ?? []).map((value) => value.trim());
	return brands.some((brand) => comparableText(brand) === candidateKey);
}

function comparableText(value: string): string {
	return value
		.normalize("NFKD")
		.replace(/\p{M}/gu, "")
		.toLocaleLowerCase("en-US")
		.replace(/[^\p{L}\p{N}]+/gu, " ")
		.trim();
}

function localizedText(value: unknown, language: string): string | null {
	const direct = cleanText(value);
	if (direct) return direct;
	const localized = asRecordOrNull(value);
	return localized ? cleanText(localized[language]) : null;
}

function nestedLocalizedText(value: unknown, language: string): string | null {
	const localized = asRecordOrNull(value);
	return localized ? cleanText(localized[language]) : null;
}

function englishSourceText(value: unknown, hit: Record<string, unknown>): string | null {
	if (!hasEnglishMetadata(hit)) return null;
	return cleanText(value);
}

function hasEnglishMetadata(hit: Record<string, unknown>): boolean {
	const language = cleanText(hit.lang)?.toLowerCase().split(/[-_]/, 1)[0];
	if (language) return language === "en";

	if (!Array.isArray(hit.languages_tags) || hit.languages_tags.length === 0) return false;
	const rawTags = hit.languages_tags.map(cleanText);
	if (rawTags.some((tag) => !tag)) return false;
	const tags = rawTags.map((tag) => tag!.toLowerCase());
	return tags.length > 0 && tags.every((tag) => tag === "en" || tag.startsWith("en:"));
}

function fallbackProductName(hit: Record<string, unknown>): string {
	const brand = Array.isArray(hit.brands)
		? hit.brands.map(cleanText).filter((value): value is string => Boolean(value)).join(", ")
		: cleanText(hit.brands);
	const category = englishCategoryName(hit.categories_tags);

	if (brand && category) return `${brand} · ${category}`;
	return "Grocery item";
}

function englishCategoryName(value: unknown): string | null {
	if (!Array.isArray(value)) return null;

	const tags = value
		.map(cleanText)
		.filter((tag): tag is string => Boolean(tag))
		.map((tag) => tag.toLowerCase())
		.filter((tag) => tag.startsWith("en:") && isTaxonomyTag(tag));
	const specificTags = tags.filter((tag) => !BROAD_ENGLISH_CATEGORY_TAGS.has(tag));
	const tag = specificTags.at(-1);
	if (!tag) return null;

	const slug = tag.slice(3).replace(/-/g, " ").trim();
	if (!slug) return null;
	return slug.replace(/\b[a-z]/g, (letter) => letter.toUpperCase());
}

function cleanText(value: unknown): string | null {
	if (typeof value !== "string") return null;
	const text = value.trim();
	return text.length > 0 ? text : null;
}

function asRecord(value: unknown): Record<string, unknown> {
	return asRecordOrNull(value) ?? {};
}

function asRecordOrNull(value: unknown): Record<string, unknown> | null {
	return value !== null && typeof value === "object" && !Array.isArray(value)
		? value as Record<string, unknown>
		: null;
}

function searchLanguages(language: ProductLanguage): ProductLanguage[] {
	return language === DEFAULT_PRODUCT_LANGUAGE
		? [DEFAULT_PRODUCT_LANGUAGE]
		: [DEFAULT_PRODUCT_LANGUAGE, language];
}

function cacheOpenFoodFactsResponse(
	upstreamResponse: Response,
	cache: Cache,
	cacheKey: Request,
	ctx: ExecutionContext,
): Response {
	const response = cors(new Response(upstreamResponse.body, {
		status: upstreamResponse.status,
		headers: {
			"Content-Type": upstreamResponse.headers.get("Content-Type") ?? "application/json; charset=utf-8",
			"Cache-Control": GOAL_CACHE_CONTROL,
		},
	}));

	ctx.waitUntil(
		cache.put(cacheKey, response.clone()).catch((error) => {
			console.warn("Pickly OFF cache write failed", error instanceof Error ? error.message : "unknown");
		}),
	);
	return response;
}

function isGoalID(value: string): value is GoalID {
	return Object.hasOwn(GOAL_FILTERS, value);
}

function isTaxonomyTag(value: string): boolean {
	return /^[a-z]{2}:[a-z0-9](?:[a-z0-9-]{0,126}[a-z0-9])?$/.test(value);
}

function optionalCountryQuery(url: URL): string | null | undefined {
	const country = url.searchParams.get("country");
	if (country === null || country === "") return null;
	return country.startsWith("en:") && isTaxonomyTag(country) ? country : undefined;
}

function productLanguageQuery(url: URL): ProductLanguage | null {
	const language = url.searchParams.get("lang") ?? DEFAULT_PRODUCT_LANGUAGE;
	return SUPPORTED_PRODUCT_LANGUAGES.includes(language as ProductLanguage)
		? language as ProductLanguage
		: null;
}

function decodePathSegment(value: string): string | null {
	try {
		return decodeURIComponent(value);
	} catch {
		return null;
	}
}

function positiveIntegerQuery(url: URL, name: string, fallback: number): number | null {
	const rawValue = url.searchParams.get(name);
	if (rawValue === null) return fallback;
	if (!/^\d+$/.test(rawValue)) return null;

	const value = Number(rawValue);
	return Number.isSafeInteger(value) && value >= 1 ? value : null;
}

async function listProducts(url: URL, env: Env): Promise<Response> {
	const language = productLanguageQuery(url);
	if (!language) return json({ error: "invalid_language" }, 400);
	const requestedLimit = Number(url.searchParams.get("limit") ?? "60");
	const limit = Number.isFinite(requestedLimit) ? Math.max(1, Math.min(requestedLimit, MAX_PRODUCTS)) : 60;
	const query = url.searchParams.get("q")?.trim() ?? "";

	const result = query.length >= 2
		? await searchCatalogProducts(env, query, language, limit)
		: await env.DB.prepare(`
			SELECT * FROM products WHERE is_published = 1 ORDER BY updated_at DESC LIMIT ?
		`).bind(limit).all<ProductRow>();

	const localizedRows = await attachProductLocalizations(result.results, language, env.DB);
	return json(localizedRows.map((row) => serializeProduct(row, language)));
}

async function searchCatalogProducts(
	env: Env,
	query: string,
	language: ProductLanguage,
	limit: number,
): Promise<{ results: ProductRow[] }> {
	const pattern = `%${escapeLike(query)}%`;
	const canonical = await env.DB.prepare(`
		SELECT * FROM products
		WHERE is_published = 1
		  AND (name LIKE ? ESCAPE '\\' COLLATE NOCASE OR display_name LIKE ? ESCAPE '\\' COLLATE NOCASE OR brand LIKE ? ESCAPE '\\' COLLATE NOCASE OR category LIKE ? ESCAPE '\\' COLLATE NOCASE OR barcode LIKE ? ESCAPE '\\')
		ORDER BY score DESC, updated_at DESC
		LIMIT ?
	`).bind(...Array(5).fill(pattern), limit).all<ProductRow>();

	if (language === DEFAULT_PRODUCT_LANGUAGE) return canonical;

	try {
		const localized = await env.DB.prepare(`
			SELECT products.*
			FROM products
			JOIN product_localizations
			  ON product_localizations.product_id = products.id
			 AND product_localizations.language = ?
			WHERE products.is_published = 1
			  AND (
				product_localizations.name LIKE ? ESCAPE '\\' COLLATE NOCASE
				OR product_localizations.category LIKE ? ESCAPE '\\' COLLATE NOCASE
				OR product_localizations.ingredients LIKE ? ESCAPE '\\' COLLATE NOCASE
			  )
			ORDER BY products.score DESC, products.updated_at DESC
			LIMIT ?
		`).bind(language, pattern, pattern, pattern, limit).all<ProductRow>();

		const seen = new Set(localized.results.map((row) => row.id));
		return {
			results: [
				...localized.results,
				...canonical.results.filter((row) => !seen.has(row.id)),
			].slice(0, limit),
		};
	} catch (error) {
		// Keep pre-localization D1 databases searchable until migration 0003 is applied.
		console.warn("Pickly localized product search unavailable", error instanceof Error ? error.message : "unknown");
		return canonical;
	}
}

async function productByBarcode(url: URL, env: Env): Promise<Response> {
	const language = productLanguageQuery(url);
	if (!language) return json({ error: "invalid_language" }, 400);
	const barcode = decodeURIComponent(url.pathname.slice("/v1/products/barcode/".length)).trim();
	if (!/^\d{8,14}$/.test(barcode)) return json({ error: "invalid_barcode" }, 400);

	const product = await env.DB.prepare(
		"SELECT * FROM products WHERE barcode = ? AND is_published = 1 LIMIT 1",
	).bind(barcode).first<ProductRow>();
	if (!product) return json({ error: "not_found" }, 404);

	const localizedProducts = await attachProductLocalizations([product], language, env.DB);
	const localizedProduct = localizedProducts[0] ?? product;

	const alternatives = await env.DB.prepare(
		"SELECT alternative_product_id FROM product_alternatives WHERE product_id = ? ORDER BY rank ASC",
	).bind(product.id).all<{ alternative_product_id: string }>();
	return json({
		...serializeProduct(localizedProduct, language),
		alternative_ids: alternatives.results.map((row) => row.alternative_product_id),
	});
}

async function createProductRequest(request: Request, env: Env): Promise<Response> {
	const user = await requireUser(request, env);
	if (!user) return json({ error: "unauthorized" }, 401);
	const body = await request.json().catch(() => null) as Record<string, unknown> | null;
	const barcode = optionalText(body?.barcode, 14);
	const name = optionalText(body?.name, 160);
	const brand = optionalText(body?.brand, 120);
	const note = optionalText(body?.note, 1_000);

	if (barcode && !/^\d{8,14}$/.test(barcode)) return json({ error: "invalid_barcode" }, 400);
	if (!barcode && !name) return json({ error: "missing_product_details" }, 400);

	await ensureUserProfile(user, env);
	await env.DB.prepare(`
		INSERT INTO product_requests (id, user_id, barcode, name, brand, note, status, created_at)
		VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, 'new', datetime('now'))
	`).bind(user.uid, barcode, name, brand, note).run();
	return json({ ok: true }, 201);
}

async function deleteAccountData(request: Request, env: Env): Promise<Response> {
	const user = await requireUser(request, env);
	if (!user) return json({ error: "unauthorized" }, 401);
	await env.DB.batch([
		env.DB.prepare("DELETE FROM saved_products WHERE user_id = ?").bind(user.uid),
		env.DB.prepare("DELETE FROM scan_history WHERE user_id = ?").bind(user.uid),
		env.DB.prepare("DELETE FROM product_requests WHERE user_id = ?").bind(user.uid),
		env.DB.prepare("DELETE FROM user_preferences WHERE user_id = ?").bind(user.uid),
		env.DB.prepare("DELETE FROM profiles WHERE id = ?").bind(user.uid),
	]);
	return json({ ok: true });
}

async function requireUser(request: Request, env: Env): Promise<{ uid: string; email: string | null; displayName: string | null } | null> {
	const authorization = request.headers.get("Authorization");
	if (!authorization?.startsWith("Bearer ")) return null;
	const token = authorization.slice("Bearer ".length).trim();
	if (!token) return null;

	try {
		const jwks = firebaseJWKS(env.FIREBASE_PROJECT_ID);
		const { payload } = await jwtVerify(token, jwks, {
			issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
			audience: env.FIREBASE_PROJECT_ID,
		});
		return typeof payload.sub === "string" && payload.sub.length > 0
			? {
				uid: payload.sub,
				email: typeof payload.email === "string" ? payload.email : null,
				displayName: typeof payload.name === "string" ? payload.name : null,
			}
			: null;
	} catch {
		return null;
	}
}

async function ensureUserProfile(
	user: { uid: string; email: string | null; displayName: string | null },
	env: Env,
) {
	const fallbackName = user.email?.split("@")[0] ?? null;
	await env.DB.batch([
		env.DB.prepare(`
			INSERT INTO profiles (id, display_name) VALUES (?, ?)
			ON CONFLICT(id) DO NOTHING
		`).bind(user.uid, user.displayName ?? fallbackName),
		env.DB.prepare(`
			INSERT INTO user_preferences (user_id) VALUES (?)
			ON CONFLICT(user_id) DO NOTHING
		`).bind(user.uid),
	]);
}

function firebaseJWKS(projectID: string) {
	let jwks = jwksByProject.get(projectID);
	if (!jwks) {
		jwks = createRemoteJWKSet(new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"));
		jwksByProject.set(projectID, jwks);
	}
	return jwks;
}

async function attachProductLocalizations(
	rows: ProductRow[],
	language: ProductLanguage,
	db: D1Database,
): Promise<ProductRow[]> {
	if (language === DEFAULT_PRODUCT_LANGUAGE || rows.length === 0) return rows;

	try {
		const placeholders = rows.map(() => "?").join(", ");
		const result = await db.prepare(`
			SELECT product_id, language, name, category, ingredients
			FROM product_localizations
			WHERE language = ? AND product_id IN (${placeholders})
		`).bind(language, ...rows.map((row) => row.id)).all<ProductLocalizationRow>();
		const byProductID = new Map(result.results.map((row) => [row.product_id, row]));
		return rows.map((row) => {
			const localized = byProductID.get(row.id);
			return localized
				? {
					...row,
					localized_name: localized.name,
					localized_category: localized.category,
					localized_ingredients: localized.ingredients,
				}
				: row;
		});
	} catch (error) {
		// Keep old D1 databases readable until migration 0003 is applied.
		console.warn("Pickly product localization table unavailable", error instanceof Error ? error.message : "unknown");
		return rows;
	}
}

function serializeProduct(row: ProductRow, language: ProductLanguage = DEFAULT_PRODUCT_LANGUAGE) {
	const displayName = optionalText(
		row.localized_name
			?? row[`name_${language}`]
			?? row[`display_name_${language}`]
			?? row.display_name,
		160,
	);
	const displayCategory = optionalText(
		row.localized_category
			?? row[`category_${language}`]
			?? row[`display_category_${language}`]
			?? row.category,
		160,
	);
	const hasLocalizedName = Boolean(optionalText(row.localized_name, 160));
	return {
		...row,
		name: displayName ?? row.name,
		pickly_display_name: displayName ?? row.name,
		pickly_display_language: language,
		pickly_display_category: displayCategory ?? row.category,
		pickly_name_fallback: hasLocalizedName || language === DEFAULT_PRODUCT_LANGUAGE ? "exact" : "canonical",
		category: displayCategory ?? row.category,
		ingredients: parseJSON(row.localized_ingredients ?? row.ingredients, []),
		nutrition: parseJSON(row.nutrition, {}),
		reasons: parseJSON(row.reasons, []),
		warnings: parseJSON(row.warnings, []),
		positives: parseJSON(row.positives, []),
		is_published: row.is_published === 1,
	};
}

function parseJSON(value: string, fallback: unknown) {
	try { return JSON.parse(value); } catch { return fallback; }
}

function optionalText(value: unknown, maxLength: number): string | null {
	if (typeof value !== "string") return null;
	const text = value.trim();
	return text.length > 0 && text.length <= maxLength ? text : null;
}

function escapeLike(value: string) {
	return value.replace(/[\\%_]/g, "\\$&");
}

function json(body: unknown, status = 200) {
	return cors(Response.json(body, { status, headers: { "Cache-Control": "no-store" } }));
}

function cors(response: Response) {
	response.headers.set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
	response.headers.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
	return response;
}
