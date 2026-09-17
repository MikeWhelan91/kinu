/* Layer pixel values are stored against the original 6.5" canvas width so old
   projects keep their typography. Artwork itself renders at the selected App
   Store export size. */
export const W = 1242;
export const H = 2688;

export type DeviceKind = "iphone" | "ipad";

export type ExportSize = {
  id: string;
  label: string;
  shortLabel: string;
  w: number;
  h: number;
  recommended?: boolean;
};

export const exportSizes: Record<DeviceKind, readonly ExportSize[]> = {
  iphone: [
    {
      id: "iphone-6-9-1320",
      label: '6.9″ — 1320 × 2868',
      shortLabel: 'iPhone 6.9"',
      w: 1320,
      h: 2868,
      recommended: true,
    },
    {
      id: "iphone-6-9-1290",
      label: '6.9″ — 1290 × 2796',
      shortLabel: 'iPhone 6.9"',
      w: 1290,
      h: 2796,
    },
    {
      id: "iphone-6-5-1284",
      label: '6.5″ — 1284 × 2778',
      shortLabel: 'iPhone 6.5"',
      w: 1284,
      h: 2778,
    },
    {
      id: "iphone-6-5-1242",
      label: '6.5″ — 1242 × 2688',
      shortLabel: 'iPhone 6.5"',
      w: 1242,
      h: 2688,
    },
  ],
  ipad: [
    {
      id: "ipad-13-2064",
      label: '13″ iPad Pro — 2064 × 2752',
      shortLabel: 'iPad Pro 13"',
      w: 2064,
      h: 2752,
      recommended: true,
    },
    {
      id: "ipad-13-2048",
      label: '13″ compatible — 2048 × 2732',
      shortLabel: 'iPad Pro 13"',
      w: 2048,
      h: 2732,
    },
  ],
};

export const defaultSize = (device: DeviceKind) => exportSizes[device][0];

export function sizeById(device: DeviceKind, id: string | undefined) {
  return exportSizes[device].find((size) => size.id === id) ?? defaultSize(device);
}

export type Palette = {
  base: string;
  wash: string;
  ink: string;
  pink: string;
  purple: string;
  /* Optional CSS background painted under the washes instead of flat base. */
  sky?: string;
};

