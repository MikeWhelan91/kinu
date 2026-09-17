"use client";

import {
  Fragment,
  MouseEvent as ReactMouseEvent,
  PointerEvent as ReactPointerEvent,
  useCallback,
} from "react";
import {
  DeviceKind,
  Frame,
  H,
  Layer,
  Palette,
  resolveColor,
  W,
} from "@/lib/types";
import { Shape } from "./Shape";

const SCREEN = {
  left: (52 / 1022) * 100,
  top: (46 / 2082) * 100,
  width: (918 / 1022) * 100,
  height: (1990 / 2082) * 100,
  rx: (126 / 918) * 100,
  ry: (126 / 1990) * 100,
};

export type Handlers = {
  onLayerDown?: (frameId: string, layerId: string, e: ReactPointerEvent<HTMLDivElement>) => void;
  onLayerEdit?: (frameId: string, layerId: string) => void;
  onLayerCommit?: (frameId: string, layerId: string, text: string) => void;
  onLayerDelete?: (frameId: string, layerId: string) => void;
  onPhoneDown?: (frameId: string, e: ReactPointerEvent<HTMLDivElement>) => void;
  onCanvasDouble?: (frameId: string, e: ReactMouseEvent<HTMLDivElement>) => void;
};

function DeviceMockup({
  frame,
  imageSrc,
  device,
  canvasW,
  showPlaceholder,
  onPointerDown,
}: {
  frame: Frame;
  imageSrc: string;
  device: DeviceKind;
  canvasW: number;
  showPlaceholder?: boolean;
  onPointerDown?: (e: ReactPointerEvent<HTMLDivElement>) => void;
}) {
  if (!frame.phone.visible) return null;
  const width = device === "ipad" ? canvasW * 0.68 : canvasW * (894 / W);
  return (
    <div
      className={`device-mockup device-${device}`}
      style={{
        left: `${frame.phone.x}%`,
        top: `${frame.phone.y}%`,
        width,
        transform: `translate(-50%, -50%) scale(${frame.phone.scale}) rotate(${frame.phone.rotate}deg)`,
      }}
      onPointerDown={onPointerDown}
    >
      {device === "iphone" ? (
        <>
          <img className="iphone-frame" src="/mockup.png" alt="" draggable={false} />
          <div
            className="device-screen"
            style={{
              left: `${SCREEN.left}%`,
              top: `${SCREEN.top}%`,
              width: `${SCREEN.width}%`,
              height: `${SCREEN.height}%`,
              borderRadius: `${SCREEN.rx}% / ${SCREEN.ry}%`,
            }}
          >
            {imageSrc ? (
              <img src={imageSrc} alt="" draggable={false} />
            ) : showPlaceholder ? (
              <div className="device-placeholder">
                <b>iPhone screenshot</b>
                <span>Open Shots to add one</span>
              </div>
            ) : null}
          </div>
        </>
      ) : (
        <>
          <img className="ipad-frame-image" src="/mockup-ipad.png" alt="" draggable={false} />
          <div className="ipad-screen">
            {imageSrc ? (
              <img src={imageSrc} alt="" draggable={false} />
            ) : showPlaceholder ? (
              <div className="device-placeholder">
                <b>iPad screenshot</b>
                <span>Open Shots to add one</span>
              </div>
            ) : null}
          </div>
        </>
      )}
    </div>
  );
}

/* The game's page-title letters: the awning colours lightened by 30%, each
   letter tipped a few degrees. Words stay unbroken so wrapping never splits one. */
const CANDY = ["#a384e2", "#e47eb9", "#ffad82"];

function candyText(text: string) {
  let letter = 0;
  return text.split("\n").map((line, lineIndex) => (
    <Fragment key={lineIndex}>
      {lineIndex > 0 ? "\n" : null}
      {line.split(/( +)/).map((word, wordIndex) =>
        word.trim() === "" ? (
          word
        ) : (
          <span key={wordIndex} className="candy-word">
            {Array.from(word).map((ch, charIndex) => {
              const i = letter++;
              return (
                <span
                  key={charIndex}
                  className="candy-letter"
                  style={{ color: CANDY[i % CANDY.length], transform: `rotate(${Math.sin(i * 1.9) * 4}deg)` }}
                >
                  {ch}
                </span>
              );
            })}
          </span>
        ),
      )}
    </Fragment>
  ));
}

