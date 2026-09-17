import {
  Frame,
  ImageLayer,
  Layer,
  Project,
  ShapeKind,
  ShapeLayer,
  TextLayer,
  defaultPhone,
  defaultTheme,
  makeImage,
  makeShape,
  makeText,
  palettes,
  uid,
} from "./types";
import copy from "./kinutumble-copy.json";
import fit from "./kinutumble-fit.json";

/* Starter set for Kinu Tumble, opened with `?project=kinutumble`. Copy, type and
   decoration are ready; device screens are left empty to be filled from Shots.
   The Kinu art in public/kinutumble is rendered from the game's own models by
   tools/render_press_art.gd, so the store art matches the app exactly.

   Drawn after the Japanese stacking and merge games this sits beside on the
   store — どうぶつタワー, スイカゲーム: an open flat sky rather than a moody
   gradient, one huge ink-outlined headline up top, a caption ribbon along the
   bottom, and characters big enough to read from a search result. Three screens
   drop the phone entirely and run as pure poster, as those listings do; the
   rest keep a tilted device so real gameplay still shows.

   Three rules this set is built on, after the first pass read as flat:

   1. The Kinu are near-white cream, so they need a saturated sky behind them.
      The kinu-sky palette puts them against open daylight and takes its ink
      from the exact outline colour (#2a1714) the models are drawn with.
   2. Nothing is at rest. Every screen carries a drop path, speed lines, an
      impact star or a lean, so the set reads as a game being played rather
      than a row of stickers.
   3. The copy is English. The earlier pass set Japanese kickers in Nunito,
      which carries no CJK at all, so every one of them fell back to whatever
      face the machine happened to have and rendered as mismatched glyphs. The
      Japanese here is carried by the motifs — the sun, seigaiha waves, sakura,
      lanterns and the tofu box itself — not by text. A Japanese listing wants
      its own set with
      a CJK face bundled.

   Voice: cosy and unhurried. A quiet tofu shop, so the copy invites rather
   than challenges — "one gentle drop at a time", not "beat your score". */

/* The store set is built once per language. Copy lives in kinutumble-copy.json
   and the fitted sizes in kinutumble-fit.json, both kept in step by
   scripts/kinu_fonts.py. Each language is set in the game's own face so the
   store matches the app; Nunito carries no CJK at all. */
export type KinuLocale = "en" | "ja" | "ko" | "zh_TW";

export const KINU_LOCALES: { locale: KinuLocale; slug: string; label: string }[] = [
  { locale: "en", slug: "kinutumble", label: "Kinu Tumble" },
  { locale: "ja", slug: "kinutumble-ja", label: "Kinu Tumble — 日本語" },
  { locale: "ko", slug: "kinutumble-ko", label: "Kinu Tumble — 한국어" },
  { locale: "zh_TW", slug: "kinutumble-zh-tw", label: "Kinu Tumble — 繁體中文" },
];

type Setting = {
  font: string;
  /* Negative tracking tightens Latin display type; CJK is already set solid. */
  tracking: { headline: number; caption: number; byline: number };
  lineHeight: number;
  /* Suffix on the localised gameplay captures and room-card folder. */
  suffix: string;
};

const SETTINGS: Record<KinuLocale, Setting> = {
  en: { font: "Nunito", tracking: { headline: -2, caption: -0.4, byline: -0.3 }, lineHeight: 0.92, suffix: "" },
  ja: { font: "Kinu JA", tracking: { headline: 0, caption: 0, byline: 0 }, lineHeight: 1.02, suffix: "ja" },
  ko: { font: "Kinu KO", tracking: { headline: 0, caption: 0, byline: 0 }, lineHeight: 1.02, suffix: "ko" },
  zh_TW: { font: "Kinu ZH", tracking: { headline: 0, caption: 0, byline: 0 }, lineHeight: 1.02, suffix: "zh_TW" },
};

/* Set while a project is being built, so the layer helpers below need no
   locale argument threaded through every call. */
let setting: Setting = SETTINGS.en;
let FONT = setting.font;
const WHITE = "#ffffff";
const CREAM = "#fffbe8";
const SUN = "#ffd84d";
const LEAF = "#57c15b";
const VERMILION = "#e8442f";
const BLUSH = "#ff5478";

/* ---------------------------------------------------------------- type ---- */

/* Poster lettering: heavy, tightly stacked and thickly ink-outlined, the way
   the Japanese stacking listings shout their one line. Sizes are hand-fitted
   per screen against Nunito's real metrics so no headline ever wraps. */
