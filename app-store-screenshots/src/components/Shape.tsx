import { ShapeKind, TRAY_ASPECT } from "@/lib/types";

/* Hand-authored SVG paths on a 0-100 viewBox. Drawn here rather than pulled
   from a clipart library so there is no licence attached to anything exported. */

const TAU = Math.PI * 2;

/* A point on a circle around the middle of the viewBox, as "x y" for a path. */
const pt = (angle: number, radius: number, cx = 50, cy = 50) =>
  `${(cx + Math.cos(angle) * radius).toFixed(2)} ${(cy + Math.sin(angle) * radius).toFixed(2)}`;

/* Wedges radiating from the centre: the flat comic-book burst the Japanese
   casual listings put behind their hero character. */
const raysPath = (() => {
  const count = 16;
  const spread = (TAU / count) * 0.44;
  return Array.from({ length: count }, (_, i) => {
    const angle = (i / count) * TAU;
    /* Starting off an inner radius rather than the exact centre: wedges that
       all meet at one point leave a pinch wherever the middle is left empty. */
    return `M${pt(angle - spread * 0.5, 9)}L${pt(angle - spread, 82)}L${pt(angle + spread, 82)}L${pt(angle + spread * 0.5, 9)}Z`;
  }).join("");
})();

/* Triangular rays around the sun, drawn apart from the disc so an outline
   traces each one, as the flat children's-book suns do. */
const sunRaysPath = (() => {
  const count = 12;
  const spread = (TAU / count) * 0.3;
  return Array.from({ length: count }, (_, i) => {
    const angle = (i / count) * TAU - Math.PI / 2;
    return `M${pt(angle - spread, 30)}L${pt(angle, 49)}L${pt(angle + spread, 30)}Z`;
  }).join("");
})();

/* The zigzag grass strip every Japanese stacking game stands its tower on. */
const grassPath = (() => {
  const blades = 13;
  let d = "M0 100V54";
  for (let i = 0; i < blades; i++) {
    const peak = ((i + 0.5) / blades) * 100;
    const valley = ((i + 1) / blades) * 100;
    d += `L${peak.toFixed(2)} 16L${valley.toFixed(2)} 54`;
  }
  return `${d}V100Z`;
})();

/* Seigaiha, the overlapping wave scales on old ceramics and noren cloth. */
const seigaihaPath = (() => {
  const columns = 6;
  const rows = 4;
  const cw = 100 / columns;
  const ch = 100 / rows;
  const arcs: string[] = [];
  for (let row = 0; row < rows; row++) {
    for (let column = 0; column <= columns; column++) {
      const cx = column * cw + (row % 2 ? cw / 2 : 0);
      const cy = (row + 1) * ch;
      for (const step of [1, 0.66, 0.33]) {
        const r = cw * 0.6 * step;
        arcs.push(
          `M${(cx - r).toFixed(2)} ${cy.toFixed(2)}A${r.toFixed(2)} ${r.toFixed(2)} 0 0 1 ${(cx + r).toFixed(2)} ${cy.toFixed(2)}`,
        );
      }
    }
  }
  return arcs.join("");
})();

/* A comic impact star, deliberately uneven so it reads as drawn rather than
   generated. Sits under a Kinu the moment it lands. */
const popPath = (() => {
  const spikes = 11;
  const points: string[] = [];
  for (let i = 0; i < spikes * 2; i++) {
    const angle = (i / (spikes * 2)) * TAU - Math.PI / 2;
    const radius = i % 2 ? 23 + (i % 3) * 3 : 49 - (i % 4) * 4;
    points.push(pt(angle, radius));
  }
  return `M${points.join("L")}Z`;
})();

/* One sakura petal, pointing up from the middle, with the notched tip real
   cherry blossom has. The flower repeats it five times. */
const PETAL =
  "M50 53C41 47 36 33 41 23c3-6 6-8 6-13 1 5 3 7 3 7s2-2 3-7c0 5 3 7 6 13 5 10 0 24-9 30z";
const SAKURA_ANGLES = [0, 72, 144, 216, 288];

