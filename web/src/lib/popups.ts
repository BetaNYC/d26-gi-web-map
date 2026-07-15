/**
 * Point-layer popup field config (Figma 106:2117). One entry per attribute to
 * show, in display order: the feature-property `key`, the user-facing `label`,
 * and an optional `format` to reformat the raw value (e.g. datetimes).
 *
 * OWNER TODO: finalize the display labels, and add `format` functions where the
 * raw value needs reshaping (the 311 datetimes in particular). `formatIsoDate`
 * below is a worked example wired to the GI constructed date.
 */
export interface PopupField {
  /** feature property name (from the PMTiles / GeoJSON) */
  key: string;
  /** user-displayed attribute title */
  label: string;
  /** optional reformatter for the raw property value */
  format?: (value: unknown) => string;
}

/** Example formatter: ISO date/datetime → "YYYY-MM-DD" (matches the Figma GI row). */
export function formatIsoDate(value: unknown): string {
  return typeof value === 'string' && value.length >= 10 ? value.slice(0, 10) : '—';
}

/**
 * 311 timestamps: parse the ISO-8601 UTC value (e.g. "2025-07-15T10:47:00Z")
 * and render it as ISO date + time in Eastern Time, e.g. "2025-07-15 06:47 EDT".
 * Uses the America/New_York zone, so it's DST-aware (EST in winter, EDT in
 * summer) — the correct NYC wall-clock time. Empty/invalid → em dash.
 *
 * To force a fixed EST (UTC−5) year-round instead, swap timeZone to a fixed
 * offset; America/New_York is preferred so displayed times match local NYC time.
 */
const EASTERN_FMT = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'America/New_York',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
  timeZoneName: 'short'
});

export function formatEastern(value: unknown): string {
  if (typeof value !== 'string' || value.length < 10) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  const parts = EASTERN_FMT.formatToParts(d);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')} ${get('hour')}:${get('minute')} ${get('timeZoneName')}`;
}

/** Per-layer popup fields, keyed by lib/layers.ts layer id. */
export const POPUP_FIELDS: Record<string, PopupField[]> = {
  // Green Infrastructure (gi_flood / gi_all): asset_type, constructed_date
  gi: [
    { key: 'asset_type', label: 'Asset Type' },
    { key: 'constructed_date', label: 'Constructed Date', format: formatIsoDate }
  ],
  // Catch Basins (catch_basins): unitid
  catch_basins: [
    { key: 'unitid', label: 'Unit ID' }
  ],
  // 311 (flooding_311.geojson): descriptor, agency, created_date, closed_date
  flooding_311: [
    { key: 'descriptor', label: 'Descriptor' },
    { key: 'agency', label: 'Agency' },
    { key: 'created_date', label: 'Opened', format: formatEastern },
    { key: 'closed_date', label: 'Closed', format: formatEastern }
  ],
  // CSO Outfalls (cso_outfalls): Waterbody, Waterbod_1
  cso: [
    { key: 'Waterbody', label: 'Waterbody' },
    { key: 'Waterbod_1', label: 'Waterbody (Secondary)' }
  ]
};

/** Map a feature's properties through the layer's config into displayable rows. */
export function buildPopupRows(
  layerId: string,
  props: Record<string, unknown>
): { label: string; value: string }[] {
  const fields = POPUP_FIELDS[layerId] ?? [];
  return fields.map((f) => {
    const raw = props[f.key];
    const value = f.format ? f.format(raw) : raw == null || raw === '' ? '—' : String(raw);
    return { label: f.label, value };
  });
}
