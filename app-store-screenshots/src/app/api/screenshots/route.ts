import { readdir } from "node:fs/promises";
import path from "node:path";

/* Lists public/screenshots so dropping a file in that folder is all it takes to
   get a new source chip — no code edit, no rebuild. */

/* Evaluated at build time and served as static JSON: a serverless function on
   Vercel cannot count on the public/ folder being readable at runtime. */
export const dynamic = "force-static";

const DIR = path.join(process.cwd(), "public", "screenshots");
const IMAGE = /\.(png|jpe?g|webp)$/i;

/** "11-test-trends.png" -> "Test trends" */
function label(filename: string) {
  const stem = filename
    .replace(IMAGE, "")
    .replace(/^\d+[-_]?/, "")
    .replace(/[-_]+/g, " ")
    .trim();
  if (!stem) return filename;
  return stem.charAt(0).toUpperCase() + stem.slice(1);
}

export async function GET() {
  try {
    const entries = await readdir(DIR, { withFileTypes: true });
    const sources = entries
      .filter((entry) => entry.isFile() && IMAGE.test(entry.name))
      .map((entry) => entry.name)
      .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
      .map((name) => ({ name: label(name), image: `/screenshots/${name}` }));
    return Response.json({ sources });
  } catch {
    return Response.json({ sources: [] });
  }
}
