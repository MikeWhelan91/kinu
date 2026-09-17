import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

/* Local-only helper: writes rendered PNGs into ./exports/<folder>/ so a whole
   set lands on disk in one go instead of ten browser downloads. */

const ROOT = path.join(process.cwd(), "exports");
const SAFE = /^[a-zA-Z0-9._-]+$/;

export async function POST(request: Request) {
  if (process.env.NODE_ENV === "production")
    return Response.json({ error: "Disabled outside dev" }, { status: 403 });

  const { folder, name, dataUrl } = (await request.json()) as {
    folder?: string;
    name?: string;
    dataUrl?: string;
  };

  if (!name || !SAFE.test(name) || !name.endsWith(".png"))
    return Response.json({ error: "Bad file name" }, { status: 400 });
  if (folder && !SAFE.test(folder))
    return Response.json({ error: "Bad folder name" }, { status: 400 });
  if (!dataUrl?.startsWith("data:image/png;base64,"))
    return Response.json({ error: "Expected a PNG data URL" }, { status: 400 });

  const dir = path.join(ROOT, folder ?? "studio");
  await mkdir(dir, { recursive: true });
  const file = path.join(dir, name);
  await writeFile(file, Buffer.from(dataUrl.split(",")[1], "base64"));

  return Response.json({ saved: path.relative(process.cwd(), file) });
}
