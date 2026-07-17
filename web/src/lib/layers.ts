/**
 * The toggleable map layers, in the Figma grid order (row-wise). 
 * This drives BOTH the toggle UI (label + indicator)
 * and the MapLibre source/layer creation 
 */
export type Indicator =
  | { type: 'swatch'; colorVar: string }
  | { type: 'icon'; code: string };

/**
 * A map-display filter variant (GI only): the toggle switches which underlying
 * source renders. Each variant is its own PMTiles file + source layer.
 */
export interface LayerFilterVariant {
  value: string;
  label: string;
  file: string;
  sourceLayer: string;
}

export interface LayerDef {
  id: string;
  label: string;
  indicator: Indicator;
  ranked: boolean;
  rankColumn: string | null;
  delivery: 'pmtiles' | 'cog' | 'geojson';
  file: string;
  sourceLayer?: string;
  geometry: 'point' | 'polygon' | 'raster';
  cogValue?: number;
  /** Polygon fill opacity override (default 0.5). */
  fillOpacity?: number;
  /**
   * Optional continuous COG ramp (311 Hotspots). The pixel value is the
   * pipeline-normalized density in [0,1]; stops are interpolated piecewise and
   * intensity is carried by the ramp color (pale → saturated) and rendered
   * opaque, so the layer's color is independent of any layer beneath it. When
   * set, it takes precedence over the single-value `cogValue` colorizer.
   */
  cogRamp?: {
    stops: { t: number; color: string }[];
  };
  /**
   * Optional map-display filter (GI only). Renders one map layer per variant and
   * shows the selected one; only actionable while the layer is on. Purely a
   * display concern — does NOT affect ranks (computed pipeline-side over all
   * assets). `file`/`sourceLayer` above mirror the default variant.
   */
  filter?: {
    defaultValue: string;
    variants: LayerFilterVariant[];
  };
}

export const LAYERS: LayerDef[] = [
  { id: 'gi', label: 'Green Infrastructure', indicator: { type: 'icon', code: 'GI' }, ranked: true, rankColumn: 'rank_n_gi_sqmi', delivery: 'pmtiles', file: 'gi_flood.pmtiles', sourceLayer: 'gi_flood', geometry: 'point',
    filter: {
      defaultValue: 'flood',
      variants: [
        { value: 'flood', label: 'Flood-Related', file: 'gi_flood.pmtiles', sourceLayer: 'gi_flood' },
        { value: 'all', label: 'All', file: 'gi_all.pmtiles', sourceLayer: 'gi_all' }
      ]
    } },
  { id: 'flooding_311', label: '311 Service Requests (Flooding-Related)', indicator: { type: 'icon', code: '311' }, ranked: true, rankColumn: 'rank_n_flooding_311_p10k', delivery: 'geojson', file: 'flooding_311.geojson', geometry: 'point' },
    { id: 'hotspot_311', label: 'Flood-Related 311 Hotspots', indicator: { type: 'swatch', colorVar: '--color-layer-hotspot' }, ranked: false, rankColumn: null, delivery: 'cog', file: 'hotspot_311.tif', geometry: 'raster',
    cogRamp: {
      stops: [
        { t: 0, color: '#e2dbeb' },
        { t: 0.25, color: '#decee2' },
        { t: 0.5, color: '#c3b3d4' },
        { t: 0.75, color: '#bb81b2' },
        { t: 1, color: '#b970a8' }
      ]
    } },
  { id: 'catch_basins', label: 'Catch Basins', indicator: { type: 'icon', code: 'CB' }, ranked: true, rankColumn: 'rank_n_cb_sqmi', delivery: 'pmtiles', file: 'catch_basins.pmtiles', sourceLayer: 'catch_basins', geometry: 'point' },
  { id: 'cso', label: 'Combined Sewer Overflow Outfalls', indicator: { type: 'icon', code: 'CSO' }, ranked: false, rankColumn: null, delivery: 'pmtiles', file: 'cso_outfalls.pmtiles', sourceLayer: 'cso_outfalls', geometry: 'point' },
  { id: 'fema_100', label: '100-Year Flood Plane', indicator: { type: 'swatch', colorVar: '--color-layer-100-year' }, ranked: true, rankColumn: 'rank_pct_100_year', delivery: 'pmtiles', file: 'nfhl_100yr.pmtiles', sourceLayer: 'nfhl_100yr', geometry: 'polygon' },
  { id: 'fema_500', label: '500-Year Flood Plane', indicator: { type: 'swatch', colorVar: '--color-layer-500-year' }, ranked: true, rankColumn: 'rank_pct_500_year', delivery: 'pmtiles', file: 'nfhl_500yr.pmtiles', sourceLayer: 'nfhl_500yr', geometry: 'polygon' },
  { id: 'swf_limited', label: 'Stormwater Flooding (Limited)', indicator: { type: 'swatch', colorVar: '--color-layer-limited-flood' }, ranked: true, rankColumn: 'rank_limited_swf_pct', delivery: 'pmtiles', file: 'swf_limited.pmtiles', sourceLayer: 'swf_limited', geometry: 'polygon', fillOpacity: 0.85 },
  { id: 'swf_moderate', label: 'Stormwater Flooding (Moderate)', indicator: { type: 'swatch', colorVar: '--color-layer-moderate-flood' }, ranked: true, rankColumn: 'rank_moderate_swf_pct', delivery: 'pmtiles', file: 'swf_moderate.pmtiles', sourceLayer: 'swf_moderate', geometry: 'polygon', fillOpacity: 0.65 },
  { id: 'permeable', label: 'Permeable Surfaces', indicator: { type: 'swatch', colorVar: '--color-layer-permeable-surfaces' }, ranked: true, rankColumn: 'rank_pct_permeable_surface', delivery: 'cog', file: 'permeable_surface.tif', geometry: 'raster', cogValue: 2 },
  { id: 'tree_canopy', label: 'Tree Canopy', indicator: { type: 'swatch', colorVar: '--color-layer-tree-canopy' }, ranked: true, rankColumn: 'rank_pct_tree_canopy', delivery: 'cog', file: 'tree_canopy.tif', geometry: 'raster', cogValue: 1 },
  // Sewer Areas dropped from the available layers for now (registry entry removed).
];
