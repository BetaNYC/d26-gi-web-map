import type { Map } from 'maplibre-gl';
import { setColorFunction } from '@geomatico/maplibre-cog-protocol';
import { LAYERS, type LayerDef } from '../layers';
import { dataUrl, freshDataUrl } from '../config';
import { cssVar } from './tokens';
import { makeIconMarker, ICON_PIXEL_RATIO, ICON_SIZE_RAMP } from './markers';

/** Parse a #rrggbb (or #rgb) token into [r,g,b]. */
function hexToRgb(hex: string): [number, number, number] {
  let h = hex.replace('#', '').trim();
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  const n = parseInt(h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/**
 * Build the toggle-layer sources + layers from the registry, all
 * initially hidden. Point layers use a canvas-generated icon marker (the Figma
 * legend icon) as `icon-image`; polygon layers are fills in the layer's swatch
 * token color.
 *
 * Polygon fills are inserted below the ZCTA outline so the boundaries stay
 * visible on top; point markers sit above everything.
 */
const ICON_PREFIX = 'd26-icon-';
const POLY_BEFORE = 'zctas-line';

/**
 * Explicit draw order for the polygon + raster fill layers, lowest → highest.
 * Decoupled from the registry order (which drives the toolbar grid). Point
 * layers are not listed — they always sit on top. Enforced via moveLayer after
 * the layers are built.
 */
const FILL_DRAW_ORDER = [
  'fema_100',
  'fema_500',
  'permeable',
  'swf_moderate',
  'swf_limited',
  'tree_canopy'
];

/**
 * A concrete MapLibre source+layer to build for a registry entry. Most layers
 * map to a single spec; a filter layer (GI) expands to one spec per variant,
 * each with its own source file and a `variant` tag used to pick which shows.
 */
export interface MapLayerSpec {
  id: string;
  sourceId: string;
  file: string;
  sourceLayer?: string;
  variant?: string;
}

export function mapLayerSpecs(l: LayerDef): MapLayerSpec[] {
  if (l.filter) {
    return l.filter.variants.map((v) => ({
      id: `lyr-${l.id}-${v.value}`,
      sourceId: `src-${l.id}-${v.value}`,
      file: v.file,
      sourceLayer: v.sourceLayer,
      variant: v.value
    }));
  }
  return [{ id: `lyr-${l.id}`, sourceId: `src-${l.id}`, file: l.file, sourceLayer: l.sourceLayer }];
}

export async function addDataLayers(map: Map): Promise<void> {
  await ensureIconFont();

  // Register the point-marker images first (symbol layers reference them by id).
  for (const l of LAYERS) {
    if (l.geometry === 'point' && l.indicator.type === 'icon') {
      const id = ICON_PREFIX + l.id;
      if (!map.hasImage(id)) {
        const img = makeIconMarker(l.indicator.code, {
          fill: cssVar('--color-surface-base'),
          border: cssVar('--color-on-surface-primary'),
          text: cssVar('--color-on-surface-primary')
        });
        map.addImage(id, img, { pixelRatio: ICON_PIXEL_RATIO });
      }
    }
  }

  for (const l of LAYERS) addOne(map, l);
  applyFillDrawOrder(map);
}

/**
 * Enforce FILL_DRAW_ORDER. Moving each id (lowest → highest) to just below the
 * ZCTA outline stacks them in list order: the last moved ends up highest. Point
 * layers, added without a beforeId, stay above all of these.
 */
function applyFillDrawOrder(map: Map): void {
  if (!map.getLayer(POLY_BEFORE)) return;
  for (const id of FILL_DRAW_ORDER) {
    const lid = `lyr-${id}`;
    if (map.getLayer(lid)) map.moveLayer(lid, POLY_BEFORE);
  }
}

function addOne(map: Map, l: LayerDef): void {
  for (const spec of mapLayerSpecs(l)) addSpec(map, l, spec);
}

/** Build one MapLibre source + layer for a single spec (a plain layer, or one
 *  variant of a filter layer). All GI variants share the one `GI` icon image. */
function addSpec(map: Map, l: LayerDef, spec: MapLayerSpec): void {
  const sid = spec.sourceId;

  // COG raster (Tree Canopy, Permeable): colorize the single class value to the
  // layer's swatch token; everything else (incl. NoData 255) is transparent.
  if (l.delivery === 'cog') {
    if (l.geometry !== 'raster' || l.indicator.type !== 'swatch' || l.cogValue == null) return;
    const url = dataUrl(spec.file); // setColorFunction uses the URL WITHOUT the cog:// prefix
    const [r, g, b] = hexToRgb(cssVar(l.indicator.colorVar));
    const value = l.cogValue;
    setColorFunction(url, (pixel, color) => {
      if (pixel[0] === value) color.set([r, g, b, 255]);
      else color.set([0, 0, 0, 0]);
    });
    if (!map.getSource(sid)) map.addSource(sid, { type: 'raster', url: `cog://${url}`, tileSize: 256 });
    map.addLayer(
      {
        id: spec.id,
        type: 'raster',
        source: sid,
        layout: { visibility: 'none' },
        // nearest keeps crisp class edges (no blending to transparent); opacity tunable.
        paint: { 'raster-resampling': 'nearest', 'raster-opacity': 1 }
      },
      map.getLayer(POLY_BEFORE) ? POLY_BEFORE : undefined
    );
    return;
  }

  if (l.delivery === 'pmtiles') {
    if (!map.getSource(sid)) map.addSource(sid, { type: 'vector', url: `pmtiles://${dataUrl(spec.file)}` });
  } else if (l.delivery === 'geojson') {
    // 311 GeoJSON is cache-busted — it refreshes daily.
    if (!map.getSource(sid)) map.addSource(sid, { type: 'geojson', data: freshDataUrl(spec.file) });
  }

  if (l.geometry === 'point' && l.indicator.type === 'icon') {
    map.addLayer({
      id: spec.id,
      type: 'symbol',
      source: sid,
      ...(spec.sourceLayer ? { 'source-layer': spec.sourceLayer } : {}),
      layout: {
        visibility: 'none',
        'icon-image': ICON_PREFIX + l.id,
        // Native size (scale 1) up to zMin, then ramp to ×sMax by zMax. Shared
        // with the popup offset via ICON_SIZE_RAMP so they track together.
        'icon-size': [
          'interpolate',
          ['linear'],
          ['zoom'],
          ICON_SIZE_RAMP.zMin,
          ICON_SIZE_RAMP.sMin,
          ICON_SIZE_RAMP.zMax,
          ICON_SIZE_RAMP.sMax
        ]
      }
    });
  } else if (l.geometry === 'polygon' && l.indicator.type === 'swatch') {
    map.addLayer(
      {
        id: spec.id,
        type: 'fill',
        source: sid,
        ...(spec.sourceLayer ? { 'source-layer': spec.sourceLayer } : {}),
        layout: { visibility: 'none' },
        paint: { 'fill-color': cssVar(l.indicator.colorVar), 'fill-opacity': l.fillOpacity ?? 0.5 }
      },
      map.getLayer(POLY_BEFORE) ? POLY_BEFORE : undefined
    );
  }
}

/**
 * Sync each layer's visibility to the toggle set. For a filter layer (GI), only
 * the spec matching the active variant shows (and only when the layer is on);
 * `activeVariants` maps layer id → selected variant value, defaulting to the
 * layer's `filter.defaultValue`. Safe to call before layers exist.
 */
export function applyLayerVisibility(
  map: Map,
  visible: Set<string>,
  activeVariants: Record<string, string> = {}
): void {
  for (const l of LAYERS) {
    const on = visible.has(l.id);
    const active = activeVariants[l.id] ?? l.filter?.defaultValue;
    for (const spec of mapLayerSpecs(l)) {
      if (!map.getLayer(spec.id)) continue;
      const show = on && (spec.variant == null || spec.variant === active);
      map.setLayoutProperty(spec.id, 'visibility', show ? 'visible' : 'none');
    }
  }
}

async function ensureIconFont(): Promise<void> {
  try {
    await document.fonts.load('italic 8.5px "NewComputerModernMono10"');
  } catch {
    /* fall back to monospace if the font isn't ready */
  }
}