const headline = (text: string, size: number, color = WHITE): TextLayer => ({
  ...makeText("headline", 50, 5.6),
  text,
  font: FONT,
  width: 96,
  size,
  weight: 900,
  tracking: setting.tracking.headline,
  lineHeight: setting.lineHeight,
  color: "custom",
  customColor: color,
  outline: 19,
  lift: true,
});

/* The line under a poster headline, on screens with no caption ribbon. */
const byline = (text: string, y: number, size = 58): TextLayer => ({
  ...makeText("subhead", 50, y),
  text,
  font: FONT,
  width: 88,
  size,
  weight: 800,
  tracking: setting.tracking.byline,
  lineHeight: 1.2,
  color: "custom",
  customColor: WHITE,
  outline: 9,
  lift: true,
  opacity: 100,
});

/* The caption band along the bottom of a gameplay screen, as the merge games
   run theirs: a folded ribbon with the line set straight across it. */
const ribbonBand = (): ShapeLayer => ({
  ...makeShape("banner", 50, 91),
  width: 104,
  height: 15,
  color: "custom",
  customColor: VERMILION,
  ink: 9,
  opacity: 100,
});

const ribbonText = (text: string, size = 54): TextLayer => ({
  ...makeText("subhead", 50, 88.4 + (54 - size) * 0.03),
  text,
  font: FONT,
  width: 84,
  size,
  weight: 900,
  tracking: setting.tracking.caption,
  lineHeight: 1.16,
  color: "custom",
  customColor: CREAM,
  opacity: 100,
});

/* ------------------------------------------------------------ the world --- */

/* `spans` lays a layer out in set coordinates so it keeps going past the edge
   of its screen; `behind` drops it under the device. Backdrop decoration wants
   both, which is why the sky, ground and clouds run as one continuous
   landscape across all seven screens instead of restarting on each. */

const grass = (): ShapeLayer => ({
  ...makeShape("grass", 50, 96),
  width: 116,
  height: 18,
  color: "custom",
  customColor: LEAF,
  ink: 7,
  opacity: 100,
  spans: true,
  behind: true,
});

const waves = (): ShapeLayer => ({
  ...makeShape("seigaiha", 50, 99.5),
  width: 116,
  height: 13,
  color: "custom",
  customColor: "#2e8f52",
  strokeWidth: 5,
  opacity: 58,
  spans: true,
  behind: true,
});

const cloud = (x: number, y: number, width: number, opacity = 100): ShapeLayer => ({
  ...makeShape("cloud", x, y),
  width,
  height: width * 0.66,
  color: "custom",
  customColor: WHITE,
  ink: 6,
  opacity,
  spans: true,
  behind: true,
});

const sun = (x: number, y: number, width: number): ShapeLayer => ({
  ...makeShape("sunburst", x, y),
  width,
  height: width,
  color: "custom",
  customColor: SUN,
  ink: 8,
  opacity: 100,
  spans: true,
  behind: true,
});

/* The flat comic burst behind a hero character. Pale, so it lifts the middle of
   the screen without competing with the art sitting on it. */
const burst = (x: number, y: number, width: number, color = WHITE, opacity = 30): ShapeLayer => ({
  ...makeShape("rays", x, y),
  width,
  height: width,
  color: "custom",
  customColor: color,
  rotate: 7,
  opacity,
  behind: true,
});

/* --------------------------------------------------------------- motion --- */

/* Wobble marks either side of a tower that is about to go. */
const wobble = (x: number, y: number, width: number, rotate: number): ShapeLayer => ({
  ...makeShape("squiggle", x, y),
  width,
  height: width * 0.5,
  color: "custom",
  customColor: WHITE,
  strokeWidth: 15,
  rotate,
  opacity: 92,
});

/* ------------------------------------------------------------- confetti --- */

const flat = (
  shape: ShapeKind,
  x: number,
  y: number,
  width: number,
  color: string,
  rotate = 0,
  aspect = 1,
): ShapeLayer => ({
  ...makeShape(shape, x, y),
  width,
  height: width * aspect,
  color: "custom",
  customColor: color,
  ink: 6,
  rotate,
  opacity: 100,
});

const sparkle = (x: number, y: number, width: number, color = CREAM): ShapeLayer => ({
  ...makeShape("sparkle", x, y),
  width,
  height: width,
  color: "custom",
  customColor: color,
  rotate: 0,
  opacity: 94,
});

const blossom = (x: number, y: number, width: number, rotate = 0) =>
  flat("sakura", x, y, width, "#ffb9d2", rotate);

const bean = (x: number, y: number, width: number, rotate = 0) =>
  flat("bean", x, y, width, "#ffcc4d", rotate, 1.35);

