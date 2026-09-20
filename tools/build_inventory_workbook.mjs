import fs from "node:fs/promises";
import path from "node:path";
import { Workbook, SpreadsheetFile } from "/Users/mike/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";

const repo = "/Users/mike/Dev/Apps/critternest";
const outputDir = path.join(repo, "outputs", "kinu_content_inventory");
const outputPath = path.join(outputDir, "kinu_content_inventory.xlsx");
const catalogPath = path.join(repo, "resources/kinu/catalog.tres");
const thumbDir = path.join(repo, "resources/kinu/thumbs");
const sourceUrl = "resources/kinu/catalog.tres";

function extract(block, expression, fallback = "") {
  return block.match(expression)?.[1] ?? fallback;
}

function parseCatalog(text) {
  const items = [];
  const resources = text.matchAll(/\[sub_resource[^\n]*\n([\s\S]*?)(?=\[sub_resource|$)/g);
  for (const match of resources) {
    const block = match[1];
    const id = extract(block, /^id = "([^"]+)"/m);
    const name = extract(block, /^display_name = "([^"]+)"/m);
    if (!id || !name) continue;
    let type = extract(block, /^kind = "([^"]+)"/m);
    if (!type && block.includes("hood_color")) type = "outfit";
    if (!type || !["outfit", "box", "room"].includes(type)) continue;
    const price = Number(extract(block, /^price = (\d+)/m, "0"));
    const goal = extract(block, /^goal = "([^"]+)"/m);
    const goalAmount = Number(extract(block, /^goal_amount = (\d+)/m, "0"));
    const craneOnly = /^crane_only = true$/m.test(block);
    const rarity = extract(block, /^rarity = "([^"]+)"/m, "Starter");
    const catcherEligible = !goal && (price > 0 || craneOnly);
    const shopEligible = !goal && price > 0;
    const thumbnail = path.join(thumbDir, `${type}_${id}.png`);
    const hasThumbnail = awaitFile(thumbnail);
    let acquisition = "Starter / free";
    if (goal) acquisition = "Goal";
    else if (shopEligible && craneOnly) acquisition = "Shop + Catcher";
    else if (shopEligible) acquisition = "Shop + Catcher";
    else if (craneOnly) acquisition = "Catcher";
    items.push({
      type: type[0].toUpperCase() + type.slice(1), id, name, rarity: rarity[0].toUpperCase() + rarity.slice(1),
      price, goal, goalAmount, craneOnly, catcherEligible, shopEligible, thumbnail,
      thumbnailState: hasThumbnail ? "PNG linked" : "Needs room PNG",
      acquisition,
      proposedDay7: craneOnly ? "Eligible" : "Not eligible",
      availability: "Permanent", collectionSet: "Core", status: "Live", release: "Current", notes: hasThumbnail ? "" : "Room is currently rendered as an in-game swatch. Add exported PNG here."
    });
  }
  return items.sort((a, b) => a.type.localeCompare(b.type) || a.name.localeCompare(b.name));
}

function awaitFile(file) {
  try { return requireStat(file); } catch { return false; }
}
function requireStat(file) {
  // This uses the process-visible filesystem only to identify project-owned image assets.
  return Boolean(fsSync.statSync(file));
}

// fsSync avoids making the synchronous catalog parser asynchronous.
import fsSync from "node:fs";

function setHeader(range, fill = "#284B63") {
  range.format = {
    fill,
    font: { bold: true, color: "#FFFFFF", name: "Arial", size: 10 },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "all", style: "thin", color: "#D9E2EA" }
  };
}

function setSection(range) {
  range.format = {
    fill: "#DCEAF2",
    font: { bold: true, color: "#173042", name: "Arial", size: 10 },
    verticalAlignment: "center"
  };
}

const catalogText = await fs.readFile(catalogPath, "utf8");
const items = parseCatalog(catalogText);
const workbook = Workbook.create();
const dashboard = workbook.worksheets.add("Overview");
const inventory = workbook.worksheets.add("Inventory");
const lists = workbook.worksheets.add("Lists");

for (const sheet of [dashboard, inventory, lists]) {
  sheet.showGridLines = false;
  sheet.tabColor = sheet === dashboard ? "#284B63" : "#7FA8BD";
}

dashboard.getRange("A2:H2").merge();
dashboard.getRange("A2").values = [["Kinu Tumble content inventory"]];
dashboard.getRange("A2").format = { font: { bold: true, color: "#173042", name: "Arial", size: 16 }, verticalAlignment: "center" };
dashboard.getRange("A3:H3").merge();
dashboard.getRange("A3").values = [["Live catalogue snapshot and planning register. Edit future-facing fields on Inventory; the catalogue file remains the shipping source."]];
dashboard.getRange("A3").format = { font: { italic: true, color: "#52616B", name: "Arial", size: 10 } };
dashboard.getRange("A5:B5").values = [["Live inventory", "Count"]];
setHeader(dashboard.getRange("A5:B5"));
dashboard.getRange("A6:A11").values = [["All collectibles"], ["Outfits"], ["Boxes"], ["Rooms"], ["Machine eligible"], ["Claw-only"]];
dashboard.getRange("B6:B11").formulas = [["=COUNTA(Inventory!$C$7:$C$200)"], ["=COUNTIF(Inventory!$A$7:$A$200,\"Outfit\")"], ["=COUNTIF(Inventory!$A$7:$A$200,\"Box\")"], ["=COUNTIF(Inventory!$A$7:$A$200,\"Room\")"], ["=COUNTIF(Inventory!$J$7:$J$200,\"Yes\")"], ["=COUNTIF(Inventory!$I$7:$I$200,\"Yes\")"]];
dashboard.getRange("A6:B11").format = { font: { name: "Arial", size: 10 }, borders: { preset: "inside", style: "thin", color: "#D9E2EA" } };
dashboard.getRange("B6:B11").format.horizontalAlignment = "right";