const paths: Record<string, string> = {
  blob: "M50 4c18 0 34 9 41 24 7 16 2 33-7 47-10 14-24 21-40 21-17 0-33-8-40-24C-3 56 4 38 16 25 26 13 36 4 50 4z",
  triangle: "M50 6 96 92H4z",
  star: "M50 3l13 30 33 3-25 22 8 33-29-18-29 18 8-33L4 36l33-3z",
  sparkle: "M50 2c4 24 22 42 46 48-24 6-42 24-46 48-4-24-22-42-46-48 24-6 42-24 46-48z",
  arrow: "M6 58c22-30 48-44 78-44l-4-12 18 20-18 20 4-13c-26 0-48 12-66 36z",
  squiggle: "M4 62c10-22 20-32 30-30 12 3 8 30 20 32 10 2 20-10 30-34",
  /* A fat cumulus with four bumps and a flat base, the way a picture book
     draws one. Single path so an outline runs round the silhouette only. */
  cloud: "M10 78Q-2 54 17 47Q18 24 41 27Q52 7 69 22Q94 20 93 47Q106 60 92 78Z",
  heart: "M50 92C22 69 6 53 6 34 6 19 18 9 31 9c9 0 16 5 19 11 3-6 10-11 19-11 13 0 25 10 25 25 0 19-16 35-44 58z",
  /* A soybean: the shop currency, an oval with the seam down one side. */
  bean: "M50 6c22 0 38 18 38 44s-16 44-38 44S12 76 12 50 28 6 50 6z",
  /* A hexagonal caption ribbon with folded ends, for a line along the bottom. */
  banner: "M9 10h82l9 40-9 40H9L0 50z",
  /* The path a dropped piece travels, from the top corner down and out. It is
     drawn falling left-to-right; rotating the layer 90° mirrors it. */
  arc: "M7 5Q13 58 95 93",
};


/* The tofu box itself, after the game's own prop: a shallow wooden tray seen
   from just above, so the pale floor reads as a surface you drop things onto.
   It sits on a navy mat with a cream border. Two halves, so a heap can sit
   *inside* it — `tray` is the floor and the far rails, `trayfront` is the near
   rail that laps over whatever is packed in.

   Two earlier passes got this wrong. The first used the game's full
   three-quarter camera and the corner posts read as table legs; the second went
   flat and straight-on, which lost the opening entirely and stood far too tall,
   reading as a crate. This one keeps a shallow perspective on the floor and is
   authored in its own wide viewBox so nothing distorts. Colours are the game's,
   so like the awning it ignores the layer colour. */
const TRAY_WOOD = "#c8763a";
const TRAY_WOOD_LIT = "#e5a066";
const TRAY_INNER = "#f6e6bb";
const TRAY_MAT = "#1e3a8f";
const TRAY_MAT_EDGE = "#fdf6e3";

/* Authored in its own wide viewBox rather than the shared square one, so the
   tray keeps its real proportions. A layer using it wants height = width ×
   TRAY_ASPECT; anything else stretches the art. */
const TRAY_H = 1000 * TRAY_ASPECT;

function Tray({ front, ink }: { front: boolean; ink: number }) {
  const line = ink
    ? {
        stroke: "#2a1714",
        strokeWidth: ink,
        strokeLinejoin: "round" as const,
        vectorEffect: "non-scaling-stroke" as const,
        paintOrder: "stroke" as const,
      }
    : {};
  return (
    <svg viewBox={`0 0 1000 ${TRAY_H}`} width="100%" height="100%" preserveAspectRatio="none">
      {front ? (
        <>
          {/* Near rail, lapping over whatever is packed in the tray. */}
          <path d="M200 300h600l150 100H50z" fill={TRAY_WOOD} {...line} />
          <path d="M200 300h600l10 22H190z" fill={TRAY_WOOD_LIT} />
          {/* The little red catch on the front of the box. */}
          <ellipse cx="500" cy="356" rx="23" ry="16" fill="#fdf6e3" />
          <ellipse cx="500" cy="356" rx="13" ry="9" fill="#e8442f" />
        </>
      ) : (
        <>
          <rect x="25" y="288" width="950" height="152" rx="74" fill={TRAY_MAT_EDGE} {...line} />
          <rect x="58" y="306" width="884" height="114" rx="56" fill={TRAY_MAT} />
          {/* The tray wall, and the floor you drop onto showing through it. */}
          <path d="M170 40h660l120 360H50z" fill={TRAY_WOOD} {...line} />
          <path d="M180 47h640l7 30H173z" fill={TRAY_WOOD_LIT} />
          <path d="M280 112h440l80 188H200z" fill={TRAY_INNER} {...line} />
          {[-1, 0, 1].map((i) => (
            <path
              key={i}
              d={`M${500 + i * 120} 114L${500 + i * 165} 296`}
              fill="none"
              stroke="#e3cd9c"
              strokeWidth="5"
              vectorEffect="non-scaling-stroke"
            />
          ))}
        </>
      )}
    </svg>
  );
}