export const palettes: { id: string; label: string; palette: Palette }[] = [
  {
    id: "milk",
    label: "Milk",
    palette: { base: "#fffdfd", wash: "#f4edff", ink: "#21143f", pink: "#ff69ad", purple: "#7030e9" },
  },
  {
    id: "rose",
    label: "Rose",
    palette: { base: "#fff4f8", wash: "#f8d8e9", ink: "#371b3a", pink: "#ff5f9e", purple: "#8e43e6" },
  },
  {
    id: "blush",
    label: "Blush",
    palette: { base: "#ffe9f1", wash: "#ffd0e2", ink: "#3d1330", pink: "#ff3d7f", purple: "#8b2fd8" },
  },
  {
    id: "violet",
    label: "Violet",
    palette: { base: "#5d1bd2", wash: "#b991ff", ink: "#ffffff", pink: "#ff9bc9", purple: "#f3eaff" },
  },
  {
    id: "midnight",
    label: "Midnight",
    palette: { base: "#160f2e", wash: "#3b2a6d", ink: "#ffffff", pink: "#ff6fae", purple: "#a98bff" },
  },
  {
    id: "mint",
    label: "Mint",
    palette: { base: "#f0fbf6", wash: "#cdf0e0", ink: "#0f3328", pink: "#ff6f9c", purple: "#2fa87a" },
  },
  {
    id: "sand",
    label: "Sand",
    palette: { base: "#fdf6ee", wash: "#f3e2cd", ink: "#3a2a1b", pink: "#e8734a", purple: "#b08442" },
  },
  {
    /* Critter Scale, sampled from the game: the pastel_sky shader's lilac-to-
       blush gradient, its cloud tint, the plum UI ink and the awning colours. */
    id: "critter-sky",
    label: "Critter Sky",
    palette: {
      base: "#c6b0cd",
      wash: "#f1e2e8",
      ink: "#3a2350",
      pink: "#d9479b",
      purple: "#7b4fd6",
      sky: "linear-gradient(180deg, #ad9ace 0%, #c4abcb 42%, #dcb6bd 78%, #e6c2c0 100%)",
    },
  },
  {
    /* Kinu Tumble, sampled from the app icon: the night-market sky falling from
       indigo through plum to lantern coral, with the cream of the tofu itself. */
    id: "kinu-night",
    label: "Kinu Night",
    palette: {
      base: "#5a3aa0",
      wash: "#ffe8d6",
      ink: "#ffffff",
      pink: "#ff7fb3",
      purple: "#c9a6ff",
      sky: "linear-gradient(180deg, #3f2a86 0%, #7a3fc4 38%, #e8578f 76%, #ff9a63 100%)",
    },
  },
  {
    /* Kinu Tumble's shop: the warm paper-and-hinoki of the game's interior, with
       noren indigo and lantern vermilion. Flat and bright, so the store art sits
       beside the Japanese stacking games rather than the moody puzzle ones. */
    id: "kinu-shop",
    label: "Kinu Shop",
    palette: {
      base: "#fff6e4",
      wash: "#ffd9a8",
      ink: "#2b1a17",
      pink: "#e0463a",
      purple: "#2f4fa0",
      sky: "linear-gradient(180deg, #fff3da 0%, #ffe6bb 52%, #ffcf96 100%)",
    },
  },
  {
    /* Kinu Tumble's store set. The Kinu themselves are near-white cream, so a
       cream ground left them invisible from a search result: this puts them
       against an open daytime sky that warms to tatami at the horizon. Ink is
       the exact outline colour the models are drawn with (#2a1714) and pink is
       their blush, so the decoration and the characters share one palette. */
    id: "kinu-sky",
    label: "Kinu Sky",
    palette: {
      base: "#7fd4ee",
      wash: "#ffffff",
      ink: "#2a1714",
      pink: "#ff5478",
      purple: "#2f4fa0",
      sky: "linear-gradient(180deg, #4cc3ea 0%, #7fd4ee 34%, #b9e7f2 62%, #ffe3ae 100%)",
    },
  },
];

export const paletteById = (id: string) =>
  palettes.find((entry) => entry.id === id)?.palette ?? palettes[0].palette;

/* One theme for the whole set: picking it repaints every screen. `alternateId`
   lets a set run two palettes in turn (Milk, Rose, Milk, Rose...). */
export type Theme = {
  paletteId: string;
  custom: Palette;
  alternate: boolean;
  alternateId: string;
  bleed: boolean; // decoration spans the whole set instead of each screen
};

export const defaultTheme: Theme = {
  paletteId: "milk",
  custom: { ...palettes[0].palette },
  alternate: false,
  alternateId: "rose",
  bleed: true,
};

export function themeFor(theme: Theme, index: number): Palette {
  const primary =
    theme.paletteId === "custom" ? theme.custom : paletteById(theme.paletteId);
  if (!theme.alternate || index % 2 === 0) return primary;
  return paletteById(theme.alternateId);
}

export type ColorToken = "ink" | "pink" | "purple" | "base" | "wash" | "custom";

export const colorTokens: ColorToken[] = ["ink", "pink", "purple", "base", "wash"];

export function resolveColor(token: ColorToken, custom: string) {
  return token === "custom" ? custom : `var(--${token})`;
}

