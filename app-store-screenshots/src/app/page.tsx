"use client";

import {
  ChangeEvent,
  DragEvent,
  MouseEvent as ReactMouseEvent,
  PointerEvent as ReactPointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { Artwork } from "@/components/Artwork";
import { Shape } from "@/components/Shape";
import { critterScaleProject, reorderCritterScaleProject, upgradeCritterScaleProject } from "@/lib/critterscale";
import { KINU_LOCALES, kinuLocaleForSlug, kinuTumbleProject } from "@/lib/kinutumble";
import { download, exportErrorMessage, renderNode, slugify, zipBlobs } from "@/lib/export";
import {
  StoredAsset,
  allAssets,
  assetUrlMap,
  deleteAsset,
  exportProjectFile,
  loadProject,
  normaliseProject,
  clearProject,
  projectSlug,
  putAsset,
  resolveSrc,
  saveProject,
} from "@/lib/storage";
import {
  ColorToken,
  DeviceKind,
  Frame,
  Layer,
  Palette,
  Project,
  ShapeLayer,
  TextKind,
  TextLayer,
  W,
  colorTokens,
  defaultDevice,
  defaultPhone,
  defaultSize,
  defaultTheme,
  exportSizes,
  frameForDevice,
  layerLabel,
  makeImage,
  makeShape,
  makeText,
  palettes,
  shapeKinds,
  sizeById,
  themeFor,
  uid,
} from "@/lib/types";

const fonts = [
  "Avenir Next",
  "Nunito",
  "Kinu JA",
  "Kinu KO",
  "Kinu ZH",
  "Helvetica Neue",
  "Georgia",
  "Trebuchet MS",
  "Futura",
  "Baskerville",
  "American Typewriter",
  "Courier New",
];

const clamp = (n: number, min: number, max: number) => Math.max(min, Math.min(max, n));

const starterFrame = (image: string): Frame => ({
  id: uid(),
  image,
  phone: defaultPhone(),
  layers: [makeText("headline", 50, 7.5), makeText("subhead", 50, 22.5)],
});

type ReferenceCircle = {
  x: number;
  y: number;
  width: number;
  color: "pink" | "purple";
  opacity?: number;
};

type ReferenceFrame = {
  image: string;
  headline: string;
  subtitle: string;
  circles: ReferenceCircle[];
  headlineY?: number;
  headlineSize?: number;
  ruleY?: number;
  subtitleY?: number;
};

const referenceFrames: ReferenceFrame[] = [
  {
    image: "/screenshots/02-faint.png",
    headline: "Spot Faint\nLines",
    subtitle: "AI-assisted photo review\nof every strip",
    circles: [
      { x: 18, y: 14, width: 31, color: "pink", opacity: 17 },
      { x: 86, y: 17, width: 43, color: "purple", opacity: 15 },
      { x: 101, y: 26, width: 42, color: "purple", opacity: 14 },
    ],
  },
  {
    image: "/screenshots/03-ovulation-result.png",
    headline: "Follow Ovulation\nTrends",
    subtitle: "From low to peak,\ncycle after cycle",
    headlineSize: 177,
    circles: [
      { x: -1, y: 19, width: 35, color: "purple", opacity: 15 },
      { x: 60, y: 16, width: 36, color: "pink", opacity: 16 },
      { x: 98, y: 19, width: 36, color: "pink", opacity: 18 },
    ],
  },
  {
    image: "/screenshots/04-calendar.png",
    headline: "Plan Your\nCycle",
    subtitle: "Dates, tests and fertile\nwindows",
    circles: [
      { x: -1, y: 22, width: 38, color: "pink", opacity: 17 },
      { x: 81, y: 23, width: 36, color: "pink", opacity: 14 },
      { x: 102, y: 48, width: 40, color: "purple", opacity: 13 },
    ],
  },
  {
    image: "/screenshots/11-test-trends.png",
    headline: "See Your\nTrends",
    subtitle: "OPK and BBT and more\ncharted for you",
    circles: [
      { x: 80, y: 14, width: 36, color: "pink", opacity: 17 },
      { x: -1, y: 48, width: 34, color: "purple", opacity: 14 },
      { x: 101, y: 61, width: 38, color: "pink", opacity: 19 },
    ],
  },
  {
    image: "/screenshots/06-log.png",
    headline: "Log\nEverything",
    subtitle: "Symptoms, temperature,\nmucus and more",
    circles: [
      { x: 19, y: 17, width: 31, color: "pink", opacity: 17 },
      { x: 96, y: 19, width: 38, color: "purple", opacity: 15 },
      { x: -2, y: 66, width: 35, color: "pink", opacity: 21 },
    ],
  },
  {
    image: "/screenshots/07-compare.png",
    headline: "See Results\nChange",
    subtitle: "Use AI to compare your\ntests over time",
    circles: [
      { x: -1, y: 19, width: 35, color: "purple", opacity: 15 },
      { x: 61, y: 21, width: 37, color: "pink", opacity: 16 },
      { x: 99, y: 18, width: 35, color: "pink", opacity: 18 },
    ],
  },
  {
    image: "/screenshots/08-luna.png",
    headline: "Ask Luna",
    subtitle: "Personal guidance based\non your saved data",
    headlineY: 8.5,
    headlineSize: 190,
    ruleY: 17,
    subtitleY: 20.2,
    circles: [
      { x: -1, y: 22, width: 38, color: "pink", opacity: 17 },
      { x: 80, y: 14, width: 36, color: "pink", opacity: 15 },
      { x: 101, y: 66, width: 40, color: "pink", opacity: 20 },
    ],
  },
];

const referenceDots = (x: number): ShapeLayer => ({
  ...makeShape("dots", x, 6.6),
  width: 18,
  height: 10,
  color: "ink",
  opacity: 13,
});

const referenceCircle = (circle: ReferenceCircle): ShapeLayer => ({
  ...makeShape("circle", circle.x, circle.y),
  width: circle.width,
  height: circle.width,
  color: circle.color,
  opacity: circle.opacity ?? 16,
});

const referenceFrame = (spec: ReferenceFrame): Frame => {
  const headline: TextLayer = {
    ...makeText("headline", 50, spec.headlineY ?? 6.1),
    text: spec.headline,
    width: 95,
    size: spec.headlineSize ?? 186,
    weight: 800,
    tracking: -5,
    lineHeight: 0.9,
  };
  const rule: TextLayer = {
    ...makeText("eyebrow", 50, spec.ruleY ?? 17.6),
    text: "",
    size: 68,
    width: 20,
    tracking: 0,
  };
  const subtitle: TextLayer = {
    ...makeText("subhead", 50, spec.subtitleY ?? 20.5),
    text: spec.subtitle,
    width: 92,
    size: 72,
    weight: 650,
    tracking: -1,
    lineHeight: 1.22,
    opacity: 68,
  };

  return {
    id: uid(),
    image: spec.image,
    phone: defaultPhone(),
    variants: {
      ipad: {
        image: "",
        phone: { x: 50, y: 63.5, scale: 1.1, rotate: 0, visible: true },
      },
    },
    layers: [
      referenceDots(7),
      referenceDots(93),
      ...spec.circles.map(referenceCircle),
      headline,
      rule,
      subtitle,
    ],
  };
};

const starterProject = (): Project => ({
  version: 4,
  device: "ipad",
  sizeId: defaultSize("ipad").id,
  theme: { ...defaultTheme, bleed: false },
  frames: referenceFrames.map(referenceFrame),
});

const referenceHeadlines = new Set(referenceFrames.map((frame) => frame.headline));
const referenceSubtitles = new Set(referenceFrames.map((frame) => frame.subtitle));

/* Preserve uploaded iPad screenshots and other edits while bringing projects
   created from the first reference set forward to the improved type scale. */
const upgradeReferenceTypography = (project: Project): Project => ({
  ...project,
  frames: project.frames.map((frame) => ({
    ...frame,
    layers: frame.layers.map((layer) => {
      if (layer.kind !== "text") return layer;
      if (referenceHeadlines.has(layer.text) && layer.width === 91) {
        return { ...layer, width: 95, size: Math.round(layer.size * 1.08) };
      }
      if (referenceSubtitles.has(layer.text) && layer.width === 88) {
        return { ...layer, width: 92, size: 72 };
      }
      if (referenceSubtitles.has(layer.text) && layer.width === 92 && layer.size === 64) {
        return { ...layer, size: 72 };
      }
      return layer;
    }),
  })),
});

function withDeviceFrame(
  frame: Frame,
  device: DeviceKind,
  next: Partial<Pick<Frame, "image" | "phone">>,
): Frame {
  if (device === "iphone") return { ...frame, ...next };
  const current = frame.variants?.ipad ?? { image: "", phone: defaultDevice("ipad") };
  return {
    ...frame,
    variants: {
      ...frame.variants,
      ipad: { ...current, ...next },
    },
  };
}

type Tab = "screens" | "text" | "shapes" | "images" | "theme" | "export";

const tabs: { id: Tab; icon: string; label: string }[] = [
  { id: "screens", icon: "▦", label: "Screens" },
  { id: "text", icon: "T", label: "Text" },
  { id: "shapes", icon: "◍", label: "Shapes" },
  { id: "images", icon: "▣", label: "Shots" },
  { id: "theme", icon: "◐", label: "Theme" },
  { id: "export", icon: "⤓", label: "Export" },
];

type DragState = {
  kind: "phone" | "layer";
  frameId: string;
  layerId?: string;
  stage: HTMLElement;
  originX: number;
  originY: number;
  startX: number;
  startY: number;
};

export default function Studio() {
  const [project, setProject] = useState<Project>(starterProject);
  const [assets, setAssets] = useState<StoredAsset[]>([]);
  const [library, setLibrary] = useState<[string, string][]>([]);
  const [tab, setTab] = useState<Tab>("screens");
  const [activeFrameId, setActiveFrameId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [dragging, setDragging] = useState<null | "phone" | "layer">(null);
  const [zoom, setZoom] = useState(230);
  const [busy, setBusy] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [dropping, setDropping] = useState(false);
  const [hydrated, setHydrated] = useState(false);
  const [slug, setSlug] = useState("");

  const exportNodes = useRef(new Map<string, HTMLDivElement>());
  const drag = useRef<DragState | null>(null);

  const { frames, theme, device } = project;
  const displayFrames = useMemo(
    () => frames.map((frame) => frameForDevice(frame, device)),
    [frames, device],
  );
  const exportSize = sizeById(device, project.sizeId);
  const canvasW = exportSize.w;
  const canvasH = exportSize.h;
  const activeFrame = frames.find((f) => f.id === activeFrameId) ?? frames[0] ?? null;
  const activeDeviceFrame = activeFrame ? frameForDevice(activeFrame, device) : null;
  const activeIndex = activeFrame ? frames.indexOf(activeFrame) : 0;
  const selected = activeFrame?.layers.find((l) => l.id === selectedId) ?? null;

  const urls = useMemo(() => assetUrlMap(assets), [assets]);
  const resolve = useCallback((src: string) => resolveSrc(src, urls), [urls]);
  const palette = (index: number) => themeFor(theme, index);

  /* ---------- load + autosave ---------- */

  useEffect(() => {
    void allAssets().then(setAssets);
    void fetch("/api/screenshots")
      .then((r) => r.json())
      .then((data: { sources?: { name: string; image: string }[] }) =>
        setLibrary((data.sources ?? []).map((s) => [s.name, s.image])),
      )
      .catch(() => undefined);

    const queryDevice = new URLSearchParams(window.location.search).get("device");
    setSlug(projectSlug());
    /* `?fresh=1` throws away the autosaved project and reopens the starter set.
       Editing a starter in code is otherwise invisible: the save in localStorage
       always wins, so every change needs the key clearing by hand first. */
    const fresh = new URLSearchParams(window.location.search).get("fresh");
    if (fresh) clearProject();
    const savedProject = fresh ? null : loadProject();
    const saved = savedProject
      ? projectSlug() === "critterscale"
        ? reorderCritterScaleProject(upgradeCritterScaleProject(savedProject))
        : upgradeReferenceTypography(savedProject)
      : null;
    if (saved) {
      setProject({
        ...saved,
        ...(queryDevice === "ipad" || queryDevice === "iphone"
          ? { device: queryDevice, sizeId: defaultSize(queryDevice).id }
          : {}),
      });
    }
    else if (projectSlug() === "critterscale") {
      const starter = critterScaleProject();
      setProject(starter);
      setActiveFrameId(starter.frames[0]?.id ?? null);
    }
    else if (kinuLocaleForSlug(projectSlug())) {
      const starter = kinuTumbleProject(kinuLocaleForSlug(projectSlug()));
      setProject(starter);
      setActiveFrameId(starter.frames[0]?.id ?? null);
    }
    else if (queryDevice === "ipad" || queryDevice === "iphone") {
      setProject((current) => ({
        ...current,
        device: queryDevice,
        sizeId: defaultSize(queryDevice).id,
      }));
    }
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    const timer = setTimeout(() => {
      const ok = saveProject(project);
      setSavedAt(ok ? new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : null);
    }, 300);
    return () => clearTimeout(timer);
  }, [project, hydrated]);

  /* ---------- mutation ---------- */

  const patchTheme = (next: Partial<typeof theme>) =>
    setProject((p) => ({ ...p, theme: { ...p.theme, ...next } }));

  const chooseDevice = (next: DeviceKind) => {
    setProject((p) => ({ ...p, device: next, sizeId: defaultSize(next).id }));
    const url = new URL(window.location.href);
    url.searchParams.set("device", next);
    window.history.replaceState(null, "", url);
  };

  const chooseSize = (sizeId: string) => setProject((p) => ({ ...p, sizeId }));

  const patchActiveDevice = (next: Partial<Pick<Frame, "image" | "phone">>) => {
    if (!activeFrame) return;
    setProject((p) => ({
      ...p,
      frames: p.frames.map((frame) =>
        frame.id === activeFrame.id ? withDeviceFrame(frame, device, next) : frame,
      ),
    }));
  };

  const patchDeviceFrame = useCallback(
    (id: string, next: Partial<Pick<Frame, "image" | "phone">>) => {
      setProject((p) => ({
        ...p,
        frames: p.frames.map((frame) =>
          frame.id === id ? withDeviceFrame(frame, device, next) : frame,
        ),
      }));
    },
    [device],
  );

  const patchLayer = useCallback((frameId: string, layerId: string, next: Partial<Layer>) => {
    setProject((p) => ({
      ...p,
      frames: p.frames.map((frame) =>
        frame.id !== frameId
          ? frame
          : {
              ...frame,
              layers: frame.layers.map((layer) =>
                layer.id === layerId ? ({ ...layer, ...next } as Layer) : layer,
              ),
            },
      ),
    }));
  }, []);

  const patchSelected = (next: Partial<Layer>) => {
    if (activeFrame && selectedId) patchLayer(activeFrame.id, selectedId, next);
  };

  const addLayer = (frameId: string, layer: Layer) => {
    setProject((p) => ({
      ...p,
      frames: p.frames.map((f) => (f.id === frameId ? { ...f, layers: [...f.layers, layer] } : f)),
    }));
    setActiveFrameId(frameId);
    setSelectedId(layer.id);
    if (layer.kind === "text") setEditingId(layer.id);
  };

  const removeLayer = useCallback((frameId: string, layerId: string) => {
    setProject((p) => ({
      ...p,
      frames: p.frames.map((f) =>
        f.id !== frameId ? f : { ...f, layers: f.layers.filter((l) => l.id !== layerId) },
      ),
    }));
    setSelectedId((c) => (c === layerId ? null : c));
    setEditingId((c) => (c === layerId ? null : c));
  }, []);

  const duplicateLayer = (frameId: string, layerId: string) => {
    const copyId = uid();
    setProject((p) => ({
      ...p,
      frames: p.frames.map((frame) => {
        if (frame.id !== frameId) return frame;
        const source = frame.layers.find((l) => l.id === layerId);
        if (!source) return frame;
        return { ...frame, layers: [...frame.layers, { ...source, id: copyId, y: Math.min(96, source.y + 5) }] };
      }),
    }));
    setSelectedId(copyId);
  };

  const moveLayerOrder = (frameId: string, layerId: string, delta: number) => {
    setProject((p) => ({
      ...p,
      frames: p.frames.map((frame) => {
        if (frame.id !== frameId) return frame;
        const i = frame.layers.findIndex((l) => l.id === layerId);
        const target = i + delta;
        if (i < 0 || target < 0 || target >= frame.layers.length) return frame;
        const layers = [...frame.layers];
        const [item] = layers.splice(i, 1);
        layers.splice(target, 0, item);
        return { ...frame, layers };
      }),
    }));
  };

  /* ---------- frames ---------- */

  function addFrame() {
    const template = activeFrame ?? frames[frames.length - 1];
    const next: Frame = template
      ? {
          ...template,
          id: uid(),
          variants: template.variants
            ? { ipad: template.variants.ipad ? { ...template.variants.ipad, phone: { ...template.variants.ipad.phone } } : undefined }
            : undefined,
          layers: template.layers.map((l) => ({ ...l, id: uid() })),
        }
      : starterFrame(library[0]?.[1] ?? "");
    setProject((p) => ({ ...p, frames: [...p.frames, next] }));
    setActiveFrameId(next.id);
    setSelectedId(null);
  }

  function duplicateFrame(id: string) {
    const copyId = uid();
    setProject((p) => {
      const i = p.frames.findIndex((f) => f.id === id);
      if (i < 0) return p;
      const source = p.frames[i];
      const copy: Frame = {
        ...source,
        id: copyId,
        phone: { ...source.phone },
        variants: source.variants
          ? { ipad: source.variants.ipad ? { ...source.variants.ipad, phone: { ...source.variants.ipad.phone } } : undefined }
          : undefined,
        layers: source.layers.map((l) => ({ ...l, id: uid() })),
      };
      const next = [...p.frames];
      next.splice(i + 1, 0, copy);
      return { ...p, frames: next };
    });
    setActiveFrameId(copyId);
  }

  function removeFrame(id: string) {
    if (frames.length === 1) return;
    if (!confirm("Delete this screen?")) return;
    setProject((p) => ({ ...p, frames: p.frames.filter((f) => f.id !== id) }));
    setActiveFrameId((c) => (c === id ? null : c));
  }

  function moveFrame(id: string, delta: number) {
    setProject((p) => {
      const i = p.frames.findIndex((f) => f.id === id);
      const target = i + delta;
      if (i < 0 || target < 0 || target >= p.frames.length) return p;
      const next = [...p.frames];
      const [item] = next.splice(i, 1);
      next.splice(target, 0, item);
      return { ...p, frames: next };
    });
  }

  function applyPhoneToAll() {
    if (!activeDeviceFrame) return;
    setProject((p) => ({
      ...p,
      frames: p.frames.map((frame) =>
        withDeviceFrame(frame, device, { phone: { ...activeDeviceFrame.phone } }),
      ),
    }));
  }

  function applyTypeToAll() {
    if (!activeFrame) return;
    setProject((p) => ({
      ...p,
      frames: p.frames.map((frame) => {
        if (frame.id === activeFrame.id) return frame;
        return {
          ...frame,
          layers: frame.layers.map((layer, i) => {
            const model = activeFrame.layers[i];
            if (!model || model.kind !== "text" || layer.kind !== "text") return layer;
            const { id, text, x, y, ...style } = model;
            void id; void text; void x; void y;
            return { ...layer, ...style };
          }),
        };
      }),
    }));
  }

  /* ---------- uploads ---------- */

  async function ingestFiles(files: FileList | File[]) {
    const images = Array.from(files).filter((f) => f.type.startsWith("image/"));
    if (!images.length) return;
    setBusy(`Importing ${images.length} image${images.length === 1 ? "" : "s"}…`);
    for (const file of images) await putAsset(file);
    setAssets(await allAssets());
    setBusy(null);
    setTab("images");
  }

  function onUploadInput(event: ChangeEvent<HTMLInputElement>) {
    if (event.target.files) void ingestFiles(event.target.files);
    event.target.value = "";
  }

  async function onProjectInput(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    try {
      const next = normaliseProject(JSON.parse(await file.text()));
      if (!next) throw new Error("This file does not contain a screenshot project.");
      setProject(next);
      setActiveFrameId(next.frames[0]?.id ?? null);
      setSelectedId(null);
      setEditingId(null);
      setSavedAt(null);
    } catch (error) {
      alert(`Could not open project: ${(error as Error).message}`);
    }
  }

  function onDrop(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    setDropping(false);
    if (event.dataTransfer.files.length) void ingestFiles(event.dataTransfer.files);
  }

  async function removeAsset(id: string) {
    await deleteAsset(id);
    setAssets(await allAssets());
  }

  /* ---------- pointer ---------- */

  const stageOf = (event: ReactPointerEvent<HTMLElement> | ReactMouseEvent<HTMLElement>) =>
    (event.target as HTMLElement).closest(".stage") as HTMLElement | null;

  function pointIn(stage: HTMLElement, clientX: number, clientY: number) {
    const bounds = stage.getBoundingClientRect();
    return {
      x: ((clientX - bounds.left) / bounds.width) * 100,
      y: ((clientY - bounds.top) / bounds.height) * 100,
    };
  }

  function beginDrag(kind: "phone" | "layer", frame: Frame, event: ReactPointerEvent<HTMLDivElement>, layerId?: string) {
    const stage = stageOf(event);
    if (!stage) return;
    const point = pointIn(stage, event.clientX, event.clientY);
    const layer = layerId ? frame.layers.find((l) => l.id === layerId) : undefined;
    drag.current = {
      kind,
      frameId: frame.id,
      layerId,
      stage,
      originX: kind === "phone" ? frame.phone.x : (layer?.x ?? 50),
      originY: kind === "phone" ? frame.phone.y : (layer?.y ?? 0),
      startX: point.x,
      startY: point.y,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
    setDragging(kind);
  }

  function moveDrag(event: ReactPointerEvent<HTMLDivElement>) {
    const state = drag.current;
    if (!state) return;
    const point = pointIn(state.stage, event.clientX, event.clientY);
    const rawX = state.originX + point.x - state.startX;
    const rawY = state.originY + point.y - state.startY;
    const snapX = Math.abs(rawX - 50) < 1.5 ? 50 : rawX;
    if (state.kind === "phone") {
      const frame = displayFrames.find((f) => f.id === state.frameId);
      if (!frame) return;
      patchDeviceFrame(state.frameId, {
        phone: {
          ...frame.phone,
          x: clamp(snapX, -40, 140),
          y: Math.abs(rawY - 76) < 1.5 ? 76 : clamp(rawY, 0, 130),
        },
      });
    } else if (state.layerId) {
      patchLayer(state.frameId, state.layerId, { x: clamp(snapX, -40, 140), y: clamp(rawY, -20, 120) });
    }
  }

  const stopDrag = () => {
    drag.current = null;
    setDragging(null);
  };

  /* ---------- keyboard ---------- */

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (editingId || !selectedId || !activeFrame) return;
      const target = event.target as HTMLElement | null;
      if (target && (target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName))) return;
      const layer = activeFrame.layers.find((l) => l.id === selectedId);
      if (!layer) return;
      const step = event.shiftKey ? 2 : 0.4;
      const nudges: Record<string, Partial<Layer>> = {
        ArrowLeft: { x: layer.x - step },
        ArrowRight: { x: layer.x + step },
        ArrowUp: { y: layer.y - step },
        ArrowDown: { y: layer.y + step },
      };
      if (nudges[event.key]) {
        event.preventDefault();
        patchLayer(activeFrame.id, selectedId, nudges[event.key]);
      } else if (event.key === "Backspace" || event.key === "Delete") {
        event.preventDefault();
        removeLayer(activeFrame.id, selectedId);
      } else if (event.key === "Enter" && layer.kind === "text") {
        event.preventDefault();
        setEditingId(selectedId);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [activeFrame, editingId, selectedId, patchLayer, removeLayer]);

  /* ---------- export ---------- */

  async function renderFrames(list: Frame[]) {
    const files: { name: string; blob: Blob }[] = [];
    for (let i = 0; i < list.length; i++) {
      const frame = list[i];
      const position = frames.indexOf(frame);
      setBusy(`Rendering ${i + 1} of ${list.length}…`);
      const node = exportNodes.current.get(frame.id);
      if (!node) continue;
      const headline = frame.layers.find((l): l is TextLayer => l.kind === "text");
      files.push({
        name: `${slugify(headline?.text ?? "screen", position, slug || "screen")}-${device}-${canvasW}x${canvasH}.png`,
        blob: await renderNode(node, canvasW, canvasH),
      });
    }
    return files;
  }

  async function exportZip() {
    setBusy("Rendering…");
    try {
      const files = await renderFrames(frames);
      setBusy("Zipping…");
      download(
        await zipBlobs(files),
        `app-store-screenshots-${slug ? `${slug}-` : ""}${device}-${canvasW}x${canvasH}-${frames.length}.zip`,
      );
    } catch (error) {
      console.error(error);
      alert(`Export failed: ${exportErrorMessage(error)}`);
    } finally {
      setBusy(null);
    }
  }

  async function exportActive() {
    if (!activeFrame) return;
    setBusy("Rendering…");
    try {
      const [file] = await renderFrames([activeFrame]);
      if (file) download(file.blob, file.name);
    } catch (error) {
      console.error(error);
      alert(`Export failed: ${exportErrorMessage(error)}`);
    } finally {
      setBusy(null);
    }
  }

  /* ---------- panels ---------- */

  const libraryChips: [string, string][] = [
    ...library,
    ...assets.map((a) => [a.name.replace(/\.[a-z]+$/i, ""), `asset:${a.id}`] as [string, string]),
  ];

  function panel() {
    if (!activeFrame) return null;
    switch (tab) {
      case "screens":
        return (
          <>
            <PanelHead title="Screens" hint="Each screen is one App Store image." />
            <button className="primary" onClick={addFrame}>+ Add a screen</button>
            <ol className="screen-list">
              {frames.map((frame, index) => (
                <li key={frame.id} className={frame.id === activeFrame.id ? "active" : ""}>
                  <button className="pick" onClick={() => setActiveFrameId(frame.id)}>
                    <b>{index + 1}</b>
                    <span>{layerLabel(frame.layers.find((l) => l.kind === "text") ?? frame.layers[0] ?? { kind: "text", text: "Empty" } as Layer)}</span>
                  </button>
                  <div className="row-actions">
                    <button onClick={() => moveFrame(frame.id, -1)} disabled={index === 0} title="Move left">←</button>
                    <button onClick={() => moveFrame(frame.id, 1)} disabled={index === frames.length - 1} title="Move right">→</button>
                    <button onClick={() => duplicateFrame(frame.id)} title="Duplicate">⧉</button>
                    <button onClick={() => removeFrame(frame.id)} disabled={frames.length === 1} title="Delete">✕</button>
                  </div>
                </li>
              ))}
            </ol>
            <PanelHead title="Match the set" hint="Copy the active screen's settings to every other screen." />
            <div className="stack">
              <button onClick={applyPhoneToAll}>Use this device position everywhere</button>
              <button onClick={applyTypeToAll}>Use this text styling everywhere</button>
            </div>
            <PanelHead title="View" />
            <Range label="Preview size" value={zoom} min={140} max={420} step={10} suffix="px" onChange={setZoom} />
          </>
        );

      case "text":
        return (
          <>
            <PanelHead title="Text" hint="Click to add, then drag it on the screen. Double-click text to type." />
            <div className="stack">
              {(
                [
                  ["headline", "Add a headline", "Big, 2 short lines"],
                  ["subhead", "Add a supporting line", "One line under the headline"],
                  ["eyebrow", "Add a small label", "Tiny caps, e.g. a brand name"],
                ] as [TextKind, string, string][]
              ).map(([kind, label, hint]) => (
                <button key={kind} className="big" onClick={() => addLayer(activeFrame.id, makeText(kind, 50, 30))}>
                  <b>{label}</b>
                  <small>{hint}</small>
                </button>
              ))}
            </div>
            <PanelHead title="On this screen" hint="Click one to edit it on the right." />
            <LayerList
              frame={activeFrame}
              selectedId={selectedId}
              onSelect={(id) => { setSelectedId(id); setEditingId(null); }}
              onMove={(id, d) => moveLayerOrder(activeFrame.id, id, d)}
              onDuplicate={(id) => duplicateLayer(activeFrame.id, id)}
              onDelete={(id) => removeLayer(activeFrame.id, id)}
              only="text"
            />
          </>
        );

      case "shapes":
        return (
          <>
            <PanelHead title="Shapes" hint="Click one to drop it on the active screen. Colour and size are on the right." />
            <div className="shape-grid">
              {shapeKinds.map(({ kind, label }) => (
                <button key={kind} onClick={() => addLayer(activeFrame.id, makeShape(kind, 50, 40))}>
                  <Shape shape={kind} color="#7540da" outline={false} strokeWidth={8} ink={3} />
                  <em>{label}</em>
                </button>
              ))}
            </div>
            <PanelHead title="On this screen" />
            <LayerList
              frame={activeFrame}
              selectedId={selectedId}
              onSelect={(id) => { setSelectedId(id); setEditingId(null); }}
              onMove={(id, d) => moveLayerOrder(activeFrame.id, id, d)}
              onDuplicate={(id) => duplicateLayer(activeFrame.id, id)}
              onDelete={(id) => removeLayer(activeFrame.id, id)}
              only="shape"
            />
          </>
        );

      case "images":
        return (
          <>
            <PanelHead
              title={`${device === "ipad" ? "iPad" : "iPhone"} screenshots`}
              hint={`Pick the app capture that goes inside the ${device === "ipad" ? "iPad" : "iPhone"} frame on this screen.`}
            />
            <label className={`upload${dropping ? " hot" : ""}`}>
              <input type="file" accept="image/*" multiple onChange={onUploadInput} />
              <span>↑</span>
              <b>Upload images</b>
              <small>Pick several at once, or drag a folder onto the page</small>
            </label>
            <div className="source-grid">
              {libraryChips.map(([name, src]) => (
                <button
                  key={src}
                  className={activeDeviceFrame?.image === src ? "selected" : ""}
                  onClick={() => patchActiveDevice({ image: src })}
                  title={name}
                >
                  {name}
                </button>
              ))}
            </div>
            {assets.length > 0 && (
              <>
                <PanelHead title="Uploads" hint="“+” places an image on top of the screen, e.g. a logo." />
                <div className="asset-list">
                  {assets.map((asset) => (
                    <div key={asset.id}>
                      <img src={urls.get(asset.id)} alt="" />
                      <span>{asset.name}</span>
                      <button onClick={() => addLayer(activeFrame.id, makeImage(`asset:${asset.id}`, 50, 40))} title="Place on top of the screen">+</button>
                      <button onClick={() => void removeAsset(asset.id)} title="Delete this upload">✕</button>
                    </div>
                  ))}
                </div>
              </>
            )}
          </>
        );

      case "theme":
        return (
          <>
            <PanelHead title="Theme" hint="Changes the background and text colours on every screen at once." />
            <div className="theme-grid">
              {palettes.map((entry) => (
                <button key={entry.id} className={theme.paletteId === entry.id ? "active" : ""} onClick={() => patchTheme({ paletteId: entry.id })}>
                  <i style={{ background: swatch(entry.palette) }} />
                  {entry.label}
                </button>
              ))}
              <button className={theme.paletteId === "custom" ? "active" : ""} onClick={() => patchTheme({ paletteId: "custom" })}>
                <i style={{ background: swatch(theme.custom) }} />
                Custom
              </button>
            </div>
            {theme.paletteId === "custom" && (
              <div className="custom-theme">
                {(Object.keys(theme.custom) as (keyof Palette)[]).map((key) => (
                  <label key={key}>
                    <input type="color" value={theme.custom[key]} onChange={(e) => patchTheme({ custom: { ...theme.custom, [key]: e.target.value } })} />
                    {key}
                  </label>
                ))}
              </div>
            )}
            <PanelHead title="Across the set" />
            <label className="toggle">
              <input
                type="checkbox"
                checked={theme.alternate}
                onChange={(e) => patchTheme({ alternate: e.target.checked })}
              />
              Alternate between two themes
            </label>
            {theme.alternate ? (
              <>
                {/* Spelling out which screens get which palette: with this on, a
                    theme click only repaints half the set, which otherwise looks
                    like the click failed. */}
                <div className="parity">
                  <div>
                    <i style={{ background: swatch(theme.paletteId === "custom" ? theme.custom : (palettes.find((p) => p.id === theme.paletteId) ?? palettes[0]).palette) }} />
                    <b>Screens 1, 3, 5…</b>
                    <small>The theme picked above</small>
                  </div>
                  <div>
                    <i style={{ background: swatch((palettes.find((p) => p.id === theme.alternateId) ?? palettes[0]).palette) }} />
                    <b>Screens 2, 4, 6…</b>
                    <select
                      value={theme.alternateId}
                      onChange={(e) => patchTheme({ alternateId: e.target.value })}
                    >
                      {palettes.map((p) => (
                        <option key={p.id} value={p.id}>{p.label}</option>
                      ))}
                    </select>
                  </div>
                </div>
                <p className="notice">
                  Alternating is on, so picking a theme above only changes screens 1, 3, 5…
                  Untick it to give every screen the same theme.
                </p>
              </>
            ) : null}
            <label className="toggle">
              <input type="checkbox" checked={theme.bleed} onChange={(e) => patchTheme({ bleed: e.target.checked })} />
              Let shapes run across screen edges
            </label>
            <p className="hint">
              Turn bleed on for a layer in its own panel — a circle on a boundary is then cut in
              half and continues on the next screenshot.
            </p>
          </>
        );

      case "export":
        return (
          <>
            <PanelHead
              title="Export"
              hint={`Every screen renders at ${canvasW} × ${canvasH} for ${exportSize.shortLabel}.`}
            />
            <FormatControls
              device={device}
              sizeId={project.sizeId}
              onDevice={chooseDevice}
              onSize={chooseSize}
              compact
            />
            <div className="export-summary">
              <span>{device === "ipad" ? "iPad Pro 13-inch" : "iPhone"}</span>
              <b>{canvasW} × {canvasH} px</b>
              <small>Portrait PNG · no transparency</small>
            </div>
            <button className="primary big" onClick={exportZip} disabled={!!busy}>
              <b>{busy ?? `Download all ${frames.length} as a .zip`}</b>
              <small>One file, ready to upload to App Store Connect</small>
            </button>
            <div className="stack">
              <button onClick={exportActive} disabled={!!busy}>Download only the active screen</button>
              <button onClick={() => exportProjectFile(project)}>Save the project as a file</button>
              <label className="button-label">
                Open a saved project
                <input type="file" accept="application/json,.json" onChange={onProjectInput} />
              </label>
            </div>
            <p className="hint">
              Nothing is uploaded anywhere — images are rendered in this browser. Your work saves
              itself automatically{savedAt ? `, last at ${savedAt}` : ""}.
            </p>
          </>
        );
    }
  }

  /* ---------- render ---------- */

  return (
    <main
      className={`studio${dropping ? " dropping" : ""}`}
      onDragOver={(e) => { e.preventDefault(); setDropping(true); }}
      onDragLeave={() => setDropping(false)}
      onDrop={onDrop}
    >
      <nav className="rail">
        <div className="rail-brand">SS</div>
        {tabs.map((entry) => (
          <button
            key={entry.id}
            className={tab === entry.id ? "on" : ""}
            onClick={() => setTab(entry.id)}
            title={entry.label}
          >
            <i>{entry.icon}</i>
            {entry.label}
          </button>
        ))}
        <div className="rail-save">{savedAt ? `Saved ${savedAt}` : "Saving…"}</div>
      </nav>

      <aside className="panel">{panel()}</aside>

      <section className="workspace">
        <header>
          <div>
            <h1>
              Screenshot studio
              <select
                className="project-switch"
                value={slug}
                title="Each app keeps its own screenshot set"
                onChange={(event) => {
                  saveProject(project);
                  const url = new URL(window.location.href);
                  if (event.target.value) url.searchParams.set("project", event.target.value);
                  else url.searchParams.delete("project");
                  window.location.href = url.toString();
                }}
              >
                <option value="">LineCheck</option>
                <option value="critterscale">Critter Scale</option>
                {KINU_LOCALES.map(({ slug, label }) => (
                  <option key={slug} value={slug}>{label}</option>
                ))}
              </select>
            </h1>
            <p>
              {frames.length} screen{frames.length === 1 ? "" : "s"} · {exportSize.shortLabel} · {canvasW} × {canvasH}
            </p>
          </div>
          <div className="header-tools">
            <FormatControls
              device={device}
              sizeId={project.sizeId}
              onDevice={chooseDevice}
              onSize={chooseSize}
            />
            <span className={`interaction-hint${dragging ? " dragging" : ""}`}>
              {dragging === "phone" ? "Moving device" : dragging === "layer" ? "Moving layer" : "Select an item to edit it"}
            </span>
          </div>
        </header>

        <div className="getting-started" role="note">
          <b>Quick start</b>
          <span><i>1</i> Choose a screen</span>
          <span><i>2</i> Add copy or artwork</span>
          <span><i>3</i> Select anything to fine-tune it</span>
        </div>

        <div className="board" onPointerMove={moveDrag} onPointerUp={stopDrag} onPointerCancel={stopDrag}>
          {frames.map((frame, index) => (
            <figure
              key={frame.id}
              className={`board-item${frame.id === activeFrame?.id ? " active" : ""}`}
              onPointerDownCapture={() => setActiveFrameId(frame.id)}
            >
              <figcaption>
                <b>Screen {index + 1}</b>
                <div className="frame-actions">
                  <button onClick={() => moveFrame(frame.id, -1)} disabled={index === 0} title="Move left">←</button>
                  <button onClick={() => moveFrame(frame.id, 1)} disabled={index === frames.length - 1} title="Move right">→</button>
                  <button onClick={() => duplicateFrame(frame.id)} title="Duplicate screen">⧉</button>
                  <button onClick={() => removeFrame(frame.id)} disabled={frames.length === 1} title="Delete screen">✕</button>
                </div>
              </figcaption>
              <div className="preview-frame" style={{ width: zoom, aspectRatio: `${canvasW} / ${canvasH}` }}>
                <div className="stage" style={{ width: canvasW, height: canvasH, transform: `scale(${zoom / canvasW})` }}>
                  <Artwork
                    frames={displayFrames}
                    index={index}
                    palette={palette(index)}
                    bleed={theme.bleed}
                    resolve={resolve}
                    device={device}
                    canvasW={canvasW}
                    canvasH={canvasH}
                    interactive
                    selectedId={frame.id === activeFrame?.id ? selectedId : null}
                    editingId={frame.id === activeFrame?.id ? editingId : null}
                    handlers={{
                      onLayerDown: (frameId, layerId, event) => {
                        event.stopPropagation();
                        const owner = displayFrames.find((f) => f.id === frameId);
                        if (!owner) return;
                        setActiveFrameId(frameId);
                        setSelectedId(layerId);
                        if (editingId === layerId) return;
                        setEditingId(null);
                        beginDrag("layer", owner, event, layerId);
                      },
                      onLayerEdit: (frameId, layerId) => {
                        stopDrag();
                        setActiveFrameId(frameId);
                        setEditingId(layerId);
                      },
                      onLayerCommit: (frameId, layerId, text) => {
                        patchLayer(frameId, layerId, { text });
                        setEditingId(null);
                      },
                      onLayerDelete: removeLayer,
                      onPhoneDown: (frameId, event) => {
                        const owner = displayFrames.find((f) => f.id === frameId);
                        if (!owner) return;
                        setActiveFrameId(frameId);
                        setSelectedId(null);
                        setEditingId(null);
                        beginDrag("phone", owner, event);
                      },
                      onCanvasDouble: (frameId, event) => {
                        const target = event.target as HTMLElement;
                        if (target.closest(".layer")) return;
                        const stage = stageOf(event);
                        if (!stage) return;
                        const point = pointIn(stage, event.clientX, event.clientY);
                        addLayer(frameId, makeText("headline", 50, clamp(point.y - 3, 0, 92)));
                      },
                    }}
                  />
                </div>
              </div>
            </figure>
          ))}
          <button className="board-add" style={{ width: zoom }} onClick={addFrame}>
            <span>+</span>
            Add screen
          </button>
        </div>
      </section>

      <aside className="inspector-panel">
        {selected && activeFrame ? (
          <>
            <div className="inspector-head">
              <div>
                <small>EDITING</small>
                <strong>{selected.kind === "text" ? "Text" : selected.kind === "shape" ? layerLabel(selected) : "Image"}</strong>
              </div>
              <div className="row-actions">
                <button onClick={() => duplicateLayer(activeFrame.id, selected.id)} title="Duplicate">⧉</button>
                <button onClick={() => removeLayer(activeFrame.id, selected.id)} title="Delete">✕</button>
                <button onClick={() => setSelectedId(null)} title="Done">✓</button>
              </div>
            </div>

            {selected.kind === "text" && (
              <TextInspector layer={selected} palette={palette(activeIndex)} patch={patchSelected} />
            )}
            {selected.kind === "shape" && (
              <ShapeInspector layer={selected} palette={palette(activeIndex)} patch={patchSelected} />
            )}
            {selected.kind === "image" && (
              <>
                <Range label="Width" value={selected.width} min={5} max={140} step={1} suffix="%" onChange={(width) => patchSelected({ width })} />
                <Range label="Height" value={selected.height} min={5} max={140} step={1} suffix="%" onChange={(height) => patchSelected({ height })} />
                <Range label="Rounded corners" value={selected.radius} min={0} max={200} step={2} suffix="px" onChange={(radius) => patchSelected({ radius })} />
              </>
            )}

            <PanelHead title="Position" />
            <Range label="Rotate" value={selected.rotate} min={-45} max={45} step={1} suffix="°" onChange={(rotate) => patchSelected({ rotate })} />
            <Range label="See-through" value={selected.opacity} min={2} max={100} step={1} suffix="%" onChange={(opacity) => patchSelected({ opacity })} />
            <div className="pos-row">
              <Range label="Left / right" value={Math.round(selected.x)} min={-40} max={140} step={1} suffix="%" onChange={(x) => patchSelected({ x })} />
              <Range label="Up / down" value={Math.round(selected.y)} min={-20} max={120} step={1} suffix="%" onChange={(y) => patchSelected({ y })} />
            </div>
            <label className="toggle">
              <input type="checkbox" checked={!!selected.spans} onChange={(e) => patchSelected({ spans: e.target.checked })} />
              Run across the screen edge
            </label>
            <label className="toggle">
              <input type="checkbox" checked={!!selected.behind} onChange={(e) => patchSelected({ behind: e.target.checked })} />
              Sit behind the device
            </label>
          </>
        ) : activeFrame && activeDeviceFrame ? (
          <>
            <div className="inspector-head">
              <div>
                <small>EDITING</small>
                <strong>Screen {activeIndex + 1}</strong>
              </div>
            </div>
            <p className="hint">Click any text or shape on a screen to style it here.</p>
            <PanelHead title="Device" hint={`The ${device === "ipad" ? "iPad" : "iPhone"} frame holding your app screenshot.`} />
            <label className="toggle">
              <input type="checkbox" checked={activeDeviceFrame.phone.visible} onChange={(e) => patchActiveDevice({ phone: { ...activeDeviceFrame.phone, visible: e.target.checked } })} />
              Show the {device === "ipad" ? "iPad" : "iPhone"}
            </label>
            <label className="toggle">
              <input type="checkbox" checked={!!activeDeviceFrame.phone.spans} onChange={(e) => patchActiveDevice({ phone: { ...activeDeviceFrame.phone, spans: e.target.checked } })} />
              Let it run onto the next screen
            </label>
            <Range label="Size" value={activeDeviceFrame.phone.scale} min={0.5} max={2.2} step={0.01} suffix="×" onChange={(scale) => patchActiveDevice({ phone: { ...activeDeviceFrame.phone, scale } })} />
            <Range label="Left / right" value={Math.round(activeDeviceFrame.phone.x)} min={-40} max={140} step={1} suffix="%" onChange={(x) => patchActiveDevice({ phone: { ...activeDeviceFrame.phone, x } })} />
            <Range label="Up / down" value={Math.round(activeDeviceFrame.phone.y)} min={0} max={130} step={1} suffix="%" onChange={(y) => patchActiveDevice({ phone: { ...activeDeviceFrame.phone, y } })} />
            <Range label="Tilt" value={activeDeviceFrame.phone.rotate} min={-25} max={25} step={1} suffix="°" onChange={(rotate) => patchActiveDevice({ phone: { ...activeDeviceFrame.phone, rotate } })} />
            <button className="reset" onClick={() => patchActiveDevice({ phone: defaultDevice(device) })}>Reset the device</button>
            <PanelHead title="Layers on this screen" />
            <LayerList
              frame={activeFrame}
              selectedId={selectedId}
              onSelect={(id) => { setSelectedId(id); setEditingId(null); }}
              onMove={(id, d) => moveLayerOrder(activeFrame.id, id, d)}
              onDuplicate={(id) => duplicateLayer(activeFrame.id, id)}
              onDelete={(id) => removeLayer(activeFrame.id, id)}
            />
          </>
        ) : null}
      </aside>

      <div className="export-canvas" aria-hidden="true">
        {frames.map((frame, index) => (
          <Artwork
            key={frame.id}
            frames={displayFrames}
            index={index}
            palette={palette(index)}
            bleed={theme.bleed}
            resolve={resolve}
            device={device}
            canvasW={canvasW}
            canvasH={canvasH}
            canvasRef={(node) => {
              if (node) exportNodes.current.set(frame.id, node);
              else exportNodes.current.delete(frame.id);
            }}
          />
        ))}
      </div>
    </main>
  );
}

/* ---------- small pieces ---------- */

const swatch = (p: Palette) =>
  `linear-gradient(135deg, ${p.base} 0%, ${p.wash} 40%, ${p.pink} 70%, ${p.purple} 100%)`;

function FormatControls({
  device,
  sizeId,
  onDevice,
  onSize,
  compact = false,
}: {
  device: DeviceKind;
  sizeId: string;
  onDevice: (device: DeviceKind) => void;
  onSize: (sizeId: string) => void;
  compact?: boolean;
}) {
  return (
    <div className={`format-controls${compact ? " compact" : ""}`} aria-label="Screenshot format">
      <div className="device-switch" role="group" aria-label="Device">
        <button className={device === "iphone" ? "on" : ""} onClick={() => onDevice("iphone")}>
          <i className="mini-device mini-phone" />
          iPhone
        </button>
        <button className={device === "ipad" ? "on" : ""} onClick={() => onDevice("ipad")}>
          <i className="mini-device mini-ipad" />
          iPad Pro 13″
        </button>
      </div>
      <label className="size-select">
        <span>Export size</span>
        <select value={sizeId} onChange={(event) => onSize(event.target.value)}>
          {exportSizes[device].map((size) => (
            <option key={size.id} value={size.id}>
              {size.recommended ? "★ " : ""}{size.label}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}

function PanelHead({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="panel-head">
      <h2>{title}</h2>
      {hint && <p>{hint}</p>}
    </div>
  );
}

function LayerList({
  frame,
  selectedId,
  onSelect,
  onMove,
  onDuplicate,
  onDelete,
  only,
}: {
  frame: Frame;
  selectedId: string | null;
  onSelect: (id: string) => void;
  onMove: (id: string, delta: number) => void;
  onDuplicate: (id: string) => void;
  onDelete: (id: string) => void;
  only?: Layer["kind"];
}) {
  const layers = only ? frame.layers.filter((l) => l.kind === only) : frame.layers;
  if (!layers.length) return <p className="hint">Nothing here yet.</p>;
  return (
    <ul className="layer-list">
      {layers.map((layer) => {
        const index = frame.layers.indexOf(layer);
        return (
          <li key={layer.id} className={layer.id === selectedId ? "active" : ""}>
            <button className="pick" onClick={() => onSelect(layer.id)}>
              <span>{layerLabel(layer)}</span>
              <small>{layer.kind}</small>
            </button>
            <div className="row-actions">
              <button onClick={() => onMove(layer.id, -1)} disabled={index === 0} title="Send back">↑</button>
              <button onClick={() => onMove(layer.id, 1)} disabled={index === frame.layers.length - 1} title="Bring forward">↓</button>
              <button onClick={() => onDuplicate(layer.id)} title="Duplicate">⧉</button>
              <button onClick={() => onDelete(layer.id)} title="Delete">✕</button>
            </div>
          </li>
        );
      })}
    </ul>
  );
}

function ColorRow({
  color,
  customColor,
  palette,
  onChange,
}: {
  color: ColorToken;
  customColor: string;
  palette: Palette;
  onChange: (next: { color: ColorToken; customColor?: string }) => void;
}) {
  return (
    <>
      <p className="control-label">Colour</p>
      <div className="color-row">
        {colorTokens.map((token) => (
          <button
            key={token}
            className={color === token ? "on" : ""}
            style={{ background: palette[token as keyof Palette] }}
            onClick={() => onChange({ color: token })}
            title={`Theme ${token}`}
          />
        ))}
        <label className={`custom-color${color === "custom" ? " on" : ""}`} title="Pick any colour">
          <input type="color" value={customColor} onChange={(e) => onChange({ color: "custom", customColor: e.target.value })} />
          Any
        </label>
      </div>
    </>
  );
}

function TextInspector({
  layer,
  palette,
  patch,
}: {
  layer: TextLayer;
  palette: Palette;
  patch: (next: Partial<TextLayer>) => void;
}) {
  return (
    <>
      <label className="field">
        Words
        <textarea value={layer.text} rows={3} onChange={(e) => patch({ text: e.target.value })} />
      </label>
      <label className="field">
        Font
        <select value={layer.font} onChange={(e) => patch({ font: e.target.value })}>
          {fonts.map((font) => (
            <option key={font}>{font}</option>
          ))}
        </select>
      </label>
      <p className="control-label">Alignment and style</p>
      <div className="seg">
        {(["left", "center", "right"] as const).map((align) => (
          <button key={align} className={layer.align === align ? "on" : ""} onClick={() => patch({ align })} title={`Align ${align}`}>
            {align === "left" ? "⇤" : align === "center" ? "⇹" : "⇥"}
          </button>
        ))}
        <button className={layer.uppercase ? "on" : ""} onClick={() => patch({ uppercase: !layer.uppercase })} title="ALL CAPS">AA</button>
        <button className={layer.italic ? "on" : ""} onClick={() => patch({ italic: !layer.italic })} title="Italic"><i style={{ fontStyle: "italic" }}>I</i></button>
        <button className={layer.rule ? "on" : ""} onClick={() => patch({ rule: !layer.rule })} title="Small dash before the text">▬</button>
      </div>
      <button className="wide" onClick={() => patch({ size: fitSize(layer) })}>
        Fit the text to its box
      </button>
      <Range label="Size" value={layer.size} min={16} max={260} step={1} suffix="px" onChange={(size) => patch({ size })} />
      <Range label="Thickness" value={layer.weight} min={300} max={900} step={100} onChange={(weight) => patch({ weight })} />
      <Range label="Letter spacing" value={layer.tracking} min={-16} max={30} step={0.5} suffix="px" onChange={(tracking) => patch({ tracking })} />
      <Range label="Line spacing" value={layer.lineHeight} min={0.7} max={2.2} step={0.05} onChange={(lineHeight) => patch({ lineHeight })} />
      <Range label="Box width" value={Math.round(layer.width)} min={10} max={130} step={1} suffix="%" onChange={(width) => patch({ width })} />
      <ColorRow color={layer.color} customColor={layer.customColor} palette={palette} onChange={patch} />
    </>
  );
}

function ShapeInspector({
  layer,
  palette,
  patch,
}: {
  layer: ShapeLayer;
  palette: Palette;
  patch: (next: Partial<ShapeLayer>) => void;
}) {
  return (
    <>
      <ColorRow color={layer.color} customColor={layer.customColor} palette={palette} onChange={patch} />
      <p className="control-label">Size</p>
      <Range label="Width" value={layer.width} min={2} max={160} step={1} suffix="%" onChange={(width) => patch({ width })} />
      <Range label="Height" value={layer.height} min={2} max={160} step={1} suffix="%" onChange={(height) => patch({ height })} />
      <label className="toggle">
        <input type="checkbox" checked={layer.outline} onChange={(e) => patch({ outline: e.target.checked })} />
        Outline instead of solid
      </label>
      {layer.outline && (
        <Range label="Line thickness" value={layer.strokeWidth} min={1} max={40} step={1} onChange={(strokeWidth) => patch({ strokeWidth })} />
      )}
      {!layer.outline && (
        <Range
          label="Ink outline"
          value={layer.ink ?? 0}
          min={0}
          max={24}
          step={1}
          onChange={(ink) => patch({ ink })}
        />
      )}
      <details className="swap-shape">
        <summary>Change the shape</summary>
        <div className="shape-grid">
          {shapeKinds.map(({ kind, label }) => (
            <button key={kind} className={layer.shape === kind ? "on" : ""} onClick={() => patch({ shape: kind })}>
              <Shape shape={kind} color="#7540da" outline={false} strokeWidth={8} ink={3} />
              <em>{label}</em>
            </button>
          ))}
        </div>
      </details>
    </>
  );
}

/* Largest size at which every line still fits the layer's box, measured in the
   real font so long headlines stop overflowing. */
function fitSize(layer: TextLayer, max = 260, min = 20) {
  const context = document.createElement("canvas").getContext("2d");
  if (!context) return layer.size;
  const lines = layer.text.split("\n").filter((line) => line.trim());
  if (!lines.length) return layer.size;
  const probe = 100;
  context.font = `${layer.weight} ${probe}px "${layer.font}", sans-serif`;
  const widest = Math.max(
    ...lines.map((line) => context.measureText(layer.uppercase ? line.toUpperCase() : line).width),
  );
  const longest = Math.max(...lines.map((line) => line.length));
  const target = (layer.width / 100) * W * 0.98 - layer.tracking * Math.max(0, longest - 1);
  return Math.round(clamp((target / widest) * probe, min, max));
}

function Range({
  label,
  value,
  min,
  max,
  step,
  suffix = "",
  onChange,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  suffix?: string;
  onChange: (n: number) => void;
}) {
  const safe = Number.isFinite(value) ? value : 0;
  return (
    <label className="range">
      <span>
        {label}
        <b>{Math.round(safe * 100) / 100}{suffix}</b>
      </span>
      <input type="range" value={safe} min={min} max={max} step={step} onChange={(e) => onChange(Number(e.target.value))} />
    </label>
  );
}
