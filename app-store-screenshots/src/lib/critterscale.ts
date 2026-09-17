import {
  Frame,
  ImageLayer,
  Project,
  ShapeLayer,
  TextLayer,
  defaultPhone,
  defaultSize,
  defaultTheme,
  makeImage,
  makeShape,
  makeText,
  palettes,
  uid,
} from "./types";

/* Starter set for Critter Scale, opened with `?project=critterscale`. Copy,
   type and decoration are ready; device screens are left empty to be filled
   from Shots. The critter art in public/critterscale is rendered from the
   game's own drawing code so it matches the app exactly. */

type Critter = {
  art: string;
  x: number;
  y: number;
  size: number;
  rotate?: number;
  spans?: boolean;
};

type CritterScreen = {
  headline: string;
  byline: string;
  critters: Critter[];
};

const FONT = "Nunito";

const screens: CritterScreen[] = [
  {
    headline: "Balance the\nCritters",
    byline: "A cosy physics puzzle with a\nsquishy, stackable cast",
    critters: [
      { art: "pip-falling", x: 12, y: 26, size: 19, rotate: -12 },
      { art: "dot", x: 90, y: 41, size: 22, rotate: 8 },
      { art: "plum", x: 100, y: 79, size: 30, spans: true },
    ],
  },
  {
    headline: "Mind the\nWater",
    byline: "Dropped critters melt and the\nflood rises. Don't let it spill!",
    critters: [
      { art: "plum-worried", x: 89, y: 33, size: 22, rotate: 9 },
      { art: "sipper", x: 10, y: 55, size: 18, rotate: -14 },
    ],
  },
  {
    headline: "Meet the\nSpecials",
    byline: "Nibblers nibble, Sippers sip\nand Swells keep on growing",
    critters: [
      { art: "nibbler", x: 11, y: 28, size: 20, rotate: -6 },
      { art: "swell", x: 90, y: 45, size: 20, rotate: 12 },
      { art: "lump", x: 100, y: 80, size: 26, spans: true },
    ],
  },
  {
    headline: "Tap Left,\nTap Right",
    byline: "Steer every critter onto the\npile that needs the weight",
    critters: [
      { art: "sipper", x: 9, y: 49, size: 20, rotate: -8 },
      { art: "pip", x: 89, y: 27, size: 17, rotate: 14 },
    ],
  },
  {
    headline: "Keep It\nLevel",
    byline: "Balanced drops build your\nmultiplier all the way to ×3",
    critters: [
      { art: "swell", x: 11, y: 31, size: 21, rotate: -10 },
      { art: "dot-squish", x: 100, y: 75, size: 28, spans: true },
    ],
  },
  {
    headline: "Dress Up\nYour Scale",
    byline: "Golden critters, licorice planks\nand sunset skies",
    critters: [
      { art: "wisp", x: 10, y: 39, size: 20, rotate: -10 },
      { art: "pip", x: 90, y: 29, size: 18, rotate: 10 },
    ],
  },
  {
    headline: "Beat Your\nBest",
    byline: "Climb the Game Center\nleaderboard, one drop at a time",
    critters: [
      { art: "dot", x: 11, y: 30, size: 19, rotate: -12 },
      { art: "plum", x: 89, y: 49, size: 24, rotate: 6 },
    ],
  },
];

const WHITE = "#ffffff";

// Chunky candy letters with an ink outline and a drop shadow: the game's page titles.
const headline = (text: string): TextLayer => ({
  ...makeText("headline", 50, 3.0),
  text,
  font: FONT,
  width: 96,
  size: 150,
  weight: 900,
  tracking: -1,
  lineHeight: 0.98,
  outline: 13,
  lift: true,
  candy: true,
});

const byline = (text: string): TextLayer => ({
  ...makeText("subhead", 50, 15.4),
  text,
  font: FONT,
  width: 92,
  size: 58,
  weight: 800,
  tracking: -0.3,
  lineHeight: 1.22,
  opacity: 88,
});

// The soft white motes that drift across the in-game sky.
const mote = (x: number, y: number, width: number): ShapeLayer => ({
  ...makeShape("sparkle", x, y),
  width,
  height: width,
  color: "custom",
  customColor: WHITE,
  opacity: 70,
});

const critter = (c: Critter): ImageLayer => ({
  ...makeImage(`/critterscale/${c.art}.png`, c.x, c.y),
  width: c.size,
  height: c.size,
  rotate: c.rotate ?? 0,
  spans: c.spans,
});

const screenFrame = (screen: CritterScreen, index: number): Frame => ({
  id: uid(),
  image: "",
  phone: { ...defaultPhone(), y: 62, scale: 1.08 },
  variants: {
    ipad: { image: "", phone: { x: 50, y: 67, scale: 1.02, rotate: 0, visible: true } },
  },
  layers: [
    // The screen list names each screen after its first text layer.
    headline(screen.headline),
    byline(screen.byline),
    mote(index % 2 === 0 ? 7 : 93, 6.1, 4.2),
    mote(index % 2 === 0 ? 94 : 6, 14.1, 3),
    ...screen.critters.map(critter),
  ],
});

export const critterScaleProject = (): Project => ({
  version: 4,
  device: "iphone",
  sizeId: defaultSize("iphone").id,
  theme: {
    ...defaultTheme,
    paletteId: "critter-sky",
    custom: { ...palettes.find((p) => p.id === "critter-sky")!.palette },
    bleed: true,
  },
  frames: screens.map(screenFrame),
});

/* Sets saved before the awning and name label were dropped: remove both, raise
   the device to 62% and lift the copy and critters with it, keeping any other
   edits. Runs once, since the awning is what identifies an old set. */
export function upgradeCritterScaleProject(project: Project): Project {
  const old = project.frames.some((frame) =>
    frame.layers.some((layer) => layer.kind === "shape" && layer.shape === "awning"),
  );
  if (!old) return project;
  return {
    ...project,
    frames: project.frames.map((frame) => ({
      ...frame,
      phone: { ...frame.phone, y: 62 },
      layers: frame.layers
        .filter(
          (layer) =>
            !(layer.kind === "shape" && layer.shape === "awning") &&
            !(layer.kind === "text" && layer.text === "CRITTER SCALE"),
        )
        .map((layer) =>
          layer.kind === "image"
            ? { ...layer, y: layer.y - 11 }
            : { ...layer, y: +(layer.y - 6.4).toFixed(2) },
        ),
    })),
  };
}

/* App Store search shows only the first three screenshots, so the hook, the
   flood and the specials lead. Critters bleeding across an edge are drawn in set
   coordinates, so they stay continuous on their new neighbours. */
const ORDER = ["Balance", "Water", "Specials", "Tap Left", "Level", "Dress Up", "Beat Your"];
const FIRST_ORDER = ["Balance", "Tap Left", "Level", "Water", "Specials", "Dress Up", "Beat Your"];

const screenKey = (frame: Frame) => {
  const text = frame.layers.find((layer) => layer.kind === "text");
  const headline = text && text.kind === "text" ? text.text : "";
  return ORDER.find((key) => headline.includes(key)) ?? "";
};

/* Reorders a set still in the first order, and leaves one the user has arranged
   themselves alone. */
export function reorderCritterScaleProject(project: Project): Project {
  const keys = project.frames.map(screenKey);
  const untouched = keys.length === FIRST_ORDER.length && keys.every((key, i) => key === FIRST_ORDER[i]);
  if (!untouched) return project;
  return {
    ...project,
    frames: [...project.frames].sort(
      (a, b) => ORDER.indexOf(screenKey(a)) - ORDER.indexOf(screenKey(b)),
    ),
  };
}
