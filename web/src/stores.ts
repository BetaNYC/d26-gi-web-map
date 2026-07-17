import { writable, get } from 'svelte/store';
import type { Map as MaplibreMap } from 'maplibre-gl';
import { LAYERS } from './lib/layers';

/** The MapLibre map instance, shared once Map.svelte initializes it. */
export const mapStore = writable<MaplibreMap | null>(null);

/** Attribute parquet state, loaded once at startup via hyparquet. */
type AttrRow = Record<string, number | string | null>;
export const attrsLoading = writable<boolean>(true);
/** Per-ZCTA attributes + ranks, keyed by ZCTA5. */
export const zctaAttrs = writable<Map<string, AttrRow> | null>(null);
/** District-level aggregates (1 row). */
export const districtAttrs = writable<AttrRow | null>(null);

/**
 * Which toggle layers (lib/layers.ts ids) are currently visible. Default-on:
 * Green Infrastructure + every polygon and raster layer (the other point layers,
 * 311 and CSO, start off). The 311 hotspot is an analytical overlay and also
 * starts off, so the default map isn't over-stacked.
 */
const DEFAULT_VISIBLE = new Set<string>([
  'gi',
  ...LAYERS.filter(
    (l) => (l.geometry === 'polygon' || l.geometry === 'raster') && l.id !== 'hotspot_311'
  ).map((l) => l.id)
]);
export const visibleLayers = writable<Set<string>>(DEFAULT_VISIBLE);

/** Which modal is open (one at a time): the mobile Layers sheet or About. */
export type ActiveModal = 'layers' | 'about' | null;
export const activeModal = writable<ActiveModal>(null);
export function openModal(m: Exclude<ActiveModal, null>) {
  activeModal.set(m);
}
export function closeModal() {
  activeModal.set(null);
}

/**
 * Green Infrastructure map-display filter: which asset variant renders.
 * 'flood' (default) shows the flood-related subset; 'all' shows every GI asset.
 * Map-display only — does NOT affect ranks (computed pipeline-side over all
 * assets). Only actionable while the GI layer is on (enforced in the UI).
 */
export const giFilter = writable<string>('flood');
export function setGiFilter(value: string) {
  giFilter.set(value);
}

/** Flip a layer's visibility (driven by the layer toggles). */
export function toggleLayer(id: string) {
  visibleLayers.update((s) => {
    const next = new Set(s);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    return next;
  });
}

/**
 * App view state. A single `view` value drives the sidebar content:
 *   district  ← D26 tab        (district Stat Rows)
 *   zip-list  ← Zip Codes tab  (list of Zip Code Rows)
 *   zip-detail ← a zip selected (Rank Rows; back returns to zip-list)
 * The Tab Bar's active tab is derived from `view` (district vs. zip-*).
 */
export type View = 'district' | 'zip-list' | 'zip-detail';

const params = new URLSearchParams(window.location.search);

function initialState(): { view: View; zip: string | null } {
  const v = params.get('view');
  let zip = params.get('zip');
  let view: View = v === 'zip-list' || v === 'zip-detail' ? v : 'district';
  // Guard inconsistent deep-links (zip-detail needs a zip).
  if (view === 'zip-detail' && !zip) view = 'zip-list';
  // A remembered zip may persist alongside the district / zip-list views.
  return { view, zip };
}

const init = initialState();

export const view = writable<View>(init.view);
export const selectedZip = writable<string | null>(init.zip);

/** ZCTA currently hovered in the sidebar zip list → red highlight on the map. */
export const hoveredZip = writable<string | null>(null);

/**
 * Tab Bar → view. The selected zip is REMEMBERED across tab toggles: switching
 * to the Zip Codes tab returns to that zip's detail if one is remembered (else
 * the list); only the back chevron (backToList) clears the remembered zip.
 *
 * All navigation clears hoveredZip: a list row can unmount on click before its
 * mouseleave fires, which would otherwise leave the hover (red) stuck on a zip.
 */
export function selectTab(tab: 'district' | 'zip') {
  hoveredZip.set(null);
  if (tab === 'district') {
    view.set('district');
  } else {
    view.set(get(selectedZip) ? 'zip-detail' : 'zip-list');
  }
}

/** Select a zip (from the list or, later, the map) → drill into detail. */
export function selectZip(zip: string) {
  hoveredZip.set(null);
  selectedZip.set(zip);
  view.set('zip-detail');
}

/** Back affordance in zip-detail → return to the list (clears the remembered zip). */
export function backToList() {
  hoveredZip.set(null);
  selectedZip.set(null);
  view.set('zip-list');
}