const heart = (x: number, y: number, width: number, rotate = 0) =>
  flat("heart", x, y, width, BLUSH, rotate);

/* ---------------------------------------------------------------- kinu ---- */

type Kinu = {
  art: string;
  x: number;
  y: number;
  /* % of canvas width. The first pass topped out around 40, which left the
     characters unreadable at store thumbnail size; a hero piece belongs at
     60-90, a supporting one at 42-58. The art carries roughly 75% of its own
     square, so a piece at 58 reads about 43% of the canvas wide. */
  size: number;
  rotate?: number;
};

const piece = (k: Kinu): ImageLayer => ({
  ...makeImage(`/kinutumble/${k.art}.png`, k.x, k.y),
  width: k.size,
  height: k.size,
  rotate: k.rotate ?? 0,
});

/* The same thing placed inline among the front layers, for the screens where
   paint order matters — speed lines behind the piece, drop path in front. */
const kinuAt = (art: string, x: number, y: number, size: number, rotate = 0): ImageLayer =>
  piece({ art, x, y, size, rotate });

/* A room captured in play and baked into a labelled card
   (public/kinutumble/cards). The card art is 582 × 590. */
const roomCard = (room: string, x: number, y: number, rotate: number, size = 36): ImageLayer => ({
  ...makeImage(`/kinutumble/cards/${setting.suffix ? `${setting.suffix}/` : ""}room-${room}.png`, x, y),
  width: size,
  height: size * (590 / 582),
  rotate,
});

/* --------------------------------------------------------------- screens -- */

/* A gameplay capture from tools/capture_play.gd, shot with the HUD in the
   set's language (lang=ja writes play-sakura-ja.png). */
const capture = (name: string) => `/screenshots/${name}${setting.suffix ? `-${setting.suffix}` : ""}.png`;

type KinuScreen = {
  headline: string;
  size: number;
  /* Poster screens hide the device and let the art carry the whole canvas. */
  poster?: boolean;
  byline?: string;
  bylineSize?: number;
  caption?: string;
  captionSize?: number;
  /* The gameplay capture in the device, from public/screenshots. */
  image?: string;
  phone?: { y: number; scale: number; rotate: number };
  /* Painted behind the device, in set coordinates. */
  sky?: Layer[];
  /* Painted in front of everything, the device included. */
  front?: Layer[];
  kinu: Kinu[];
};

/* Positions are worked out against the art's real coverage, so nothing lands
   half off the edge by accident: a cube Kinu at size s stands s × 0.159 of the
   canvas height tall either side of its centre, a tall one s × 0.196, the slab
   s × 0.083, and the grass line tops out at about y 92.5. */
