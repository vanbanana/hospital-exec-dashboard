<template>
  <div class="overview-view">
    <!-- 3D Campus Digital Twin Center Stage -->
    <div class="campus-stage">
      <img src="/assets/hospital_campus.jpg" alt="智慧医院数字孪生" class="campus-bg-img" />
      <div class="stage-vignette"></div>

      <!-- Interactive 3D Building Pins (Matching Reference Images 1 & 2) -->
      <!-- 综合楼 -->
      <div class="building-pin pin-zonghe" style="top: 45%; left: 34%;">
        <div class="pin-card">
          <div class="pin-icon-wrap">
            <TechIcon name="hospital" :size="16" />
          </div>
          <span class="pin-text">综合楼</span>
        </div>
        <div class="pin-stem"></div>
        <div class="pin-pulse"></div>
      </div>

      <!-- 住院部 -->
      <div class="building-pin pin-zhuyuan" style="top: 22%; left: 51%;">
        <div class="pin-card">
          <div class="pin-icon-wrap">
            <TechIcon name="bed" :size="16" />
          </div>
          <span class="pin-text">住院部</span>
        </div>
        <div class="pin-stem"></div>
        <div class="pin-pulse"></div>
      </div>

      <!-- 门诊部 -->
      <div class="building-pin pin-menzhen" style="top: 35%; left: 24%;">
        <div class="pin-card">
          <div class="pin-icon-wrap">
            <TechIcon name="stethoscope" :size="16" />
          </div>
          <span class="pin-text">门诊部</span>
        </div>
        <div class="pin-stem"></div>
        <div class="pin-pulse"></div>
      </div>

      <!-- 宿舍楼 -->
      <div class="building-pin pin-sushe" style="top: 29%; left: 66%;">
        <div class="pin-card">
          <div class="pin-icon-wrap">
            <TechIcon name="dorm" :size="16" />
          </div>
          <span class="pin-text">宿舍楼</span>
        </div>
        <div class="pin-stem"></div>
        <div class="pin-pulse"></div>
      </div>

      <!-- 急诊部 (Interactive target with alert beacon, clicking opens Image 2 modal) -->
      <div
        class="building-pin pin-jizhen clickable"
        style="top: 42%; left: 72%;"
        @click="showEmergencyModal = true"
      >
        <div class="pin-card pin-card-alert">
          <div class="pin-icon-wrap alert-icon">
            <TechIcon name="ambulance" :size="16" />
          </div>
          <span class="pin-text">急诊部</span>
          <span class="alert-beacon-dot"></span>
        </div>
        <div class="pin-stem stem-alert"></div>
        <div class="pin-pulse pulse-alert"></div>
      </div>

      <!-- 停车场 -->
      <div class="building-pin pin-parking" style="top: 72%; left: 51%;">
        <div class="pin-card pin-card-parking">
          <div class="pin-icon-wrap parking-icon">
            <TechIcon name="parking" :size="16" />
          </div>
          <span class="pin-text">停车场</span>
        </div>
        <div class="pin-stem"></div>
        <div class="pin-pulse"></div>
      </div>

      <!-- Emergency Modal (Exact 100% Replica of Reference Image 2) -->
      <transition name="pop-scale">
        <div class="emergency-modal" v-if="showEmergencyModal" style="top: 44%; left: 52%;">
          <div class="modal-header">
            <div class="modal-title">
              <span class="title-bar-accent"></span>
              急诊部
            </div>
            <button class="modal-close-btn" @click.stop="showEmergencyModal = false">
              <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" stroke-width="2.5" fill="none"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
          <div class="modal-body">
            <div class="metric-row-3">
              <div class="metric-col">
                <span class="metric-label">当日急诊数</span>
                <span class="metric-val">21</span>
              </div>
              <div class="divider-v"></div>
              <div class="metric-col">
                <span class="metric-label">就诊人数</span>
                <span class="metric-val">21</span>
              </div>
              <div class="divider-v"></div>
              <div class="metric-col">
                <span class="metric-label">平均处理率</span>
                <span class="metric-val highlight">100%</span>
              </div>
            </div>

            <div class="metric-row-2">
              <div class="metric-item-horizontal">
                <span class="metric-sublabel">平均到达时间</span>
                <span class="metric-subval">10.1分钟</span>
              </div>
              <div class="metric-item-horizontal">
                <span class="metric-sublabel">抢救成功率</span>
                <span class="metric-subval">96%</span>
              </div>
            </div>

            <div class="metric-row-2">
              <div class="metric-item-horizontal">
                <span class="metric-sublabel">常见急症治愈</span>
                <span class="metric-subval">100%</span>
              </div>
              <div class="metric-item-horizontal">
                <span class="metric-sublabel">设备更新频率</span>
                <span class="metric-subval">75%</span>
              </div>
            </div>

            <div class="metric-footer-row">
              <span class="metric-sublabel">综合满意度评分:</span>
              <span class="metric-score">72分</span>
            </div>
          </div>
        </div>
      </transition>
    </div>

    <!-- Central Hero KPI Ribbon (5 Primary Operational Metrics) -->
    <div class="center-hero-ribbon">
      <div class="hero-metric-item">
        <div class="hero-metric-icon">
          <TechIcon name="user" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">今日门急诊总量</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">2,678</span>
            <span class="hero-metric-unit">人次</span>
            <span class="hero-metric-badge badge-up">+4.2%</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon">
          <TechIcon name="bed" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">在院总患者数</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">1,863</span>
            <span class="hero-metric-unit">人</span>
            <span class="hero-metric-badge badge-stable">床位率 83.5%</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-amber">
          <TechIcon name="ecg" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">今日手术总台数</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">142</span>
            <span class="hero-metric-unit">台</span>
            <span class="hero-metric-badge badge-warn">术中 18台</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="ambulance" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">急诊抢救成功率</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">98.6%</span>
            <span class="hero-metric-badge badge-up">优级标杆</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="security" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">全院设备在线率</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">99.2%</span>
            <span class="hero-metric-badge badge-up">全域正常</span>
          </div>
        </div>
      </div>
    </div>

    <!-- UI Overlay Layout: Left Sidebar + Bottom Row -->
    <div class="ui-overlay">
      <!-- Left Column Panels -->
      <aside class="left-column">
        <!-- Panel 1: 当前就诊患者情况 -->
        <div class="tech-panel panel-patient">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="user" :size="14" />
            </div>
            <span>当前就诊患者情况</span>
          </div>

          <div class="panel-body">
            <div class="patient-sub-bar">
              <div class="current-badge">
                <span class="badge-icon-box">
                  <TechIcon name="user" :size="13" />
                </span>
                <span class="badge-label">当前就诊人数</span>
                <span class="badge-num">2678人</span>
              </div>
              <div class="chart-legends">
                <div class="legend-item"><span class="dot dot-cyan"></span> 门诊次数</div>
                <div class="legend-item"><span class="dot dot-sky"></span> 均次费用</div>
              </div>
            </div>

            <!-- ECharts Spline Waves -->
            <div ref="patientChartRef" class="chart-box-patient"></div>
          </div>
        </div>

        <!-- Panel 2: 医疗资源占用 -->
        <div class="tech-panel panel-resource">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="hospital" :size="14" />
            </div>
            <span>医疗资源占用</span>
          </div>

          <div class="panel-body">
            <!-- 4 Workorder Cards -->
            <div class="workorder-grid">
              <div class="wo-card">
                <div class="wo-title">
                  <TechIcon name="clipboard" :size="13" />
                  <span>工单总数</span>
                </div>
                <div class="wo-value">3937</div>
              </div>
              <div class="wo-card">
                <div class="wo-title">
                  <TechIcon name="cog" :size="13" />
                  <span>正在处理</span>
                </div>
                <div class="wo-value text-cyan">693</div>
              </div>
              <div class="wo-card">
                <div class="wo-title">
                  <TechIcon name="check-circle" :size="13" />
                  <span>处理完成</span>
                </div>
                <div class="wo-value text-green">2104</div>
              </div>
              <div class="wo-card">
                <div class="wo-title">
                  <TechIcon name="clock" :size="13" />
                  <span>待处理</span>
                </div>
                <div class="wo-value text-amber">503</div>
              </div>
            </div>

            <!-- 4 Resource Utilization Rows -->
            <div class="resource-rows">
              <div class="res-row">
                <div class="res-icon-box">
                  <TechIcon name="ecg" :size="15" />
                </div>
                <div class="res-label">空闲手术室占比</div>
                <div class="res-ratio">89<span class="slash">/167</span></div>
                <div class="res-pct-box">
                  <div class="progress-bar-bg">
                    <div class="progress-fill" style="width: 53%;"></div>
                  </div>
                  <span class="res-pct">53%</span>
                </div>
              </div>

              <div class="res-row">
                <div class="res-icon-box">
                  <TechIcon name="node" :size="15" />
                </div>
                <div class="res-label">空闲急诊室占比</div>
                <div class="res-ratio">52<span class="slash">/214</span></div>
                <div class="res-pct-box">
                  <div class="progress-bar-bg">
                    <div class="progress-fill fill-sky" style="width: 24%;"></div>
                  </div>
                  <span class="res-pct">24%</span>
                </div>
              </div>

              <div class="res-row">
                <div class="res-icon-box">
                  <TechIcon name="bed" :size="15" />
                </div>
                <div class="res-label">空闲病房占比</div>
                <div class="res-ratio">21<span class="slash">/188</span></div>
                <div class="res-pct-box">
                  <div class="progress-bar-bg">
                    <div class="progress-fill" style="width: 11%;"></div>
                  </div>
                  <span class="res-pct">11%</span>
                </div>
              </div>

              <div class="res-row">
                <div class="res-icon-box">
                  <TechIcon name="flask" :size="15" />
                </div>
                <div class="res-label">空闲化验房占比</div>
                <div class="res-ratio">45<span class="slash">/58</span></div>
                <div class="res-pct-box">
                  <div class="progress-bar-bg">
                    <div class="progress-fill fill-cyan" style="width: 85%;"></div>
                  </div>
                  <span class="res-pct text-cyan">85%</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <!-- Bottom Row Panels -->
      <footer class="bottom-row">
        <!-- Card 1: 能耗总览 (Water + Electricity) -->
        <div class="tech-panel panel-energy">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="bolt" :size="14" />
            </div>
            <span>能耗总览</span>
          </div>

          <div class="panel-body energy-split">
            <!-- Left: 耗水分析 -->
            <div class="energy-half">
              <div class="half-title">■ 耗水分析</div>
              <div class="half-summary">
                <div class="energy-icon-orb orb-water">
                  <TechIcon name="water" :size="18" />
                </div>
                <div class="summary-text">
                  <div class="val-big">1031<span class="unit">t</span></div>
                  <div class="val-trend">耗水总量 <span class="trend-up">▲ 51.21</span></div>
                </div>
                <div class="energy-mini-bars">
                  <div class="mini-bar-item">
                    <span class="bar-name">住院楼</span>
                    <div class="bar-track"><div class="bar-fill" style="width: 73%"></div></div>
                    <span class="bar-pct">73%</span>
                  </div>
                  <div class="mini-bar-item">
                    <span class="bar-name">门诊楼</span>
                    <div class="bar-track"><div class="bar-fill" style="width: 54%"></div></div>
                    <span class="bar-pct">54%</span>
                  </div>
                  <div class="mini-bar-item">
                    <span class="bar-name">急诊楼</span>
                    <div class="bar-track"><div class="bar-fill" style="width: 41%"></div></div>
                    <span class="bar-pct">41%</span>
                  </div>
                </div>
              </div>
              <!-- Water Histogram -->
              <div ref="waterChartRef" class="mini-hist-chart"></div>
            </div>

            <!-- Right: 耗电分析 -->
            <div class="energy-half">
              <div class="half-title">■ 耗电分析</div>
              <div class="half-summary">
                <div class="energy-icon-orb orb-power">
                  <TechIcon name="bolt" :size="18" />
                </div>
                <div class="summary-text">
                  <div class="val-big">1062<span class="unit">kwh</span></div>
                  <div class="val-trend">耗电总量 <span class="trend-up">▲ 51.21</span></div>
                </div>
                <div class="energy-mini-bars">
                  <div class="mini-bar-item">
                    <span class="bar-name">住院楼</span>
                    <div class="bar-track"><div class="bar-fill fill-amber" style="width: 42%"></div></div>
                    <span class="bar-pct">42%</span>
                  </div>
                  <div class="mini-bar-item">
                    <span class="bar-name">门诊楼</span>
                    <div class="bar-track"><div class="bar-fill fill-amber" style="width: 74%"></div></div>
                    <span class="bar-pct">74%</span>
                  </div>
                  <div class="mini-bar-item">
                    <span class="bar-name">急诊楼</span>
                    <div class="bar-track"><div class="bar-fill fill-amber" style="width: 68%"></div></div>
                    <span class="bar-pct">68%</span>
                  </div>
                </div>
              </div>
              <!-- Power Histogram -->
              <div ref="powerChartRef" class="mini-hist-chart"></div>
            </div>
          </div>
        </div>

        <!-- Card 2: 医疗资源详情 (Speedometer + Staff Chips) -->
        <div class="tech-panel panel-staff">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="doctor" :size="14" />
            </div>
            <span>医疗资源详情</span>
          </div>

          <div class="panel-body staff-body">
            <!-- Center Gauge Dial -->
            <div class="gauge-center-box">
              <div ref="staffGaugeRef" class="staff-gauge"></div>
              <div class="gauge-overlay-text">
                <span class="gauge-num">1589</span>
                <span class="gauge-lbl">职工总数</span>
              </div>
            </div>

            <!-- 6 Staff Role Chips -->
            <div class="staff-chips-grid">
              <div class="staff-chip">
                <span class="chip-icon-box"><TechIcon name="doctor" :size="13" /></span>
                <span class="chip-name">医生</span>
                <span class="chip-val">608人</span>
                <span class="chip-pct">25.8%</span>
              </div>
              <div class="staff-chip">
                <span class="chip-icon-box"><TechIcon name="nurse" :size="13" /></span>
                <span class="chip-name">护士</span>
                <span class="chip-val">793人</span>
                <span class="chip-pct">23.1%</span>
              </div>
              <div class="staff-chip">
                <span class="chip-icon-box"><TechIcon name="caregiver" :size="13" /></span>
                <span class="chip-name">护工</span>
                <span class="chip-val">816人</span>
                <span class="chip-pct">20.6%</span>
              </div>
              <div class="staff-chip">
                <span class="chip-icon-box"><TechIcon name="security" :size="13" /></span>
                <span class="chip-name">安保</span>
                <span class="chip-val">570人</span>
                <span class="chip-pct">18.9%</span>
              </div>
              <div class="staff-chip">
                <span class="chip-icon-box"><TechIcon name="logistics" :size="13" /></span>
                <span class="chip-name">后勤</span>
                <span class="chip-val">316人</span>
                <span class="chip-pct">14.5%</span>
              </div>
              <div class="staff-chip">
                <span class="chip-icon-box"><TechIcon name="users" :size="13" /></span>
                <span class="chip-name">其他</span>
                <span class="chip-val">281人</span>
                <span class="chip-pct">15.4%</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Card 3: 环境监测 (Radar + Thermometer Dial) -->
        <div class="tech-panel panel-env">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="sensor" :size="14" />
            </div>
            <span>环境监测</span>
          </div>

          <div class="panel-body env-body">
            <!-- Radar Chart -->
            <div class="env-radar-col">
              <div ref="radarChartRef" class="radar-chart"></div>
            </div>

            <!-- Temperature Ring Meter -->
            <div class="env-temp-col">
              <div ref="tempGaugeRef" class="temp-dial"></div>
              <div class="temp-center-text">
                <span class="temp-val">22.6</span>
                <span class="temp-unit">温度(℃)</span>
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

