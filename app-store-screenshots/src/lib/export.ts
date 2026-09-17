"use client";

import { toSvg } from "html-to-image";
import { encode } from "fast-png";
import JSZip from "jszip";

/* html-to-image's toPng/toCanvas resolve inside requestAnimationFrame, which
   never fires while the tab is hidden or backgrounded - that hangs the export.
   Rasterising the SVG here keeps it working in the background. */
/* The studio's own faces aren't installed locally, and the rasterised SVG
   cannot see page fonts, so every one is inlined into every render. The CJK
   faces are subsets cut to the store copy by scripts/kinu_fonts.py, a few
   dozen kilobytes each, which keeps that cheap. Keep this list in step with
   the @font-face rules in globals.css. */
const BUNDLED_FONTS = [
  { family: "Nunito", url: "/fonts/Nunito.ttf", format: "truetype" },
  { family: "Kinu JA", url: "/fonts/kinu-ja.ttf", format: "truetype" },
  { family: "Kinu KO", url: "/fonts/kinu-ko.otf", format: "opentype" },
  { family: "Kinu ZH", url: "/fonts/kinu-zh.ttf", format: "truetype" },
];

let bundledFontCss: Promise<string> | null = null;
function bundledFonts() {
  bundledFontCss ??= Promise.all(
    BUNDLED_FONTS.map(async ({ family, url, format }) => {
      const response = await fetch(url, { cache: "no-cache" });
      /* A missing face would not fail loudly: the text would silently fall back
         to some system font, which for CJK is exactly the bug these faces fix. */
      if (!response.ok) throw new Error(`Could not load the ${family} font (${url})`);
      const bytes = new Uint8Array(await response.arrayBuffer());
      let binary = "";
      for (let i = 0; i < bytes.length; i += 0x8000) {
        binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
      }
      const mime = format === "opentype" ? "font/otf" : "font/ttf";
      // A weight range, so the single-weight CJK faces are never faux-bolded.
      return `@font-face{font-family:"${family}";src:url(data:${mime};base64,${btoa(binary)}) format("${format}");font-weight:100 1000;font-style:normal;}`;
    }),
  )
    .then((faces) => faces.join(""))
    .catch((error) => {
      bundledFontCss = null;
      throw error;
    });
  return bundledFontCss;
}

/* Images are inlined here rather than left to html-to-image. Its own fetch
   keeps a page-lifetime cache that stores failures too, so one fetch that
   caught a file mid-write (a re-render, a hot reload) broke that image for
   every export until a full reload, and surfaced only as a generic error. This
   cache drops failures, retries, and names the file that would not load. */
const inlined = new Map<string, Promise<string>>();

function imageDataUrl(url: string): Promise<string> {
  let pending = inlined.get(url);
  if (!pending) {
    pending = (async () => {
      let lastError: unknown;
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          const response = await fetch(url, { cache: "no-cache" });
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          const blob = await response.blob();
          return await new Promise<string>((resolve, reject) => {
            const reader = new FileReader();
            reader.onerror = () => reject(reader.error);
            reader.onloadend = () => resolve(String(reader.result));
            reader.readAsDataURL(blob);
          });
        } catch (error) {
          lastError = error;
          await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
        }
      }
      throw new Error(`Could not load ${decodeURIComponent(url.split("/").pop() ?? url)} (${exportErrorMessage(lastError)})`);
    })();
    inlined.set(url, pending);
    pending.catch(() => inlined.delete(url));
  }
  return pending;
}

/* Swaps every image in the node for a data URL for the length of one render,
   then puts the original sources back so the live node keeps tracking them. */
async function withInlinedImages<T>(node: HTMLElement, render: () => Promise<T>): Promise<T> {
  const images = Array.from(node.querySelectorAll("img")).filter((image) => image.src && !image.src.startsWith("data:"));
  const originals = images.map((image) => image.getAttribute("src"));
  try {
    const dataUrls = await Promise.all(images.map((image) => imageDataUrl(image.src)));
    await Promise.all(
      images.map(async (image, index) => {
        image.src = dataUrls[index];
        await image.decode().catch(() => undefined);
      }),
    );
    return await render();
  } finally {
    images.forEach((image, index) => {
      const original = originals[index];
      if (original !== null) image.setAttribute("src", original);
    });
  }
}

export async function renderNode(node: HTMLElement, width: number, height: number): Promise<Blob> {
  return withInlinedImages(node, () => rasterise(node, width, height));
}

async function rasterise(node: HTMLElement, width: number, height: number): Promise<Blob> {
  const svg = await toSvg(node, {
    width,
    height,
    skipFonts: true, // everything else uses locally installed faces
    fontEmbedCSS: await bundledFonts(),
    /* Appending a cache-busting query makes blob: URLs from IndexedDB invalid.
       Ask fetch to revalidate instead, so uploaded screenshots remain usable. */
    cacheBust: false,
    fetchRequestInit: { cache: "no-cache" },
  });
  const img = new Image();
  img.decoding = "sync";
  await new Promise<void>((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = () => reject(new Error("Could not rasterise the canvas"));
    img.src = svg;
  });
  await img.decode().catch(() => undefined);

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("No 2D context");
  context.drawImage(img, 0, 0, width, height);

  /* Canvas PNG encoders commonly write RGBA even when alpha is 255 everywhere.
     App Store Connect rejects those files, so explicitly encode three-channel
     RGB data instead. */
  const rgba = context.getImageData(0, 0, width, height).data;
  const rgb = new Uint8Array(width * height * 3);
  for (let source = 0, target = 0; source < rgba.length; source += 4) {
    rgb[target++] = rgba[source];
    rgb[target++] = rgba[source + 1];
    rgb[target++] = rgba[source + 2];
  }
  const png = encode({ width, height, data: rgb, channels: 3, depth: 8 });
  const bytes = new Uint8Array(png.byteLength);
  bytes.set(png);
  return new Blob([bytes.buffer], { type: "image/png" });
}

export function exportErrorMessage(error: unknown) {
  if (error instanceof Error && error.message) return error.message;
  if (typeof error === "string" && error) return error;
  /* Firefox throws XPCOM exceptions (NS_ERROR_…) that are not Errors, and image
     failures reject with a bare Event: say what it was rather than guess. */
  if (error && typeof error === "object") {
    const detail = error as { name?: unknown; message?: unknown; type?: unknown; target?: { src?: string } };
    if (detail.target?.src) return `An image failed to load (${detail.target.src.slice(0, 80)})`;
    const text = [detail.name, detail.message].filter((part) => typeof part === "string" && part).join(": ");
    if (text) return text;
    const fallback = String(error);
    if (fallback && fallback !== "[object Object]") return fallback;
  }
  return "The browser could not render one of the images. Try reloading the page.";
}

export function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export async function zipBlobs(files: { name: string; blob: Blob }[]) {
  const zip = new JSZip();
  for (const file of files) zip.file(file.name, file.blob);
  return zip.generateAsync({ type: "blob" });
}

/** "Catch Faint Lines" -> "01-catch-faint-lines" */
/* Headlines outside Latin script reduce to nothing here, so the fallback
   carries the project (e.g. "kinutumble-ja") and a Japanese set never
   downloads with the same file names as the Korean one. */
export function slugify(text: string, index: number, fallback = "screen") {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .split("-")
    .filter(Boolean)
    .slice(0, 5)
    .join("-");
  return `${String(index + 1).padStart(2, "0")}-${words || fallback}`;
}
