<script lang="ts">
  import LayerToggleRow from './primitives/LayerToggleRow.svelte';
  import ContextText from './ContextText.svelte';
  import { LAYERS, type LayerDef } from '../lib/layers';
  import { LAYERS_CONTEXT } from '../lib/copy';
  import { visibleLayers, toggleLayer, giFilter, setGiFilter } from '../stores';

  // Only GI carries a filter today; its selection lives in the giFilter store.
  function filterProps(l: LayerDef, value: string) {
    if (!l.filter) return undefined;
    return {
      options: l.filter.variants.map((v) => ({ value: v.value, label: v.label })),
      value,
      onChange: setGiFilter
    };
  }

  /**
   * Desktop bottom band: context paragraph (left) + the 11-layer toggle
   * grid (4 cols × 3 rows, row-wise). Driven by the lib/layers.ts registry and
   * the shared visibleLayers store (so the map and the toggles stay in sync).
   * On mobile this is replaced by the FAB + layers modal.
   */
</script>

<div class="bottom-band">
  <div class="context">
    <ContextText text={LAYERS_CONTEXT} size="caption" />
  </div>
  <div class="grid">
    {#each LAYERS as l (l.id)}
      <LayerToggleRow
        label={l.label}
        indicator={l.indicator.type === 'swatch'
          ? { type: 'swatch', color: `var(${l.indicator.colorVar})` }
          : l.indicator}
        on={$visibleLayers.has(l.id)}
        onToggle={() => toggleLayer(l.id)}
        filter={filterProps(l, $giFilter)}
      />
    {/each}
  </div>
</div>

<style>
  .bottom-band {
    display: flex;
    gap: var(--space-400);
    align-items: flex-start;
  }
  .context {
    flex-shrink: 0;
    width: 320px;
  }
  .grid {
    flex: 1;
    /* min-width:0 lets the grid shrink to its flex allotment instead of forcing
       the band (and the whole page) wider than the map; the grid itself scrolls
       horizontally when the 4 columns don't fit. Only this div scrolls. */
    min-width: 0;
    overflow-x: auto;
    overflow-y: hidden;
    display: grid;
    /* Track min sized so the widest row — GI, with its Flood-Related/All filter
       — fits on one line without overflowing; narrower windows scroll the grid
       (below) rather than clip. Tunable. */
    grid-template-columns: repeat(4, minmax(270px, 1fr));
    column-gap: var(--space-200);
  }
</style>
