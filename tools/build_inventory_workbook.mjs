import fs from "node:fs/promises";
import path from "node:path";
import { Workbook, SpreadsheetFile } from "/Users/mike/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";

const repo = "/Users/mike/Dev/Apps/critternest";
const outputDir = path.join(repo, "outputs", "kinu_content_inventory");
const outputPath = path.join(outputDir, "kinu_content_inventory.xlsx");
const catalogPath = path.join(repo, "resources/kinu/catalog.tres");
const thumbDir = path.join(repo, "resources/kinu/thumbs");
const sourceUrl = "resources/kinu/catalog.tres";
const seasonalItems = new Map([
  ["pumpkin", { availability: "Seasonal", collectionSet: "Harvest", notes: "Shop item for the autumn window." }],
  ["pumpkin_patch", { availability: "Seasonal", collectionSet: "Harvest", notes: "Shop item for the autumn window." }],
  ["snowman", { availability: "Seasonal", collectionSet: "Winter", status: "Upcoming", release: "Winter window", notes: "Hidden from shop and Catcher until the winter window opens." }],
  ["snowdrift", { availability: "Seasonal", collectionSet: "Winter", status: "Upcoming", release: "Winter window", notes: "Hidden from shop and Catcher until the winter window opens." }]
]);

// How each Monthly Showcase reward was acquired before it became showcase-only, so a later decision
// to move an expended reward into the shop or claw has the old price and tier to hand.
// The Grand Opening launch event. Its goals live in scripts/systems/grand_opening.gd (REWARDS);
// keep these in step if they change.
const grandOpening = { start: "2026-09-29", end: "2026-10-31", storeCard: "1 Oct – 31 Oct 2026" };
const grandOpeningRewards = new Map([
  ["outfit:opening_day", { order: 1, requirement: "Play 1 run" }],
  ["box:first_edition", { order: 2, requirement: "Finish 5 daily missions" }],
  ["room:grand_opening", { order: 3, requirement: "Play on 5 different days" }],
]);

