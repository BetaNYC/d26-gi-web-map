import maplibregl, { type Map } from 'maplibre-gl';
import { mount, unmount } from 'svelte';
import Popup from '../../components/Popup.svelte';
import { LAYERS, type LayerDef } from '../layers';
import { buildPopupRows } from '../popups';
import { mapLayerSpecs } from './dataLayers';
import { iconSizePx, ICON_NATIVE_PX } from './markers';

/**
 * The visible bordered box is inset from the icon IMAGE's bounding box by a thin
 * transparent/border margin (logical px at native size). We align the popup to
 * the VISIBLE edge, not the image edge, so it doesn't creep left as the icon
 * scales up. Tunable: increase if the popup still sits left of the icon, decrease
 * if it overshoots right.
 */
const ICON_EDGE_INSET = 0.40;

/**
 * Offset so the popup's bottom-left corner sits at the icon's (visible) left edge,
 * 6px above its top edge. The axes are decoupled:
 *  - X aligns to the VISIBLE left edge → half-extent reduced by the edge inset.
 *  - Y keeps a constant 6px gap above the icon's top → use the FULL half-extent;
 *    applying the inset here (coupling the axes) made the gap shrink with zoom.
 * Both scale with the icon (ICON_SIZE_RAMP), recomputed per zoom.
 */
function popupOffset(zoom: number): [number, number] {
  const factor = iconSizePx(zoom) / ICON_NATIVE_PX;
  const halfVisible = (ICON_NATIVE_PX / 2 - ICON_EDGE_INSET) * factor;
  const halfFull = (ICON_NATIVE_PX / 2) * factor;
  return [-halfVisible, -(halfFull + 6)];
}

/**
 * Register click → attribute popup on every point layer (GI, Catch Basins, 311,
 * CSO). Clicking a rendered point opens the Popup (Figma 106:2117) at the
 * feature; clicking the map or another point closes/replaces it. Pointer cursor
 * on hover. Only visible (toggled-on) layers respond, since click queries
 * rendered features.
 */
let current: { popup: maplibregl.Popup; cmp: Record<string, unknown> } | null = null;

/** True while a point popup is open. Used to suppress zip selection on the click
 *  that dismisses a popup (closeOnClick) — that click shouldn't change the zip. */
export function hasOpenPopup(): boolean {
  return current !== null;
}

function closeCurrent() {
  current?.popup.remove(); // fires 'close' → unmounts the component
  current = null;
}

export function registerPointPopups(map: Map): void {
  for (const l of LAYERS) {
    if (l.geometry !== 'point') continue;
    // A filter layer (GI) has one map layer per variant; register on each so the
    // popup works whichever variant is showing (only the visible one has
    // rendered features to hit).
    for (const spec of mapLayerSpecs(l)) registerPointPopup(map, l, spec.id);
  }
}

function registerPointPopup(map: Map, l: LayerDef, id: string): void {
  map.on('click', id, (e) => {
    const f = e.features?.[0];
    if (!f) return;
    const rows = buildPopupRows(l.id, (f.properties ?? {}) as Record<string, unknown>);
    if (rows.length === 0) return;
    if (f.geometry.type !== 'Point') return;

    const coords = f.geometry.coordinates.slice(0, 2) as [number, number];

    closeCurrent();
    const target = document.createElement('div');
    const cmp = mount(Popup, { target, props: { rows } });
    const popup = new maplibregl.Popup({
      closeButton: false,
      closeOnClick: true,
      className: 'd26-popup',
      maxWidth: 'none',
      anchor: 'bottom-left',
      offset: popupOffset(map.getZoom())
    })
      .setLngLat(coords)
      .setDOMContent(target)
      .addTo(map);

    // Keep the popup pinned to the icon as it resizes with zoom.
    const onZoom = () => popup.setOffset(popupOffset(map.getZoom()));
    map.on('zoom', onZoom);
    popup.on('close', () => {
      map.off('zoom', onZoom);
      unmount(cmp);
      if (current?.popup === popup) current = null;
    });
    current = { popup, cmp };
  });

  map.on('mouseenter', id, () => {
    map.getCanvas().style.cursor = 'pointer';
  });
  map.on('mouseleave', id, () => {
    map.getCanvas().style.cursor = '';
  });
}