dashboard.getRange("D5:E5").values = [["Shop economy", "Beans"]];
setHeader(dashboard.getRange("D5:E5"));
dashboard.getRange("D6:D10").values = [["Shop total"], ["Outfits"], ["Boxes"], ["Rooms"], ["Common items"]];
dashboard.getRange("E6:E10").formulas = [["=SUM(Inventory!$F$7:$F$200)"], ["=SUMIF(Inventory!$A$7:$A$200,\"Outfit\",Inventory!$F$7:$F$200)"], ["=SUMIF(Inventory!$A$7:$A$200,\"Box\",Inventory!$F$7:$F$200)"], ["=SUMIF(Inventory!$A$7:$A$200,\"Room\",Inventory!$F$7:$F$200)"], ["=SUMIF(Inventory!$E$7:$E$200,\"Common\",Inventory!$F$7:$F$200)"]];
dashboard.getRange("D6:E10").format = { font: { name: "Arial", size: 10 }, borders: { preset: "inside", style: "thin", color: "#D9E2EA" } };
dashboard.getRange("E6:E10").format.numberFormat = "#,##0";

dashboard.getRange("A14:H14").merge();
dashboard.getRange("A14").values = [["Planning rules"]];
setSection(dashboard.getRange("A14:H14"));
dashboard.getRange("A15:B20").values = [
  ["Field", "Use"],
  ["Status", "Live, planned, seasonal, vaulted, or retired. Only Live is currently shipping."],
  ["Collection set", "Group future releases into named themes such as Spring 2027 or Moonlight."],
  ["Availability", "Permanent for core content. Use Seasonal only for timed content that will return."],
  ["Proposed Day 7", "Recommended weekly reward pool: claw-only items only, so the bean shop remains targeted."],
  ["Thumbnail state", "PNG linked means an actual project thumbnail is embedded. Needs PNG flags any future item awaiting art."]
];
setHeader(dashboard.getRange("A15:B15"), "#5E7D8A");
dashboard.getRange("A16:B20").format = { font: { name: "Arial", size: 10 }, wrapText: true, verticalAlignment: "top", borders: { preset: "inside", style: "thin", color: "#E1E8ED" } };
dashboard.getRange("A16:A20").format.font = { bold: true, color: "#173042", name: "Arial", size: 10 };

dashboard.getRange("D14:H14").merge();
dashboard.getRange("D14").values = [["Source and refresh"]];
setSection(dashboard.getRange("D14:H14"));
dashboard.getRange("D15:H18").values = [
  ["Shipping catalogue", sourceUrl, "" , "", ""],
  ["Thumbnail folder", "resources/kinu/thumbs", "", "", ""],
  ["Last generated", new Date(), "", "", ""],
  ["Workflow", "Add the item to the Godot catalogue, export its PNG to the thumbnail folder, then regenerate this workbook.", "", "", ""]
];
dashboard.getRange("D15:D18").format.font = { bold: true, color: "#173042", name: "Arial", size: 10 };
dashboard.getRange("D15:E18").format = { font: { name: "Arial", size: 10 }, wrapText: true, verticalAlignment: "top", borders: { preset: "inside", style: "thin", color: "#E1E8ED" } };
dashboard.getRange("E17").format.numberFormat = "yyyy-mm-dd";