function LayerView({
  layer,
  resolve,
  selected,
  editing,
  onPointerDown,
  onDoubleClick,
  onCommit,
  onDelete,
}: {
  layer: Layer;
  resolve: (src: string) => string;
  selected?: boolean;
  editing?: boolean;
  onPointerDown?: (e: ReactPointerEvent<HTMLDivElement>) => void;
  onDoubleClick?: () => void;
  onCommit?: (text: string) => void;
  onDelete?: () => void;
}) {
  /* While editing, the node is uncontrolled: React must not touch the DOM the
     caret lives in, so the text is seeded once through the callback ref. */
  const seed = useCallback(
    (node: HTMLDivElement | null) => {
      if (!node || !editing || layer.kind !== "text") return;
      node.textContent = layer.text;
      node.focus();
      const range = document.createRange();
      range.selectNodeContents(node);
      window.getSelection()?.removeAllRanges();
      window.getSelection()?.addRange(range);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [editing],
  );

  const className = [
    "layer",
    `layer-${layer.kind}`,
    selected ? "selected" : "",
    editing ? "editing" : "",
  ]
    .filter(Boolean)
    .join(" ");

  const handle = selected && !editing && onDelete && (
    <button
      className="layer-delete"
      title="Delete (or press ⌫)"
      onPointerDown={(event) => {
        event.stopPropagation();
        event.preventDefault();
      }}
      onClick={onDelete}
    >
      ✕
    </button>
  );

  if (layer.kind === "text") {
    return (
      <div
        className={className}
        style={{
          left: `${layer.x}%`,
          top: `${layer.y}%`,
          width: `${layer.width}%`,
          transform: `translateX(-50%) rotate(${layer.rotate}deg)`,
          textAlign: layer.align,
          fontFamily: layer.font,
          fontSize: layer.size,
          fontWeight: layer.weight,
          fontStyle: layer.italic ? "italic" : "normal",
          letterSpacing: `${layer.tracking}px`,
          lineHeight: layer.lineHeight,
          textTransform: layer.uppercase ? "uppercase" : "none",
          color: resolveColor(layer.color, layer.customColor),
          opacity: layer.opacity / 100,
          zIndex: layer.behind ? 1 : undefined,
        }}
        onPointerDown={onPointerDown}
        onDoubleClick={onDoubleClick}
      >
        {handle}
        {layer.rule && <i className="layer-rule" />}
        {editing ? (
          <div
            className="layer-text"
            ref={seed}
            contentEditable
            suppressContentEditableWarning
            onBlur={(e) => onCommit?.(e.currentTarget.innerText)}
            onKeyDown={(e) => {
              if (e.key === "Escape") e.currentTarget.blur();
              e.stopPropagation();
            }}
          />
        ) : layer.outline || layer.candy ? (
          <div className="layer-text-stack">
            {layer.outline ? (
              <div
                className="layer-text layer-text-outline"
                aria-hidden
                style={{
                  WebkitTextStroke: `${layer.outline * 2}px var(--ink)`,
                  textShadow: layer.lift ? `0 ${layer.size * 0.07}px 0 rgba(0, 0, 0, 0.22)` : undefined,
                }}
              >
                {layer.candy ? candyText(layer.text) : layer.text}
              </div>
            ) : null}
            <div className={`layer-text${layer.outline ? " layer-text-fill" : ""}`}>
              {layer.candy ? candyText(layer.text) : layer.text}
            </div>
          </div>
        ) : (
          <div className="layer-text">{layer.text}</div>
        )}
      </div>
    );
  }

  const box = {
    left: `${layer.x}%`,
    top: `${layer.y}%`,
    width: `${layer.width}%`,
    height: `${(layer.height / 100) * W}px`,
    transform: `translate(-50%, -50%) rotate(${layer.rotate}deg)`,
    opacity: layer.opacity / 100,
    /* The device sits at z-index 2; anything marked `behind` drops under it. */
    zIndex: layer.behind ? 1 : undefined,
  };

  if (layer.kind === "shape") {
    return (
      <div className={className} style={box} onPointerDown={onPointerDown}>
        {handle}
        <Shape
          shape={layer.shape}
          color={resolveColor(layer.color, layer.customColor)}
          outline={layer.outline}
          strokeWidth={layer.strokeWidth}
          ink={layer.ink}
          aspect={layer.height / layer.width}
        />
      </div>
    );
  }

  return (
    <div className={className} style={box} onPointerDown={onPointerDown}>
      {handle}
      <img
        src={resolve(layer.src)}
        alt=""
        draggable={false}
        style={{ borderRadius: layer.radius, width: "100%", height: "100%", objectFit: "contain" }}
      />
    </div>
  );
}

export function Artwork({
  frames,
  index,
  palette,
  bleed,
  resolve,
  selectedId,
  editingId,
  interactive,
  device,
  canvasW,
  canvasH,
  canvasRef,
  handlers = {},
}: {
  frames: Frame[];
  index: number;
  palette: Palette;
  bleed: boolean;
  resolve: (src: string) => string;
  selectedId?: string | null;
  editingId?: string | null;
  interactive?: boolean;
  device: DeviceKind;
  canvasW: number;
  canvasH: number;
  canvasRef?: (node: HTMLDivElement | null) => void;
  handlers?: Handlers;
}) {
  const frame = frames[index];
  /* Anything marked as spanning is positioned in set coordinates, so a shape or
     a phone sitting on a boundary is cut in half and continues on the next
     screenshot instead of stopping at the edge. */
  const spanning = bleed
    ? frames.flatMap((other, otherIndex) =>
        other.layers
          .filter((layer) => layer.spans)
          .map((layer) => ({ frame: other, frameIndex: otherIndex, layer })),
      )
    : [];
  const own = frame.layers.filter((layer) => !bleed || !layer.spans);
  const spanningPhones = bleed
    ? frames
        .map((other, otherIndex) => ({ frame: other, frameIndex: otherIndex }))
        .filter((entry) => entry.frame.phone.spans && entry.frame.phone.visible)
    : [];
  const ownPhoneSpans = bleed && frame.phone.spans;

  const canvasScale = canvasW / W;
  const typeScale = device === "ipad" ? Math.min(canvasScale, canvasH / H) : canvasScale;
  const scaledLayer = (layer: Layer): Layer => {
    if (layer.kind === "text") {
      return {
        ...layer,
        size: layer.size * typeScale,
        tracking: layer.tracking * typeScale,
        outline: layer.outline ? layer.outline * typeScale : layer.outline,
      };
    }
    if (layer.kind === "image") {
      return {
        ...layer,
        height: layer.height * canvasScale,
        radius: layer.radius * canvasScale,
      };
    }
    return { ...layer, height: layer.height * canvasScale };
  };

  const layerNode = (frameId: string, layer: Layer) => (
    <LayerView
      key={layer.id}
      layer={scaledLayer(layer)}
      resolve={resolve}
      selected={interactive && layer.id === selectedId}
      editing={interactive && layer.id === editingId}
      onPointerDown={
        handlers.onLayerDown
          ? (event) => handlers.onLayerDown?.(frameId, layer.id, event)
          : undefined
      }
      onDoubleClick={
        handlers.onLayerEdit ? () => handlers.onLayerEdit?.(frameId, layer.id) : undefined
      }
      onCommit={
        handlers.onLayerCommit
          ? (text) => handlers.onLayerCommit?.(frameId, layer.id, text)
          : undefined
      }
      onDelete={
        handlers.onLayerDelete ? () => handlers.onLayerDelete?.(frameId, layer.id) : undefined
      }
    />
  );

  return (
    <div
      className={`artwork${interactive ? " interactive" : ""}`}
      ref={canvasRef}
      style={
        {
          "--base": palette.base,
          "--wash": palette.wash,
          "--ink": palette.ink,
          "--pink": palette.pink,
          "--purple": palette.purple,
          "--canvas-scale": canvasScale,
          ...(palette.sky
            ? {
                background: `radial-gradient(circle at 8% 90%, ${palette.wash}, transparent 38%), radial-gradient(circle at 102% 17%, ${palette.wash}, transparent 28%), ${palette.sky}`,
              }
            : {}),
          width: canvasW,
          height: canvasH,
        } as React.CSSProperties
      }
      onDoubleClick={(event) => handlers.onCanvasDouble?.(frame.id, event)}
    >
      <div className="wash wash-a" />
      <div className="wash wash-b" />

      {(spanning.length > 0 || spanningPhones.length > 0) && (
        <div
          className="panorama"
          style={{ width: frames.length * canvasW, height: canvasH, left: -index * canvasW }}
        >
          {spanning.map(({ frame: owner, frameIndex, layer }) => (
            <div
              key={layer.id}
              className="panorama-slot"
              style={{ left: frameIndex * canvasW, width: canvasW, height: canvasH }}
            >
              {layerNode(owner.id, layer)}
            </div>
          ))}
          {spanningPhones.map(({ frame: owner, frameIndex }) => (
            <div
              key={`phone-${owner.id}`}
              className="panorama-slot"
              style={{ left: frameIndex * canvasW, width: canvasW, height: canvasH }}
            >
              <DeviceMockup
                frame={owner}
                imageSrc={resolve(owner.image)}
                device={device}
                canvasW={canvasW}
                showPlaceholder={interactive}
                onPointerDown={
                  handlers.onPhoneDown
                    ? (event) => handlers.onPhoneDown?.(owner.id, event)
                    : undefined
                }
              />
            </div>
          ))}
        </div>
      )}

      <div className="phone-zone">
        {ownPhoneSpans ? null : (
        <DeviceMockup
          frame={frame}
          imageSrc={resolve(frame.image)}
          device={device}
          canvasW={canvasW}
          showPlaceholder={interactive}
          onPointerDown={
            handlers.onPhoneDown
              ? (event) => handlers.onPhoneDown?.(frame.id, event)
              : undefined
          }
        />
        )}
      </div>

      {own.map((layer) => layerNode(frame.id, layer))}
    </div>
  );
}