const showcaseHistory = new Map([
  ["geode", { previous: "Kinu Claw only (Legendary)", previousPrice: 0, requirement: "Weeks 3–4 (launched 21 Sep, mid-month)" }],
  ["maneki", { previous: "Kinu Claw only (Legendary)", previousPrice: 0 }],
  ["moon_base", { previous: "Kinu Claw only (Legendary)", previousPrice: 0 }],
  ["shortcake", { previous: "Shop 7,500 + Kinu Claw (Rare)", previousPrice: 7500 }],
  ["ramen_bowl", { previous: "Shop 6,000 + Kinu Claw (Epic)", previousPrice: 6000 }],
  ["lantern_river", { previous: "Shop 16,250 + Kinu Claw (Epic)", previousPrice: 16250 }]
]);
const today = new Date();
const thisMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}`;
function showcaseStatus(month) {
  return month === thisMonth ? "Active" : month > thisMonth ? "Upcoming" : "Expended";
}
function monthDate(month) {
  const [year, number] = month.split("-").map(Number);
  return new Date(Date.UTC(year, number - 1, 1));
}
function monthLabel(month) {
  return monthDate(month).toLocaleString("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
}

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
    const available = !/^available = false$/m.test(block);
    const showcase = extract(block, /^showcase = "([^"]+)"/m);
    const event = extract(block, /^event = "([^"]+)"/m);
    const eventReward = grandOpeningRewards.get(`${type}:${id}`);
    const rarity = extract(block, /^rarity = "([^"]+)"/m, "Starter");
    const catcherEligible = available && !goal && !showcase && !event && (price > 0 || craneOnly);
    const shopEligible = available && !goal && !showcase && !event && price > 0;
    const thumbnail = path.join(thumbDir, `${type}_${id}.png`);
    const hasThumbnail = awaitFile(thumbnail);
    let acquisition = "Starter / free";
    if (goal) acquisition = "Goal";
    else if (shopEligible && craneOnly) acquisition = "Shop + Catcher";
    else if (shopEligible) acquisition = "Shop + Catcher";
    else if (craneOnly) acquisition = "Catcher";
    const planning = seasonalItems.get(id) ?? {};
    if (!available) acquisition = "Upcoming seasonal";
    if (showcase) acquisition = "Monthly Showcase";
    if (event) acquisition = "Grand Opening";
    items.push({
      type: type[0].toUpperCase() + type.slice(1), id, name, rarity: rarity[0].toUpperCase() + rarity.slice(1),
      price, goal, goalAmount, craneOnly, catcherEligible, shopEligible, available, thumbnail, showcase, event,
      thumbnailState: hasThumbnail ? "PNG linked" : "Needs room PNG",
      acquisition,
      proposedDay7: craneOnly ? "Eligible" : "Not eligible",
      availability: planning.availability ?? "Permanent", collectionSet: planning.collectionSet ?? (id === "abyss" || id === "kraken_hatchling" ? "Abyssal" : id === "starforge" ? "Celestial Forge" : "Core"), status: planning.status ?? (available ? "Live" : "Upcoming"), release: planning.release ?? (planning.availability ? "Seasonal" : "Current"), notes: planning.notes ?? (hasThumbnail ? "" : "Room is currently rendered as an in-game swatch. Add exported PNG here.")
    });
    if (showcase) {
      const item = items[items.length - 1];
      item.availability = "Monthly Showcase";
      item.collectionSet = "Monthly Showcase";
      item.status = showcaseStatus(showcase);
      item.release = monthLabel(showcase);
      item.proposedDay7 = "Not eligible";
      item.notes = `${monthLabel(showcase)} Monthly Showcase reward. Not sold in the shop or dropped by the Kinu Catcher.`;
    }
    if (event) {
      const item = items[items.length - 1];
      item.availability = "Limited event";
      item.collectionSet = "Grand Opening";
      item.status = new Date() > new Date("2026-10-31T23:59:59") ? "Expended" : "Live";
      item.release = "Event";
      item.proposedDay7 = "Not eligible";
      item.requirement = eventReward?.requirement ?? "";
      item.notes = `Grand Opening launch exclusive: ${item.requirement.toLowerCase()} between 29 Sep and 31 Oct 2026. Never sold or dropped, and never returns.`;
    }
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
const current = workbook.worksheets.add("Current");
const upcoming = workbook.worksheets.add("Upcoming seasonal");
const showcaseSheet = workbook.worksheets.add("Monthly Showcase");
const eventSheet = workbook.worksheets.add("Grand Opening");
const lists = workbook.worksheets.add("Lists");

for (const sheet of [dashboard, inventory, current, upcoming, showcaseSheet, eventSheet, lists]) {
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
dashboard.getRange("A6:A13").values = [["All collectibles"], ["Outfits"], ["Boxes"], ["Rooms"], ["Machine eligible"], ["Claw-only"], ["Monthly Showcase"], ["Grand Opening"]];
dashboard.getRange("B6:B13").formulas = [["=COUNTA(Inventory!$C$7:$C$200)"], ["=COUNTIF(Inventory!$A$7:$A$200,\"Outfit\")"], ["=COUNTIF(Inventory!$A$7:$A$200,\"Box\")"], ["=COUNTIF(Inventory!$A$7:$A$200,\"Room\")"], ["=COUNTIF(Inventory!$J$7:$J$200,\"Yes\")"], ["=COUNTIF(Inventory!$I$7:$I$200,\"Yes\")"], ["=COUNTIF(Inventory!$L$7:$L$200,\"Monthly Showcase\")"], ["=COUNTIF(Inventory!$L$7:$L$200,\"Grand Opening\")"]];
dashboard.getRange("A6:B13").format = { font: { name: "Arial", size: 10 }, borders: { preset: "inside", style: "thin", color: "#D9E2EA" } };
dashboard.getRange("B6:B13").format.horizontalAlignment = "right";

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
lists.getRange("A5:D12").values = [
  ["Permanent", "Live", "Current", "Eligible"],
  ["Seasonal", "Planned", "Seasonal", "Not eligible"],
  ["Vaulted", "In production", "Event", ""],
  ["Retired", "Vaulted", "", ""],
  ["Monthly Showcase", "Retired", "", ""],
  ["Limited event", "Upcoming", "", ""],
  ["", "Active", "", ""],
  ["", "Expended", "", ""]
];
lists.getRange("A5:D12").format = { font: { name: "Arial", size: 10 }, borders: { preset: "inside", style: "thin", color: "#E1E8ED" } };
lists.getRange("A1:D15").format.columnWidth = 18;

inventory.getRange(`M7:M${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$A$5:$A$10" } };
inventory.getRange(`O7:O${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$B$5:$B$12" } };
inventory.getRange(`P7:P${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$C$5:$C$7" } };
inventory.getRange(`K7:K${lastRow}`).dataValidation = { rule: { type: "list", formula1: "Lists!$D$5:$D$6" } };

async function buildReleaseView(sheet, title, subtitle, viewItems, tableName, tint) {
  const viewHeaders = ["Type", "Item ID", "Display name", "Thumbnail", "Rarity", "Availability", "Release", "Acquisition", "Shop price", "Notes"];
  sheet.getRange("A2:J2").merge();
  sheet.getRange("A2").values = [[title]];
  sheet.getRange("A2").format = { font: { bold: true, color: "#173042", name: "Arial", size: 16 } };
  sheet.getRange("A3:J3").merge();
  sheet.getRange("A3").values = [[subtitle]];
  sheet.getRange("A3").format = { font: { italic: true, color: "#52616B", name: "Arial", size: 10 } };
  sheet.getRange("A6:J6").values = [viewHeaders];
  setHeader(sheet.getRange("A6:J6"), tint);
  const viewRows = viewItems.map(item => [item.type, item.id, item.name, "", item.rarity, item.availability, item.release, item.acquisition, item.price || "", item.notes]);
  const viewLastRow = 6 + viewRows.length;
  if (viewRows.length) {
    sheet.getRangeByIndexes(6, 0, viewRows.length, viewHeaders.length).values = viewRows;
    sheet.tables.add(`A6:J${viewLastRow}`, true, tableName);
    sheet.getRange(`A7:J${viewLastRow}`).format = { font: { name: "Arial", size: 10 }, verticalAlignment: "center", wrapText: true, rowHeightPx: 72, borders: { preset: "all", style: "thin", color: "#9CBED0" } };
    sheet.getRange(`I7:I${viewLastRow}`).format.numberFormat = "#,##0";
    for (let index = 0; index < viewItems.length; index++) {
      const item = viewItems[index];
      if (!fsSync.existsSync(item.thumbnail)) continue;
      const dataUrl = "data:image/png;base64," + (await fs.readFile(item.thumbnail)).toString("base64");
      sheet.images.add({ dataUrl, alt: `${item.name} thumbnail`, anchor: { from: { row: index + 6, col: 3, rowOffsetPx: 5, colOffsetPx: 7 }, extent: { widthPx: 66, heightPx: 62 } } });
    }
  }
  const viewWidths = [14, 20, 24, 16, 12, 14, 18, 20, 12, 46];
  for (let col = 0; col < viewWidths.length; col++) sheet.getRangeByIndexes(0, col, 1, 1).format.columnWidth = viewWidths[col];
  sheet.freezePanes.freezeRows(6);
  sheet.freezePanes.freezeColumns(3);
}

await buildReleaseView(current, "Current content", "Items currently available in the game. Seasonal autumn items remain here while their window is open.", items.filter(item => item.available), "CurrentContent", "#284B63");
await buildReleaseView(upcoming, "Upcoming seasonal content", "Items held out of the shop and Kinu Catcher until their seasonal release window.", items.filter(item => !item.available && item.availability === "Seasonal"), "UpcomingSeasonal", "#5E7D8A");

// ---------- Monthly Showcase ----------
// The schedule comes from `showcase = "YYYY-MM"` on catalogue items. Status is a live formula
// against TODAY(), so a month flips to Expended on its own once it ends, with no regeneration.
const showcaseItems = items.filter(item => item.showcase).sort((a, b) => a.showcase.localeCompare(b.showcase));
showcaseSheet.getRange("A2:N2").merge();
showcaseSheet.getRange("A2").values = [["Monthly Showcase rewards"]];
showcaseSheet.getRange("A2").format = { font: { bold: true, color: "#173042", name: "Arial", size: 16 } };
showcaseSheet.getRange("A3:N3").merge();
showcaseSheet.getRange("A3").values = [["One exclusive cosmetic per calendar month, earned by finishing all four of that month's weekly challenges. Resets on the 1st. Showcase rewards are never sold in the shop or dropped by the Kinu Catcher; they stay visible in the Kinu Book as exclusives."]];
showcaseSheet.getRange("A3").format = { font: { italic: true, color: "#52616B", name: "Arial", size: 10 }, wrapText: true };
showcaseSheet.getRange("A3:N3").format.rowHeightPx = 32;
const showcaseHeaders = ["Month", "Month key", "Reward type", "Item ID", "Display name", "Thumbnail", "Rarity", "Exclusivity", "Acquisition", "Requirement", "Status", "Acquired before showcase", "After it expends", "Notes"];
showcaseSheet.getRange("A6:N6").values = [showcaseHeaders];
setHeader(showcaseSheet.getRange("A6:N6"), "#8A2150");
const showcaseRows = showcaseItems.map(item => {
  const history = showcaseHistory.get(item.id) ?? {};
  return [monthDate(item.showcase), item.showcase, item.type === "Outfit" ? "Kinu outfit" : item.type, item.id, item.name, "", item.rarity, "Showcase-only", "Finish every weekly challenge in the month", history.requirement ?? "All 4 weekly challenges", "", history.previous ?? "", "Undecided: may move to Shop or Kinu Claw", item.id === "geode" ? "Short first month: only weeks 3–4 remained at launch, so September asks for those two." : ""];
});
const showcaseLast = 6 + showcaseRows.length;
showcaseSheet.getRangeByIndexes(6, 0, showcaseRows.length, showcaseHeaders.length).values = showcaseRows;
for (let row = 7; row <= showcaseLast; row++) {
  showcaseSheet.getRange(`K${row}`).formulas = [[`=IF(EOMONTH(A${row},0)<TODAY(),"Expended",IF(A${row}>TODAY(),"Upcoming","Active"))`]];
}
showcaseSheet.tables.add(`A6:N${showcaseLast}`, true, "MonthlyShowcase");
showcaseSheet.getRange(`A7:N${showcaseLast}`).format = { font: { name: "Arial", size: 10 }, verticalAlignment: "center", wrapText: true, rowHeightPx: 72, borders: { preset: "all", style: "thin", color: "#E3B3C8" } };
showcaseSheet.getRange(`A7:A${showcaseLast}`).format.numberFormat = "mmmm yyyy";
showcaseSheet.getRange(`A7:A${showcaseLast}`).format.font = { bold: true, name: "Arial", size: 10, color: "#5B1E3C" };
showcaseSheet.getRange(`M7:N${showcaseLast}`).format.fill = "#FFF7DB";
showcaseSheet.getRange(`K7:K${showcaseLast}`).format.horizontalAlignment = "center";
showcaseSheet.getRange(`K7:K${showcaseLast}`).conditionalFormats.add("containsText", { text: "Active", format: { fill: "#D8F3BD", font: { color: "#2E6B1F", bold: true } } });
showcaseSheet.getRange(`K7:K${showcaseLast}`).conditionalFormats.add("containsText", { text: "Upcoming", format: { fill: "#DCEAF2", font: { color: "#173042", bold: true } } });
showcaseSheet.getRange(`K7:K${showcaseLast}`).conditionalFormats.add("containsText", { text: "Expended", format: { fill: "#E6E1E5", font: { color: "#6B5E68", bold: true } } });
for (let index = 0; index < showcaseItems.length; index++) {
  const item = showcaseItems[index];
  if (!fsSync.existsSync(item.thumbnail)) continue;
  const dataUrl = "data:image/png;base64," + (await fs.readFile(item.thumbnail)).toString("base64");
  showcaseSheet.images.add({ dataUrl, alt: `${item.name} thumbnail`, anchor: { from: { row: index + 6, col: 5, rowOffsetPx: 5, colOffsetPx: 7 }, extent: { widthPx: 66, heightPx: 62 } } });
}
const showcaseWidths = [16, 11, 13, 16, 18, 14, 11, 15, 22, 22, 12, 26, 24, 40];
for (let col = 0; col < showcaseWidths.length; col++) showcaseSheet.getRangeByIndexes(0, col, 1, 1).format.columnWidth = showcaseWidths[col];
showcaseSheet.freezePanes.freezeRows(6);

// Claw odds with the six rewards taken out. Cosmetic hits are a fixed 10% of plays split by tier,
// so removing items only raises each remaining item's share within its tier.
const oddsTop = showcaseLast + 3;
showcaseSheet.getRange(`A${oddsTop}:G${oddsTop}`).merge();
showcaseSheet.getRange(`A${oddsTop}`).values = [["Kinu Claw odds after removing the showcase rewards"]];
setSection(showcaseSheet.getRange(`A${oddsTop}:G${oddsTop}`));
const oddsHeaderRow = oddsTop + 1;
showcaseSheet.getRange(`A${oddsHeaderRow}:G${oddsHeaderRow}`).values = [["Tier", "Share of cosmetic hits", "Tier chance per play", "Items before", "Items now", "Per item before", "Per item now"]];
setHeader(showcaseSheet.getRange(`A${oddsHeaderRow}:G${oddsHeaderRow}`), "#5E7D8A");
const tierWeights = { Common: 55, Rare: 25, Epic: 13, Legendary: 7 };
const clawNow = items.filter(item => item.catcherEligible);
const tierRows = Object.entries(tierWeights).map(([tier, weight], index) => {
  const row = oddsHeaderRow + 1 + index;
  const now = clawNow.filter(item => item.rarity === tier).length;
  const removed = showcaseItems.filter(item => item.rarity === tier).length;
  return { row, values: [tier, weight / 100, "", now + removed, now, "", ""] };
});
for (const { row, values } of tierRows) {
  showcaseSheet.getRange(`A${row}:G${row}`).values = [values];
  showcaseSheet.getRange(`C${row}`).formulas = [[`=0.1*B${row}`]];
  showcaseSheet.getRange(`F${row}`).formulas = [[`=IF(D${row}=0,0,C${row}/D${row})`]];
  showcaseSheet.getRange(`G${row}`).formulas = [[`=IF(E${row}=0,0,C${row}/E${row})`]];
}
const oddsLast = oddsHeaderRow + tierRows.length;
showcaseSheet.getRange(`A${oddsHeaderRow + 1}:G${oddsLast}`).format = { font: { name: "Arial", size: 10 }, borders: { preset: "all", style: "thin", color: "#D9E2EA" } };
showcaseSheet.getRange(`B${oddsHeaderRow + 1}:C${oddsLast}`).format.numberFormat = "0.0%";
showcaseSheet.getRange(`F${oddsHeaderRow + 1}:G${oddsLast}`).format.numberFormat = "0.000%";
showcaseSheet.getRange(`A${oddsLast + 1}:G${oddsLast + 1}`).merge();
showcaseSheet.getRange(`A${oddsLast + 1}`).values = [["Items the player already owns also drop out of the draw, so live per-item odds only rise from here. The in-game Odds page is computed from the catalogue and already reflects this."]];
showcaseSheet.getRange(`A${oddsLast + 1}`).format = { font: { italic: true, color: "#52616B", name: "Arial", size: 9 }, wrapText: true };
showcaseSheet.getRange(`A${oddsLast + 1}:G${oddsLast + 1}`).format.rowHeightPx = 30;

dashboard.getRange("A1:H25").format.font = { name: "Arial", size: 10, color: "#1F2933" };
dashboard.getRange("A1:H25").format.columnWidth = 18;
dashboard.getRange("B15:B20").format.columnWidth = 54;
dashboard.getRange("E15:E18").format.columnWidth = 34;
dashboard.getRange("A2:H2").format.rowHeightPx = 28;
dashboard.getRange("A14:H14").format.rowHeightPx = 22;
dashboard.getRange("D14:H14").format.rowHeightPx = 22;
dashboard.getRange("A16:B20").format.rowHeightPx = 35;
dashboard.getRange("D15:E18").format.rowHeightPx = 30;

// ---------- Grand Opening ----------
// The launch event: three exclusives, each with its own goal, earnable only inside the window.
const eventItems = items.filter(item => item.event === "grand_opening").sort((a, b) => (grandOpeningRewards.get(`${a.type.toLowerCase()}:${a.id}`)?.order ?? 9) - (grandOpeningRewards.get(`${b.type.toLowerCase()}:${b.id}`)?.order ?? 9));
eventSheet.getRange("A2:J2").merge();
eventSheet.getRange("A2").values = [["Grand Opening launch event"]];
eventSheet.getRange("A2").format = { font: { bold: true, color: "#173042", name: "Arial", size: 16 } };
eventSheet.getRange("A3:J3").merge();
eventSheet.getRange("A3").values = [["Three launch exclusives, each earned with its own goal between the event's start and end dates. Earned items are kept for good. They are never sold in the shop, dropped by the Kinu Catcher or offered in the Day 7 draw, and they never return."]];
eventSheet.getRange("A3").format = { font: { italic: true, color: "#52616B", name: "Arial", size: 10 }, wrapText: true };
eventSheet.getRange("A3:J3").format.rowHeightPx = 32;
const eventHeaders = ["Order", "Reward type", "Item ID", "Display name", "Thumbnail", "Rarity", "Requirement", "Window", "Status", "Notes"];
eventSheet.getRange("A6:J6").values = [eventHeaders];
setHeader(eventSheet.getRange("A6:J6"), "#B92F35");
const eventRows = eventItems.map((item, index) => [index + 1, item.type === "Outfit" ? "Kinu outfit" : item.type, item.id, item.name, "", item.rarity, item.requirement, `${grandOpening.start} to ${grandOpening.end}`, "", "Never returns."]);
const eventLast = 6 + eventRows.length;
if (eventRows.length) {
  eventSheet.getRangeByIndexes(6, 0, eventRows.length, eventHeaders.length).values = eventRows;
  for (let row = 7; row <= eventLast; row++) {
    eventSheet.getRange(`I${row}`).formulas = [[`=IF(TODAY()>DATE(2026,10,31),"Expended",IF(TODAY()<DATE(2026,9,29),"Upcoming","Active"))`]];
  }
  eventSheet.tables.add(`A6:J${eventLast}`, true, "GrandOpening");
  eventSheet.getRange(`A7:J${eventLast}`).format = { font: { name: "Arial", size: 10 }, verticalAlignment: "center", wrapText: true, rowHeightPx: 72, borders: { preset: "all", style: "thin", color: "#E8B9A8" } };
  eventSheet.getRange(`I7:I${eventLast}`).format.horizontalAlignment = "center";
  eventSheet.getRange(`I7:I${eventLast}`).conditionalFormats.add("containsText", { text: "Active", format: { fill: "#D8F3BD", font: { color: "#2E6B1F", bold: true } } });
  eventSheet.getRange(`I7:I${eventLast}`).conditionalFormats.add("containsText", { text: "Expended", format: { fill: "#E6E1E5", font: { color: "#6B5E68", bold: true } } });
  for (let index = 0; index < eventItems.length; index++) {
    const item = eventItems[index];
    if (!fsSync.existsSync(item.thumbnail)) continue;
    const dataUrl = "data:image/png;base64," + (await fs.readFile(item.thumbnail)).toString("base64");
    eventSheet.images.add({ dataUrl, alt: `${item.name} thumbnail`, anchor: { from: { row: index + 6, col: 4, rowOffsetPx: 5, colOffsetPx: 7 }, extent: { widthPx: 66, heightPx: 62 } } });
  }
}
const eventInfoTop = eventLast + 3;
eventSheet.getRange(`A${eventInfoTop}:J${eventInfoTop}`).merge();
eventSheet.getRange(`A${eventInfoTop}`).values = [["Event schedule"]];
setSection(eventSheet.getRange(`A${eventInfoTop}:J${eventInfoTop}`));
const eventInfo = [
  ["In-game window", `${grandOpening.start} to ${grandOpening.end}, by the server's date`],
  ["App Store event card", `${grandOpening.storeCard}. Apple caps an in-app event at 31 days.`],
  ["Card media", "outputs/grand_opening_event/ (1920 x 1080 card, 1080 x 1920 details)"],
  ["After it ends", "Items stay owned. The Kinu Book says they will never return; keep them out of the shop and claw."],
];
// Labels span the two narrow leading columns so they aren't clipped.
for (let i = 0; i < eventInfo.length; i++) {
  const row = eventInfoTop + 1 + i;
  eventSheet.getRange(`A${row}:B${row}`).merge();
  eventSheet.getRange(`A${row}`).values = [[eventInfo[i][0]]];
  eventSheet.getRange(`C${row}`).values = [[eventInfo[i][1]]];
}
eventSheet.getRange(`A${eventInfoTop + 1}:A${eventInfoTop + eventInfo.length}`).format.font = { bold: true, color: "#173042", name: "Arial", size: 10 };
eventSheet.getRange(`C${eventInfoTop + 1}:C${eventInfoTop + eventInfo.length}`).format.font = { name: "Arial", size: 10 };
const eventWidths = [8, 13, 17, 18, 14, 11, 24, 24, 12, 30];
for (let col = 0; col < eventWidths.length; col++) eventSheet.getRangeByIndexes(0, col, 1, 1).format.columnWidth = eventWidths[col];
eventSheet.freezePanes.freezeRows(6);

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
  ["Monthly Showcase", "A1:N23", "showcase_preview.png"],
  ["Grand Opening", "A1:J18", "grand_opening_preview.png"],
  ["Lists", "A1:D10", "lists_preview.png"]
]) {
  const preview = await workbook.render({ sheetName, range, scale: 1.25, format: "png" });
  await fs.writeFile(path.join(outputDir, filename), new Uint8Array(await preview.arrayBuffer()));
}
console.log(`Wrote ${outputPath}`);