const showEmergencyModal = ref(false)

const patientChartRef = ref<HTMLDivElement>()
const waterChartRef = ref<HTMLDivElement>()
const powerChartRef = ref<HTMLDivElement>()
const staffGaugeRef = ref<HTMLDivElement>()
const radarChartRef = ref<HTMLDivElement>()
const tempGaugeRef = ref<HTMLDivElement>()

const charts: echarts.ECharts[] = []

const initPatientChart = () => {
  if (!patientChartRef.value) return
  const chart = echarts.init(patientChartRef.value)
  charts.push(chart)

  const hours = ['00', '02', '04', '06', '08', '10', '12', '14', '16', '18', '20', '22']
  const visits = [1500, 1800, 1500, 1750, 1600, 1750, 1650, 1950, 1850, 2000, 1900, 1850]
  const fees = [1100, 1300, 1000, 1200, 1100, 1250, 1200, 1400, 1300, 1450, 1350, 1300]

  chart.setOption({
    grid: { left: 42, right: 20, top: 25, bottom: 25 },
    tooltip: { trigger: 'axis' },
    xAxis: {
      type: 'category',
      data: hours,
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } },
      axisLabel: { color: '#8fa0bf', fontSize: 10 }
    },
    yAxis: [
      {
        type: 'value',
        name: '次/人',
        nameTextStyle: { color: '#8fa0bf', fontSize: 9 },
        min: 0,
        max: 2100,
        splitNumber: 4,
        splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.06)', type: 'dashed' } },
        axisLabel: { color: '#8fa0bf', fontSize: 10 }
      },
      {
        type: 'value',
        name: '费用/元',
        nameTextStyle: { color: '#8fa0bf', fontSize: 9 },
        min: 0,
        max: 2100,
        splitNumber: 4,
        show: true,
        splitLine: { show: false },
        axisLabel: { color: '#8fa0bf', fontSize: 10 }
      }
    ],
    series: [
      {
        name: '门诊次数',
        type: 'line',
        smooth: true,
        data: visits,
        symbol: 'none',
        lineStyle: { color: '#00b4d8', width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(0, 180, 216, 0.18)' },
            { offset: 1, color: 'rgba(0, 180, 216, 0.0)' }
          ])
        }
      },
      {
        name: '均次费用',
        type: 'line',
        yAxisIndex: 1,
        smooth: true,
        data: fees,
        symbol: 'none',
        lineStyle: { color: '#1e65eb', width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(30, 101, 235, 0.18)' },
            { offset: 1, color: 'rgba(30, 101, 235, 0.0)' }
          ])
        }
      }
    ]
  })
}

