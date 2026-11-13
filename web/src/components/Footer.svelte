<script lang="ts">
  const base = import.meta.env.BASE_URL;
</script>

<footer class="footer">
  <div class="lockup">
    <img class="cil-mark" src={`${base}cil.svg`} alt="" />
    <span class="cil-text">Civic Innovation Lab</span>
  </div>
  <a class="changes" href={`${base}whats-changed.html`}>What's changed</a>
  <img class="betanyc" src={`${base}betanyc.svg`} alt="BetaNYC" />
</footer>

<style>
  .footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    gap: var(--space-200);
    /* min-height, not height: the What's changed link is a 44px tap target. */
    min-height: 44px;
    padding: 0 var(--space-400);
  }
  /* What's changed page (BetaNYC's What's changed standard), built into public/. */
  .changes {
    display: inline-flex;
    align-items: center;
    min-height: 44px;
    font-size: var(--type-small-size);
    color: var(--color-on-surface-primary);
    text-decoration: underline;
    white-space: nowrap;
  }
  .changes:focus-visible {
    outline: 3px solid #2359a8;
    outline-offset: 2px;
  }
  .lockup {
    display: flex;
    align-items: center;
    gap: var(--space-200);
  }
  .cil-mark {
    display: block;
    height: 12px;
    width: auto;
  }
  .cil-text {
    font-size: var(--type-small-size);
    color: var(--color-on-surface-primary);
  }
  .betanyc {
    display: block;
    height: 20px;
    width: auto;
  }
  @media (min-width: 768px) {
    .footer {
      min-height: 48px;
    }
    .changes {
      font-size: var(--type-body-size);
    }
    .cil-mark {
      height: 16px;
    }
    /* body/default per Figma CIL Lockup (40:603). */
    .cil-text {
      font-size: var(--type-body-size);
    }
    .betanyc {
      height: 28px;
    }
  }
</style>