const headers = ["Type", "Item ID", "Display name", "Thumbnail", "Rarity", "Shop price", "Goal type", "Goal amount", "Claw-only", "Catcher eligible", "Proposed Day 7", "Acquisition", "Availability", "Collection set", "Status", "Release", "Thumbnail state", "Notes"];
inventory.getRange("A2:R2").merge();
inventory.getRange("A2").values = [["Content inventory"]];
inventory.getRange("A2").format = { font: { bold: true, color: "#173042", name: "Arial", size: 16 } };
inventory.getRange("A3:R3").merge();
inventory.getRange("A3").values = [["Fields through Thumbnail state reflect the current catalogue. Availability, Collection set, Status, Release, and Notes are planning fields for future content."]];
inventory.getRange("A3").format = { font: { italic: true, color: "#52616B", name: "Arial", size: 10 } };
inventory.getRange("A6:R6").values = [headers];
setHeader(inventory.getRange("A6:R6"));
const rows = items.map(item => [item.type, item.id, item.name, "", item.rarity, item.price || "", item.goal, item.goalAmount || "", item.craneOnly ? "Yes" : "No", item.catcherEligible ? "Yes" : "No", item.proposedDay7, item.acquisition, item.availability, item.collectionSet, item.status, item.release, item.thumbnailState, item.notes]);
inventory.getRangeByIndexes(6, 0, rows.length, headers.length).values = rows;
const lastRow = 6 + rows.length;
inventory.tables.add(`A6:R${lastRow}`, true, "ContentInventory");
inventory.getRange(`A7:R${lastRow}`).format = { font: { name: "Arial", size: 9 }, verticalAlignment: "center", wrapText: true };
inventory.getRange(`A6:R${lastRow}`).format.borders = { preset: "all", style: "thin", color: "#9CBED0" };
inventory.getRange(`F7:F${lastRow}`).format.numberFormat = "#,##0";
inventory.getRange(`H7:H${lastRow}`).format.numberFormat = "#,##0";
inventory.getRange(`A7:R${lastRow}`).format.rowHeightPx = 72;
inventory.getRange(`N7:R${lastRow}`).format.fill = "#FFF7DB";
inventory.getRange(`A7:M${lastRow}`).format.fill = "#F7FAFC";
inventory.getRange(`Q7:Q${lastRow}`).conditionalFormats.add("containsText", { text: "Needs", format: { fill: "#FDE2E2", font: { color: "#A32626", bold: true } } });
inventory.freezePanes.freezeRows(6);
inventory.freezePanes.freezeColumns(3);

const widths = [14, 20, 24, 16, 12, 12, 15, 13, 11, 14, 15, 19, 14, 18, 14, 14, 16, 38];
for (let col = 0; col < widths.length; col++) inventory.getRangeByIndexes(0, col, 1, 1).format.columnWidth = widths[col];

for (let index = 0; index < items.length; index++) {
  const item = items[index];
  if (!item.thumbnail || !fsSync.existsSync(item.thumbnail)) continue;
  const dataUrl = "data:image/png;base64," + (await fs.readFile(item.thumbnail)).toString("base64");
  inventory.images.add({
    dataUrl,
    alt: `${item.name} thumbnail`,
    anchor: { from: { row: index + 6, col: 3, rowOffsetPx: 5, colOffsetPx: 7 }, extent: { widthPx: 66, heightPx: 62 } }
  });
}

lists.getRange("A2:D2").merge();
lists.getRange("A2").values = [["Controlled planning values"]];
lists.getRange("A2").format = { font: { bold: true, color: "#173042", name: "Arial", size: 14 } };
lists.getRange("A4:D4").values = [["Availability", "Status", "Release format", "Day 7 eligibility"]];
setHeader(lists.getRange("A4:D4"), "#5E7D8A");
lists.getRange("A5:D9").values = [
  ["Permanent", "Live", "Current", "Eligible"],
  ["Seasonal", "Planned", "Seasonal", "Not eligible"],
  ["Vaulted", "In production", "Event", ""],
  ["Retired", "Vaulted", "", ""],
  ["", "Retired", "", ""]
];
lists.getRange("A5:D9").format = { font: { name: "Arial", size: 10 }, borders: { preset: "inside", style: "thin", color: "#E1E8ED" } };
lists.getRange("A1:D15").format.columnWidth = 18;

inventory.getRange(`M7:M${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$A$5:$A$8" } };
inventory.getRange(`O7:O${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$B$5:$B$9" } };
inventory.getRange(`P7:P${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$C$5:$C$7" } };
inventory.getRange(`K7:K${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$D$5:$D$6" } };

dashboard.getRange("A1:H25").format.font = { name: "Arial", size: 10, color: "#1F2933" };
dashboard.getRange("A1:H25").format.columnWidth = 18;
dashboard.getRange("B15:B20").format.columnWidth = 54;
dashboard.getRange("E15:E18").format.columnWidth = 34;
dashboard.getRange("A2:H2").format.rowHeightPx = 28;
dashboard.getRange("A14:H14").format.rowHeightPx = 22;
dashboard.getRange("D14:H14").format.rowHeightPx = 22;
dashboard.getRange("A16:B20").format.rowHeightPx = 35;
dashboard.getRange("D15:E18").format.rowHeightPx = 30;

workbook.recalculate();
await fs.mkdir(outputDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

const summary = await workbook.inspect({ kind: "table", range: "Overview!A2:E18", include: "values,formulas", tableMaxRows: 25, tableMaxCols: 8 });
console.log(summary.ndjson);
const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 50 }, summary: "formula error scan" });
console.log(errors.ndjson);
for (const [sheetName, range, filename] of [
  ["Overview", "A1:H20", "overview_preview.png"],
  ["Inventory", "A1:R18", "inventory_preview.png"],
  ["Lists", "A1:D10", "lists_preview.png"]
]) {
  const preview = await workbook.render({ sheetName, range, scale: 1.25, format: "png" });
  await fs.writeFile(path.join(outputDir, filename), new Uint8Array(await preview.arrayBuffer()));
}
console.log(`Wrote ${outputPath}`);
