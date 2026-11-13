<script lang="ts">
  const base = import.meta.env.BASE_URL;
</script>

<footer class="footer">
  <div class="lockup">
    <img class="cil-mark" src={`${base}cil.svg`} alt="" />
    <span class="cil-text">Civic Innovation Lab</span>
  </div>
  <img class="betanyc" src={`${base}betanyc.svg`} alt="BetaNYC" />
</footer>

<style>
  .footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
    height: 32px;
    padding: 0 var(--space-400);
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
      height: 48px;
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
