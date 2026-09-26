<template>
  <div class="security-view">
    <!-- 3D Architectural Wireframe Center Stage -->
    <div class="wireframe-stage">
      <img src="/assets/hospital_floor_wireframe.jpg" alt="医院楼层安防线框图" class="wireframe-bg-img" />
      <div class="wireframe-vignette"></div>

      <!-- Hazard Alert Pins directly in floor rooms (Image 4 Replica) -->
      <div class="hazard-pin pin-fire pulsing-alert" style="top: 32%; left: 34%;">
        <div class="hazard-bubble red-bubble">
          <span class="hazard-icon-box text-red">
            <TechIcon name="flame" :size="13" />
          </span>
          <span class="hazard-text">5#储物室 烟雾预警</span>
        </div>
        <div class="hazard-marker red-marker"></div>
      </div>

      <div class="hazard-pin pin-accident pulsing-alert" style="top: 64%; right: 28%;">
        <div class="hazard-bubble yellow-bubble">
          <span class="hazard-icon-box text-amber">
            <TechIcon name="alert-triangle" :size="13" />
          </span>
          <span class="hazard-text">手术室1楼1门 医疗求助</span>
        </div>
        <div class="hazard-marker yellow-marker"></div>
      </div>

      <div class="hazard-pin pin-security pulsing-alert" style="top: 30%; right: 35%;">
        <div class="hazard-bubble cyan-bubble">
          <span class="hazard-icon-box text-cyan">
            <TechIcon name="bell" :size="13" />
          </span>
          <span class="hazard-text">心内科3楼 门禁触发</span>
        </div>
        <div class="hazard-marker cyan-marker"></div>
      </div>
    </div>

    <!-- Central Hero KPI Ribbon (5 Security & Emergency Telemetry Metrics) -->
    <div class="center-hero-ribbon">
      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="security" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">院区安防态势等级</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">一级平稳</span>
            <span class="hero-metric-badge badge-up">全域受控</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon">
          <TechIcon name="bell" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">实时待处理警情</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">0</span>
            <span class="hero-metric-unit">起</span>
            <span class="hero-metric-badge badge-up">今日已结3起</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="exit" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">消防通道通畅率</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">100%</span>
            <span class="hero-metric-badge badge-up">无障碍占用</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon">
          <TechIcon name="camera" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">安防监控设备在线</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">99.4%</span>
            <span class="hero-metric-unit">542/545台</span>
            <span class="hero-metric-badge badge-stable">正常巡检</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="flame" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">火灾自动报警联动</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">双轨待命</span>
            <span class="hero-metric-badge badge-up">就绪</span>
          </div>
        </div>
      </div>
    </div>

    <!-- UI Overlay Layout -->
    <div class="ui-overlay">
      <!-- Left Column -->
      <aside class="left-column-security">
        <!-- Panel 1: 火灾自动报警系统 -->
        <div class="tech-panel panel-fire-alarm">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="flame" :size="14" />
            </div>
            <span>火灾自动报警系统</span>
          </div>

          <div class="panel-body fire-body">
            <div class="fire-top-section">
              <!-- Radar Sweep Box -->
              <div class="radar-sweep-box">
                <div class="radar-circle">
                  <div class="radar-sweep-beam"></div>
                  <div class="radar-cross-h"></div>
                  <div class="radar-cross-v"></div>
                  <div class="radar-blip"></div>
                </div>
                <span class="radar-caption">火灾实时监控</span>
              </div>

              <!-- Location & Type Tags -->
              <div class="fire-tags-col">
                <div class="fire-info-pill">
                  <span class="pill-icon-box text-cyan">
                    <TechIcon name="location" :size="14" />
                  </span>
                  <div class="pill-texts">
                    <span class="pill-lbl">报警位置</span>
                    <span class="pill-val">5#储物室</span>
                  </div>
                </div>

                <div class="fire-info-pill">
                  <span class="pill-icon-box text-red">
                    <TechIcon name="alert-triangle" :size="14" />
                  </span>
                  <div class="pill-texts">
                    <span class="pill-lbl">报警类型</span>
                    <span class="pill-val text-red">设备报警</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- 3 Switch Controls (Segmented Pill Switch matching Reference Image 4) -->
            <div class="switch-controls-list">
              <div class="switch-item">
                <span class="switch-title">开启5楼整层广播</span>
                <div class="segmented-pill-switch">
                  <button type="button" class="pill-option" :class="{ active: !switch1 }" @click="switch1 = false">关</button>
                  <button type="button" class="pill-option" :class="{ active: switch1 }" @click="switch1 = true">开</button>
                </div>
              </div>

              <div class="switch-item">
                <span class="switch-title">开启五楼安全通道</span>
                <div class="segmented-pill-switch">
                  <button type="button" class="pill-option" :class="{ active: !switch2 }" @click="switch2 = false">关</button>
                  <button type="button" class="pill-option" :class="{ active: switch2 }" @click="switch2 = true">开</button>
                </div>
              </div>

              <div class="switch-item">
                <span class="switch-title">开启5楼消防设施</span>
                <div class="segmented-pill-switch">
                  <button type="button" class="pill-option" :class="{ active: !switch3 }" @click="switch3 = false">关</button>
                  <button type="button" class="pill-option" :class="{ active: switch3 }" @click="switch3 = true">开</button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Panel 2: 实时报警信息 (Scrolling 17 Events Table) -->
        <div class="tech-panel panel-alarm-records">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="bell" :size="14" />
            </div>
            <span>实时报警信息</span>
          </div>

          <div class="panel-body alarm-table-body">
            <table class="tech-table alarm-table">
              <thead>
                <tr>
                  <th>设备名称</th>
                  <th>设备位置</th>
                  <th>报警类型</th>
                  <th>报警时间</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(rec, idx) in alarmRecords" :key="idx">
                  <td class="td-device">{{ rec.name }}</td>
                  <td class="td-location">{{ rec.location }}</td>
                  <td class="td-type" :class="getTypeClass(rec.type)">{{ rec.type }}</td>
                  <td class="td-time">{{ rec.time }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </aside>

      <!-- Bottom Row -->
      <footer class="bottom-row-security">
        <!-- Panel 1: 设备安防总览 (Status Orbs + Action Table) -->
        <div class="tech-panel panel-equipment-overview">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="camera" :size="14" />
            </div>
            <span>设备安防总览</span>
          </div>

          <div class="panel-body eq-overview-body">
            <!-- Left 2 Status Cards -->
            <div class="status-orb-col">
              <div class="status-orb-card">
                <div class="orb-icon-circle orb-smoke">
                  <TechIcon name="camera" :size="20" />
                </div>
                <div class="orb-info">
                  <span class="orb-title">烟雾报警运行状态</span>
                  <span class="orb-badge badge-normal">运行正常</span>
                </div>
              </div>

              <div class="status-orb-card">
                <div class="orb-icon-circle orb-hydrant">
                  <TechIcon name="hydrant" :size="20" />
                </div>
                <div class="orb-info">
                  <span class="orb-title">消防栓运行状态</span>
                  <span class="orb-badge badge-normal">运行正常</span>
                </div>
              </div>
            </div>

            <!-- Right Dispatch Table -->
            <div class="eq-table-wrap">
              <table class="tech-table eq-table">
                <thead>
                  <tr>
                    <th>处理状态</th>
                    <th>报警事件信息</th>
                    <th>播放设备</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(item, idx) in eventActions" :key="idx">
                    <td>
                      <span class="status-pill-tag" :class="getStatusPillClass(item.status)">
                        {{ item.status }}
                      </span>
                    </td>
                    <td class="td-event-info">{{ item.info }}</td>
                    <td class="td-broadcast">{{ item.device }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Panel 2: 安防报警趋势 -->
        <div class="tech-panel panel-alarm-trend">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="chart-line" :size="14" />
            </div>
            <span>安防报警趋势</span>
          </div>

          <div class="panel-body trend-body">
            <div class="trend-legends">
              <div class="legend-item"><span class="dot dot-blue"></span> 设备报警</div>
              <div class="legend-item"><span class="dot dot-cyan"></span> 零件报警</div>
            </div>
            <div ref="trendChartRef" class="trend-chart"></div>
          </div>
        </div>
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import TechIcon from '../components/TechIcon.vue'

const switch1 = ref(false)
const switch2 = ref(true)
const switch3 = ref(false)

const trendChartRef = ref<HTMLDivElement>()
const charts: echarts.ECharts[] = []

const alarmRecords = [
  { name: 'EQ-001', location: '手术室 1 楼 1 门', type: '医疗事故', time: '2024-07-25 04:35:00' },
  { name: 'ZX-002', location: '住院部 1 楼 8 门', type: '火灾', time: '2024-06-10 06:45:30' },
  { name: 'VK-003', location: '心内科 3 楼 1 门', type: '暴力事件', time: '2024-04-20 08:20:45' },
  { name: 'MN-004', location: '口腔科诊室 1 楼', type: '设备故障', time: '2024-03-14 03:10:15' },
  { name: 'XY-005', location: '眼科治疗室 2 楼', type: '紧急医疗求助', time: '2024-02-10 04:05:30' },
  { name: 'FG-006', location: '泌尿科检查室', type: '药品失窃', time: '2024-01-28 08:59:45' },
  { name: 'ST-007', location: '儿科病房 6 楼', type: '医患冲突', time: '2023-11-02 15:10:35' },
  { name: 'KL-008', location: '外科病房 4 楼', type: '医疗设备', time: '2023-10-19 14:20:05' },
  { name: 'IJ-009', location: '皮肤科治疗室 2 楼', type: '氧气泄漏', time: '2023-07-03 09:46:53' },
  { name: 'RT-010', location: '眼科治疗室 2 楼', type: '放射性物质泄漏', time: '2023-06-15 11:55:20' },
  { name: 'OP-011', location: '泌尿科检查室 4 楼', type: '危险化学品泄漏', time: '2023-05-30 10:25:50' },
  { name: 'QW-012', location: '妇产科病房 5 楼', type: '信息系统故障', time: '2023-04-25 13:40:05' },
  { name: 'AB-013', location: '外科病房 4 楼', type: '电梯故障', time: '2023-04-07 12:30:20' },
  { name: 'CD-014', location: '神经内科病房 4 楼', type: '病人走失', time: '2023-04-25 13:40:05' },
  { name: 'EF-015', location: '肿瘤科病房 5 楼', type: '突发疾病', time: '2023-04-07 12:30:20' },
  { name: 'AA-026', location: '消化内科病房', type: '医疗诈骗', time: '2023-04-07 12:30:20' },
  { name: 'BB-027', location: '骨科诊室 1 楼', type: '公共卫生事件', time: '2023-04-07 12:30:20' }
]

const eventActions = [
  { status: '已处理', info: '401室紧急救援求助', device: '门诊整栋播放' },
  { status: '待处理', info: 'C129摄像机离线', device: '安保监控室广播' },
  { status: '已处理', info: 'A区人流密集超标报警', device: 'A区一楼广播,安保室' },
  { status: '处理中', info: 'D113电梯故障报警', device: '维修房广播' },
  { status: '处理中', info: '306井盖位移报警', device: '维修房、安保室广播' }
]

const getTypeClass = (type: string) => {
  if (['火灾', '放射性物质泄漏', '危险化学品泄漏', '暴力事件'].includes(type)) return 'type-danger'
  if (['紧急医疗求助', '药品失窃', '医患冲突', '氧气泄漏'].includes(type)) return 'type-warning'
  return 'type-info'
}

const getStatusPillClass = (status: string) => {
  if (status === '已处理') return 'tag-done'
  if (status === '待处理') return 'tag-pending'
  return 'tag-process'
}

const initTrendChart = () => {
  if (!trendChartRef.value) return
  const chart = echarts.init(trendChartRef.value)
  charts.push(chart)

  const dates = ['04/01', '04/03', '04/05', '04/07', '04/09', '04/11', '04/13', '04/15', '04/17']
  const eqData = [1200, 1000, 1500, 1100, 1700, 1300, 1600, 1200, 1400]
  const partData = [800, 600, 1100, 750, 1200, 950, 1150, 850, 1000]

  chart.setOption({
    grid: { left: 40, right: 15, top: 25, bottom: 25 },
    tooltip: { trigger: 'axis' },
    xAxis: {
      type: 'category',
      data: dates,
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } },
      axisLabel: { color: '#8fa0bf', fontSize: 9 }
    },
    yAxis: {
      type: 'value',
      name: '个',
      nameTextStyle: { color: '#8fa0bf', fontSize: 9 },
      min: 0,
      max: 2100,
      splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.06)', type: 'dashed' } },
      axisLabel: { color: '#8fa0bf', fontSize: 9 }
    },
    series: [
      {
        name: '设备报警',
        type: 'line',
        smooth: true,
        data: eqData,
        lineStyle: { color: '#1e65eb', width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(30, 101, 235, 0.2)' },
            { offset: 1, color: 'rgba(30, 101, 235, 0.0)' }
          ])
        },
        symbol: 'none'
      },
      {
        name: '零件报警',
        type: 'line',
        smooth: true,
        data: partData,
        lineStyle: { color: '#00b4d8', width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(0, 180, 216, 0.18)' },
            { offset: 1, color: 'rgba(0, 180, 216, 0.0)' }
          ])
        },
        symbol: 'none'
      }
    ]
  })
}