export type ShapeKind =
  | "circle"
  | "ring"
  | "rounded"
  | "dots"
  | "blob"
  | "triangle"
  | "star"
  | "sparkle"
  | "arrow"
  | "squiggle"
  | "bar"
  | "awning"
  /* Japanese picture-book motifs and motion marks, drawn for Kinu Tumble. */
  | "sunburst"
  | "rays"
  | "cloud"
  | "grass"
  | "seigaiha"
  | "sakura"
  | "lantern"
  | "torii"
  | "arc"
  | "speedlines"
  | "pop"
  | "banner"
  | "steam"
  | "heart"
  | "bean"
  /* The game's own tofu box, in two halves so a pile sits inside it. */
  | "tray"
  | "trayfront";

/* The tofu box is authored in its own wide viewBox, so a layer using "tray" or
   "trayfront" wants height = width × this. Anything else stretches the art. */
export const TRAY_ASPECT = 0.46;

export const shapeKinds: { kind: ShapeKind; label: string }[] = [
  { kind: "circle", label: "Circle" },
  { kind: "ring", label: "Ring" },
  { kind: "rounded", label: "Square" },
  { kind: "dots", label: "Dots" },
  { kind: "blob", label: "Blob" },
  { kind: "triangle", label: "Triangle" },
  { kind: "star", label: "Star" },
  { kind: "sparkle", label: "Sparkle" },
  { kind: "arrow", label: "Arrow" },
  { kind: "squiggle", label: "Squiggle" },
  { kind: "bar", label: "Bar" },
  { kind: "awning", label: "Candy band" },
  { kind: "sunburst", label: "Sun" },
  { kind: "rays", label: "Burst" },
  { kind: "cloud", label: "Cloud" },
  { kind: "grass", label: "Grass" },
  { kind: "seigaiha", label: "Waves" },
  { kind: "sakura", label: "Blossom" },
  { kind: "lantern", label: "Lantern" },
  { kind: "torii", label: "Torii" },
  { kind: "arc", label: "Drop path" },
  { kind: "speedlines", label: "Speed lines" },
  { kind: "pop", label: "Impact" },
  { kind: "banner", label: "Ribbon" },
  { kind: "steam", label: "Steam" },
  { kind: "heart", label: "Heart" },
  { kind: "bean", label: "Soybean" },
  { kind: "tray", label: "Box (back)" },
  { kind: "trayfront", label: "Box (front)" },
];

type LayerBase = {
  id: string;
  x: number; // % of canvas width
  y: number; // % of canvas height
  rotate: number;
  opacity: number; // 0-100
  locked?: boolean;
  /* A layer placed in set coordinates keeps going past the edge of its screen
     and reappears on the next one. */
  spans?: boolean;
  /* Painted under the device instead of over it. Spanning layers sit at the
     same depth as every other layer, so backdrop decoration has to say so. */
  behind?: boolean;
};

export type TextLayer = LayerBase & {
  kind: "text";
  text: string;
  width: number; // % of canvas width
  align: "left" | "center" | "right";
  font: string;
  size: number;
  weight: number;
  tracking: number;
  lineHeight: number;
  color: ColorToken;
  customColor: string;
  uppercase: boolean;
  italic: boolean;
  rule: boolean;
  /* Game-title styling: an ink outline (px at the 1242 canvas), a drop shadow
     under it, and letters cycling through the awning colours. */
  outline?: number;
  lift?: boolean;
  candy?: boolean;
};

export type ShapeLayer = LayerBase & {
  kind: "shape";
  shape: ShapeKind;
  width: number; // % of canvas width
  height: number; // % of canvas width, kept in the same unit so scaling is even
  color: ColorToken;
  customColor: string;
  outline: boolean;
  strokeWidth: number;
  /* Sticker outline: an ink line painted under the fill, matching the way the
     Kinu art itself is drawn. 0 leaves the shape flat. */
  ink?: number;
};

export type ImageLayer = LayerBase & {
  kind: "image";
  src: string; // "/path", "asset:<id>" or a data URL
  width: number; // % of canvas width
  height: number; // % of canvas width
  radius: number;
};

export type Layer = TextLayer | ShapeLayer | ImageLayer;

