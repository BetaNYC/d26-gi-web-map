<script lang="ts">
  /**
   * Bordered text button.
   */
  let {
    label,
    onclick,
    type = 'button'
  }: {
    label: string;
    onclick?: () => void;
    type?: 'button' | 'submit';
  } = $props();
</script>

<button {type} class="border-button" {onclick}>{label}</button>

<style>
  .border-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    /* AUTHENTIC Sans sits ~0.1em above its line-box center (typo asc/desc
       776/-224, cap 752 @ 1000upm), so a flex-centered label reads high. Bias
       the vertical padding down ~1.4px (total 16px unchanged) to optically
       center it within the outline. */
    padding: 9.4px 6px 6.6px;
    border: 0.75px solid var(--color-on-surface-primary);
    border-radius: 3px;
    background: var(--color-surface-base);
    font-size: var(--type-body-size);
    color: var(--color-on-surface-primary);
    white-space: nowrap;
  }
  /* Inferred states (not in Figma). */
  .border-button:hover {
    background: color-mix(in srgb, var(--color-on-surface-primary) 6%, var(--color-surface-base));
  }
  .border-button:active {
    background: color-mix(in srgb, var(--color-on-surface-primary) 12%, var(--color-surface-base));
  }
</style>
