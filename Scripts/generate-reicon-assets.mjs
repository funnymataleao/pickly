#!/usr/bin/env node

import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const packageRoot = process.argv[2];
const outputRoot = process.argv[3];

if (!packageRoot || !outputRoot) {
  console.error(
    "Usage: generate-reicon-assets.mjs <reicon-react package root> <asset catalog group>"
  );
  process.exit(1);
}

const iconNames = [
  "AlertTriangle",
  "ArrowSwapHorizontal",
  "ArrowUpRightCircle",
  "Bag",
  "Barcode",
  "Basket",
  "Bookmark",
  "BranchUp",
  "Camera",
  "ChartBar",
  "Check",
  "CheckCircle",
  "ChevronDown",
  "ChevronRight",
  "Clock",
  "CloseCircle",
  "CloudX",
  "ThreeDCube",
  "DocText",
  "Drop",
  "Droplet",
  "Envelope",
  "EnvelopeCheck",
  "Eye",
  "Feather",
  "Flask",
  "FoodTray",
  "ForkKnife",
  "Grid",
  "Hashtag",
  "HeartPulse",
  "HeartSquare",
  "Image",
  "InfoCircle",
  "Keyboard",
  "Layout",
  "Leaf",
  "ListSquare",
  "Milk",
  "Minus",
  "Mobile",
  "ProfileCircle",
  "Record",
  "Refresh",
  "ScanBarcode",
  "Search",
  "SearchPlus",
  "SearchStatus",
  "Shield",
  "ShieldCheck",
  "ShieldLock",
  "SignalSquare",
  "Sliders",
  "Sparkles",
  "UserId",
  "Verified"
];

const weights = [
  { key: "O", suffix: "Outline" },
  { key: "F", suffix: "Filled" }
];

const contents = {
  images: [{ filename: "icon.svg", idiom: "universal" }],
  info: { author: "xcode", version: 1 },
  properties: {
    "preserves-vector-representation": true,
    "template-rendering-intent": "template"
  }
};

for (const iconName of iconNames) {
  const sourcePath = path.join(packageRoot, "icons", `${iconName}.js`);
  const source = await readFile(sourcePath, "utf8");

  for (const weight of weights) {
    const pattern = new RegExp("\\b" + weight.key + ": `([\\s\\S]*?)`");
    const match = source.match(pattern);

    if (!match) {
      throw new Error(`Missing ${weight.key} SVG markup in ${sourcePath}`);
    }

    const markup = match[1]
      .replaceAll("currentColor", "#000000")
      .replaceAll("<script", "&lt;script");
    const svg = [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">',
      markup,
      "</svg>",
      ""
    ].join("\n");

    const assetName = `Reicon${iconName}${weight.suffix}`;
    const assetDirectory = path.join(outputRoot, `${assetName}.imageset`);

    await mkdir(assetDirectory, { recursive: true });
    await writeFile(path.join(assetDirectory, "icon.svg"), svg, "utf8");
    await writeFile(
      path.join(assetDirectory, "Contents.json"),
      `${JSON.stringify(contents, null, 2)}\n`,
      "utf8"
    );
  }
}

console.log(`Generated ${iconNames.length * weights.length} Reicon vector assets.`);
