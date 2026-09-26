<template>
  <div class="pillars-panel">
    <!-- Pillar 1: 患者至上 -->
    <div class="pillar-item">
      <div class="pillar-icon-box">
        <svg viewBox="0 0 40 40" class="pillar-svg">
          <!-- Solid Person Glyph -->
          <circle cx="20" cy="11" r="5.5" fill="#38bdf8" />
          <path d="M 9 32 C 9 24 13 20 20 20 C 27 20 31 24 31 32 C 31 33 30 34 29 34 L 11 34 C 10 34 9 33 9 32 Z" fill="#38bdf8" />
        </svg>
      </div>
      <div class="pillar-text-group">
        <div class="pillar-title">患者至上</div>
        <div class="pillar-en">PATIENT FIRST</div>
      </div>
    </div>

    <div class="pillar-divider"></div>

    <!-- Pillar 2: 质量安全 -->
    <div class="pillar-item">
      <div class="pillar-icon-box">
        <svg viewBox="0 0 40 40" class="pillar-svg">
          <!-- Solid Shield with Cutout Checkmark -->
          <path d="M 20 5 L 32 9.5 C 32 21 27 29 20 35 C 13 29 8 21 8 9.5 Z" fill="#38bdf8" />
          <path d="M 15 19 L 18.5 22.5 L 26 15" fill="none" stroke="#071936" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </div>
      <div class="pillar-text-group">
        <div class="pillar-title">质量安全</div>
        <div class="pillar-en">QUALITY &amp; SAFETY</div>
      </div>
    </div>

    <div class="pillar-divider"></div>

    <!-- Pillar 3: 精细运营 (4-Node Topology) -->
    <div class="pillar-item">
      <div class="pillar-icon-box">
        <svg viewBox="0 0 40 40" class="pillar-svg">
          <!-- Central Hub & 4 Surrounding Nodes -->
          <!-- Connecting bars -->
          <line x1="20" y1="20" x2="20" y2="8" stroke="#38bdf8" stroke-width="3" stroke-linecap="round" />
          <line x1="20" y1="20" x2="20" y2="32" stroke="#38bdf8" stroke-width="3" stroke-linecap="round" />
          <line x1="20" y1="20" x2="8" y2="20" stroke="#38bdf8" stroke-width="3" stroke-linecap="round" />
          <line x1="20" y1="20" x2="32" y2="20" stroke="#38bdf8" stroke-width="3" stroke-linecap="round" />
          <!-- Nodes -->
          <circle cx="20" cy="20" r="4.5" fill="#38bdf8" stroke="#071936" stroke-width="1.5" />
          <circle cx="20" cy="8" r="4" fill="#38bdf8" />
          <circle cx="20" cy="32" r="4" fill="#38bdf8" />
          <circle cx="8" cy="20" r="4" fill="#38bdf8" />
          <circle cx="32" cy="20" r="4" fill="#38bdf8" />
        </svg>
      </div>
      <div class="pillar-text-group">
        <div class="pillar-title">精细运营</div>
        <div class="pillar-en">REFINED OPERATION</div>
      </div>
    </div>

    <div class="pillar-divider"></div>

    <!-- Pillar 4: 高质量发展 (Solid Leaf) -->
    <div class="pillar-item">
      <div class="pillar-icon-box">
        <svg viewBox="0 0 40 40" class="pillar-svg">
          <!-- Solid Leaf with Cutout Vein -->
          <path d="M 10 32 C 10 32 12 18 24 10 C 29 6 34 6 34 6 C 34 6 33 13 29 19 C 23 28 10 32 10 32 Z" fill="#38bdf8" />
          <path d="M 10 32 C 15 28 22 22 28 12" fill="none" stroke="#071936" stroke-width="2" stroke-linecap="round" />
        </svg>
      </div>
      <div class="pillar-text-group">
        <div class="pillar-title">高质量发展</div>
        <div class="pillar-en">SUSTAINABLE GROWTH</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.pillars-panel {
  width: 100%;
  height: 80px;
  display: flex !important;
  flex-direction: row !important;
  align-items: center;
  justify-content: space-between;
  padding: 0 48px;
  background: rgba(4, 24, 52, 0.7);
  border: 1px solid rgba(22, 64, 112, 0.45);
  border-radius: 6px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
}

.pillar-item {
  display: flex !important;
  flex-direction: row !important;
  align-items: center;
  gap: 16px;
}

.pillar-icon-box {
  width: 42px;
  height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.pillar-svg {
  width: 38px;
  height: 38px;
}

.pillar-text-group {
  display: flex;
  flex-direction: column;
}

.pillar-title {
  font-size: 18px;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: 1.5px;
  line-height: 1.2;
}

.pillar-en {
  font-size: 11px;
  font-weight: 700;
  color: #38bdf8;
  letter-spacing: 1px;
  margin-top: 2px;
}

.pillar-divider {
  width: 1px;
  height: 36px;
  background: linear-gradient(180deg, transparent, rgba(40, 110, 190, 0.45), transparent);
}
</style>