const layouts = (): KinuScreen[] => [
  /* 1 — the poster, and the one screen that has to explain the game: Kinu are
     dropped into a tofu box and pile up out of it. An earlier pass showed a
     free-standing tower on grass, which is only half the game. */
  {
    headline: "",
    size: 186,
    poster: true,
    byline: "",
    sky: [sun(88, 9, 30), cloud(14, 44, 21), cloud(90, 38, 18, 86)],
    front: [
      // A mass, not a tower: five rough rows three or four across, overlapping
      // and running off the left, right and bottom edges, so the screen reads
      // as packed full rather than as a stack of blocks.
      // Painted first, so they tuck behind and close the gaps the bottom row
      // would otherwise leave for the grass to show through.
      kinuAt("kinu-ramune", 38, 97, 38, 7),
      kinuAt("kinu-chocolate", 72, 98, 38, -10),
      kinuAt("kinu-ube", 4, 96, 36, 14),
      kinuAt("kinu-slab", 22, 99, 40, -5),
      kinuAt("kinu-silken", 55, 101, 40, 4),
      kinuAt("kinu-matcha", 86, 99, 38, -9),
      kinuAt("kinu-sesame", 13, 89, 38, 12),
      kinuAt("kinu-sesame", 30, 92, 36, 6),
      kinuAt("kinu-gold", 41, 87, 40, -7),
      kinuAt("kinu-sakura", 70, 88, 38, 9),
      kinuAt("kinu-tall-tamago", 93, 86, 36, -14),
      kinuAt("kinu-fox", 57, 80, 34, 9),
      kinuAt("kinu-jelly", 6, 73, 34, 16),
      kinuAt("kinu-ube", 24, 76, 38, -11),
      kinuAt("kinu-silken", 53, 74, 40, 7),
      kinuAt("kinu-ball", 80, 76, 36, -6),
      kinuAt("kinu-gold", 95, 72, 34, -8),
      kinuAt("kinu-panda", 8, 57, 34, 11),
      kinuAt("kinu-tanuki", 78, 57, 32, -13),
      kinuAt("kinu-mint", 12, 61, 34, 13),
      kinuAt("kinu-kabocha", 34, 64, 40, -8),
      kinuAt("kinu-blueberry", 64, 62, 38, 10),
      kinuAt("kinu-worried", 88, 63, 34, -16),
      kinuAt("kinu-bunny", 4, 52, 32, 15),
      kinuAt("kinu-matcha", 22, 53, 34, 8),
      kinuAt("kinu-chocolate", 46, 52, 36, -12),
      kinuAt("kinu-sakura", 74, 51, 34, 14),
      kinuAt("kinu-bunny", 95, 54, 32, -10),
      kinuAt("kinu-falling", 72, 34, 36, -26),
    ],
    kinu: [],
  },

  /* 2 — the controls, in the game's own words: aim with the shadow, swipe to
     turn the box, let go. */
  {
    headline: "",
    size: 186,
    caption: "",
    image: capture("play-sakura"),
    phone: { y: 62, scale: 1.02, rotate: -5 },
    sky: [cloud(84, 20, 26), cloud(12, 52, 18, 82), burst(50, 58, 110, WHITE, 20)],
    front: [
      // The capture already shows the real Kinu hovering over the box, so the
      // breakout character stays clear of the HUD instead of acting it out.
      kinuAt("kinu-fox", 13, 25, 34, -14),
      kinuAt("kinu-worried", 84, 76, 52, 15),
      sparkle(90, 40, 9),
    ],
    kinu: [],
  },

  /* 3 — the rule that makes it a game: three Kinu off the counter and the run
     is over. */
  {
    headline: "",
    size: 186,
    caption: "",
    image: capture("packed"),
    phone: { y: 64, scale: 1.02, rotate: 7 },
    sky: [cloud(18, 20, 26), cloud(86, 32, 20, 84), burst(50, 60, 112, WHITE, 20)],
    front: [
      wobble(11, 36, 22, -18),
      wobble(89, 30, 22, 162),
      sparkle(33, 32, 9),
      sparkle(76, 68, 8),
    ],
    kinu: [
      { art: "kinu-worried", x: 15, y: 55, size: 58, rotate: -13 },
      { art: "kinu-ball", x: 86, y: 44, size: 44, rotate: 22 },
    ],
  },

  /* 4 — the collection. Flavours unlock by pile count, so the caption says so
     rather than just listing them. */
  {
    headline: "",
    size: 186,
    poster: true,
    caption: "",
    sky: [burst(50, 54, 126, WHITE, 28), cloud(11, 24, 21), cloud(89, 22, 18, 84)],
    front: [
      sparkle(60, 36, 10),
      sparkle(39, 71, 9),
      blossom(8, 36, 11, 12),
      blossom(93, 76, 10, -18),
    ],
    kinu: [
      { art: "kinu-matcha", x: 25, y: 31, size: 42, rotate: -14 },
      { art: "kinu-ramune", x: 73, y: 29, size: 40, rotate: 12 },
      { art: "kinu-kabocha", x: 22, y: 48, size: 44, rotate: 8 },
      { art: "kinu-chocolate", x: 50, y: 45, size: 50, rotate: -6 },
      { art: "kinu-jelly", x: 87, y: 47, size: 40, rotate: 14 },
      { art: "kinu-ube", x: 27, y: 63, size: 46, rotate: 10 },
      { art: "kinu-blueberry", x: 72, y: 64, size: 44, rotate: -11 },
      { art: "kinu-mint", x: 50, y: 79, size: 42, rotate: 5 },
    ],
  },

  /* 5 — the outfits. No count in the copy: the catalogue keeps growing. */
  {
    headline: "",
    size: 186,
    poster: true,
    caption: "",
    sky: [burst(50, 55, 128, WHITE, 28), cloud(89, 26, 22), cloud(11, 31, 19, 82)],
    front: [
      sparkle(50, 53, 13),
      sparkle(24, 31, 9),
      sparkle(77, 68, 10),
      heart(12, 58, 10, -14),
      heart(89, 44, 9, 16),
    ],
    kinu: [
      { art: "kinu-bunny", x: 27, y: 43, size: 60, rotate: -9 },
      { art: "kinu-fox", x: 73, y: 38, size: 56, rotate: 11 },
      { art: "kinu-panda", x: 29, y: 72, size: 56, rotate: 8 },
      { art: "kinu-tanuki", x: 73, y: 73, size: 60, rotate: -7 },
    ],
  },

  /* 6 — customisation, shown as what it looks like. No counts in the copy:
     rooms and boxes keep being added. Every room in the game, each shot in
     a different box by tools/capture_play.gd (mode=scene) and baked into a card,
     so one collage covers both rooms and boxes. Rows of 3, 4, 3, overlapping and
     tipped, so it reads as a scrapbook rather than a spreadsheet. */
  {
    headline: "",
    size: 186,
    poster: true,
    caption: "",
    sky: [burst(50, 53, 130, WHITE, 26), cloud(12, 21, 20), cloud(90, 24, 17, 84)],
    front: [
      roomCard("shop", 20, 34, -5),
      roomCard("night", 50, 33, 3),
      roomCard("winter", 80, 34, -3),
      roomCard("sakura_street", 15.5, 55, 4, 31),
      roomCard("bamboo_grove", 38.5, 56, -3, 31),
      roomCard("onsen", 61.5, 55, 5, 31),
      roomCard("festival", 84.5, 56, -4, 31),
      roomCard("autumn_temple", 20, 76, 3),
      roomCard("moon_viewing", 50, 77, -4),
      roomCard("neon_alley", 80, 76, 5),
    ],
    kinu: [],
  },

  /* 7 — the payoff. One gold Kinu, as big as it will go, on a gold burst. */
  {
    headline: "",
    size: 186,
    poster: true,
    caption: "",
    sky: [burst(50, 52, 146, "#ffe793", 62), cloud(12, 28, 22), cloud(88, 26, 19, 84)],
    front: [
      sparkle(21, 38, 15),
      sparkle(79, 34, 12),
      sparkle(31, 70, 11),
      sparkle(71, 74, 13),
      heart(90, 60, 12, 14),
      bean(10, 60, 11, -18),
      bean(16, 68, 9, 22),
    ],
    kinu: [
      { art: "kinu-gold", x: 50, y: 50, size: 88, rotate: -5 },
      { art: "kinu-ball", x: 20, y: 80, size: 44, rotate: 19 },
      { art: "kinu-sakura", x: 80, y: 79, size: 42, rotate: -15 },
    ],
  },
];