/* Critter Scale's in-game awning: the purple-pink-orange band with drifting
   candy stripes, a top gloss and a scalloped hem. Colours are the game's own,
   so it ignores the layer colour. `aspect` is height / width. */
function Awning({ aspect }: { aspect: number }) {
  const w = 1000;
  const h = w * aspect;
  const r = Math.max(12, Math.min(w / 26, h * 0.2));
  const body = h - r * 1.15;
  const stripe = 34;
  const stripes = [];
  for (let x = -body - stripe * 2; x < w + stripe * 2; x += stripe * 2) {
    stripes.push(`M${x} 0h${stripe}l${-body} ${body}h${-stripe}z`);
  }
  const scallops = Array.from({ length: Math.ceil(w / (r * 2)) + 1 }, (_, i) => i * r * 2);
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" height="100%" preserveAspectRatio="none">
      <defs>
        <linearGradient id="awning-band" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2={w} y2="0">
          <stop offset="0" stopColor="#7b4fd6" />
          <stop offset="0.5" stopColor="#d9479b" />
          <stop offset="1" stopColor="#ff8a4c" />
        </linearGradient>
        <clipPath id="awning-body">
          <rect x="0" y="0" width={w} height={body} />
        </clipPath>
      </defs>
      {scallops.map((cx) => (
        <circle key={`s${cx}`} cx={cx} cy={body + 3} r={r + 1.5} fill="#3a2350" fillOpacity="0.1" />
      ))}
      {scallops.map((cx) => (
        <circle key={`c${cx}`} cx={cx} cy={body} r={r} fill="url(#awning-band)" />
      ))}
      <rect x="0" y="0" width={w} height={body} fill="url(#awning-band)" />
      <g clipPath="url(#awning-body)">
        <path d={stripes.join("")} fill="#fff" fillOpacity="0.07" />
        <rect x="0" y="0" width={w} height={body * 0.42} fill="#fff" fillOpacity="0.08" />
      </g>
      {scallops.map((cx) => (
        <path
          key={`g${cx}`}
          d={`M${cx - (r - 4) * 0.89} ${body + (r - 4) * 0.45}A${r - 4} ${r - 4} 0 0 0 ${cx + (r - 4) * 0.89} ${body + (r - 4) * 0.45}`}
          fill="none"
          stroke="#fff"
          strokeOpacity="0.16"
          strokeWidth="2"
        />
      ))}
    </svg>
  );
}

