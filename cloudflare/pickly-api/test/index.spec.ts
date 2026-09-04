import {
	env,
	createExecutionContext,
	waitOnExecutionContext,
	SELF,
} from "cloudflare:test";
import { afterEach, describe, it, expect, vi } from "vitest";
import worker from "../src/index";

// For now, you'll need to do something like this to get a correctly-typed
// `Request` to pass to `worker.fetch()`.
const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;
const openFoodFactsOrigin = "https://world.openfoodfacts.org";

const goalFilters = [
	["lowSugar", "nutrient_levels_tags", "en:sugars-in-low-quantity", "nutriments.sugars_100g:[0 TO 5]"],
	["lowSodium", "nutrient_levels_tags", "en:salt-in-low-quantity", "nutriments.salt_100g:[0 TO 0.8]"],
	["highProtein", "nutrient_levels_tags", "en:proteins-in-high-quantity", "nutriments.proteins_100g:[8 TO *]"],
	["sensitiveDigestion", "nutrient_levels_tags", "en:saturated-fat-in-low-quantity", "nutriments.saturated-fat_100g:[0 TO 3] AND nutriments.sugars_100g:[0 TO 5] AND nutriments.salt_100g:[0 TO 0.8] AND ingredients_n:[1 TO 4]"],
	["vegetarian", "labels_tags", "en:vegetarian", 'labels_tags:"en:vegetarian"'],
	["vegan", "labels_tags", "en:vegan", 'labels_tags:"en:vegan"'],
	["glutenFree", "labels_tags", "en:no-gluten", 'labels_tags:("en:no-gluten" OR "en:gluten-free")'],
	["lactoseFree", "labels_tags", "en:no-lactose", 'labels_tags:("en:no-lactose" OR "en:lactose-free" OR "en:without-lactose")'],
] as const;

afterEach(() => {
	vi.restoreAllMocks();
});

function fetchedURL(input: RequestInfo | URL): URL {
	if (input instanceof Request) return new URL(input.url);
	return new URL(input.toString());
}

function offPage(page: number, pageSize: number) {
	return {
		count: 174_873,
		page,
		page_count: Math.ceil(174_873 / pageSize),
		page_size: pageSize,
		products: [{ code: "3760049798609", product_name: "Vegetarian product" }],
	};
}

function searchPage(page: number, pageSize: number) {
	return {
		count: 10_000,
		page,
		page_count: Math.ceil(10_000 / pageSize),
		page_size: pageSize,
		hits: [{
			code: "3760049798609",
			product_name: "Goal product",
			brands: ["Pickly Test", "OFF"],
			ingredients_n: 3,
		}],
	};
}

function normalizedSearchPage(page: number, pageSize: number) {
	return {
		count: 10_000,
		page,
		page_count: Math.ceil(10_000 / pageSize),
		page_size: pageSize,
		products: [{
			code: "3760049798609",
			product_name: "Grocery item",
			product_name_en: "Grocery item",
			pickly_display_name: "Grocery item",
			pickly_display_language: "en",
			pickly_name_fallback: "exact",
			brands: "Pickly Test, OFF",
			ingredients_n: 3,
		}],
	};
}

function normalizedOffPage(page: number, pageSize: number) {
	return {
		...offPage(page, pageSize),
		products: [{
			...offPage(page, pageSize).products[0],
			product_name: "Grocery item",
			product_name_en: "Grocery item",
			pickly_display_name: "Grocery item",
			pickly_display_language: "en",
			pickly_name_fallback: "exact",
		}],
	};
}

async function runWorker(url: string) {
	const request = new IncomingRequest(url);
	const ctx = createExecutionContext();
	const response = await worker.fetch(request, env, ctx);
	return { response, ctx };
}