const screenFrame = (screen: KinuScreen): Frame => {
  const caption: Layer[] = screen.caption ? [ribbonBand(), ribbonText(screen.caption, screen.captionSize)] : [];
  return {
    id: uid(),
    // Poster screens have no device, so the art carries the whole canvas.
    image: screen.poster ? "" : (screen.image ?? ""),
    phone: screen.poster
      ? { ...defaultPhone(), visible: false }
      : { ...defaultPhone(), ...screen.phone },
    variants: {
      ipad: {
        image: screen.poster ? "" : (screen.image ?? ""),
        phone: { x: 50, y: 68, scale: 1, rotate: 0, visible: !screen.poster },
      },
    },
    layers: [
      // The ground runs under every screen, continuous across the whole set.
      grass(),
      waves(),
      ...(screen.sky ?? []),
      // The screen list names each screen after its first text layer, so the
      // headline has to come before the rest of the front layers.
      headline(screen.headline, screen.size),
      ...(screen.byline ? [byline(screen.byline, 20.5, screen.bylineSize)] : []),
      ...screen.kinu.map(piece),
      ...(screen.front ?? []),
      ...caption,
    ],
  };
};

/* One project per language. Every language uses a single headline size and a
   single caption size across all seven screens — the smallest any of its lines
   needs — so a set never looks like it was typeset screen by screen. */
export const kinuTumbleProject = (locale: KinuLocale = "en"): Project => {
  setting = SETTINGS[locale];
  FONT = setting.font;
  const text = copy[locale] as string[][];
  const sizes = fit[locale];
  const headlineSize = Math.min(...sizes.headline);
  const captionSize = Math.min(...sizes.caption.filter((size) => size > 0));
  const screens = layouts().map((screen, index) => {
    const [head, body] = text[index];
    return index === 0
      ? { ...screen, headline: head, size: headlineSize, byline: body, bylineSize: sizes.byline }
      : { ...screen, headline: head, size: headlineSize, caption: body, captionSize };
  });
  const project: Project = {
    version: 4,
    device: "iphone",
    // App Store Connect takes this set at 6.5" (1242 × 2688), not the 6.9" size.
    sizeId: "iphone-6-5-1242",
    theme: {
      ...defaultTheme,
      paletteId: "kinu-sky",
      custom: { ...palettes.find((p) => p.id === "kinu-sky")!.palette },
      bleed: true,
    },
    frames: screens.map(screenFrame),
  };
  setting = SETTINGS.en;
  FONT = setting.font;
  return project;
};

export const kinuLocaleForSlug = (slug: string) => KINU_LOCALES.find((entry) => entry.slug === slug)?.locale;
