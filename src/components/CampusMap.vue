<template>
  <div class="campus-container">
    <!-- 3D Isometric Hospital Campus Map Background -->
    <img src="../assets/campus_3d.png" alt="医院全景三维孪生地图" class="campus-bg-img" />

    <!-- Pulse beacon for Emergency Center (急诊中心留观超时) -->
    <div class="emergency-beacon" title="急诊留观超时预警">
      <div class="beacon-circle animate-beacon"></div>
      <div class="beacon-center"></div>
    </div>

    <!-- Interactive Hotspots for the 4 Main Buildings with Tooltip / Highlight -->
    <!-- 1. 外科楼 -->
    <div
      class="interactive-hotspot hotspot-surgery"
      @mouseenter="hoveredBuilding = 'surgery'"
      @mouseleave="hoveredBuilding = ''"
    >
      <div v-if="hoveredBuilding === 'surgery'" class="hotspot-glow glow-amber"></div>
    </div>

    <!-- 2. 门诊楼 -->
    <div
      class="interactive-hotspot hotspot-outpatient"
      @mouseenter="hoveredBuilding = 'outpatient'"
      @mouseleave="hoveredBuilding = ''"
    >
      <div v-if="hoveredBuilding === 'outpatient'" class="hotspot-glow glow-cyan"></div>
    </div>

    <!-- 3. 急诊楼 -->
    <div
      class="interactive-hotspot hotspot-emergency"
      @mouseenter="hoveredBuilding = 'emergency'"
      @mouseleave="hoveredBuilding = ''"
    >
      <div v-if="hoveredBuilding === 'emergency'" class="hotspot-glow glow-red"></div>
    </div>

    <!-- 4. 医技楼 -->
    <div
      class="interactive-hotspot hotspot-tech"
      @mouseenter="hoveredBuilding = 'tech'"
      @mouseleave="hoveredBuilding = ''"
    >
      <div v-if="hoveredBuilding === 'tech'" class="hotspot-glow glow-green"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const hoveredBuilding = ref('')
</script>

<style scoped>
.campus-container {
  position: relative;
  width: 100%;
  height: 746px;
  overflow: hidden;
  border-radius: 6px;
  border: 1px solid rgba(28, 76, 132, 0.6);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.45);
  background: #021428;
}

.campus-bg-img {
  width: 100%;
  height: 100%;
  object-fit: fill;
  display: block;
}

/* Emergency siren pulsing beacon positioned directly on the siren icon */
.emergency-beacon {
  position: absolute;
  top: 241px;
  left: 733px;
  width: 24px;
  height: 24px;
  pointer-events: none;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 20;
}

.beacon-center {
  width: 8px;
  height: 8px;
  background-color: #ff334b;
  border-radius: 50%;
  box-shadow: 0 0 8px #ff334b;
}

.beacon-circle {
  position: absolute;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: 2px solid #ff4d4f;
  background: rgba(255, 77, 79, 0.3);
}

@keyframes beacon-pulse {
  0% {
    transform: scale(0.6);
    opacity: 1;
  }
  100% {
    transform: scale(2.2);
    opacity: 0;
  }
}

.animate-beacon {
  animation: beacon-pulse 1.8s cubic-bezier(0, 0.2, 0.8, 1) infinite;
}

/* Hotspots */
.interactive-hotspot {
  position: absolute;
  cursor: pointer;
  z-index: 15;
  border-radius: 8px;
}

.hotspot-surgery {
  top: 50px;
  left: 350px;
  width: 220px;
  height: 120px;
}

.hotspot-outpatient {
  top: 210px;
  left: 130px;
  width: 220px;
  height: 100px;
}

.hotspot-emergency {
  top: 160px;
  left: 700px;
  width: 180px;
  height: 130px;
}

.hotspot-tech {
  top: 380px;
  left: 600px;
  width: 200px;
  height: 110px;
}

.hotspot-glow {
  width: 100%;
  height: 100%;
  border-radius: 8px;
  animation: hotspot-fade 0.3s ease-in-out;
}

.glow-amber {
  box-shadow: 0 0 20px 4px rgba(255, 183, 3, 0.5);
  background: rgba(255, 183, 3, 0.08);
}

.glow-cyan {
  box-shadow: 0 0 20px 4px rgba(0, 210, 255, 0.5);
  background: rgba(0, 210, 255, 0.08);
}

.glow-red {
  box-shadow: 0 0 20px 4px rgba(255, 77, 79, 0.6);
  background: rgba(255, 77, 79, 0.12);
}

.glow-green {
  box-shadow: 0 0 20px 4px rgba(0, 230, 153, 0.5);
  background: rgba(0, 230, 153, 0.08);
}

@keyframes hotspot-fade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
</style>