const initWaterChart = () => {
  if (!waterChartRef.value) return
  const chart = echarts.init(waterChartRef.value)
  charts.push(chart)

  const hours = Array.from({ length: 24 }, (_, i) => i.toString().padStart(2, '0'))
  const data = [280, 240, 210, 190, 220, 290, 420, 560, 680, 750, 710, 690, 620, 540, 590, 610, 650, 720, 800, 780, 720, 640, 510, 390]

  chart.setOption({
    grid: { left: 30, right: 10, top: 10, bottom: 20 },
    xAxis: {
      type: 'category',
      data: hours,
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } },
      axisLabel: { color: '#8fa0bf', fontSize: 8, interval: 3 }
    },
    yAxis: {
      type: 'value',
      max: 800,
      splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.06)', type: 'dashed' } },
      axisLabel: { color: '#8fa0bf', fontSize: 8 }
    },
    series: [
      {
        type: 'bar',
        barWidth: 5,
        data: data,
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#00b4d8' },
            { offset: 1, color: '#1e40af' }
          ]),
          borderRadius: [2, 2, 0, 0]
        }
      }
    ]
  })
}

const initPowerChart = () => {
  if (!powerChartRef.value) return
  const chart = echarts.init(powerChartRef.value)
  charts.push(chart)

  const hours = Array.from({ length: 24 }, (_, i) => i.toString().padStart(2, '0'))
  const data = [300, 260, 230, 210, 250, 350, 480, 620, 730, 790, 760, 730, 650, 580, 630, 660, 710, 780, 840, 810, 750, 680, 550, 420]

  chart.setOption({
    grid: { left: 30, right: 10, top: 10, bottom: 20 },
    xAxis: {
      type: 'category',
      data: hours,
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } },
      axisLabel: { color: '#8fa0bf', fontSize: 8, interval: 3 }
    },
    yAxis: {
      type: 'value',
      max: 800,
      splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.06)', type: 'dashed' } },
      axisLabel: { color: '#8fa0bf', fontSize: 8 }
    },
    series: [
      {
        type: 'bar',
        barWidth: 5,
        data: data,
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#f59e0b' },
            { offset: 1, color: '#b45309' }
          ]),
          borderRadius: [2, 2, 0, 0]
        }
      }
    ]
  })
}

