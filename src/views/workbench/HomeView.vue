<template>
  <div class="home-page">
    <!-- Hero Banner -->
    <WorkbenchHero />

    <!-- KPI Cards Row (5 columns) -->
    <WorkbenchKpiCards />

    <!-- Middle Section (Charts & Operations) -->
    <section class="workbench-mid-grid">
      <TrendChartCard class="mid-trend-col" />
      <DepartmentTop10Card class="mid-top10-col" />
      <KeyIndicatorsCard class="mid-indicators-col" />
    </section>

    <!-- Bottom Section (Supervision & Collaboration) -->
    <section class="workbench-bottom-grid">
      <WorkProgressCard />
      <RiskAlertsCard />
      <NoticesTodosCard />
    </section>
  </div>
</template>

<script setup lang="ts">
import WorkbenchHero from '../../components/workbench/WorkbenchHero.vue'
import WorkbenchKpiCards from '../../components/workbench/WorkbenchKpiCards.vue'
import TrendChartCard from '../../components/workbench/TrendChartCard.vue'
import DepartmentTop10Card from '../../components/workbench/DepartmentTop10Card.vue'
import KeyIndicatorsCard from '../../components/workbench/KeyIndicatorsCard.vue'
import WorkProgressCard from '../../components/workbench/WorkProgressCard.vue'
import RiskAlertsCard from '../../components/workbench/RiskAlertsCard.vue'
import NoticesTodosCard from '../../components/workbench/NoticesTodosCard.vue'
</script>

<style scoped>
.home-page {
  display: flex;
  flex-direction: column;
  gap: var(--wb-gap);
}

.workbench-mid-grid {
  display: grid;
  grid-template-columns: 1.7fr 1.05fr 0.95fr;
  gap: var(--wb-gap);
  align-items: stretch;
}

.workbench-bottom-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--wb-gap);
  align-items: stretch;
}
</style>
