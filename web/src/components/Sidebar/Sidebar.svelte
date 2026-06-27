<script lang="ts">
  import TabBar from '../primitives/TabBar.svelte';
  import DistrictView from './DistrictView.svelte';
  import ZipListView from './ZipListView.svelte';
  import ZipDetailView from './ZipDetailView.svelte';
  import { onMount } from 'svelte';
  import { view, selectTab } from '../../stores';

  /**
   * Responsive sidebar: "same content, different container." Desktop = a
   * pinned top-left 320px panel (node 40:551); mobile = a bottom sheet with a
   * drag handle and peek/expanded states.
   *
   * Desktop sizing: the `.sidebar-anchor` is absolutely positioned with both top
   * and bottom set, so it has a DEFINITE height that recomputes cleanly on window
   * resize. The panel is an in-flow flex child that hugs its content, but caps +
   * scrolls (via the inner `.scroll`) when content exceeds the anchor — and
   * re-expands when the window grows. (A percentage max-height on the abspos panel
   * itself failed to re-expand after a resize in Chromium.) The anchor is
   * pointer-events:none so the empty area below the hugged panel doesn't block the map.
   *
   * Layout: a FROZEN header (drag handle + Tab Bar) over a SCROLL area (the view).
   * `sheetExpanded` is local UI state so peek/expanded persists across tab switches.
   */
  let sheetExpanded = $state(false);

  // Mobile bottom-sheet drag: drag the handle to resize the sheet, snapping to
  // peek/expanded on release. A tap (or keyboard activation) still toggles, and
  // drag is mobile-only. dragHeight overrides the class height while dragging.
  const PEEK_PX = 120; // keep in sync with --sheet-peek
  const EXPANDED_FRAC = 0.7; // matches .is-expanded height: 70%
  let dragHeight = $state<number | null>(null);
  let dragging = $state(false);
  let suppressClick = false;
  let dragStartY = 0;
  let dragStartH = 0;
  let dragMoved = false;

  function stageHeight(): number {
    return (sheetEl?.offsetParent as HTMLElement | null)?.clientHeight ?? window.innerHeight;
  }

  function onHandlePointerDown(e: PointerEvent) {
    if (window.innerWidth >= 768 || !sheetEl) return;
    dragging = true;
    dragMoved = false;
    dragStartY = e.clientY;
    dragStartH = sheetEl.offsetHeight;
    (e.currentTarget as Element).setPointerCapture(e.pointerId);
  }
  function onHandlePointerMove(e: PointerEvent) {
    if (!dragging) return;
    const dy = dragStartY - e.clientY; // drag up = grow
    if (Math.abs(dy) > 4) dragMoved = true;
    dragHeight = Math.max(PEEK_PX, Math.min(stageHeight() * 0.85, dragStartH + dy));
  }
  function onHandlePointerUp() {
    if (!dragging) return;
    dragging = false;
    if (dragMoved) {
      const mid = (PEEK_PX + stageHeight() * EXPANDED_FRAC) / 2;
      sheetExpanded = (dragHeight ?? PEEK_PX) >= mid;
      suppressClick = true; // a click fires after the drag; ignore it
    }
    dragHeight = null;
  }
  function onHandleClick() {
    if (suppressClick) {
      suppressClick = false;
      return;
    }
    sheetExpanded = !sheetExpanded;
  }

  const tabs = [
    { id: 'district', label: 'District 26' },
    { id: 'zip', label: 'Zip Codes' }
  ];
  let activeTab = $derived($view === 'district' ? 'district' : 'zip');

  // ARIA tabs linkage: the panel id + the active tab's element id.
  const PANEL_ID = 'sidebar-tabpanel';
  let activeTabElId = $derived(`${PANEL_ID}-tab-${activeTab}`);

  // Track the sheet's live height in --sheet-height (on :root) so the map's
  // bottom controls (attribution) can rest just above the sheet's top edge as it
  // moves between peek and expanded — including during the transition. Only used
  // by the mobile media query in Map.svelte; ignored on desktop.
  let sheetEl = $state<HTMLElement>();
  // Measure the scroll area's actually-reserved scrollbar gutter (offsetWidth -
  // clientWidth: 0 on overlay-scrollbar systems, ~15px with classic scrollbars,
  // and it can differ by input device on macOS). The right-padding compensation
  // subtracts this, so a hardcoded guess is wrong for whichever scrollbar type
  // the device isn't — measuring makes the content edge line up in every case.
  // scrollbar-gutter: stable keeps this value constant whether or not scrolling.
  let scrollEl = $state<HTMLElement>();
  function measureGutter() {
    if (scrollEl) {
      scrollEl.style.setProperty('--scrollbar-gutter-w', `${scrollEl.offsetWidth - scrollEl.clientWidth}px`);
    }
  }
  onMount(() => {
    measureGutter();
    if (!sheetEl) return;
    const ro = new ResizeObserver(() => {
      document.documentElement.style.setProperty('--sheet-height', `${sheetEl!.offsetHeight}px`);
      measureGutter();
    });
    ro.observe(sheetEl);
    return () => {
      ro.disconnect();
      document.documentElement.style.removeProperty('--sheet-height');
    };
  });
</script>

