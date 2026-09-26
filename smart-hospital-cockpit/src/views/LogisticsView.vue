<template>
  <div class="logistics-view">
    <!-- 3D Layered Floor Stack Center Stage -->
    <div class="stack-stage">
      <img src="/assets/hospital_floors_stack.jpg" alt="医院多层切片透视" class="stack-bg-img" />
      <div class="stack-vignette"></div>

      <!-- Floor Level Badges (5F - 1F) Aligned to Slices (Matching Reference Image 5) -->
      <div class="floor-markers-container">
        <div
          v-for="floor in floors"
          :key="floor.level"
          class="floor-badge-target"
          :class="{ active: currentFloor === floor.level }"
          :style="floor.positionStyle"
          @click="selectFloor(floor.level)"
        >
          <div class="floor-ring">{{ floor.level }}</div>
          <div class="floor-indicator-line"></div>
          <div class="floor-status-tag" v-if="currentFloor === floor.level">
            <span class="pulse-dot"></span>
            {{ floor.name }}
          </div>
        </div>
      </div>

      <!-- 1F Service Hall CCTV Modal (Exact Replica of Reference Image 5) -->
      <transition name="pop-scale">
        <div class="cctv-modal" v-if="showCctvModal">
          <div class="modal-header">
            <div class="modal-title">
              <span class="title-bar-accent"></span>
              {{ currentFloor }}服务大厅
            </div>
            <button class="modal-close-btn" @click.stop="showCctvModal = false">
              <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" stroke-width="2.5" fill="none"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <div class="cctv-grid-4">
            <div class="cctv-feed-box">
              <img src="/assets/cctv_service_hall.jpg" alt="A1-2" class="cctv-thumb" />
              <div class="cctv-rec-dot"></div>
              <div class="cctv-bar">
                <span class="cctv-id">A1-2</span>
                <span class="cctv-ts">04/12 12:32:11</span>
              </div>
            </div>

            <div class="cctv-feed-box">
              <img src="/assets/cctv_corridor.jpg" alt="A1-2" class="cctv-thumb thumb-tint-1" />
              <div class="cctv-rec-dot"></div>
              <div class="cctv-bar">
                <span class="cctv-id">A1-2</span>
                <span class="cctv-ts">04/12 12:32:11</span>
              </div>
            </div>

            <div class="cctv-feed-box">
              <img src="/assets/cctv_corridor.jpg" alt="B1-1" class="cctv-thumb thumb-tint-2" />
              <div class="cctv-rec-dot"></div>
              <div class="cctv-bar">
                <span class="cctv-id">B1-1</span>
                <span class="cctv-ts">04/12 12:32:11</span>
              </div>
            </div>

            <div class="cctv-feed-box">
              <img src="/assets/cctv_service_hall.jpg" alt="B1-2" class="cctv-thumb thumb-tint-3" />
              <div class="cctv-rec-dot"></div>
              <div class="cctv-bar">
                <span class="cctv-id">B1-2</span>
                <span class="cctv-ts">04/12 12:32:11</span>
              </div>
            </div>
          </div>
        </div>
      </transition>
    </div>

    <!-- Central Hero KPI Ribbon (5 Logistics & Facility Operations Telemetry Metrics) -->
    <div class="center-hero-ribbon">
      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="security" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">智慧后勤综合指数</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">98.8</span>
            <span class="hero-metric-unit">分</span>
            <span class="hero-metric-badge badge-up">优级运行</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="bolt" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">综合能耗控制定额</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">92.4%</span>
            <span class="hero-metric-badge badge-up">节电 4,120kWh</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon">
          <TechIcon name="cog" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">核心机电设备在线</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">99.1%</span>
            <span class="hero-metric-unit">1,057/1,067台</span>
            <span class="hero-metric-badge badge-stable">稳定运行</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-amber">
          <TechIcon name="logistics" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">维修工单平均响应</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">8.2</span>
            <span class="hero-metric-unit">分钟</span>
            <span class="hero-metric-badge badge-up">环比快1.4分</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="clipboard" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">应急物资储备保障</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">100%</span>
            <span class="hero-metric-badge badge-up">30天满额备货</span>
          </div>
        </div>
      </div>
    </div>

    <!-- UI Overlay Layout -->
    <div class="ui-overlay">
      <!-- Left Column -->
      <aside class="left-column-logistics">
        <!-- Panel 1: 监控在线统计 -->
        <div class="tech-panel panel-cctv-stats">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="camera" :size="14" />
            </div>
            <span>监控在线统计</span>
          </div>

          <div class="panel-body cctv-list-body">
            <div class="dept-cam-row" v-for="dept in cameraDepts" :key="dept.name">
              <div class="dept-title-box">
                <TechIcon :name="dept.icon" :size="13" class="dept-icon-svg" />
                <span class="dept-name">{{ dept.name }}</span>
              </div>
              <div class="cam-status-box">
                <span class="status-pill" :class="dept.online ? 'pill-online' : 'pill-offline'">
                  {{ dept.online ? '在线' : '离线' }}
                </span>
                <span class="cam-code">{{ dept.code }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Panel 2: 设备在线统计 (Dual Rings) -->
        <div class="tech-panel panel-online-devices">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="chart-bar" :size="14" />
            </div>
            <span>设备在线统计</span>
          </div>

          <div class="panel-body online-body">
            <div class="dual-ring-wrap">
              <div class="ring-item">
                <div ref="onlineRingRef" class="ring-chart"></div>
                <div class="ring-center-txt">
                  <span class="ring-num text-cyan">1057</span>
                  <span class="ring-lbl">设备在线数</span>
                </div>
              </div>

              <div class="ring-item">
                <div ref="offlineRingRef" class="ring-chart"></div>
                <div class="ring-center-txt">
                  <span class="ring-num text-sky">269</span>
                  <span class="ring-lbl">设备离线数</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Panel 3: 各科室监控数 (Mountain Peak Chart) -->
        <div class="tech-panel panel-mountain-chart">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="mountain" :size="14" />
            </div>
            <span>各科室监控数</span>
          </div>

          <div class="panel-body mountain-body">
            <div ref="mountainChartRef" class="mountain-chart"></div>
          </div>
        </div>
      </aside>

      <!-- Bottom Row: 3 Panels -->
      <footer class="bottom-row-logistics">
        <!-- 1. 安全通道情况 -->
        <div class="tech-panel panel-passages">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="exit" :size="14" />
            </div>
            <span>安全通道情况</span>
          </div>

          <div class="panel-body passages-body">
            <div class="passage-row" v-for="(p, idx) in passageData" :key="idx">
              <span class="passage-dept">{{ p.dept }}</span>
              <span class="passage-chan">{{ p.channel }}</span>
              <div class="passage-bar-wrap">
                <div
                  class="passage-bar-fill"
                  :class="p.status === '拥挤' ? 'fill-crowded' : 'fill-clear'"
                  :style="{ width: p.status === '拥挤' ? '85%' : '35%' }"
                ></div>
              </div>
              <span
                class="passage-status-badge"
                :class="p.status === '拥挤' ? 'badge-crowded' : 'badge-clear'"
              >
                {{ p.status }}
              </span>
            </div>
          </div>
        </div>

        <!-- 2. 各科室人流统计 (Neural Branch Graph) -->
        <div class="tech-panel panel-flow-branch">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="node" :size="14" />
            </div>
            <span>各科室人流统计</span>
          </div>

          <div class="panel-body flow-branch-body">
            <!-- Left Branches -->
            <div class="branch-col branch-left">
              <div class="flow-node">
                <span class="node-name">医疗总务处</span>
                <span class="node-val">15 <span class="node-unit">%</span></span>
              </div>
              <div class="flow-node">
                <span class="node-name">机械设备科</span>
                <span class="node-val">20 <span class="node-unit">%</span></span>
              </div>
            </div>

            <!-- Center Core -->
            <div class="branch-center">
              <svg class="branch-svg" viewBox="0 0 200 120">
                <path d="M 25,30 Q 70,60 100,60" stroke="#00b4d8" stroke-width="2" fill="none" opacity="0.8" />
                <path d="M 25,90 Q 70,60 100,60" stroke="#00b4d8" stroke-width="2" fill="none" opacity="0.8" />
                <path d="M 175,30 Q 130,60 100,60" stroke="#38bdf8" stroke-width="2" fill="none" opacity="0.8" />
                <path d="M 175,90 Q 130,60 100,60" stroke="#38bdf8" stroke-width="2" fill="none" opacity="0.8" />
              </svg>
              <div class="core-bubble">
                <span class="core-val">65%</span>
                <span class="core-lbl">小儿门诊部</span>
              </div>
            </div>

            <!-- Right Branches -->
            <div class="branch-col branch-right">
              <div class="flow-node">
                <span class="node-name">儿童护理部</span>
                <span class="node-val text-sky">40 <span class="node-unit">%</span></span>
              </div>
              <div class="flow-node">
                <span class="node-name">药剂科</span>
                <span class="node-val text-sky">25 <span class="node-unit">%</span></span>
              </div>
            </div>
          </div>
        </div>

        <!-- 3. 实时监控 Matrix -->
        <div class="tech-panel panel-live-cctv">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="camera" :size="14" />
            </div>
            <span>实时监控</span>
          </div>

          <div class="panel-body live-cctv-body">
            <!-- Large Left Stream -->
            <div class="main-cctv-stream">
              <img src="/assets/cctv_service_hall.jpg" alt="A1-1前台" class="stream-img" />
              <div class="cctv-rec-dot"></div>
              <div class="stream-footer">
                <span class="stream-tag">A1-1前台</span>
                <span class="stream-ts">04/28 11:38:11</span>
              </div>
            </div>

            <!-- 4 Small Right Streams -->
            <div class="mini-cctv-grid">
              <div class="mini-cctv-box" v-for="cam in miniCams" :key="cam.id">
                <img :src="cam.img" :alt="cam.id" class="mini-cam-img" :style="cam.style" />
                <div class="mini-cam-footer">
                  <span class="mini-cam-id">{{ cam.id }}</span>
                  <span class="mini-cam-ts">{{ cam.ts }}</span>
                </div>
              </div>
            </div>
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

const currentFloor = ref('1F')
const showCctvModal = ref(true)

const floors = [
  { level: '5F', name: '5F 综合手术室', status: '正常运行', positionStyle: { top: '16%', right: '20%' } },
  { level: '4F', name: '4F 住院重症区', status: '正常运行', positionStyle: { top: '31%', right: '20%' } },
  { level: '3F', name: '3F 检验化验科', status: '设备维护', positionStyle: { top: '46%', right: '20%' } },
  { level: '2F', name: '2F 门诊诊疗区', status: '人流高峰', positionStyle: { top: '61%', right: '20%' } },
  { level: '1F', name: '1F 挂号收费厅', status: '正常运行', positionStyle: { top: '76%', right: '20%' } }
]

const selectFloor = (level: string) => {
  currentFloor.value = level
  showCctvModal.value = true
}

const cameraDepts = [
  { name: '小儿门诊部', code: '视频监控A1', online: true, icon: 'hospital' },
  { name: '医疗总务处', code: '视频监控A2', online: true, icon: 'clipboard' },
  { name: '儿童护理部', code: '视频监控A3', online: false, icon: 'caregiver' },
  { name: '机械设备科', code: '视频监控A4', online: false, icon: 'cog' },
  { name: '药剂科', code: '视频监控A5', online: true, icon: 'flask' },
  { name: '放射科', code: '视频监控A6', online: true, icon: 'sensor' },
  { name: '急诊大厅', code: '视频监控A7', online: false, icon: 'ambulance' }
]

const passageData = [
  { dept: '小儿门诊部', channel: '1#通道', status: '拥挤' },
  { dept: '医疗总务处', channel: '1#通道', status: '通畅' },
  { dept: '儿童护理部', channel: '1#通道', status: '拥挤' },
  { dept: '机械设备科', channel: '1#通道', status: '通畅' },
  { dept: '药剂科', channel: '1#通道', status: '通畅' }
]

const miniCams = [
  { id: 'A3-201', ts: '04/28 11:38:11', img: '/assets/cctv_corridor.jpg', style: 'filter: hue-rotate(15deg);' },
  { id: 'B1-301', ts: '04/28 11:38:11', img: '/assets/cctv_service_hall.jpg', style: 'filter: brightness(0.9);' },
  { id: 'A3-205', ts: '04/28 11:38:11', img: '/assets/cctv_corridor.jpg', style: 'filter: contrast(1.15);' },
  { id: 'A1-杂货间', ts: '04/28 11:38:11', img: '/assets/cctv_service_hall.jpg', style: 'filter: hue-rotate(200deg) brightness(0.85);' }
]

const onlineRingRef = ref<HTMLDivElement>()
const offlineRingRef = ref<HTMLDivElement>()
const mountainChartRef = ref<HTMLDivElement>()
const charts: echarts.ECharts[] = []

const initOnlineRings = () => {
  if (onlineRingRef.value) {
    const chart = echarts.init(onlineRingRef.value)
    charts.push(chart)
    chart.setOption({
      series: [
        {
          type: 'pie',
          radius: ['70%', '88%'],
          silent: true,
          label: { show: false },
          data: [
            {
              value: 1057,
              itemStyle: {
                color: new echarts.graphic.LinearGradient(0, 0, 1, 1, [
                  { offset: 0, color: '#00b4d8' },
                  { offset: 1, color: '#1e65eb' }
                ])
              }
            },
            {
              value: 300,
              itemStyle: { color: 'rgba(30, 101, 235, 0.12)' }
            }
          ]
        }
      ]
    })
  }

  if (offlineRingRef.value) {
    const chart = echarts.init(offlineRingRef.value)
    charts.push(chart)
    chart.setOption({
      series: [
        {
          type: 'pie',
          radius: ['70%', '88%'],
          silent: true,
          label: { show: false },
          data: [
            {
              value: 269,
              itemStyle: {
                color: new echarts.graphic.LinearGradient(0, 0, 1, 1, [
                  { offset: 0, color: '#38bdf8' },
                  { offset: 1, color: '#1e40af' }
                ])
              }
            },
            {
              value: 1000,
              itemStyle: { color: 'rgba(56, 189, 248, 0.12)' }
            }
          ]
        }
      ]
    })
  }
}

const initMountainChart = () => {
  if (!mountainChartRef.value) return
  const chart = echarts.init(mountainChartRef.value)
  charts.push(chart)

  const depts = ['门诊部', '住院部', '总务处', '医务处', '药剂科']
  const values = [4, 6, 2, 5, 3]

  chart.setOption({
    grid: { left: 30, right: 15, top: 20, bottom: 25 },
    xAxis: {
      type: 'category',
      data: depts,
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } },
      axisLabel: { color: '#8fa0bf', fontSize: 10 }
    },
    yAxis: {
      type: 'value',
      name: '个',
      nameTextStyle: { color: '#8fa0bf', fontSize: 9 },
      min: 1,
      max: 6,
      splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.06)', type: 'dashed' } },
      axisLabel: { color: '#8fa0bf', fontSize: 9 }
    },
    series: [
      {
        type: 'line',
        data: values,
        smooth: false,
        symbol: 'none',
        lineStyle: { color: '#00b4d8', width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(0, 180, 216, 0.28)' },
            { offset: 1, color: 'rgba(0, 180, 216, 0.0)' }
          ])
        }
      }
    ]
  })
}

