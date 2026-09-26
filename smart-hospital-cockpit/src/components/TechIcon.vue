<template>
  <svg
    :viewBox="viewBox"
    :width="size"
    :height="size"
    class="tech-icon-svg"
    :class="customClass"
    fill="none"
    stroke="currentColor"
    stroke-linecap="round"
    stroke-linejoin="round"
  >
    <!-- Hospital Building with Cross -->
    <g v-if="name === 'hospital'">
      <path d="M3 21h18M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16" stroke-width="2" />
      <path d="M9 21v-4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4" stroke-width="2" />
      <path d="M12 7v6M9 10h6" stroke-width="2.5" stroke="#00b4d8" />
    </g>

    <!-- Hospital Bed -->
    <g v-else-if="name === 'bed'">
      <path d="M2 4v16M2 12h18a2 2 0 0 1 2 2v6" stroke-width="2" />
      <path d="M2 8h8a2 2 0 0 1 2 2v2H2V8z" fill="currentColor" fill-opacity="0.2" stroke-width="2" />
      <circle cx="6" cy="10" r="1.5" fill="currentColor" />
    </g>

    <!-- Stethoscope / Clinic -->
    <g v-else-if="name === 'stethoscope'">
      <path d="M4.5 3v5a5.5 5.5 0 0 0 11 0V3" stroke-width="2" />
      <path d="M3 3h3M14 3h3" stroke-width="2" />
      <path d="M10 13.5V17a3 3 0 0 0 3 3h3a2 2 0 0 0 2-2v-1" stroke-width="2" />
      <circle cx="18" cy="15" r="2" fill="currentColor" fill-opacity="0.3" stroke-width="2" />
    </g>

    <!-- Dormitory Building -->
    <g v-else-if="name === 'dorm'">
      <rect x="4" y="3" width="16" height="18" rx="1" stroke-width="2" />
      <path d="M8 7h2M14 7h2M8 11h2M14 11h2M8 15h2M14 15h2M10 21v-3h4v3" stroke-width="2" />
    </g>

    <!-- Ambulance / Emergency -->
    <g v-else-if="name === 'ambulance'">
      <rect x="2" y="7" width="14" height="10" rx="1" stroke-width="2" />
      <path d="M16 10h4l2 3v4h-6v-7z" stroke-width="2" />
      <circle cx="6" cy="18" r="2" stroke-width="2" />
      <circle cx="18" cy="18" r="2" stroke-width="2" />
      <path d="M9 10v4M7 12h4" stroke-width="2" stroke="#00b4d8" />
    </g>

    <!-- Parking P -->
    <g v-else-if="name === 'parking'">
      <rect x="3" y="3" width="18" height="18" rx="3" stroke-width="2" fill="#00b4d8" fill-opacity="0.15" />
      <path d="M9 17V7h4a3 3 0 0 1 0 6H9" stroke-width="2.5" />
    </g>

    <!-- ECG Wave -->
    <g v-else-if="name === 'ecg'">
      <polyline points="2 12 6 12 9 5 13 19 16 10 18 14 20 12 22 12" stroke-width="2.2" />
    </g>

    <!-- Network 3-Node (Emergency Network) -->
    <g v-else-if="name === 'node'">
      <circle cx="6" cy="6" r="3" stroke-width="2" />
      <circle cx="18" cy="6" r="3" stroke-width="2" />
      <circle cx="12" cy="18" r="3" stroke-width="2" />
      <line x1="8.5" y1="7.5" x2="15.5" y2="7.5" stroke-width="2" />
      <line x1="7.5" y1="8.5" x2="10.5" y2="15.5" stroke-width="2" />
      <line x1="16.5" y1="8.5" x2="13.5" y2="15.5" stroke-width="2" />
    </g>

    <!-- Chemistry Flask / Lab -->
    <g v-else-if="name === 'flask'">
      <path d="M10 2v5L4 18a2 2 0 0 0 1.7 3h12.6a2 2 0 0 0 1.7-3L14 7V2h-4z" stroke-width="2" />
      <line x1="9" y1="2" x2="15" y2="2" stroke-width="2" />
      <path d="M7 16h10" stroke-width="1.5" stroke="#00b4d8" />
    </g>

    <!-- Water Drop -->
    <g v-else-if="name === 'water'">
      <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" stroke-width="2" fill="currentColor" fill-opacity="0.2" />
    </g>

    <!-- Power Lightning -->
    <g v-else-if="name === 'bolt'">
      <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" stroke-width="2" fill="currentColor" fill-opacity="0.2" />
    </g>

    <!-- Doctor -->
    <g v-else-if="name === 'doctor'">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" stroke-width="2" />
      <circle cx="9" cy="7" r="4" stroke-width="2" />
      <path d="M19 8v6M16 11h6" stroke-width="2" stroke="#00b4d8" />
    </g>

    <!-- Nurse -->
    <g v-else-if="name === 'nurse'">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" stroke-width="2" />
      <circle cx="9" cy="7" r="4" stroke-width="2" />
      <path d="M6 3h6l1 3H5l1-3z" stroke-width="1.5" fill="#00b4d8" fill-opacity="0.3" />
      <path d="M9 4v2M8 5h2" stroke-width="1.5" stroke="#ffffff" />
    </g>

    <!-- Caregiver / Helping Hand -->
    <g v-else-if="name === 'caregiver'">
      <path d="M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2" stroke-width="2" />
      <circle cx="10" cy="7" r="4" stroke-width="2" />
      <path d="M18 11l2 2 4-4" stroke-width="2" stroke="#00b4d8" />
    </g>

    <!-- Security Shield -->
    <g v-else-if="name === 'security'">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke-width="2" fill="currentColor" fill-opacity="0.2" />
    </g>

    <!-- Logistics Wrench -->
    <g v-else-if="name === 'logistics'">
      <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" stroke-width="2" />
    </g>

    <!-- Users Group -->
    <g v-else-if="name === 'users'">
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" stroke-width="2" />
      <circle cx="9" cy="7" r="4" stroke-width="2" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87" stroke-width="2" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" stroke-width="2" />
    </g>

    <!-- Single User -->
    <g v-else-if="name === 'user'">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" stroke-width="2" />
      <circle cx="12" cy="7" r="4" stroke-width="2" />
    </g>

    <!-- Clipboard -->
    <g v-else-if="name === 'clipboard'">
      <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" stroke-width="2" />
      <rect x="8" y="2" width="8" height="4" rx="1" ry="1" stroke-width="2" />
      <line x1="8" y1="11" x2="16" y2="11" stroke-width="1.8" />
      <line x1="8" y1="15" x2="14" y2="15" stroke-width="1.8" />
    </g>

    <!-- Gear / Settings -->
    <g v-else-if="name === 'cog'">
      <circle cx="12" cy="12" r="3" stroke-width="2" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" stroke-width="2" />
    </g>

    <!-- Checkmark Circle -->
    <g v-else-if="name === 'check-circle'">
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" stroke-width="2" />
      <polyline points="22 4 12 14.01 9 11.01" stroke-width="2" />
    </g>

    <!-- Clock Pending -->
    <g v-else-if="name === 'clock'">
      <circle cx="12" cy="12" r="10" stroke-width="2" />
      <polyline points="12 6 12 12 16 14" stroke-width="2" />
    </g>

    <!-- CCTV Camera -->
    <g v-else-if="name === 'camera'">
      <path d="M23 7l-7 5 7 5V7z" stroke-width="2" />
      <rect x="1" y="5" width="15" height="14" rx="2" ry="2" stroke-width="2" />
      <circle cx="8.5" cy="12" r="2.5" stroke-width="1.5" />
    </g>

    <!-- Alarm Bell -->
    <g v-else-if="name === 'bell'">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" stroke-width="2" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" stroke-width="2" />
    </g>

    <!-- Fire / Flame -->
    <g v-else-if="name === 'flame'">
      <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" stroke-width="2" fill="currentColor" fill-opacity="0.2" />
    </g>

    <!-- Fire Extinguisher / Hydrant -->
    <g v-else-if="name === 'hydrant'">
      <path d="M12 2v2M8 4h8M9 4v16a3 3 0 0 0 6 0V4" stroke-width="2" />
      <path d="M5 8h4M15 8h4" stroke-width="2" />
      <circle cx="12" cy="12" r="2" stroke-width="2" />
    </g>

    <!-- Alert Warning Triangle -->
    <g v-else-if="name === 'alert-triangle'">
      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" stroke-width="2" fill="currentColor" fill-opacity="0.15" />
      <line x1="12" y1="9" x2="12" y2="13" stroke-width="2.2" />
      <line x1="12" y1="17" x2="12.01" y2="17" stroke-width="2.5" />
    </g>

    <!-- Location Pin -->
    <g v-else-if="name === 'location'">
      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" stroke-width="2" />
      <circle cx="12" cy="10" r="3" stroke-width="2" />
    </g>

    <!-- Emergency Exit / Running Man -->
    <g v-else-if="name === 'exit'">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" stroke-width="2" />
      <polyline points="16 17 21 12 16 7" stroke-width="2" />
      <line x1="21" y1="12" x2="9" y2="12" stroke-width="2" />
    </g>

    <!-- Bar Chart -->
    <g v-else-if="name === 'chart-bar'">
      <line x1="18" y1="20" x2="18" y2="10" stroke-width="2.5" />
      <line x1="12" y1="20" x2="12" y2="4" stroke-width="2.5" />
      <line x1="6" y1="20" x2="6" y2="14" stroke-width="2.5" />
      <line x1="2" y1="20" x2="22" y2="20" stroke-width="2" />
    </g>

    <!-- Line Trend Chart -->
    <g v-else-if="name === 'chart-line'">
      <polyline points="22 7 13.5 15.5 8.5 10.5 2 17" stroke-width="2" />
      <polyline points="16 7 22 7 22 13" stroke-width="2" />
    </g>

    <!-- Holographic Sphere -->
    <g v-else-if="name === 'sphere'">
      <circle cx="12" cy="12" r="9" stroke-width="2" />
      <ellipse cx="12" cy="12" rx="9" ry="4" stroke-width="1.8" />
      <ellipse cx="12" cy="12" rx="4" ry="9" stroke-width="1.8" />
    </g>

    <!-- Mountain Peaks -->
    <g v-else-if="name === 'mountain'">
      <path d="M8 3l4 8 5-5 5 15H2L8 3z" stroke-width="2" fill="currentColor" fill-opacity="0.2" />
    </g>

    <!-- Money Pouch -->
    <g v-else-if="name === 'pouch'">
      <path d="M12 2c-2 0-3 2-3 4l-4 4c-1 1-1 3-1 5a8 8 0 0 0 16 0c0-2 0-4-1-5l-4-4c0-2-1-4-3-4z" stroke-width="2" />
      <line x1="9" y1="6" x2="15" y2="6" stroke-width="2" />
      <path d="M12 11v6M10 13h4" stroke-width="1.8" stroke="#00b4d8" />
    </g>

    <!-- Environmental Megaphone / Wave Sensor -->
    <g v-else-if="name === 'sensor'">
      <path d="M11 5L6 9H2v6h4l5 4V5z" stroke-width="2" />
      <path d="M15.54 8.46a5 5 0 0 1 0 7.07" stroke-width="2" />
      <path d="M19.07 4.93a10 10 0 0 1 0 14.14" stroke-width="2" />
    </g>

    <!-- Fallback Cross -->
    <g v-else>
      <path d="M12 5v14M5 12h14" stroke-width="2" />
    </g>
  </svg>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    name: string
    size?: number | string
    viewBox?: string
    customClass?: string
  }>(),
  {
    size: 16,
    viewBox: '0 0 24 24',
    customClass: ''
  }
)
</script>

<style scoped>
.tech-icon-svg {
  display: inline-block;
  vertical-align: middle;
  flex-shrink: 0;
}
</style>