const initStaffGauge = () => {
  if (!staffGaugeRef.value) return
  const chart = echarts.init(staffGaugeRef.value)
  charts.push(chart)

  chart.setOption({
    series: [
      {
        type: 'gauge',
        startAngle: 210,
        endAngle: -30,
        min: 0,
        max: 2000,
        splitNumber: 4,
        axisLine: {
          lineStyle: {
            width: 8,
            color: [
              [0.3, '#1e40af'],
              [0.8, '#1e65eb'],
              [1, '#00b4d8']
            ]
          }
        },
        pointer: {
          show: true,
          length: '65%',
          width: 3,
          itemStyle: { color: '#00b4d8' }
        },
        axisTick: { distance: -12, length: 4, lineStyle: { color: '#1e3868', width: 1 } },
        splitLine: { distance: -14, length: 6, lineStyle: { color: '#00b4d8', width: 2 } },
        axisLabel: { show: false },
        detail: { show: false },
        data: [{ value: 1589 }]
      }
    ]
  })
}

const initRadarChart = () => {
  if (!radarChartRef.value) return
  const chart = echarts.init(radarChartRef.value)
  charts.push(chart)

  chart.setOption({
    radar: {
      indicator: [
        { name: '温度', max: 100 },
        { name: '细菌', max: 100 },
        { name: '噪音', max: 100 },
        { name: '风速', max: 100 },
        { name: 'PM', max: 100 },
        { name: '湿度', max: 100 }
      ],
      shape: 'polygon',
      splitNumber: 4,
      axisName: { color: '#8fa0bf', fontSize: 10 },
      splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.08)', type: 'dashed' } },
      splitArea: {
        show: true,
        areaStyle: {
          color: ['rgba(16, 28, 54, 0.5)', 'rgba(12, 22, 44, 0.5)']
        }
      },
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } }
    },
    series: [
      {
        type: 'radar',
        data: [
          {
            value: [75, 55, 80, 60, 45, 70],
            name: '环境参数',
            symbol: 'circle',
            symbolSize: 4,
            itemStyle: { color: '#00b4d8' },
            lineStyle: { color: '#00b4d8', width: 2 },
            areaStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: 'rgba(0, 180, 216, 0.25)' },
                { offset: 1, color: 'rgba(30, 101, 235, 0.1)' }
              ])
            }
          }
        ]
      }
    ]
  })
}

