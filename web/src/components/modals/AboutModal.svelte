<script lang="ts">
  import Modal from '../primitives/Modal.svelte';
  import { closeModal } from '../../stores';

  // About modal (Figma 73:2003 desktop / 73:2099 mobile): centered on both
  // breakpoints. Copy is placeholder until the real About text is provided.
</script>

<Modal title="About" placement="centered" onClose={closeModal}>
  <div class="about">
    <p>
      The District 26 Green Infrastructure web map was developed by the <a href="https://www.beta.nyc/our-work/civic-innovation-lab/" target="_blank" rel="noopener noreferrer">Civic Innovation Lab</a> at BetaNYC for the <a href="https://council.nyc.gov/district-26/" target="_blank" rel="noopener noreferrer">Office of New York City Council Member Julie Won.</a> 
      This map brings together disparate data on green infrastructure assets, flooding, and sewer infrastructure to help the Office identify neighborhood-level patterns,
      gaps, and opportunities for future investment.
    </p>
    <p>
      Use the layer toggles to select feature layers of interest. Point locations are represented by icons on the map. 
      Click on them to view a popup with per-feature detail describing green infrastructure assets, flood-related 311 service requests filed since January 1, 2022, 
      catch basins, and combined sewer overflow outfalls. Flood-prone areas are defined by separate layers for 100- and 500-year coastal flood planes and stormwater flooding under limited and moderate rainfall events. 
      Flood-mitigating areas of permeable surfaces and tree canopy each have their own layer.
    </p>
    <p>
      Users may switch between viewing the District 26 boundary and those of overlapping neighborhoods, represented as zip codes. In the District 26 view, calculated summaries of district-wide factors related to flood risk are displayed. 
      Upon selecting a single zip code, rankings are displayed that compare these same factors to the other zip codes overlapping with the district. 
      Averages of the city's census-tract level Flood Vulnerability Index are included in the calculations and rankings but are not shown on the map;
      locations of combined sewer overflow outfalls are shown on the map but are not included in the calculations and rankings.
    </p>
    <p>
      The data used for this map are sourced from various New York City Agencies via NYC Open Data, the New York City Department of City Planning, ESRI's Federal Data Collection, the NYC Open Sewer Atlas, and the Federal Emergency Management Agency.
      Full documentation of this map's data sources and methodology can be found <a href="https://github.com/BetaNYC/d26-gi-web-map" target="_blank" rel="noopener noreferrer">on Github</a>, published alongside its open source code. 
    </p>
  </div>
</Modal>

<style>
  .about {
    display: flex;
    flex-direction: column;
    gap: var(--space-300);
    font-size: var(--type-body-size);
    line-height: 1.45;
    color: var(--color-on-surface-primary);
  }
  .about p {
    margin: 0;
  }
  .about a {
    color: var(--color-on-surface-beta-blue);
  }
</style>