describe("Pickly API", () => {
	it("reports healthy without accessing the database", async () => {
		const request = new IncomingRequest("http://example.com/health");
		// Create an empty context to pass to `worker.fetch()`.
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		// Wait for all `Promise`s passed to `ctx.waitUntil()` to settle before running test assertions
		await waitOnExecutionContext(ctx);
		expect(await response.json()).toEqual({ ok: true });
	});

	it("does not expose an unrecognised route", async () => {
		const response = await SELF.fetch("https://example.com/unknown");
		expect(response.status).toBe(404);
		expect(await response.json()).toEqual({ error: "not_found" });
	});

	it("uses a verified display name for list, search, and barcode responses", async () => {
		const productID = "foreign-name-display-test";
		const barcode = "6111242102552";
		// The Worker pool exposes an empty D1 binding and does not apply Wrangler
		// migrations automatically, so this endpoint test owns its minimal schema.
		await env.DB.prepare(`
			CREATE TABLE IF NOT EXISTS products (
				id TEXT PRIMARY KEY,
				barcode TEXT UNIQUE,
				name TEXT NOT NULL,
				display_name TEXT,
				brand TEXT,
				category TEXT NOT NULL DEFAULT 'Grocery',
				ingredients TEXT NOT NULL DEFAULT '[]',
				nutrition TEXT NOT NULL DEFAULT '{}',
				score INTEGER,
				verdict TEXT NOT NULL DEFAULT 'limited_data',
				summary TEXT NOT NULL DEFAULT '',
				reasons TEXT NOT NULL DEFAULT '[]',
				warnings TEXT NOT NULL DEFAULT '[]',
				positives TEXT NOT NULL DEFAULT '[]',
				confidence TEXT NOT NULL DEFAULT 'low',
				source TEXT NOT NULL DEFAULT 'manual',
				score_version TEXT NOT NULL DEFAULT 'mvp-v1',
				is_published INTEGER NOT NULL DEFAULT 1,
				created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
				updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
			)
		`).run();
		await env.DB.prepare(`
			CREATE TABLE IF NOT EXISTS product_alternatives (
				product_id TEXT NOT NULL,
				alternative_product_id TEXT NOT NULL,
				rank INTEGER NOT NULL DEFAULT 0
			)
		`).run();
		await env.DB.prepare(`
			INSERT INTO products (
				id, barcode, name, display_name, brand, category, score, verdict, summary, confidence, is_published
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`).bind(
			productID,
			barcode,
			"Dessert gourmand choco",
			"Jaouda Yogurt",
			"Jaouda",
			"Yogurt",
			72,
			"good",
			"Reviewed fixture.",
			"medium",
			1,
		).run();

		try {
			const { response: listResponse } = await runWorker("https://api.pickly.test/v1/products?limit=100");
			expect(await listResponse.json()).toEqual(expect.arrayContaining([
				expect.objectContaining({
					id: productID,
					name: "Jaouda Yogurt",
					display_name: "Jaouda Yogurt",
				}),
			]));

			const { response: searchResponse } = await runWorker("https://api.pickly.test/v1/products?q=Jaouda%20Yogurt");
			expect(await searchResponse.json()).toEqual(expect.arrayContaining([
				expect.objectContaining({ id: productID, name: "Jaouda Yogurt" }),
			]));

			const { response: barcodeResponse } = await runWorker(
				`https://api.pickly.test/v1/products/barcode/${barcode}`,
			);
			expect(await barcodeResponse.json()).toMatchObject({
				id: productID,
				name: "Jaouda Yogurt",
				display_name: "Jaouda Yogurt",
			});
		} finally {
			await env.DB.prepare("DELETE FROM products WHERE id = ?").bind(productID).run();
		}
	});

	it("uses D1 localizations for localized list, search, and barcode responses", async () => {
		const productID = "localized-d1-display-test";
		const barcode = "6111242102553";
		await env.DB.prepare(`
			CREATE TABLE IF NOT EXISTS product_localizations (
				product_id TEXT NOT NULL,
				language TEXT NOT NULL,
				name TEXT,
				category TEXT,
				ingredients TEXT,
				updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
				PRIMARY KEY (product_id, language)
			)
		`).run();
		await env.DB.prepare(`
			INSERT INTO products (
				id, barcode, name, display_name, brand, category, ingredients, score, verdict, summary, confidence, is_published
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`).bind(
			productID,
			barcode,
			"Oat flakes",
			"Oat flakes",
			"Crownfield",
			"Breakfast Cereals",
			"[]",
			91,
			"great",
			"Reviewed fixture.",
			"high",
			1,
		).run();
		await env.DB.prepare(`
			INSERT INTO product_localizations (product_id, language, name, category, ingredients)
			VALUES (?, ?, ?, ?, ?)
		`).bind(
			productID,
			"fr",
			"Flocons d’avoine",
			"Céréales du petit-déjeuner",
			JSON.stringify(["Avoine"]),
		).run();

		try {
			const { response: listResponse } = await runWorker(
				"https://api.pickly.test/v1/products?lang=fr&limit=100",
			);
			expect(await listResponse.json()).toEqual(expect.arrayContaining([
				expect.objectContaining({
					id: productID,
					name: "Flocons d’avoine",
					category: "Céréales du petit-déjeuner",
					pickly_display_language: "fr",
				}),
			]));

			const { response: searchResponse } = await runWorker(
				"https://api.pickly.test/v1/products?q=Flocons%20d%E2%80%99avoine&lang=fr",
			);
			expect(await searchResponse.json()).toEqual(expect.arrayContaining([
				expect.objectContaining({ id: productID, name: "Flocons d’avoine" }),
			]));

			const { response: barcodeResponse } = await runWorker(
				`https://api.pickly.test/v1/products/barcode/${barcode}?lang=fr`,
			);
			expect(await barcodeResponse.json()).toMatchObject({
				id: productID,
				name: "Flocons d’avoine",
				category: "Céréales du petit-déjeuner",
				ingredients: ["Avoine"],
			});
		} finally {
			await env.DB.prepare("DELETE FROM product_localizations WHERE product_id = ?").bind(productID).run();
			await env.DB.prepare("DELETE FROM products WHERE id = ?").bind(productID).run();
		}
	});

	it("requires a Firebase credential before deleting account data", async () => {
		const response = await SELF.fetch("https://example.com/v1/account/data", {
			method: "DELETE",
		});
		expect(response.status).toBe(401);
		expect(await response.json()).toEqual({ error: "unauthorized" });
	});

	it("routes every supported goal to the production Open Food Facts filter", async () => {
		const upstreamURLs: URL[] = [];
		const upstreamBodies: Array<Record<string, unknown>> = [];
		vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
			const url = fetchedURL(input);
			upstreamURLs.push(url);
			const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
			upstreamBodies.push(body);
			return new Response(JSON.stringify(searchPage(
				Number(body.page),
				Number(body.page_size),
			)), {
				headers: { "Content-Type": "application/json" },
			});
		});

		for (const [index, [goal]] of goalFilters.entries()) {
			const page = 101 + index;
			const pageSize = 11 + index;
			const { response, ctx } = await runWorker(
				`https://api.pickly.test/v1/goals/${goal}?page=${page}&page_size=${pageSize}`,
			);
			expect(response.status).toBe(200);
			expect(await response.json()).toEqual(normalizedSearchPage(page, pageSize));
			expect(response.headers.get("Cache-Control")).toBe("public, max-age=300, s-maxage=3600");
			await waitOnExecutionContext(ctx);
		}

		expect(upstreamURLs).toHaveLength(goalFilters.length);
		for (const [index, [, , , searchQuery]] of goalFilters.entries()) {
			const url = upstreamURLs[index];
			expect(url.origin).toBe("https://search.openfoodfacts.org");
			expect(url.pathname).toBe("/search");
			expect(url.href).not.toContain("openfoodfacts.net");
			expect(upstreamBodies[index].q).toBe(searchQuery);
			expect(upstreamBodies[index].page).toBe(101 + index);
			expect(upstreamBodies[index].page_size).toBe(11 + index);
			expect(upstreamBodies[index].sort_by).toBe("-unique_scans_n");
			expect(upstreamBodies[index].fields).toEqual(expect.arrayContaining([
				"code",
				"product_name",
				"brands",
				"image_front_url",
				"ingredients",
				"nutriments",
				"labels_tags",
				"ingredients_n",
			]));
		}
	});

	it("prefers an explicit English product name over main-language text", async () => {
		vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({
			count: 1,
			page: 311,
			page_count: 1,
			page_size: 7,
			hits: [{
				code: "5411188112709",
				product_name: { main: "Geröstete Mandel Ohne Zucker", en: "Nested English" },
				product_name_en: "Almond Unsweetened",
				product_name_pt: "Sem Açúcares Amêndoa",
				brands: ["Alpro"],
			}],
		}), { headers: { "Content-Type": "application/json" } }));

		const { response, ctx } = await runWorker(
			"https://api.pickly.test/v1/goals/lowSugar?page=311&page_size=7",
		);
		expect(response.status).toBe(200);
		expect(await response.json()).toMatchObject({
			products: [{
				product_name: "Almond Unsweetened",
				product_name_en: "Almond Unsweetened",
				product_name_pt: "Sem Açúcares Amêndoa",
				brands: "Alpro",
			}],
		});
		await waitOnExecutionContext(ctx);
	});

	it("rejects a French value mislabeled as product_name_en", async () => {
		vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({
			count: 1,
			page: 312,
			page_count: 1,
			page_size: 7,
			hits: [{
				code: "20995553",
				product_name: "Chocolat noir - 85% cacao",
				product_name_en: "Chocolat noir - 85% cacao",
				product_name_fr: "Chocolat noir - 85% cacao",
				generic_name_en: "Dark chocolate",
				lang: "en",
				brands: ["Lidl", "J.D. Gross"],
				categories_tags: ["en:dark-chocolates"],
			}],
		}), { headers: { "Content-Type": "application/json" } }));

		const { response, ctx } = await runWorker(
			"https://api.pickly.test/v1/goals/lowSugar?page=312&page_size=7",
		);
		expect(response.status).toBe(200);
		expect(await response.json()).toMatchObject({
			products: [{
				product_name: "Dark chocolate",
				product_name_en: "Dark chocolate",
				product_name_fr: "Chocolat noir - 85% cacao",
				generic_name_en: "Dark chocolate",
			}],
		});
		await waitOnExecutionContext(ctx);
	});

	it("uses only verified English names and deterministic taxonomy descriptors", async () => {
		vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({
			count: 4,
			page: 1,
			page_count: 1,
			page_size: 4,
			hits: [
				{
					code: "1000000000001",
					product_name: "Haferflocken",
					lang: "de",
					languages_tags: ["en:english", "de:german"],
					product_name_de: "Haferflocken",
					generic_name_en: "Oat flakes",
					brands: ["Crownfield"],
					categories_tags: ["en:foods", "en:breakfast-cereals"],
				},
				{
					code: "1000000000002",
					product_name: "Lait",
					languages_tags: ["en:english", "fr:french"],
					brands: ["Example"],
					categories_tags: ["en:foods", "en:dairy-drinks"],
				},
				{
					code: "1000000000003",
					product_name: "Oat flakes",
					lang: "en",
					brands: ["Example"],
					categories_tags: ["en:foods", "en:breakfast-cereals"],
				},
				{
					code: "1000000000004",
					product_name: "Haferflocken",
					lang: "de",
					languages_tags: ["en:english", "de:german"],
					brands: ["Example"],
					categories_tags: ["en:foods", "en:breakfast-cereals"],
				},
			],
		}), { headers: { "Content-Type": "application/json" } }));

		const { response, ctx } = await runWorker(
			"https://api.pickly.test/v1/goals/lowSugar?page=1&page_size=4",
		);
		expect(response.status).toBe(200);
		expect(await response.json()).toMatchObject({
			products: [
				{
					product_name: "Oat flakes",
					generic_name_en: "Oat flakes",
				},
				{
					product_name: "Example · Dairy Drinks",
				},
				{
					product_name: "Oat flakes",
				},
				{
					product_name: "Example · Breakfast Cereals",
				},
			],
		});
		await waitOnExecutionContext(ctx);
	});

	it("queries an exact category and country and resolves English before market language", async () => {
		const upstreamBodies: Array<Record<string, unknown>> = [];
		vi.spyOn(globalThis, "fetch").mockImplementation(async (_input, init) => {
			const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
			upstreamBodies.push(body);
			return new Response(JSON.stringify({
				count: 2,
				page: 17,
				page_count: 1,
				page_size: 9,
				hits: [
					{
						code: "87157260",
						product_name: "Tomaten Ketchup",
						product_name_en: "Tomato Ketchup",
						product_name_pt: "Ketchup de tomate",
						brands: ["Heinz"],
					},
					{
						code: "4056489470847",
						product_name: { main: "Hafer Flocken Zart", pt: "Flocos de Aveia Suaves" },
						product_name_pt: "Flocos de Aveia Suaves",
						categories_tags: ["en:foods", "en:breakfast-cereals"],
						brands: ["Crownfield", "Lidl"],
					},
				],
			}), { headers: { "Content-Type": "application/json" } });
		});

		const { response, ctx } = await runWorker(
			"https://api.pickly.test/v1/categories/en%3Aketchup?page=17&page_size=9&country=en%3Aportugal&lang=pt",
		);
		expect(response.status).toBe(200);
		expect(response.headers.get("Cache-Control")).toBe("public, max-age=300, s-maxage=3600");
		expect(await response.json()).toMatchObject({
			count: 2,
			products: [
				{
					product_name: "Ketchup de tomate",
					product_name_en: "Tomato Ketchup",
					brands: "Heinz",
				},
				{
					product_name: "Flocos de Aveia Suaves",
					product_name_pt: "Flocos de Aveia Suaves",
					brands: "Crownfield, Lidl",
				},
			],
		});
		await waitOnExecutionContext(ctx);

		expect(upstreamBodies).toHaveLength(1);
		expect(upstreamBodies[0].q).toBe(
			'categories_tags:"en:ketchup" AND countries_tags:"en:portugal"',
		);
		expect(upstreamBodies[0].langs).toEqual(["en", "pt"]);
		expect(upstreamBodies[0].fields).toEqual(expect.arrayContaining([
			"product_name_en",
			"product_name_pt",
			"product_name_es",
			"product_name_fr",
			"product_name_de",
			"product_name_it",
			"generic_name_en",
			"countries_tags",
		]));
	});

	it("falls back from category Search-a-licious to strict official v2 filters", async () => {
		const upstreamURLs: URL[] = [];
		vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
			const url = fetchedURL(input);
			upstreamURLs.push(url);
			if (url.origin === "https://search.openfoodfacts.org") {
				return new Response("search unavailable", { status: 503 });
			}
			return new Response(JSON.stringify({
				count: 1,
				page: 29,
				page_count: 1,
				page_size: 8,
				products: [{
					code: "8715700112596",
					product_name: "Ketchup zéro sel ajouté",
					product_name_en: "Tomato Ketchup 70%",
					brands: "Heinz",
				}],
			}), { headers: { "Content-Type": "application/json" } });
		});

		const { response, ctx } = await runWorker(
			"https://api.pickly.test/v1/categories/en%3Aketchup?page=29&page_size=8&country=en%3Aportugal&lang=en",
		);
		expect(response.status).toBe(200);
		expect(await response.json()).toMatchObject({
			products: [{
				product_name: "Tomato Ketchup 70%",
				product_name_en: "Tomato Ketchup 70%",
			}],
		});
		await waitOnExecutionContext(ctx);

		expect(upstreamURLs).toHaveLength(2);
		expect(upstreamURLs[1].origin).toBe(openFoodFactsOrigin);
		expect(upstreamURLs[1].pathname).toBe("/api/v2/search");
		expect(upstreamURLs[1].searchParams.get("categories_tags")).toBe("en:ketchup");
		expect(upstreamURLs[1].searchParams.get("countries_tags_en")).toBe("portugal");
		expect(upstreamURLs[1].searchParams.get("lc")).toBe("en");
		expect(upstreamURLs[1].searchParams.has("search_terms")).toBe(false);
		expect(upstreamURLs[1].searchParams.has("search_simple")).toBe(false);
		expect(upstreamURLs[1].pathname).not.toBe("/cgi/search.pl");
	});

	it("rejects unsafe category, country, language, and pagination parameters", async () => {
		const fetchSpy = vi.spyOn(globalThis, "fetch");
		const invalidRequests = [
			["https://api.pickly.test/v1/categories/ketchup?page=1&page_size=24", "invalid_category"],
			["https://api.pickly.test/v1/categories/en%3Aketchup%22%20OR%20%2A?page=1&page_size=24", "invalid_category"],
			["https://api.pickly.test/v1/categories/en%3Aketchup?country=pt%3Aportugal", "invalid_country"],
			["https://api.pickly.test/v1/categories/en%3Aketchup?lang=ru", "invalid_language"],
			["https://api.pickly.test/v1/categories/en%3Aketchup?page=0&page_size=24", "invalid_pagination"],
			["https://api.pickly.test/v1/categories/en%3Aketchup?page=1&page_size=51", "invalid_pagination"],
		] as const;

		for (const [url, error] of invalidRequests) {
			const { response } = await runWorker(url);
			expect(response.status).toBe(400);
			expect(await response.json()).toEqual({ error });
		}
		expect(fetchSpy).not.toHaveBeenCalled();
	});

	it("rejects unsupported goals and invalid pagination before calling upstream", async () => {
		const fetchSpy = vi.spyOn(globalThis, "fetch");
		const invalidURLs = [
			"https://api.pickly.test/v1/goals/all?page=1&page_size=24",
			"https://api.pickly.test/v1/goals/shortIngredients?page=1&page_size=24",
			"https://api.pickly.test/v1/goals/vegetarian?page=0&page_size=24",
			"https://api.pickly.test/v1/goals/vegetarian?page=1.5&page_size=24",
			"https://api.pickly.test/v1/goals/vegetarian?page=1&page_size=0",
			"https://api.pickly.test/v1/goals/vegetarian?page=1&page_size=51",
			"https://api.pickly.test/v1/goals/vegetarian?page=1&page_size=many",
		];

		for (const [index, url] of invalidURLs.entries()) {
			const { response } = await runWorker(url);
			expect(response.status).toBe(400);
			expect(await response.json()).toEqual({
				error: index < 2 ? "invalid_goal" : "invalid_pagination",
			});
		}
		expect(fetchSpy).not.toHaveBeenCalled();
	});

	it("falls back to the production legacy taxonomy endpoint when v2 is unavailable", async () => {
		const expectedPage = normalizedOffPage(88, 17);
		const upstreamURLs: URL[] = [];
		vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
			const url = fetchedURL(input);
			upstreamURLs.push(url);
			if (url.pathname === "/api/v2/search") {
				return new Response("peak demand", { status: 503 });
			}
			return new Response(JSON.stringify(offPage(88, 17)), {
				headers: { "Content-Type": "application/json" },
			});
		});

		const { response, ctx } = await runWorker(
			"https://api.pickly.test/v1/goals/lowSodium?page=88&page_size=17",
		);
		expect(response.status).toBe(200);
		expect(await response.json()).toEqual(expectedPage);
		await waitOnExecutionContext(ctx);

		expect(upstreamURLs).toHaveLength(3);
		expect(upstreamURLs[0].origin).toBe("https://search.openfoodfacts.org");
		expect(upstreamURLs[0].pathname).toBe("/search");
		expect(upstreamURLs[1].origin).toBe(openFoodFactsOrigin);
		expect(upstreamURLs[1].pathname).toBe("/api/v2/search");
		expect(upstreamURLs[2].origin).toBe(openFoodFactsOrigin);
		expect(upstreamURLs[2].pathname).toBe("/cgi/search.pl");
		expect(upstreamURLs[2].href).not.toContain("openfoodfacts.net");
		expect(upstreamURLs[2].searchParams.get("tagtype_0")).toBe("nutrient_levels");
		expect(upstreamURLs[2].searchParams.get("tag_contains_0")).toBe("contains");
		expect(upstreamURLs[2].searchParams.get("tag_0")).toBe("salt-in-low-quantity");
	});

	it("caches successful goal pages by normalized goal and pagination", async () => {
		const expectedPage = normalizedSearchPage(47, 13);
		const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () => new Response(
			JSON.stringify(searchPage(47, 13)),
			{ headers: { "Content-Type": "application/json" } },
		));

		const first = await runWorker(
			"https://api.pickly.test/v1/goals/vegetarian?page_size=13&page=47&ignored=true",
		);
		expect(await first.response.json()).toEqual(expectedPage);
		await waitOnExecutionContext(first.ctx);

		const second = await runWorker(
			"https://api.pickly.test/v1/goals/vegetarian?page=47&page_size=13",
		);
		expect(await second.response.json()).toEqual(expectedPage);
		await waitOnExecutionContext(second.ctx);

		expect(fetchSpy).toHaveBeenCalledTimes(1);
	});

	it("isolates category cache entries by country and language", async () => {
		const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (_input, init) => {
			const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
			return new Response(JSON.stringify({
				count: 1,
				page: Number(body.page),
				page_count: 1,
				page_size: Number(body.page_size),
				hits: [{
					code: "87157260",
					product_name: "Tomato Ketchup",
					product_name_en: "Tomato Ketchup",
				}],
			}), { headers: { "Content-Type": "application/json" } });
		});

		const urls = [
			"https://api.pickly.test/v1/categories/en%3Acache-language-test?page=337&page_size=6&country=en%3Aportugal&lang=en&ignored=true",
			"https://api.pickly.test/v1/categories/en%3Acache-language-test?page_size=6&page=337&lang=en&country=en%3Aportugal",
			"https://api.pickly.test/v1/categories/en%3Acache-language-test?page=337&page_size=6&country=en%3Aspain&lang=en",
			"https://api.pickly.test/v1/categories/en%3Acache-language-test?page=337&page_size=6&country=en%3Aportugal&lang=pt",
		];

		for (const url of urls) {
			const { response, ctx } = await runWorker(url);
			expect(response.status).toBe(200);
			await response.text();
			await waitOnExecutionContext(ctx);
		}

		expect(fetchSpy).toHaveBeenCalledTimes(3);
	});

	it("returns exact v3.6 barcode metadata and caches it by language", async () => {
		const upstreamURLs: URL[] = [];
		const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
			upstreamURLs.push(fetchedURL(input));
			return new Response(JSON.stringify({
				code: "8715700112596",
				status: "success",
				product: {
					code: "8715700112596",
					product_name: { main: "Ketchup zéro sel ajouté", en: "Nested Ketchup" },
					product_name_en: "Tomato Ketchup 70%",
					product_name_pt: "Ketchup de tomate 70%",
					countries_tags: ["en:france", "en:spain"],
					brands: ["Heinz"],
					quantity: "500 g",
					serving_size: "15 g",
					nutrition: { aggregated_set: { per: "100g", nutrients: {} } },
				},
			}), { headers: { "Content-Type": "application/json" } });
		});

		const first = await runWorker(
			"https://api.pickly.test/v1/off/products/8715700112596?lang=en&ignored=true",
		);
		expect(first.response.status).toBe(200);
		expect(first.response.headers.get("Cache-Control")).toBe("public, max-age=300, s-maxage=3600");
		expect(await first.response.json()).toMatchObject({
			code: "8715700112596",
			status: "success",
			product: {
				code: "8715700112596",
				product_name: "Tomato Ketchup 70%",
				product_name_en: "Tomato Ketchup 70%",
				product_name_pt: "Ketchup de tomate 70%",
					countries_tags: ["en:france", "en:spain"],
					brands: "Heinz",
					quantity: "500 g",
					serving_size: "15 g",
				},
		});
		await waitOnExecutionContext(first.ctx);

		const second = await runWorker(
			"https://api.pickly.test/v1/off/products/8715700112596?lang=en",
		);
		expect(second.response.status).toBe(200);
		await second.response.text();
		await waitOnExecutionContext(second.ctx);

		const third = await runWorker(
			"https://api.pickly.test/v1/off/products/8715700112596?lang=pt",
		);
		expect(third.response.status).toBe(200);
		await third.response.text();
		await waitOnExecutionContext(third.ctx);

		expect(fetchSpy).toHaveBeenCalledTimes(2);
		expect(upstreamURLs[0].pathname).toBe("/api/v3.6/product/8715700112596.json");
		expect(upstreamURLs[0].searchParams.get("lc")).toBe("en");
		expect(upstreamURLs[1].searchParams.get("lc")).toBe("pt");
		expect(upstreamURLs[1].searchParams.get("tags_lc")).toBe("pt");
		expect(upstreamURLs[0].searchParams.get("product_type")).toBe("food");
		const fields = upstreamURLs[0].searchParams.get("fields")?.split(",") ?? [];
		expect(fields).toEqual(expect.arrayContaining([
			"product_name_en",
			"product_name_pt",
			"generic_name_en",
			"countries_tags",
			"nutrition",
			"quantity",
			"serving_size",
		]));
	});

	it("returns 404 for absent exact OFF metadata and validates barcode and language", async () => {
		const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(
			JSON.stringify({ code: "12345678", status: "failure" }),
			{ headers: { "Content-Type": "application/json" } },
		));

		const absent = await runWorker(
			"https://api.pickly.test/v1/off/products/12345678?lang=en",
		);
		expect(absent.response.status).toBe(404);
		expect(await absent.response.json()).toEqual({ error: "not_found" });

		const invalidBarcode = await runWorker(
			"https://api.pickly.test/v1/off/products/not-a-barcode?lang=en",
		);
		expect(invalidBarcode.response.status).toBe(400);
		expect(await invalidBarcode.response.json()).toEqual({ error: "invalid_barcode" });

		const invalidLanguage = await runWorker(
			"https://api.pickly.test/v1/off/products/12345678901234?lang=ru",
		);
		expect(invalidLanguage.response.status).toBe(400);
		expect(await invalidLanguage.response.json()).toEqual({ error: "invalid_language" });

		expect(fetchSpy).toHaveBeenCalledTimes(1);
	});

	it("returns 503 for upstream failures and never caches them", async () => {
		const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
			new Response("upstream failed", { status: 502 }),
		);

		for (let attempt = 0; attempt < 2; attempt += 1) {
			const { response, ctx } = await runWorker(
				"https://api.pickly.test/v1/goals/vegan?page=48&page_size=14",
			);
			expect(response.status).toBe(503);
			expect(response.headers.get("Cache-Control")).toBe("no-store");
			expect(await response.json()).toEqual({ error: "open_food_facts_unavailable" });
			await waitOnExecutionContext(ctx);
		}

		expect(fetchSpy).toHaveBeenCalledTimes(6);
	});
});