<div class="sidebar-anchor">
  <aside
    class="sidebar"
    class:is-expanded={sheetExpanded}
    class:is-dragging={dragging}
    style:height={dragHeight != null ? `${dragHeight}px` : null}
    bind:this={sheetEl}
  >
    <div class="sheet-header">
      <button
        type="button"
        class="handle"
        aria-label={sheetExpanded ? 'Collapse panel' : 'Expand panel'}
        aria-expanded={sheetExpanded}
        onclick={onHandleClick}
        onpointerdown={onHandlePointerDown}
        onpointermove={onHandlePointerMove}
        onpointerup={onHandlePointerUp}
        onpointercancel={onHandlePointerUp}
      >
        <span class="handle-bar" aria-hidden="true"></span>
      </button>
      <TabBar
        {tabs}
        selected={activeTab}
        panelId={PANEL_ID}
        onChange={(id) => selectTab(id as 'district' | 'zip')}
      />
    </div>

    <div class="scroll" bind:this={scrollEl}>
      <div class="views" role="tabpanel" id={PANEL_ID} aria-labelledby={activeTabElId} tabindex={0}>
        {#if $view === 'district'}
          <DistrictView />
        {:else if $view === 'zip-list'}
          <ZipListView />
        {:else}
          <ZipDetailView />
        {/if}
      </div>
    </div>
  </aside>
</div>

<style>
  /* Mobile: the anchor is a transparent passthrough — the sheet positions itself
     against the stage. */
  .sidebar-anchor {
    display: contents;
  }

  .sidebar {
    position: absolute;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    background: var(--color-surface-base);
    /* Subtracted from the scroll area's right padding to compensate for the
       reserved scrollbar gutter, so its content right edge lines up with the
       frozen header and the body gutter. The real value depends on scrollbar
       type (0 overlay, ~15px classic) so it's MEASURED at runtime and set inline
       on .scroll (see measureGutter). This is only the pre-measurement fallback —
       0 assumes overlay (full padding), the safe default for the common case. */
    --scrollbar-gutter-w: 0px;
  }

  /* Mobile = bottom sheet, sized by height so it never covers the footer. */
  .sidebar {
    left: 0;
    right: 0;
    bottom: 0;
    /* --sheet-peek is defined in app.css :root (shared with the map controls). */
    --pad-l: var(--space-400);
    --pad-r: var(--space-400);
    height: var(--sheet-peek);
    border-radius: 12px 12px 0 0;
    transition: height 0.25s ease;
  }
  @media (prefers-reduced-motion: reduce) {
    .sidebar {
      transition: none;
    }
  }
  /* Follow the finger instantly while dragging (snap animates on release). */
  .sidebar.is-dragging {
    transition: none;
  }
  .sidebar.is-expanded {
    height: 60%;
  }

  /* Frozen header: drag handle + Tab Bar. Does not scroll. */
  .sheet-header {
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    padding-left: var(--pad-l);
    padding-right: var(--pad-r);
  }
  .handle {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    min-height: 44px;
    padding: var(--space-300) 0 var(--space-200);
    background: none;
    border: none;
    /* Vertical drag should resize the sheet, not scroll the page. */
    touch-action: none;
  }
  .handle-bar {
    width: 36px;
    height: 4px;
    border-radius: 2px;
    background: var(--color-rank-empty);
  }

  /* Scrollable content area. scrollbar-gutter: stable reserves the scrollbar
     space permanently so the content width is constant whether or not the
     scrollbar is shown — without it, the scrollbar's width change reflows the
     wrapping text (long labels, context paragraph) taller and the panel never
     re-expands after a resize (the zip-list, with no wrapping content, was immune). */
  .scroll {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    scrollbar-gutter: stable;
    padding-left: var(--pad-l);
    /* gutter + this padding == the header's full --pad-r, so content right edges
       align and the rows keep Figma's content width. */
    padding-right: max(0px, calc(var(--pad-r) - var(--scrollbar-gutter-w)));
    padding-top: var(--space-100);
    padding-bottom: var(--space-400);
  }
  .views {
    display: flex;
    flex-direction: column;
    gap: var(--space-100);
  }

  /* Desktop = pinned 320px panel, flush to the top-left gutter, space/400 below
     the top. The anchor owns the definite height; the panel hugs/caps within it. */
  @media (min-width: 768px) {
    .sidebar-anchor {
      display: flex;
      flex-direction: column;
      position: absolute;
      top: var(--space-400);
      left: 0;
      bottom: 0;
      width: 320px;
      pointer-events: none;
    }
    .sidebar {
      position: static;
      width: 100%;
      /* Hug content (grow:0), shrink + scroll when capped, re-expand on grow. */
      flex: 0 1 auto;
      min-height: 0;
      max-height: 100%;
      height: auto;
      transition: none;
      border-radius: 1px;
      pointer-events: auto;
      /* No left padding (Figma 40:551); right padding matches the .body desktop
         gutter (--space-400, 16px in App.svelte) so the content's left and right
         margins read symmetric. (Figma noted pr 20px, but that left a ~4px
         asymmetry against the 16px body gutter.) */
      --pad-l: 0px;
      --pad-r: var(--space-400);
      /* --scrollbar-gutter-w is measured at runtime (see measureGutter), so no
         static desktop override here. */
    }
    /* Ignore the mobile expanded height if it lingers after a mobile→desktop resize. */
    .sidebar.is-expanded {
      height: auto;
    }
    .handle {
      display: none;
    }
    .sheet-header {
      padding-top: 6px;
    }
    .scroll {
      flex: 1 1 auto;
      padding-bottom: 4px;
    }
  }
</style>