export type Phone = {
  x: number;
  y: number;
  scale: number;
  rotate: number;
  visible: boolean;
  /* Positioned in set coordinates, so a device pushed past the edge carries on
     onto the next screenshot instead of being clipped away. */
  spans?: boolean;
};

export type Frame = {
  id: string;
  image: string;
  phone: Phone;
  /* Device captures and frame placement are kept separately so preparing the
     iPad set never overwrites a finished iPhone set. Text and decoration stay
     shared, which makes switching formats quick. */
  variants?: Partial<Record<DeviceKind, { image: string; phone: Phone }>>;
  layers: Layer[];
};

export type Project = {
  version: 4;
  device: DeviceKind;
  sizeId: string;
  theme: Theme;
  frames: Frame[];
};

let seq = 0;
export const uid = () => `l${Date.now().toString(36)}${(seq++).toString(36)}`;

export const defaultPhone = (): Phone => ({
  x: 50,
  y: 76,
  scale: 1.16,
  rotate: 0,
  visible: true,
});

export const defaultDevice = (device: DeviceKind): Phone =>
  device === "ipad"
    ? { x: 50, y: 72, scale: 1, rotate: 0, visible: true }
    : defaultPhone();

export function frameForDevice(frame: Frame, device: DeviceKind): Frame {
  if (device === "iphone") return frame;
  const variant = frame.variants?.ipad;
  return {
    ...frame,
    image: variant?.image ?? "",
    phone: variant?.phone ?? defaultDevice("ipad"),
  };
}

export type TextKind = "headline" | "subhead" | "eyebrow";

export const textDefaults: Record<TextKind, Omit<TextLayer, "id" | "x" | "y">> = {
  headline: {
    kind: "text",
    text: "Headline\ngoes here",
    width: 86,
    align: "center",
    font: "Avenir Next",
    size: 156,
    weight: 800,
    tracking: -3,
    lineHeight: 0.96,
    color: "ink",
    customColor: "#21143f",
    opacity: 100,
    rotate: 0,
    uppercase: false,
    italic: false,
    rule: false,
  },
  subhead: {
    kind: "text",
    text: "A supporting line",
    width: 84,
    align: "center",
    font: "Avenir Next",
    size: 54,
    weight: 600,
    tracking: -0.5,
    lineHeight: 1.28,
    color: "ink",
    customColor: "#21143f",
    opacity: 72,
    rotate: 0,
    uppercase: false,
    italic: false,
    rule: false,
  },
  eyebrow: {
    kind: "text",
    text: "LINECHECK",
    width: 80,
    align: "center",
    font: "Avenir Next",
    size: 36,
    weight: 900,
    tracking: 7,
    lineHeight: 1.2,
    color: "purple",
    customColor: "#7030e9",
    opacity: 100,
    rotate: 0,
    uppercase: true,
    italic: false,
    rule: true,
  },
};

export const makeText = (kind: TextKind, x: number, y: number): TextLayer => ({
  ...textDefaults[kind],
  id: uid(),
  x,
  y,
});

export const makeShape = (shape: ShapeKind, x: number, y: number): ShapeLayer => ({
  kind: "shape",
  id: uid(),
  shape,
  x,
  y,
  width: 26,
  height: 26,
  rotate: 0,
  opacity: 40,
  color: "pink",
  customColor: "#ff69ad",
  outline: false,
  strokeWidth: 10,
  ink: 0,
});

export const makeImage = (src: string, x: number, y: number): ImageLayer => ({
  kind: "image",
  id: uid(),
  src,
  x,
  y,
  width: 34,
  height: 34,
  rotate: 0,
  opacity: 100,
  radius: 0,
});

export const layerLabel = (layer: Layer) => {
  if (layer.kind === "text") return layer.text.split("\n")[0] || "Empty text";
  if (layer.kind === "shape")
    return shapeKinds.find((s) => s.kind === layer.shape)?.label ?? layer.shape;
  return "Image";
};
