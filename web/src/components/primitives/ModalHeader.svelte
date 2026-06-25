<script lang="ts">
  import CloseIcon from '../icons/CloseIcon.svelte';

  /**
   * Modal title + ✕ close, reused by the Layers and About modals. The close
   * is a real labeled button. `titleId` lets the dialog reference the title
   * via aria-labelledby.
   */
  let {
    title,
    titleId,
    onClose
  }: {
    title: string;
    titleId?: string;
    onClose?: () => void;
  } = $props();
</script>

<div class="modal-header">
  <h2 class="title" id={titleId}>{title}</h2>
  <button type="button" class="close" aria-label="Close" onclick={onClose}>
    <CloseIcon />
  </button>
</div>

<style>
  .modal-header {
    display: flex;
    align-items: center;
    gap: var(--space-200);
    padding-block: 3.5px;
  }
  .title {
    flex: 1 0 0;
    min-width: 0;
    margin: 0;
    font-size: var(--type-body-size);
    font-weight: var(--type-small-bold-weight);
    color: var(--color-on-surface-primary);
  }
  .close {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-100);
    /* Expand the hit area without shifting layout. */
    margin: calc(-1 * var(--space-100));
    background: none;
    border: none;
    color: var(--color-on-surface-primary);
  }
  /* ≥44px touch target on coarse pointers. */
  @media (pointer: coarse) {
    .close {
      padding: 10px;
      margin: -10px;
    }
  }
</style>
