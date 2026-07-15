<script lang="ts">
  import Modal from '../primitives/Modal.svelte';
  import LayerToggleRow from '../primitives/LayerToggleRow.svelte';
  import ContextText from '../ContextText.svelte';
  import { LAYERS, type LayerDef } from '../../lib/layers';
  import { LAYERS_CONTEXT } from '../../lib/copy';
  import { visibleLayers, toggleLayer, closeModal, giFilter, setGiFilter } from '../../stores';

  // Only GI carries a filter today; its selection lives in the giFilter store.
  function filterProps(l: LayerDef, value: string) {
    if (!l.filter) return undefined;
    return {
      options: l.filter.variants.map((v) => ({ value: v.value, label: v.label })),
      value,
      onChange: setGiFilter
    };
  }

  // Mobile Layers modal (Figma 66:1716): the 11 toggle rows + context, in the
  // bottom-sheet placement. Same registry/store as the desktop bottom band.
</script>

<Modal title="Layers" placement="sheet" onClose={closeModal}>
  <div class="rows">
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
  <div class="context">
    <ContextText text={LAYERS_CONTEXT} size="caption" />
  </div>
</Modal>

<style>
  .rows {
    display: flex;
    flex-direction: column;
  }
  .context {
    margin-top: var(--space-200);
  }
</style>