const initTempGauge = () => {
  if (!tempGaugeRef.value) return
  const chart = echarts.init(tempGaugeRef.value)
  charts.push(chart)

  chart.setOption({
    series: [
      {
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 50,
        axisLine: {
          lineStyle: {
            width: 10,
            color: [
              [0.45, '#00b4d8'],
              [0.8, '#1e65eb'],
              [1, '#2563eb']
            ]
          }
        },
        pointer: { show: false },
        axisTick: { show: false },
        splitLine: { show: false },
        axisLabel: { show: false },
        detail: { show: false },
        data: [{ value: 22.6 }]
      }
    ]
  })
}

const handleResize = () => {
  charts.forEach(c => c.resize())
}

onMounted(() => {
  setTimeout(() => {
    initPatientChart()
    initWaterChart()
    initPowerChart()
    initStaffGauge()
    initRadarChart()
    initTempGauge()
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
.overview-view {
  position: relative;
  width: 1920px;
  height: 1016px;
  overflow: hidden;
  background-color: var(--bg-dark);
}

/* 3D Campus Stage */
.campus-stage {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.campus-bg-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: contrast(1.08) brightness(0.95);
}

.stage-vignette {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(circle at 55% 42%, transparent 35%, rgba(10, 17, 38, 0.85) 90%);
  pointer-events: none;
}

/* 3D Building Pins */
.building-pin {
  position: absolute;
  transform: translate(-50%, -100%);
  display: flex;
  flex-direction: column;
  align-items: center;
  cursor: pointer;
  z-index: 10;
  transition: transform 0.25s ease;
}

.building-pin:hover {
  transform: translate(-50%, -108%) scale(1.06);
}

.pin-card {
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(16, 28, 54, 0.94);
  border: 1px solid #1e3a68;
  border-radius: 4px;
  padding: 4px 10px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(10px);
}

.pin-icon-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #38bdf8;
}

.pin-text {
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  letter-spacing: 0.5px;
}

.pin-stem {
  width: 2px;
  height: 16px;
  background: linear-gradient(180deg, #1e65eb, transparent);
}

.pin-pulse {
  position: absolute;
  bottom: -4px;
  left: 50%;
  transform: translateX(-50%);
  width: 14px;
  height: 6px;
  background: rgba(30, 101, 235, 0.6);
  border-radius: 50%;
  box-shadow: 0 0 8px rgba(30, 101, 235, 0.4);
}

/* Alert Pin for Emergency */
.pin-card-alert {
  border-color: #ef4444;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
  position: relative;
}

.pin-card-alert .alert-icon {
  color: #ef4444;
}

.alert-beacon-dot {
  width: 7px;
  height: 7px;
  background-color: #ef4444;
  border-radius: 50%;
  box-shadow: 0 0 6px #ef4444;
  animation: techPulse 1.2s infinite;
}

.stem-alert {
  background: linear-gradient(180deg, #ef4444, transparent);
}

.pulse-alert {
  background: rgba(239, 68, 68, 0.7);
  box-shadow: 0 0 8px rgba(239, 68, 68, 0.4);
  animation: alertPulseRed 1.5s infinite;
}

/* Parking Pin */
.pin-card-parking {
  border-color: #10b981;
}

.parking-icon {
  color: #10b981;
}

/* Emergency Detail Modal (Image 2 replica) */
.emergency-modal {
  position: absolute;
  transform: translate(25px, -50px);
  width: 330px;
  background: var(--bg-panel);
  border: 1px solid var(--border-panel-light);
  border-radius: 4px;
  box-shadow: var(--shadow-modal);
  backdrop-filter: blur(16px);
  z-index: 50;
  padding: 12px 16px;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--border-panel);
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
  width: 12px;
  height: 14px;
  background:
    linear-gradient(#00b4d8, #00b4d8) 0% 50% / 2px 8px no-repeat,
    linear-gradient(#38bdf8, #38bdf8) 50% 50% / 2px 14px no-repeat,
    linear-gradient(#1e65eb, #1e65eb) 100% 50% / 2px 10px no-repeat;
  border-radius: 1px;
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

.metric-row-3 {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: var(--bg-card-solid);
  border-radius: 4px;
  padding: 8px 12px;
  margin-bottom: 10px;
  border: 1px solid var(--border-card);
}

.metric-col {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.metric-label {
  font-size: 11px;
  color: #8fa0bf;
}

.metric-val {
  font-family: var(--font-number);
  font-size: 17px;
  font-weight: 700;
  color: #ffffff;
}

.metric-val.highlight {
  color: #38bdf8;
  text-shadow: none;
}

.divider-v {
  width: 1px;
  height: 24px;
  background: rgba(255, 255, 255, 0.08);
}

.metric-row-2 {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
  gap: 12px;
}

.metric-item-horizontal {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #132244;
  padding: 6px 10px;
  border-radius: 3px;
  border-left: 2px solid #1e65eb;
  border: 1px solid #192c55;
  border-left-width: 3px;
  border-left-color: #1e65eb;
}

.metric-sublabel {
  font-size: 11px;
  color: #8fa0bf;
}

.metric-subval {
  font-family: var(--font-number);
  font-size: 12.5px;
  font-weight: 700;
  color: #ffffff;
}

.metric-footer-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  background: #132244;
  border: 1px solid #192c55;
  border-radius: 3px;
  margin-top: 4px;
}

.metric-score {
  font-family: var(--font-number);
  font-size: 15px;
  font-weight: 700;
  color: #10b981;
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

.left-column {
  width: 430px;
  display: flex;
  flex-direction: column;
  gap: 15px;
  pointer-events: auto;
}

.bottom-row {
  width: 100%;
  height: 265px;
  display: grid;
  grid-template-columns: 2.3fr 1.8fr 1.8fr;
  gap: 16px;
  pointer-events: auto;
}

/* Left Panel 1: Patient Status */
.panel-patient {
  height: 310px;
  display: flex;
  flex-direction: column;
}

.panel-patient .panel-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 10px 14px;
}

.patient-sub-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 6px;
}

.current-badge {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #132244;
  border: 1px solid #192c55;
  padding: 4px 10px;
  border-radius: 4px;
}

.badge-icon-box {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #38bdf8;
}

.badge-label {
  font-size: 11.5px;
  color: #8fa0bf;
}

.badge-num {
  font-family: var(--font-number);
  font-size: 14px;
  font-weight: 700;
  color: #ffffff;
}

.chart-legends {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 11px;
  color: #cbd5e1;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 5px;
}

.dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}

.dot-cyan {
  background-color: #00b4d8;
}

.dot-sky {
  background-color: #1e65eb;
}

.chart-box-patient {
  flex: 1;
  width: 100%;
}

/* Left Panel 2: Resource Utilization */
.panel-resource {
  height: 375px;
  display: flex;
  flex-direction: column;
}

.panel-resource .panel-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 12px 14px;
}

.workorder-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}

.wo-card {
  background: linear-gradient(145deg, rgba(22, 38, 68, 0.85) 0%, rgba(15, 26, 48, 0.85) 100%);
  border: 1px solid rgba(34, 60, 105, 0.55);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.05);
  padding: 8px 6px;
  border-radius: 4px;
  text-align: center;
}

.wo-title {
  font-size: 11px;
  color: #8fa0bf;
  margin-bottom: 3px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.wo-value {
  font-family: var(--font-number);
  font-size: 17px;
  font-weight: 700;
  color: #ffffff;
}

.text-cyan {
  color: #38bdf8;
}

.text-green {
  color: #10b981;
}

.text-amber {
  color: #f59e0b;
}

.resource-rows {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.res-row {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12px;
}

.res-icon-box {
  width: 24px;
  height: 24px;
  background: #172b52;
  border: 1px solid #1e3868;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #38bdf8;
  border-radius: 3px;
}

.res-label {
  width: 95px;
  color: #cbd5e1;
  font-size: 12px;
}

.res-ratio {
  font-family: var(--font-number);
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  width: 55px;
}

.slash {
  color: #64748b;
  font-size: 10px;
}

.res-pct-box {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 8px;
}

.progress-bar-bg {
  flex: 1;
  height: 6px;
  background: #0d172e;
  border-radius: 3px;
  overflow: hidden;
  border: 1px solid #192c55;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #1e40af, #1e65eb);
}

.fill-sky {
  background: linear-gradient(90deg, #1e65eb, #00b4d8);
}

.fill-cyan {
  background: linear-gradient(90deg, #00b4d8, #38bdf8);
}

.res-pct {
  font-family: var(--font-number);
  font-size: 12px;
  font-weight: 700;
  color: #ffffff;
  width: 34px;
  text-align: right;
}

/* Bottom Row Panel 1: Energy Overview */
.panel-energy .panel-body {
  height: calc(100% - 37px);
  padding: 8px 12px;
}

.energy-split {
  display: flex;
  gap: 12px;
  height: 100%;
}

.energy-half {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.half-title {
  font-size: 12px;
  font-weight: 600;
  color: #ffffff;
  margin-bottom: 4px;
}

.half-summary {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 4px;
}

.energy-icon-orb {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.orb-water {
  background: #132244;
  border: 1px solid #1e3868;
  color: #38bdf8;
}

.orb-power {
  background: #132244;
  border: 1px solid #1e3868;
  color: #f59e0b;
}

.summary-text {
  width: 80px;
}

.val-big {
  font-family: var(--font-number);
  font-size: 17px;
  font-weight: 700;
  color: #ffffff;
}

.unit {
  font-size: 10px;
  color: #8fa0bf;
  margin-left: 2px;
}

.val-trend {
  font-size: 9px;
  color: #8fa0bf;
}

.trend-up {
  color: #f59e0b;
}

.energy-mini-bars {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.mini-bar-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
}

.bar-name {
  width: 36px;
  color: #8fa0bf;
}

.bar-track {
  flex: 1;
  height: 4px;
  background: #0d172e;
  border-radius: 2px;
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  background: #00b4d8;
}

.fill-amber {
  background: #f59e0b;
}

.bar-pct {
  font-family: var(--font-number);
  font-size: 10px;
  color: #cbd5e1;
  width: 24px;
  text-align: right;
}

.mini-hist-chart {
  flex: 1;
  width: 100%;
  min-height: 80px;
}

/* Bottom Row Panel 2: Staff Details */
.panel-staff .panel-body {
  height: calc(100% - 37px);
  display: flex;
  flex-direction: column;
  padding: 8px 12px;
}

.gauge-center-box {
  position: relative;
  width: 100%;
  height: 90px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.staff-gauge {
  width: 100%;
  height: 100%;
}

.gauge-overlay-text {
  position: absolute;
  top: 52%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
}

.gauge-num {
  font-family: var(--font-number);
  font-size: 20px;
  font-weight: 800;
  color: #ffffff;
}

.gauge-lbl {
  font-size: 10px;
  color: #8fa0bf;
}

.staff-chips-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
  margin-top: 6px;
}

.staff-chip {
  display: flex;
  align-items: center;
  gap: 5px;
  background: #132244;
  border: 1px solid #192c55;
  padding: 5px 6px;
  border-radius: 3px;
}

.chip-icon-box {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #38bdf8;
}

.chip-name {
  font-size: 11px;
  color: #8fa0bf;
}

.chip-val {
  font-family: var(--font-number);
  font-size: 12px;
  font-weight: 600;
  color: #ffffff;
}

.chip-pct {
  font-family: var(--font-number);
  font-size: 10px;
  color: #38bdf8;
  margin-left: auto;
}

/* Bottom Row Panel 3: Environmental Monitoring */
.panel-env .panel-body {
  height: calc(100% - 37px);
  display: flex;
  padding: 8px 12px;
}

.env-radar-col {
  flex: 1.2;
  height: 100%;
}

.radar-chart {
  width: 100%;
  height: 100%;
}

.env-temp-col {
  flex: 1;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.temp-dial {
  width: 100%;
  height: 100%;
}

.temp-center-text {
  position: absolute;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.temp-val {
  font-family: var(--font-number);
  font-size: 26px;
  font-weight: 800;
  color: #ffffff;
}

.temp-unit {
  font-size: 11px;
  color: #8fa0bf;
}

/* Transitions */
.pop-scale-enter-active,
.pop-scale-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}

.pop-scale-enter-from,
.pop-scale-leave-to {
  opacity: 0;
  transform: translate(25px, -50px) scale(0.9);
}
</style>
