"use client";

import { Project, defaultSize, palettes } from "./types";

/* A theme that has since been removed would otherwise crash the theme panel. */
const knownPalette = (id: string | undefined, fallback: string) =>
  id === "custom" || palettes.some((p) => p.id === id) ? (id as string) : fallback;

const PROJECT_KEY = "linecheck-studio-reference-project-v1";

/* `?project=<slug>` keeps a separate set per app, so opening another app's
   screenshots never autosaves over the LineCheck set under the default key. */
export function projectSlug() {
  if (typeof window === "undefined") return "";
  return new URLSearchParams(window.location.search).get("project")?.trim() ?? "";
}

const projectKey = () => {
  const slug = projectSlug();
  return slug ? `${PROJECT_KEY}-${slug}` : PROJECT_KEY;
};
const DB_NAME = "linecheck-studio";
const STORE = "assets";

export type StoredAsset = {
  id: string;
  name: string;
  type: string;
  addedAt: number;
  blob: Blob;
};

/* Uploaded screenshots are far too big for localStorage (a handful of PNGs
   blows the ~5MB quota), so the images live in IndexedDB and the project JSON
   only refers to them by id. */
function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: "id" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function tx<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>) {
  const db = await openDB();
  return new Promise<T>((resolve, reject) => {
    const transaction = db.transaction(STORE, mode);
    const request = run(transaction.objectStore(STORE));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => db.close();
  });
}

export async function putAsset(file: File): Promise<StoredAsset> {
  const asset: StoredAsset = {
    id: `a${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`,
    name: file.name,
    type: file.type,
    addedAt: Date.now(),
    blob: file,
  };
  await tx("readwrite", (store) => store.put(asset));
  return asset;
}

export async function allAssets(): Promise<StoredAsset[]> {
  const assets = await tx<StoredAsset[]>("readonly", (store) => store.getAll());
  return assets.sort((a, b) => a.addedAt - b.addedAt);
}

export async function deleteAsset(id: string) {
  await tx("readwrite", (store) => store.delete(id));
}

/* Blob URLs are per-session, so the project stores "asset:<id>" and the URL is
   resolved at render time from this map. */
export function assetUrlMap(assets: StoredAsset[]) {
  const map = new Map<string, string>();
  for (const asset of assets) map.set(asset.id, URL.createObjectURL(asset.blob));
  return map;
}

export function resolveSrc(src: string, urls: Map<string, string>) {
  if (!src.startsWith("asset:")) return src;
  return urls.get(src.slice(6)) ?? "";
}

export function loadProject(): Project | null {
  try {
    const raw = localStorage.getItem(projectKey());
    if (!raw) return null;
    return normaliseProject(JSON.parse(raw));
  } catch {
    return null;
  }
}

export function normaliseProject(value: unknown): Project | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as Partial<Project> & { frames?: Project["frames"] };
  if (!candidate.frames?.length || !candidate.theme) return null;
  const device = candidate.device === "ipad" ? "ipad" : "iphone";
  return {
    ...candidate,
    version: 4,
    device,
    sizeId: candidate.sizeId || defaultSize(device).id,
    theme: {
      ...candidate.theme,
      paletteId: knownPalette(candidate.theme.paletteId, "milk"),
      alternateId: knownPalette(candidate.theme.alternateId, "rose"),
    },
    frames: candidate.frames,
  };
}

/* Drops the autosave for this project, so the next load falls through to the
   starter set defined in code. */
export function clearProject() {
  try {
    localStorage.removeItem(projectKey());
  } catch {
    /* Private windows and blocked site data both throw here; nothing to undo. */
  }
}

export function saveProject(project: Project) {
  try {
    localStorage.setItem(projectKey(), JSON.stringify(project));
    return true;
  } catch {
    return false;
  }
}

export function exportProjectFile(project: Project) {
  const blob = new Blob([JSON.stringify(project, null, 2)], {
    type: "application/json",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `screenshot-studio-${new Date().toISOString().slice(0, 10)}.json`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}
