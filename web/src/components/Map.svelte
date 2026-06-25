<script lang="ts">
  import maplibregl from 'maplibre-gl';
  import 'maplibre-gl/dist/maplibre-gl.css';
  import { onMount, onDestroy } from 'svelte';
  import { registerMapProtocols } from '../lib/map/protocols';
  import { BASEMAP_STYLE } from '../lib/map/basemap';
  import { cssVar } from '../lib/map/tokens';
  import { dataUrl } from '../lib/config';
  import { get } from 'svelte/store';
  import { mapStore, visibleLayers, hoveredZip, selectedZip, view } from '../stores';
  import { addDataLayers, applyLayerVisibility } from '../lib/map/dataLayers';
  import { registerPointPopups } from '../lib/map/popups';
  import { LAYERS } from '../lib/layers';
  import { ZCTA_LABEL_POINTS, DISTRICT_LABEL_POINT } from '../lib/map/labelPoints';

  const COUNCIL_FILL_OPACITY = 0.08;
  /** Default (inactive) zip-code outline width — a zip that isn't selected or
   *  hovered (the thin gray line in the district / zip-detail views). Tunable. */
  const INACTIVE_ZIP_STROKE_WIDTH = 0.1;

  /** D26 district bounds [[W,S],[E,N]] (st_bbox of d26, EPSG:4326), baked like the
   *  label points — boundaries are a static Tier-2 snapshot. Used to frame the map. */
  const D26_BOUNDS: [[number, number], [number, number]] = [
    [-73.96262, 40.71999],
    [-73.8877, 40.76424]
  ];
  /** Zoom added on top of the exact fit — frames slightly tighter than the bounds. */
  const FRAME_ZOOM_BUMP = 0.1;

  /** Pan clamp: D26 bounds on each side, so the user
   *  can pan a little for context but not wander off to other neighborhoods.
   *  The values below account for panning while zoomed out with the mobile extended sheet visible. */
  const MAX_BOUNDS: [[number, number], [number, number]] = (() => {
    const [[w, s], [e, n]] = D26_BOUNDS;
    const dx = (e - w) * 2
    const dy_n = (n - s) * 2;
    const dy_s = (n - s) * 4.5;
    return [
      [w - dx, s - dy_s],
      [e + dx, n + dy_n]
    ];
  })();

  /** Padding for the initial fit, clearing the overlays: the desktop sidebar
   *  (left) / the mobile bottom-sheet peek (bottom). */
  function framePadding() {
    const base = 24;
    return window.innerWidth >= 768
      ? { top: base, right: base, bottom: base, left: 320 + 16 + base }
      : { top: base, right: base, bottom: 120 + base, left: base };
  }

  /** Frame the map to the D26 bounds (sidebar-aware padding), slightly zoomed in. */
  function frameToDistrict(m: maplibregl.Map) {
    const cam = m.cameraForBounds(D26_BOUNDS, { padding: framePadding() });
    if (cam?.center != null && cam.zoom != null) {
      m.jumpTo({ center: cam.center, zoom: cam.zoom + FRAME_ZOOM_BUMP });
    }
  }

  /**
   * Map foundation — CARTO Positron basemap, pmtiles/cog protocols, and
   * the D26 boundaries (council outline + ZCTA lines). The `zctas` source carries
   * promoteId:"ZCTA5" (kept for future map-click zip selection / a possible
   * post-V1 choropleth; the FVI choropleth is omitted in V1).
   */
  let container: HTMLDivElement;
  let map: maplibregl.Map | undefined;
  let layersReady = false;
  let currentVisible = new Set<string>();
  let unsub: (() => void) | undefined;
  let hoverUnsub: (() => void) | undefined;
  let selectUnsub: (() => void) | undefined;
  let viewUnsub: (() => void) | undefined;
  let appliedHover: string | null = null;
  let appliedSelected: string | null = null;
  let onResize: (() => void) | undefined;

  function debounce(fn: () => void, ms: number) {
    let t: ReturnType<typeof setTimeout>;
    return () => {
      clearTimeout(t);
      t = setTimeout(fn, ms);
    };
  }

  /** The zip that should show the blue 'selected' highlight — only while the
   *  zip-detail view is active. A remembered zip reverts to default styling in
   *  the District view (where only the D26 council feature shows). */
  function visiblySelected(): string | null {
    return get(view) === 'zip-detail' ? get(selectedZip) : null;
  }

  /** Set a zip's feature-state on BOTH the polygon source (drives fill/line) and
   *  the label-points source (drives label opacity), keyed by ZCTA5. */
  function setZipState(m: maplibregl.Map, id: string, state: Record<string, unknown>) {
    if (m.getSource('zctas')) m.setFeatureState({ source: 'zctas', sourceLayer: 'zctas', id }, state);
    if (m.getSource('zcta-points')) m.setFeatureState({ source: 'zcta-points', id }, state);
  }

  /** Apply the 'selected' feature-state (D26-style blue highlight) to one zip. */
  function applySelected(m: maplibregl.Map, zip: string | null) {
    if (!m.getSource('zctas') || appliedSelected === zip) return;
    if (appliedSelected != null) setZipState(m, appliedSelected, { selected: false });
    if (zip != null) setZipState(m, zip, { selected: true });
    appliedSelected = zip;
  }

  /** Council (D26) feature shows only in the District view; a selected zip
   *  replaces it with the same styling. */
  function applyCouncilVisibility(m: maplibregl.Map, v: string) {
    if (!m.getLayer('council-fill')) return;
    const vis = v === 'district' ? 'visible' : 'none';
    m.setLayoutProperty('council-fill', 'visibility', vis);
    m.setLayoutProperty('council-line', 'visibility', vis);
  }

  /**
   * ZCTA fill/line paint. In the zip-LIST view every zip gets the default D26
   * blue styling (hover still wins, red). Otherwise it's transparent/gray with
   * the `selected` (blue) and `hover` (red) feature-states, selected > hover.
   *
   * When `gated` (a polygon/raster data layer is visible): the ONLY change is
   * that the active feature's FILL goes transparent (so it doesn't tint the data
   * layer); a HOVERED zip keeps its red fill (zip-list hover preview survives).
   * Strokes are unchanged, and inactive zips keep their base/inactive styling.
   */
  function zctaPaint(isList: boolean, gated: boolean) {
    const hover: maplibregl.ExpressionSpecification = ['boolean', ['feature-state', 'hover'], false];
    const selected: maplibregl.ExpressionSpecification = ['boolean', ['feature-state', 'selected'], false];
    const blue = cssVar('--color-on-surface-beta-blue');
    const redFill = cssVar('--color-zip-hover-fill');
    const redStroke = cssVar('--color-zip-hover-stroke');
    const gray = cssVar('--color-on-surface-secondary');
    if (isList) {
      // List view: hover changes only the FILL (red); the stroke stays the
      // static blue list outline (no color/width change on row hover).
      return {
        fillColor: ['case', hover, redFill, blue] as maplibregl.ExpressionSpecification,
        fillOpacity: (gated
          ? ['case', hover, 0.2, 0]
          : ['case', hover, 0.2, 0.08]) as maplibregl.ExpressionSpecification,
        lineColor: blue,
        lineWidth: 2
      };
    }
    return {
      fillColor: ['case', selected, blue, redFill] as maplibregl.ExpressionSpecification,
      fillOpacity: (gated
        ? ['case', hover, 0.2, 0]
        : ['case', selected, 0.08, hover, 0.2, 0]) as maplibregl.ExpressionSpecification,
      lineColor: ['case', selected, blue, hover, redStroke, gray] as maplibregl.ExpressionSpecification,
      lineWidth: ['case', selected, 2, hover, 1.5, INACTIVE_ZIP_STROKE_WIDTH] as maplibregl.ExpressionSpecification
    };
  }

  /** Per-feature label opacity that mirrors fill visibility: a zip is labeled
   *  exactly when its fill shows (see zctaPaint fill-opacity). */
  function labelTextOpacity(isList: boolean, gated: boolean): number | maplibregl.ExpressionSpecification {
    const hover: maplibregl.ExpressionSpecification = ['boolean', ['feature-state', 'hover'], false];
    const selected: maplibregl.ExpressionSpecification = ['boolean', ['feature-state', 'selected'], false];
    if (isList) return gated ? (['case', hover, 1, 0] as maplibregl.ExpressionSpecification) : 1;
    return gated
      ? (['case', hover, 1, 0] as maplibregl.ExpressionSpecification)
      : (['case', selected, 1, hover, 1, 0] as maplibregl.ExpressionSpecification);
  }

  /** Show labels only where the corresponding fill is visible: district → "26";
   *  zip-list → all zips; zip-detail → the selected zip; hidden when gated. */
  function applyLabels(m: maplibregl.Map, gated: boolean) {
    if (!m.getLayer('zctas-label')) return;
    const v = get(view);
    m.setPaintProperty('zctas-label', 'text-opacity', labelTextOpacity(v === 'zip-list', gated));
    if (m.getLayer('council-label')) {
      m.setLayoutProperty('council-label', 'visibility', v === 'district' && !gated ? 'visible' : 'none');
    }
  }

  /** Re-apply the ZCTA paint for the current view + gate state. */
  function applyZctaPaint(m: maplibregl.Map, v: string, gated: boolean) {
    if (!m.getLayer('zctas-fill')) return;
    const p = zctaPaint(v === 'zip-list', gated);
    m.setPaintProperty('zctas-fill', 'fill-color', p.fillColor);
    m.setPaintProperty('zctas-fill', 'fill-opacity', p.fillOpacity);
    m.setPaintProperty('zctas-line', 'line-color', p.lineColor);
    m.setPaintProperty('zctas-line', 'line-width', p.lineWidth);
  }

  /** True if any polygon/raster data layer is currently visible — these are the
   *  translucent fills the highlight would otherwise compound with. */
  function anyDataFillVisible(): boolean {
    return LAYERS.some(
      (l) => (l.geometry === 'polygon' || l.geometry === 'raster') && currentVisible.has(l.id)
    );
  }

  /** Apply the fill gate (#1): while a polygon/raster data layer is shown, the
   *  only change is the active feature's fill going transparent (so it doesn't
   *  tint the data layer). Strokes and inactive features are unchanged. */
  function applyFillGate(m: maplibregl.Map) {
    const gated = anyDataFillVisible();
    if (m.getLayer('council-fill')) {
      m.setPaintProperty('council-fill', 'fill-opacity', gated ? 0 : COUNCIL_FILL_OPACITY);
    }
    applyZctaPaint(m, get(view), gated);
    applyLabels(m, gated);
  }

  onMount(() => {
    registerMapProtocols();
    map = new maplibregl.Map({
      container,
      style: BASEMAP_STYLE,
      center: [-73.925, 40.742], // fallback; immediately reframed to the D26 bounds below
      zoom: 12,
      minZoom: 11,
      maxZoom: 20,
      maxBounds: MAX_BOUNDS
    });
    // Frame to the district with sidebar-aware padding (replaces a fixed center/zoom).
    frameToDistrict(map);
    map.on('load', async () => {
      addBoundaries(map!);
      await addDataLayers(map!);
      registerPointPopups(map!);
      layersReady = true;
      applyLayerVisibility(map!, currentVisible);
      // Apply current selection/view state now that the layers exist.
      applySelected(map!, visiblySelected());
      applyCouncilVisibility(map!, get(view));
      applyFillGate(map!);
    });

    mapStore.set(map);

    // Re-frame to the district on resize (debounced) so layout/breakpoint changes
    // keep D26 framed with the right sidebar-aware padding.
    onResize = debounce(() => map && frameToDistrict(map), 150);
    window.addEventListener('resize', onResize);

    // Drive map layer visibility from the toggle store.
    unsub = visibleLayers.subscribe((v) => {
      currentVisible = v;
      if (map && layersReady) {
        applyLayerVisibility(map, v);
        applyFillGate(map); // re-evaluate the highlight-fill gate (#1)
      }
    });

    // Reflect the hovered zip (from map OR sidebar) as feature-state on the ZCTA
    // source, driving the red hover paint.
    hoverUnsub = hoveredZip.subscribe((zip) => {
      if (!map || !map.getSource('zctas')) return;
      if (appliedHover === zip) return;
      if (appliedHover != null) setZipState(map, appliedHover, { hover: false });
      if (zip != null) setZipState(map, zip, { hover: true });
      appliedHover = zip;
    });

    // Selected zip → blue 'selected' highlight (only while zip-detail is active).
    selectUnsub = selectedZip.subscribe(() => {
      if (map) applySelected(map, visiblySelected());
    });

    // View → council (D26) visibility + re-evaluate the visible selection (a
    // remembered zip reverts to default styling outside the zip-detail view).
    viewUnsub = view.subscribe((v) => {
      if (!map) return;
      applyCouncilVisibility(map, v);
      applySelected(map, visiblySelected());
      applyFillGate(map);
    });
  });

  onDestroy(() => {
    unsub?.();
    hoverUnsub?.();
    selectUnsub?.();
    viewUnsub?.();
    if (onResize) window.removeEventListener('resize', onResize);
    map?.remove();
    mapStore.set(null);
  });

  /** D26 council district + ZCTA boundaries. */
  function addBoundaries(m: maplibregl.Map) {
    m.addSource('zctas', {
      type: 'vector',
      url: `pmtiles://${dataUrl('d26_zctas.pmtiles')}`,
      promoteId: 'ZCTA5'
    });
    m.addSource('council', {
      type: 'vector',
      url: `pmtiles://${dataUrl('d26.pmtiles')}`
    });
    // One label anchor per feature (avoids per-tile duplicate labels). promoteId
    // ZCTA5 so the zip labels can read the same selected/hover feature-state.
    m.addSource('zcta-points', { type: 'geojson', data: ZCTA_LABEL_POINTS, promoteId: 'ZCTA5' });
    m.addSource('district-point', { type: 'geojson', data: DISTRICT_LABEL_POINT });

    // District highlight fill.
    m.addLayer({
      id: 'council-fill',
      type: 'fill',
      source: 'council',
      'source-layer': 'council-district',
      paint: { 'fill-color': cssVar('--color-on-surface-beta-blue'), 'fill-opacity': 0.08 }
    });
    // ZCTA fill/line. Paint comes from zctaPaint() and is re-applied per view +
    // gate state. Initial paint is the non-list, non-gated mode; applyFillGate
    // corrects it at load.
    const p = zctaPaint(false, false);
    m.addLayer({
      id: 'zctas-fill',
      type: 'fill',
      source: 'zctas',
      'source-layer': 'zctas',
      paint: { 'fill-color': p.fillColor, 'fill-opacity': p.fillOpacity }
    });
    m.addLayer({
      id: 'zctas-line',
      type: 'line',
      source: 'zctas',
      'source-layer': 'zctas',
      paint: { 'line-color': p.lineColor, 'line-width': p.lineWidth }
    });

    // Zip switching is sidebar-only: the map intentionally does NOT select or
    // hover-highlight zips. The zctas-fill layer exists for the selected/hover
    // feature-state styling driven by the sidebar (and point popups still work,
    // registered separately).

    // District outline (on top).
    m.addLayer({
      id: 'council-line',
      type: 'line',
      source: 'council',
      'source-layer': 'council-district',
      paint: { 'line-color': cssVar('--color-on-surface-beta-blue'), 'line-width': 2 }
    });

    // Feature labels (mirrors the boundaries-map symbol-label approach). body/small
    // size (12px); text color = the feature fill color (beta-blue) with a
    // surface/base (white) halo as the "shadow". Font is the basemap's glyph font
    // (CARTO Open Sans) — AUTHENTIC Sans isn't available as map glyphs.
    // A label shows only when its feature's fill is visible (driven by text-opacity
    // / visibility in applyLabels): district → "26"; zip-list → all zips; zip-detail
    // → the selected zip.
    const labelPaint = {
      'text-color': cssVar('--color-on-surface-beta-blue'),
      'text-halo-color': cssVar('--color-surface-base'),
      'text-halo-width': 1.5
    } as const;
    // body/default (14px) base, scaled with zoom (boundaries-map ramp, re-anchored
    // from its 12.5 to 14).
    const labelTextSize: maplibregl.ExpressionSpecification = [
      'interpolate',
      ['linear'],
      ['zoom'],
      11,
      14,
      32,
      60
    ];
    m.addLayer({
      id: 'zctas-label',
      type: 'symbol',
      source: 'zcta-points',
      layout: {
        'text-field': ['get', 'ZCTA5'],
        'text-font': ['Open Sans Regular'],
        'text-size': labelTextSize,
        'text-allow-overlap': false
      },
      paint: { ...labelPaint, 'text-opacity': labelTextOpacity(false, false) }
    });
    // District "26" label — shown only in the District view (council fill visible).
    m.addLayer({
      id: 'council-label',
      type: 'symbol',
      source: 'district-point',
      layout: {
        visibility: 'none',
        'text-field': ['get', 'CounDist'],
        'text-font': ['Open Sans Regular'],
        'text-size': labelTextSize
      },
      paint: labelPaint
    });
  }
</script>

<div class="map" bind:this={container} role="region" aria-label="District 26 map"></div>

<style>
  .map {
    position: absolute;
    inset: 0;
  }
  :global(.maplibregl-ctrl-attrib) {
    font-size: 10px;
  }
  /* Mobile: the bottom sheet overlays the map bottom, so lift the bottom map
     controls (attribution) to rest just above the sheet's live top edge. The
     Sidebar tracks the sheet height into --sheet-height (peek → expanded, and
     during the transition); fall back to the peek height before it's set. */
  @media (max-width: 767px) {
    :global(.maplibregl-ctrl-bottom-left),
    :global(.maplibregl-ctrl-bottom-right) {
      bottom: var(--sheet-height, var(--sheet-peek));
    }
  }
</style>