const handleResize = () => {
  charts.forEach(c => c.resize())
}

onMounted(() => {
  setTimeout(() => {
    initOnlineRings()
    initMountainChart()
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
.logistics-view {
  position: relative;
  width: 1920px;
  height: 1016px;
  overflow: hidden;
  background-color: var(--bg-dark);
}

/* 3D Stack Stage */
.stack-stage {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.stack-bg-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: contrast(1.1) brightness(0.95);
}

.stack-vignette {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(circle at 55% 45%, transparent 35%, rgba(10, 17, 38, 0.85) 90%);
  pointer-events: none;
}

/* Interactive Floor Badges */
.floor-markers-container {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 15;
}

.floor-badge-target {
  position: absolute;
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  pointer-events: auto;
  transition: transform 0.2s;
}

.floor-badge-target:hover {
  transform: scale(1.08);
}

.floor-ring {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: #132244;
  border: 1.5px solid #1e3868;
  color: #38bdf8;
  font-family: var(--font-number);
  font-size: 13px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.25s;
}

.floor-badge-target.active .floor-ring {
  background: #1e65eb;
  border-color: #2563eb;
  color: #ffffff;
  box-shadow: 0 2px 8px rgba(30, 101, 235, 0.4);
}

.floor-indicator-line {
  width: 16px;
  height: 2px;
  background: #1e65eb;
  opacity: 0.8;
}

.floor-status-tag {
  background: #132244;
  border: 1px solid #1e3868;
  color: #ffffff;
  font-size: 11px;
  padding: 3px 8px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  gap: 6px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
}

.pulse-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background-color: #00b4d8;
  box-shadow: 0 0 6px #00b4d8;
  animation: techPulse 1.5s infinite;
}

/* 1F Service Hall CCTV Modal (Image 5 Replica) */
.cctv-modal {
  position: absolute;
  top: 18%;
  right: 2%;
  width: 370px;
  background: rgba(16, 28, 54, 0.96);
  border: 1px solid #1e40af;
  border-radius: 4px;
  box-shadow: 0 12px 36px rgba(0, 0, 0, 0.75);
  backdrop-filter: blur(16px);
  z-index: 50;
  padding: 12px 14px;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #192c55;
  padding-bottom: 8px;
  margin-bottom: 10px;
}

.modal-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 15px;
  font-weight: 600;
  color: #ffffff;
}

.title-bar-accent {
  width: 3px;
  height: 14px;
  background: #00b4d8;
  border-radius: 1.5px;
}

.modal-close-btn {
  background: transparent;
  border: none;
  color: #8fa0bf;
  font-size: 16px;
  cursor: pointer;
  transition: color 0.2s;
}

.modal-close-btn:hover {
  color: #ffffff;
}

.cctv-grid-4 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}

.cctv-feed-box {
  position: relative;
  height: 98px;
  border: 1px solid #192c55;
  border-radius: 2px;
  overflow: hidden;
  background: #0a1126;
}

.cctv-thumb {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.thumb-tint-1 { filter: hue-rotate(15deg) contrast(1.1); }
.thumb-tint-2 { filter: hue-rotate(190deg) brightness(0.9); }
.thumb-tint-3 { filter: contrast(1.2); }

.cctv-rec-dot {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 6px;
  height: 6px;
  background-color: #ef4444;
  border-radius: 50%;
  box-shadow: 0 0 6px #ef4444;
}

.cctv-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(10, 17, 38, 0.9);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 2px 6px;
  font-size: 9.5px;
  color: #cbd5e1;
}

.cctv-id {
  color: #38bdf8;
  font-weight: 600;
}

.cctv-ts {
  font-family: var(--font-number);
  color: #8fa0bf;
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

.left-column-logistics {
  width: 430px;
  display: flex;
  flex-direction: column;
  gap: 15px;
  pointer-events: auto;
}

.bottom-row-logistics {
  width: 100%;
  height: 265px;
  display: grid;
  grid-template-columns: 1.4fr 1.3fr 1.7fr;
  gap: 16px;
  pointer-events: auto;
}

/* Left Panel 1: CCTV Stats */
.panel-cctv-stats {
  height: 250px;
  display: flex;
  flex-direction: column;
}

.cctv-list-body {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 8px 12px;
}

.dept-cam-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #132244;
  border: 1px solid #192c55;
  padding: 4px 8px;
  border-radius: 3px;
}

.dept-title-box {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #38bdf8;
}

.dept-icon-svg {
  color: #38bdf8;
}

.dept-name {
  font-size: 11.5px;
  color: #ffffff;
}

.cam-status-box {
  display: flex;
  align-items: center;
  gap: 6px;
}

.status-pill {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 2px;
  font-weight: 600;
}

.pill-online {
  background: rgba(16, 185, 129, 0.15);
  border: 1px solid #10b981;
  color: #10b981;
}

.pill-offline {
  background: rgba(100, 116, 139, 0.2);
  border: 1px solid #64748b;
  color: #8fa0bf;
}

.cam-code {
  font-size: 10.5px;
  color: #8fa0bf;
}

/* Left Panel 2: Online Devices */
.panel-online-devices {
  height: 215px;
  display: flex;
  flex-direction: column;
}

.online-body {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 6px 12px;
}

.dual-ring-wrap {
  display: flex;
  align-items: center;
  justify-content: space-around;
  width: 100%;
}

.ring-item {
  position: relative;
  width: 120px;
  height: 120px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.ring-chart {
  width: 100%;
  height: 100%;
}

.ring-center-txt {
  position: absolute;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.ring-num {
  font-family: var(--font-number);
  font-size: 19px;
  font-weight: 700;
}

.text-cyan {
  color: #00b4d8;
}

.text-sky {
  color: #38bdf8;
}

.ring-lbl {
  font-size: 10px;
  color: #8fa0bf;
}

/* Left Panel 3: Mountain Chart */
.panel-mountain-chart {
  height: 220px;
  display: flex;
  flex-direction: column;
}

.mountain-body {
  flex: 1;
  padding: 6px 10px;
}

.mountain-chart {
  width: 100%;
  height: 100%;
}

/* Bottom Row Panel 1: Passages */
.panel-passages .passages-body {
  height: calc(100% - 37px);
  display: flex;
  flex-direction: column;
  justify-content: space-around;
  padding: 8px 12px;
}

.passage-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11.5px;
}

.passage-dept {
  width: 70px;
  color: #ffffff;
  font-size: 11px;
}

.passage-chan {
  width: 48px;
  color: #8fa0bf;
  font-size: 10.5px;
}

.passage-bar-wrap {
  flex: 1;
  height: 6px;
  background: #0d172e;
  border-radius: 3px;
  overflow: hidden;
  border: 1px solid #192c55;
}

.passage-bar-fill {
  height: 100%;
  border-radius: 3px;
}

.fill-crowded {
  background: linear-gradient(90deg, #f59e0b, #ef4444);
}

.fill-clear {
  background: linear-gradient(90deg, #1e40af, #00b4d8);
}

.passage-status-badge {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 2px;
  font-weight: 600;
  width: 32px;
  text-align: center;
}

.badge-crowded {
  background: rgba(245, 158, 11, 0.15);
  border: 1px solid #f59e0b;
  color: #f59e0b;
}

.badge-clear {
  background: rgba(0, 180, 216, 0.15);
  border: 1px solid #00b4d8;
  color: #00b4d8;
}

/* Bottom Row Panel 2: Flow Branch */
.panel-flow-branch .flow-branch-body {
  height: calc(100% - 37px);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  position: relative;
}

.branch-col {
  display: flex;
  flex-direction: column;
  justify-content: space-around;
  height: 100%;
  z-index: 5;
}

.flow-node {
  display: flex;
  flex-direction: column;
  background: #132244;
  border: 1px solid #192c55;
  border-radius: 3px;
  padding: 4px 8px;
}

.node-name {
  font-size: 10.5px;
  color: #8fa0bf;
}

.node-val {
  font-family: var(--font-number);
  font-size: 13px;
  font-weight: 700;
  color: #ffffff;
}

.node-unit {
  font-size: 9.5px;
  color: #64748b;
}

.branch-center {
  position: relative;
  width: 140px;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.branch-svg {
  position: absolute;
  top: 0;
  left: -20px;
  width: 180px;
  height: 100%;
  pointer-events: none;
}

.core-bubble {
  width: 68px;
  height: 68px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(30, 101, 235, 0.25) 0%, rgba(16, 28, 54, 0.6) 70%);
  border: 2px solid #1e65eb;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  z-index: 10;
}

.core-val {
  font-family: var(--font-number);
  font-size: 16px;
  font-weight: 700;
  color: #ffffff;
}

.core-lbl {
  font-size: 9px;
  color: #8fa0bf;
}

/* Bottom Row Panel 3: Live CCTV Matrix */
.panel-live-cctv .live-cctv-body {
  height: calc(100% - 37px);
  display: flex;
  gap: 8px;
  padding: 8px 10px;
}

.main-cctv-stream {
  flex: 1.2;
  position: relative;
  background: #000000;
  border: 1px solid #192c55;
  border-radius: 2px;
  overflow: hidden;
}

.stream-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.stream-footer {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(10, 17, 38, 0.85);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 3px 8px;
  font-size: 10px;
}

.stream-tag {
  color: #38bdf8;
  font-weight: 600;
}

.stream-ts {
  font-family: var(--font-number);
  color: #8fa0bf;
}

.mini-cctv-grid {
  flex: 1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
  gap: 6px;
}

.mini-cctv-box {
  position: relative;
  background: #000000;
  border: 1px solid #192c55;
  border-radius: 2px;
  overflow: hidden;
}

.mini-cam-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.mini-cam-footer {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(10, 17, 38, 0.85);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1px 4px;
  font-size: 8.5px;
}

.mini-cam-id {
  color: #38bdf8;
  font-weight: 600;
}

.mini-cam-ts {
  font-family: var(--font-number);
  color: #64748b;
  font-size: 7.5px;
}

/* Transitions */
.pop-scale-enter-active,
.pop-scale-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}

.pop-scale-enter-from,
.pop-scale-leave-to {
  opacity: 0;
  transform: scale(0.92);
}
</style>

