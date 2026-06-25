<script lang="ts">
  import Button from './primitives/Button.svelte';
  import ExternalLinkIcon from './icons/ExternalLinkIcon.svelte';
  import MenuIcon from './icons/MenuIcon.svelte';
  import MenuCloseIcon from './icons/MenuCloseIcon.svelte';

  /*
   * Desktop: full title + About button + Github link (always).
   * Mobile: Default variant (Figma 70:1782) = short title + hamburger;
   *         Tapped variant (Figma 70:1784) = About (left) · Github (center) · ✕ (right).
   * Tapping the hamburger swaps Default → Tapped; ✕ (or Escape) swaps back.
   * The hamburger is mobile-only, so `tapped` is only reachable below the
   * breakpoint; it's cleared if the viewport crosses to desktop.
   */
  let {
    onAbout,
    githubUrl = 'https://github.com/BetaNYC/d26-gi-web-map'
  }: {
    onAbout?: () => void;
    githubUrl?: string;
  } = $props();

  let tapped = $state(false);

  function close() {
    tapped = false;
  }
  function onResize() {
    if (window.innerWidth >= 768) tapped = false;
  }
  function onKey(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }
</script>

<svelte:window onresize={onResize} onkeydown={onKey} />

<header class="header" class:is-tapped={tapped}>
  {#if tapped}
    <Button label="About" onclick={() => { close(); onAbout?.(); }} />
    <a class="gh-link gh-link--center" href={githubUrl} target="_blank" rel="noopener noreferrer">
      Github
      <ExternalLinkIcon />
    </a>
    <button type="button" class="icon-btn" aria-label="Close menu" aria-expanded="true" onclick={close}>
      <MenuCloseIcon />
    </button>
  {:else}
    <h1 class="title title--desktop">District 26 Green Infrastructure</h1>
    <h1 class="title title--mobile">D26 Green Infrastructure</h1>

    <div class="actions">
      <Button label="About" onclick={onAbout} />
      <a class="gh-link" href={githubUrl} target="_blank" rel="noopener noreferrer">
        Github
        <ExternalLinkIcon />
      </a>
    </div>

    <button
      type="button"
      class="icon-btn menu-open"
      aria-label="Open menu"
      aria-expanded="false"
      onclick={() => (tapped = true)}
    >
      <MenuIcon />
    </button>
  {/if}
</header>

<style>
  .header {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    height: 56px;
    padding: 0 var(--space-400);
  }
  .is-tapped {
    padding: 0 13.5px;
  }

  .title {
    margin: 0;
    font-size: var(--type-title-size);
    font-weight: var(--type-title-weight);
    letter-spacing: var(--type-title-tracking);
    white-space: nowrap;
  }
  .title--desktop { display: none; }
  .title--mobile { display: block; }

  .actions { display: none; }
  .gh-link {
    display: inline-flex;
    align-items: center;
    gap: var(--space-25);
    padding: 8px 6px;
    border-radius: 3px;
    text-decoration: none;
    font-size: var(--type-body-size);
    color: var(--color-on-surface-primary);
  }
  .gh-link:hover {
    background: color-mix(in srgb, var(--color-on-surface-primary) 6%, var(--color-surface-base));
  }
  /* The icon centers to the line box, but AUTHENTIC Sans's glyphs sit ~0.1em
     above it (typo asc/desc 776/-224, cap 752), so the icon reads low against
     the text. Lift it to the text's cap-height center. translateY keeps layout
     (and the flex gap) intact. */
  .gh-link :global(svg) {
    transform: translateY(-0.1em);
  }
  /* Tapped variant: Github is absolutely centered in the bar. */
  .gh-link--center {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
  }

  .icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-100);
    background: none;
    border: none;
    color: var(--color-on-surface-primary);
  }
  @media (pointer: coarse) {
    .icon-btn {
      min-width: 44px;
      min-height: 44px;
    }
  }

  @media (min-width: 768px) {
    .header { height: 48px; }
    .title--desktop { display: block; }
    .title--mobile { display: none; }
    .actions { display: flex; align-items: center; gap: var(--space-100); }
    .icon-btn.menu-open { display: none; }
  }
</style>
