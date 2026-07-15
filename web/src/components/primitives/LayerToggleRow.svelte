<script lang="ts">
  /**
   * A layer on/off control. Real <button> with aria-pressed.
   *
   * Indicator: polygon/raster layers show a color *swatch* (the layer's
   * accent token, shared with the MapLibre paint); point layers show a 2-char
   * *icon* code in the mono icon font.
   *
   * Optional `filter` (GI only): a "Flood-Related / All" control that switches
   * which map source renders. It appears only while the layer is on (the switch
   * is meaningless with nothing on the map). The whole control is one button —
   * clicking anywhere in it toggles to the other option; the highlighted label
   * shows the current one. Both the on/off button and the filter are real,
   * focusable buttons, so keyboard operation (Tab + Enter/Space) is preserved.
   */
  type Indicator =
    | { type: 'swatch'; color: string }
    | { type: 'icon'; code: string };

  type Filter = {
    options: { value: string; label: string }[];
    value: string;
    onChange: (value: string) => void;
  };

  let {
    label,
    indicator,
    on = false,
    onToggle,
    filter
  }: {
    label: string;
    indicator: Indicator;
    on?: boolean;
    onToggle?: () => void;
    filter?: Filter;
  } = $props();

  const activeLabel = $derived(
    filter?.options.find((o) => o.value === filter.value)?.label ?? ''
  );

  /** Advance to the next option (a plain toggle for the two-option GI filter). */
  function cycleFilter() {
    if (!filter) return;
    const i = filter.options.findIndex((o) => o.value === filter.value);
    const next = filter.options[(i + 1) % filter.options.length];
    filter.onChange(next.value);
  }
</script>

{#snippet body()}
  {#if indicator.type === 'swatch'}
    <span class="indicator swatch" style="background: {indicator.color};" aria-hidden="true"></span>
  {:else}
    <span class="indicator icon" aria-hidden="true">{indicator.code}</span>
  {/if}
  <span class="label">{label}</span>
{/snippet}

{#if filter}
  <div class="layer-toggle-row">
    <button
      type="button"
      class="toggle-btn"
      class:is-on={on}
      aria-pressed={on}
      onclick={onToggle}
    >
      {@render body()}
    </button>
    {#if on}
      <button
        type="button"
        class="filter-selection"
        aria-label="Toggle {label} filter (currently {activeLabel})"
        onclick={cycleFilter}
      >
        {#each filter.options as opt (opt.value)}
          <span class="filter-tab" class:is-active={filter.value === opt.value}>{opt.label}</span>
        {/each}
      </button>
    {/if}
  </div>
{:else}
  <button
    type="button"
    class="layer-toggle"
    class:is-on={on}
    aria-pressed={on}
    onclick={onToggle}
  >
    {@render body()}
  </button>
{/if}

<style>
  .layer-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-100);
    width: 100%;
    padding: var(--space-50) var(--space-100) var(--space-100) 0;
    background: var(--color-surface-base);
    border: none;
    border-bottom: 0.5px solid var(--color-on-surface-primary);
    text-align: left;
  }
  /* Filter-row variant (GI): the on/off button and the segmented filter share
     one row; the divider + surface live on the row, and only the icon+label
     region toggles the layer. */
  .layer-toggle-row {
    display: flex;
    align-items: center;
    width: 100%;
    background: var(--color-surface-base);
    border-bottom: 0.5px solid var(--color-on-surface-primary);
  }
  .toggle-btn {
    display: flex;
    align-items: center;
    gap: var(--space-100);
    padding: var(--space-50) var(--space-100) var(--space-100) 0;
    background: none;
    border: none;
    text-align: left;
  }
  .indicator {
    flex-shrink: 0;
    width: 16px;
    height: 16px;
    opacity: 0.35;
  }
  .swatch {
    border-radius: 2px;
  }
  .icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border: 0.5px solid var(--color-on-surface-primary);
    border-radius: 1px;
    font-family: var(--font-family-icon);
    font-style: italic;
    font-size: 8.5px;
    line-height: 0;
    color: var(--color-on-surface-primary);
  }
  .label {
    font-size: var(--type-small-size);
    font-weight: var(--type-small-weight);
    color: var(--color-on-surface-primary);
    white-space: nowrap;
  }

  .is-on .indicator {
    opacity: 1;
  }
  .is-on .label {
    font-weight: var(--type-small-bold-weight);
  }

  /* Segmented "Flood-Related / All" filter: active tab is bold + primary;
     inactive is regular weight + the muted rank-empty gray (Figma 142:583/635). */
  .filter-selection {
    display: flex;
    align-items: center;
    gap: var(--space-200);
    /* Match the toggle-btn's vertical padding so the filter text line centers at
       the same height as the label (the row centers each child box separately). */
    padding: var(--space-50) var(--space-300) var(--space-100) var(--space-600);
    background: none;
    border: none;
    cursor: pointer;
  }
  .filter-tab {
    padding: var(--space-25) 0;
    font-size: var(--type-small-size);
    font-weight: var(--type-small-weight);
    color: var(--color-rank-empty);
    white-space: nowrap;
  }
  .filter-tab.is-active {
    font-weight: var(--type-small-bold-weight);
    color: var(--color-on-surface-primary);
  }

  /* ≥44px touch target on coarse pointers (mobile layer rows). */
  @media (pointer: coarse) {
    .layer-toggle,
    .layer-toggle-row {
      min-height: 44px;
    }
    .toggle-btn,
    .filter-selection {
      min-height: 44px;
    }
  }
</style>
