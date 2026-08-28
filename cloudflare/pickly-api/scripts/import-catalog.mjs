import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { verifiedEnglishDisplayNamesByBarcode } from "./verified-display-names.mjs";

const execFileAsync = promisify(execFile);
const root = new URL("../../..", import.meta.url).pathname;
const workerDirectory = new URL("..", import.meta.url).pathname;

const productColumns = [
	"id", "barcode", "name", "display_name", "brand", "category", "image_url", "ingredients", "nutrition",
	"score", "verdict", "summary", "reasons", "warnings", "positives", "confidence", "source",
	"score_version", "is_published", "created_at", "updated_at",
];

async function main() {
	const products = await supabaseRows(`
		SELECT id, barcode, name, brand, category, image_url, ingredients, nutrition,
		       score, verdict, summary, reasons, warnings, positives, confidence, source,
		       score_version, is_published, created_at, updated_at
		FROM public.products
		ORDER BY id
	`);
	const alternatives = await supabaseRows(`
		SELECT product_id, alternative_product_id, reason, rank, created_at
		FROM public.product_alternatives
		ORDER BY product_id, rank, alternative_product_id
	`);

	const productStatements = products.map((product) => {
		const values = productColumns.map((column) => sqliteValue(productValue(product, column)));
		return `
			INSERT INTO products (${productColumns.join(", ")})
			VALUES (${values.join(", ")})
			ON CONFLICT(id) DO UPDATE SET
			  barcode = excluded.barcode,
			  name = excluded.name,
			  display_name = COALESCE(excluded.display_name, products.display_name),
			  brand = excluded.brand,
			  category = excluded.category,
			  image_url = excluded.image_url,
			  ingredients = excluded.ingredients,
			  nutrition = excluded.nutrition,
			  score = excluded.score,
			  verdict = excluded.verdict,
			  summary = excluded.summary,
			  reasons = excluded.reasons,
			  warnings = excluded.warnings,
			  positives = excluded.positives,
			  confidence = excluded.confidence,
			  source = excluded.source,
			  score_version = excluded.score_version,
			  is_published = excluded.is_published,
			  created_at = excluded.created_at,
			  updated_at = excluded.updated_at
		`;
	});
	await d1(productStatements.map((statement) => `${statement};`).join("\n"));

	const alternativeStatements = alternatives.map((alternative) => `
			INSERT INTO product_alternatives (product_id, alternative_product_id, reason, rank, created_at)
			VALUES (${sqliteValue(alternative.product_id)}, ${sqliteValue(alternative.alternative_product_id)}, ${sqliteValue(alternative.reason)}, ${sqliteValue(alternative.rank)}, ${sqliteValue(alternative.created_at)})
			ON CONFLICT(product_id, alternative_product_id) DO UPDATE SET
			  reason = excluded.reason,
			  rank = excluded.rank,
			  created_at = excluded.created_at
		`);
	await d1(alternativeStatements.map((statement) => `${statement};`).join("\n"));

	console.log(`Imported ${products.length} products and ${alternatives.length} alternatives.`);
}

async function supabaseRows(query) {
	const { stdout } = await execFileAsync(
		"npx",
		["supabase", "db", "query", "--linked", "--output", "json", query],
		{ cwd: root, maxBuffer: 8 * 1024 * 1024 },
	);
	const firstObject = stdout.indexOf("{");
	if (firstObject === -1) throw new Error("Supabase did not return JSON.");
	const payload = JSON.parse(stdout.slice(firstObject));
	if (!Array.isArray(payload.rows)) throw new Error("Supabase response did not contain rows.");
	return payload.rows;
}

async function d1(command) {
	await execFileAsync(
		"npx",
		["wrangler", "d1", "execute", "pickly-production", "--remote", "--command", command],
		{ cwd: workerDirectory, maxBuffer: 8 * 1024 * 1024 },
	);
}

function productValue(product, column) {
	if (column === "display_name") {
		return verifiedEnglishDisplayNamesByBarcode[product.barcode] ?? null;
	}
	if (["ingredients", "nutrition", "reasons", "warnings", "positives"].includes(column)) {
		return JSON.stringify(product[column] ?? (column === "nutrition" ? {} : []));
	}
	if (column === "is_published") return product[column] ? 1 : 0;
	return product[column] ?? null;
}

function sqliteValue(value) {
	if (value === null || value === undefined) return "NULL";
	if (typeof value === "number") return Number.isFinite(value) ? String(value) : "NULL";
	return `'${String(value).replaceAll("'", "''")}'`;
}

main().catch((error) => {
	console.error(error instanceof Error ? error.message : "Catalog import failed.");
	process.exitCode = 1;
});