export function Shape({
  shape,
  color,
  outline,
  strokeWidth,
  ink = 0,
  aspect = 0.2,
}: {
  shape: ShapeKind;
  color: string;
  outline: boolean;
  strokeWidth: number;
  /* Sticker outline: an ink line painted under the fill, the way the Kinu art
     itself is drawn. 0 leaves the shape flat. */
  ink?: number;
  aspect?: number;
}) {
  if (shape === "awning") return <Awning aspect={aspect} />;
  if (shape === "tray" || shape === "trayfront")
    return <Tray front={shape === "trayfront"} ink={ink} />;
  const fill = outline ? "none" : color;
  const stroke = outline ? color : ink ? "var(--ink)" : "none";
  const common = {
    fill,
    stroke,
    strokeWidth: outline ? strokeWidth : ink,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    /* Stroke under fill, so the ink line reads as an outline around the shape
       rather than eating half of it. */
    paintOrder: outline ? undefined : ("stroke" as const),
    vectorEffect: "non-scaling-stroke" as const,
  };
  /* Shapes made of lines rather than silhouettes: they draw in the layer
     colour and ignore fill, so `outline` and `ink` do not apply. */
  const line = {
    fill: "none",
    stroke: color,
    strokeWidth,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    vectorEffect: "non-scaling-stroke" as const,
  };

  return (
    <svg viewBox="0 0 100 100" width="100%" height="100%" preserveAspectRatio="none">
      {shape === "circle" && <circle cx="50" cy="50" r="48" {...common} />}
      {shape === "ring" && (
        <circle cx="50" cy="50" r="42" fill="none" stroke={color} strokeWidth={strokeWidth} />
      )}
      {shape === "rounded" && <rect x="3" y="3" width="94" height="94" rx="22" {...common} />}
      {shape === "bar" && <rect x="2" y="38" width="96" height="24" rx="12" {...common} />}
      {shape === "dots" &&
        Array.from({ length: 48 }, (_, index) => {
          const column = index % 8;
          const row = Math.floor(index / 8);
          return <circle key={index} cx={6 + column * 13} cy={8 + row * 17} r="1.25" fill={color} />;
        })}

      {shape === "rays" && <path d={raysPath} {...common} />}
      {shape === "sunburst" && (
        <>
          <path d={sunRaysPath} {...common} />
          <circle cx="50" cy="50" r="30" {...common} />
        </>
      )}
      {shape === "grass" && <path d={grassPath} {...common} />}
      {shape === "pop" && <path d={popPath} {...common} />}
      {shape === "sakura" && (
        <>
          {SAKURA_ANGLES.map((angle) => (
            <path key={angle} d={PETAL} transform={`rotate(${angle} 50 50)`} {...common} />
          ))}
          <circle cx="50" cy="50" r="7" {...common} />
        </>
      )}
      {/* A chōchin paper lantern: caps top and bottom, ribs across the belly. */}
      {shape === "lantern" && (
        <>
          <path d="M50 10c23 0 38 17 38 40S73 90 50 90 12 73 12 50s15-40 38-40z" {...common} />
          <path d="M48 0h4v5h-4z" {...common} />
          <rect x="33" y="3" width="34" height="10" rx="3" {...common} />
          <rect x="33" y="87" width="34" height="10" rx="3" {...common} />
          {[30, 42, 54, 66].map((y) => (
            <path
              key={y}
              d={`M${16 + Math.abs(48 - y) * 0.16} ${y}H${84 - Math.abs(48 - y) * 0.16}`}
              fill="none"
              stroke="var(--ink)"
              strokeOpacity="0.2"
              strokeWidth={Math.max(1, ink * 0.5)}
              vectorEffect="non-scaling-stroke"
            />
          ))}
        </>
      )}
      {/* A torii gate, flattened to its four bars. */}
      {shape === "torii" && (
        <>
          <path d="M3 10q47-9 94 0l-4 11q-43-8-86 0z" {...common} />
          <rect x="14" y="26" width="72" height="11" rx="2" {...common} />
          <rect x="22" y="21" width="12" height="76" {...common} />
          <rect x="66" y="21" width="12" height="76" {...common} />
        </>
      )}
      {/* Motion streaks trailing a Kinu that is still moving. */}
      {shape === "speedlines" &&
        [
          [14, 62],
          [32, 88],
          [50, 100],
          [68, 84],
          [86, 58],
        ].map(([y, w]) => (
          <rect key={y} x={0} y={y - 3.5} width={w} height="7" rx="3.5" fill={color} />
        ))}
      {/* Steam curling off something warm. */}
      {shape === "steam" &&
        [
          "M26 97C14 78 38 68 26 48 16 32 32 22 28 5",
          "M50 94C38 72 62 62 50 42 40 26 56 18 52 2",
          "M74 97C62 78 86 68 74 48 64 32 80 22 76 6",
        ].map((d) => <path key={d} d={d} {...line} />)}
      {shape === "seigaiha" && <path d={seigaihaPath} {...line} />}
      {shape === "squiggle" || shape === "arc" ? (
        <path
          d={paths[shape]}
          {...line}
          strokeDasharray={shape === "arc" ? `0 ${strokeWidth * 2.1}` : undefined}
        />
      ) : shape in paths ? (
        <path d={paths[shape]} {...common} />
      ) : null}
    </svg>
  );
}