const handleResize = () => {
  charts.forEach(c => c.resize())
}

onMounted(() => {
  setTimeout(() => {
    initTrendChart()
  }, 100)
  window.addEventListener('resize', handleResize)
  window.addEventListener('cockpit-resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  window.removeEventListener('cockpit-resize', handleResize)
  charts.forEach(c => c.dispose())
})
</script>

<style scoped>
.security-view {
  position: relative;
  width: 1920px;
  height: 1016px;
  overflow: hidden;
  background-color: var(--bg-dark);
}

/* 3D Wireframe Center Stage */
.wireframe-stage {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.wireframe-bg-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: contrast(1.1) brightness(0.92);
}

.wireframe-vignette {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(circle at 55% 45%, transparent 35%, rgba(10, 17, 38, 0.85) 90%);
  pointer-events: none;
}

/* Hazard Pins in Wireframe */
.hazard-pin {
  position: absolute;
  display: flex;
  flex-direction: column;
  align-items: center;
  z-index: 10;
  pointer-events: auto;
  cursor: pointer;
  transform: translate(-50%, -100%);
  transition: transform 0.2s;
}

.hazard-pin:hover {
  transform: translate(-50%, -108%) scale(1.06);
}

.hazard-bubble {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 4px;
  backdrop-filter: blur(8px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
}

.hazard-icon-box {
  display: flex;
  align-items: center;
  justify-content: center;
}

.red-bubble {
  background: rgba(35, 12, 16, 0.94);
  border: 1px solid #ef4444;
  box-shadow: 0 2px 8px rgba(239, 68, 68, 0.35);
}

.yellow-bubble {
  background: rgba(35, 24, 10, 0.94);
  border: 1px solid #f59e0b;
  box-shadow: 0 2px 8px rgba(245, 158, 11, 0.35);
}

.cyan-bubble {
  background: rgba(12, 28, 56, 0.94);
  border: 1px solid #00b4d8;
  box-shadow: 0 2px 8px rgba(0, 180, 216, 0.35);
}

.hazard-text {
  font-size: 12px;
  font-weight: 600;
  color: #ffffff;
  white-space: nowrap;
}

.hazard-marker {
  width: 2px;
  height: 14px;
}

.red-marker {
  background: linear-gradient(180deg, #ef4444, transparent);
}

.yellow-marker {
  background: linear-gradient(180deg, #f59e0b, transparent);
}

.cyan-marker {
  background: linear-gradient(180deg, #00b4d8, transparent);
}

/* UI Overlay Layout */
.ui-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 1920px;
  height: 1016px;
  z-index: 20;
  pointer-events: none;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 16px;
}

.left-column-security {
  width: 450px;
  display: flex;
  flex-direction: column;
  gap: 15px;
  pointer-events: auto;
}

.bottom-row-security {
  width: 100%;
  height: 265px;
  display: grid;
  grid-template-columns: 2.8fr 1.6fr;
  gap: 16px;
  pointer-events: auto;
}

/* Left Panel 1: Fire Alarm */
.panel-fire-alarm {
  height: 330px;
  display: flex;
  flex-direction: column;
}

.fire-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 10px 14px;
}

.fire-top-section {
  display: flex;
  align-items: center;
  gap: 14px;
}

.radar-sweep-box {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.radar-circle {
  width: 78px;
  height: 78px;
  border-radius: 50%;
  border: 1.5px solid #1e3868;
  position: relative;
  background: radial-gradient(circle, rgba(30, 101, 235, 0.15) 0%, rgba(10, 17, 38, 0.9) 80%);
  overflow: hidden;
}

.radar-sweep-beam {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: conic-gradient(from 0deg, rgba(0, 180, 216, 0.4) 0deg, transparent 60deg, transparent 360deg);
  border-radius: 50%;
  animation: radarSpin 3s linear infinite;
}

.radar-cross-h, .radar-cross-v {
  position: absolute;
  background: rgba(255, 255, 255, 0.08);
}

.radar-cross-h {
  top: 50%;
  left: 0;
  right: 0;
  height: 1px;
}

.radar-cross-v {
  left: 50%;
  top: 0;
  bottom: 0;
  width: 1px;
}

.radar-blip {
  position: absolute;
  top: 30%;
  left: 65%;
  width: 6px;
  height: 6px;
  background: #ef4444;
  border-radius: 50%;
  box-shadow: 0 0 6px #ef4444;
  animation: alertPulseRed 1.5s infinite;
}

.radar-caption {
  font-size: 11px;
  color: #8fa0bf;
}

.fire-tags-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.fire-info-pill {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #132244;
  border: 1px solid #192c55;
  border-radius: 4px;
  padding: 6px 10px;
}

.pill-icon-box {
  display: flex;
  align-items: center;
  justify-content: center;
}

.pill-texts {
  display: flex;
  flex-direction: column;
}

.pill-lbl {
  font-size: 10px;
  color: #8fa0bf;
}

.pill-val {
  font-size: 13px;
  font-weight: 700;
  color: #ffffff;
}

.text-red {
  color: #ef4444;
}

.text-amber {
  color: #f59e0b;
}

.text-cyan {
  color: #38bdf8;
}

/* 3 Switch Controls */
.switch-controls-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.switch-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #132244;
  border: 1px solid #192c55;
  padding: 5px 10px;
  border-radius: 3px;
}

.switch-title {
  font-size: 12px;
  color: #cbd5e1;
}

.segmented-pill-switch {
  display: flex;
  align-items: center;
  background: #0d172e;
  border: 1px solid #1f3254;
  border-radius: 12px;
  padding: 2px;
  gap: 2px;
}

.pill-option {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 9px;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s ease;
  outline: none;
}

.pill-option.active {
  background: #1e65eb;
  color: #ffffff;
  box-shadow: 0 1px 4px rgba(30, 101, 235, 0.4);
}

/* Left Panel 2: Alarm Records Table */
.panel-alarm-records {
  height: 355px;
  display: flex;
  flex-direction: column;
}

.alarm-table-body {
  flex: 1;
  overflow-y: auto;
  padding: 6px 10px;
}

.alarm-table th {
  position: sticky;
  top: 0;
  background: #1a56db;
  z-index: 5;
}

.td-device {
  font-family: var(--font-number);
  font-weight: 700;
  color: #38bdf8;
  width: 65px;
}

.td-location {
  color: #cbd5e1;
  font-size: 11.5px;
}

.td-type {
  font-size: 11.5px;
  font-weight: 600;
}

.type-danger {
  color: #ef4444;
}

.type-warning {
  color: #f59e0b;
}

.type-info {
  color: #38bdf8;
}

.td-time {
  font-family: var(--font-number);
  font-size: 10.5px;
  color: #8fa0bf;
  width: 115px;
}

/* Bottom Row Panel 1: Equipment Overview */
.panel-equipment-overview .eq-overview-body {
  height: calc(100% - 37px);
  display: flex;
  gap: 14px;
  padding: 10px 14px;
}

.status-orb-col {
  width: 170px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  justify-content: center;
}

.status-orb-card {
  display: flex;
  align-items: center;
  gap: 10px;
  background: #132244;
  border: 1px solid #192c55;
  border-radius: 4px;
  padding: 8px 10px;
}

.orb-icon-circle {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.orb-smoke {
  background: #172b52;
  border: 1px solid #1e3868;
  color: #38bdf8;
}

.orb-hydrant {
  background: #172b52;
  border: 1px solid #1e3868;
  color: #10b981;
}

.orb-info {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.orb-title {
  font-size: 11px;
  color: #cbd5e1;
}

.orb-badge {
  font-size: 10px;
  font-weight: 600;
  width: fit-content;
  padding: 1px 6px;
  border-radius: 2px;
}

.badge-normal {
  background: rgba(16, 185, 129, 0.15);
  border: 1px solid #10b981;
  color: #10b981;
}

.eq-table-wrap {
  flex: 1;
  overflow-y: auto;
}

.status-pill-tag {
  font-size: 10.5px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 10px;
  display: inline-block;
}

.tag-done {
  background: rgba(16, 185, 129, 0.15);
  border: 1px solid #10b981;
  color: #10b981;
}

.tag-pending {
  background: rgba(245, 158, 11, 0.15);
  border: 1px solid #f59e0b;
  color: #f59e0b;
}

.tag-process {
  background: rgba(30, 101, 235, 0.15);
  border: 1px solid #2563eb;
  color: #38bdf8;
}

.td-event-info {
  color: #ffffff;
  font-size: 12px;
}

.td-broadcast {
  color: #8fa0bf;
  font-size: 11px;
}

/* Bottom Row Panel 2: Trend Chart */
.panel-alarm-trend .trend-body {
  height: calc(100% - 37px);
  display: flex;
  flex-direction: column;
  padding: 8px 12px;
}

.trend-legends {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  font-size: 11px;
  color: #cbd5e1;
}

.dot-blue {
  background-color: #1e65eb;
}

.dot-cyan {
  background-color: #00b4d8;
}

.trend-chart {
  flex: 1;
  width: 100%;
}
</style>
