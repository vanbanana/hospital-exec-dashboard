<template>
  <div class="epidemic-view">
    <!-- 3D Hospital Facade Stage -->
    <div class="facade-stage">
      <img src="/assets/hospital_facade.jpg" alt="医院正面数字孪生" class="facade-bg-img" />
      <div class="facade-vignette"></div>

      <!-- 5 Floating Callout Metric Cards (Exact Replica of Reference Image 3) -->
      <!-- Callout 1: Roof / Top Right -->
      <!-- Callout 1: Roof / Top Right -->
      <div class="facade-callout callout-top-right" style="top: 14%; right: 26%;">
        <div class="callout-card">
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="hospital" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">门诊总人次</span>
              <span class="callout-val">1,863<span class="callout-unit">(人)</span></span>
            </div>
          </div>
          <div class="callout-divider"></div>
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="clipboard" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">均次医疗费用</span>
              <span class="callout-val">385<span class="callout-unit">(元)</span></span>
            </div>
          </div>
        </div>
        <div class="callout-line line-tr">
          <div class="line-dot"></div>
        </div>
      </div>

      <!-- Callout 2: Upper Tower / Top Left -->
      <div class="facade-callout callout-top-center" style="top: 22%; left: 33%;">
        <div class="callout-card">
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="bed" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">已使用床位</span>
              <span class="callout-val">1,420<span class="callout-unit">(张)</span></span>
            </div>
          </div>
          <div class="callout-divider"></div>
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="bed" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">剩余可用床位</span>
              <span class="callout-val highlight">280<span class="callout-unit">(张)</span></span>
            </div>
          </div>
        </div>
        <div class="callout-line line-tc">
          <div class="line-dot"></div>
        </div>
      </div>

      <!-- Callout 3: West Wing / Mid Left -->
      <div class="facade-callout callout-mid-left" style="top: 36%; left: 27%;">
        <div class="callout-card">
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="user" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">今日门诊人数</span>
              <span class="callout-val">2,678<span class="callout-unit">(人)</span></span>
            </div>
          </div>
          <div class="callout-divider"></div>
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="ambulance" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">今日急诊接诊</span>
              <span class="callout-val">142<span class="callout-unit">(次)</span></span>
            </div>
          </div>
        </div>
        <div class="callout-line line-ml">
          <div class="line-dot"></div>
        </div>
      </div>

      <!-- Callout 4: Main Lobby / Bottom Center -->
      <div class="facade-callout callout-bottom-center" style="top: 52%; left: 35%;">
        <div class="callout-card">
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="hospital" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">今日入院办理</span>
              <span class="callout-val">86<span class="callout-unit">(人)</span></span>
            </div>
          </div>
          <div class="callout-divider"></div>
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="exit" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">今日出院核准</span>
              <span class="callout-val">79<span class="callout-unit">(人)</span></span>
            </div>
          </div>
        </div>
        <div class="callout-line line-bc">
          <div class="line-dot"></div>
        </div>
      </div>

      <!-- Callout 5: East Pavilion / Mid Right -->
      <div class="facade-callout callout-mid-right" style="top: 48%; right: 20%;">
        <div class="callout-card">
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="doctor" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">今日专家坐诊</span>
              <span class="callout-val">48<span class="callout-unit">(人)</span></span>
            </div>
          </div>
          <div class="callout-divider"></div>
          <div class="callout-half">
            <span class="callout-icon-box">
              <TechIcon name="clock" :size="15" />
            </span>
            <div class="callout-info">
              <span class="callout-lbl">在岗执业医生</span>
              <span class="callout-val">126<span class="callout-unit">(人)</span></span>
            </div>
          </div>
        </div>
        <div class="callout-line line-mr">
          <div class="line-dot"></div>
        </div>
      </div>
    </div>

    <!-- Central Hero KPI Ribbon (5 Epidemic & Nosocomial Telemetry Metrics) -->
    <div class="center-hero-ribbon">
      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="security" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">院感综合风险等级</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">低风险</span>
            <span class="hero-metric-badge badge-up">0级受控</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon">
          <TechIcon name="ecg" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">发热门诊当日筛查</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">128</span>
            <span class="hero-metric-unit">人次</span>
            <span class="hero-metric-badge badge-up">100% 阴性</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-amber">
          <TechIcon name="bed" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">负压隔离病房占用</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">3 / 16</span>
            <span class="hero-metric-unit">间</span>
            <span class="hero-metric-badge badge-stable">空闲 13间</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="flask" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">院内消杀达标率</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">99.8%</span>
            <span class="hero-metric-badge badge-up">优级达标</span>
          </div>
        </div>
      </div>

      <div class="hero-divider"></div>

      <div class="hero-metric-item">
        <div class="hero-metric-icon icon-green">
          <TechIcon name="doctor" :size="16" />
        </div>
        <div class="hero-metric-content">
          <span class="hero-metric-label">医护感染防护合规</span>
          <div class="hero-metric-val-wrap">
            <span class="hero-metric-value">100%</span>
            <span class="hero-metric-badge badge-up">标准规范</span>
          </div>
        </div>
      </div>
    </div>

    <!-- UI Overlay Layout -->
    <div class="ui-overlay">
      <!-- Left Column -->
      <aside class="left-column">
        <!-- Panel 1: 每日医疗情况 -->
        <div class="tech-panel panel-daily-med">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="hospital" :size="14" />
            </div>
            <span>每日医疗情况</span>
          </div>

          <div class="panel-body daily-body">
            <!-- Box 1: 就诊情况 -->
            <div class="daily-block">
              <div class="block-left">
                <span class="block-tag">今日就诊总数</span>
                <div class="block-circle">
                  <span class="circle-icon">
                    <TechIcon name="security" :size="18" />
                  </span>
                  <span class="circle-num">484<span class="unit">人</span></span>
                </div>
              </div>
              <div class="block-right">
                <div class="sub-stat-row">
                  <div class="sub-stat">
                    <span class="stat-dot dot-cyan"></span>
                    <span class="stat-name">今日门诊人数</span>
                    <span class="stat-num">255</span>
                  </div>
                  <div class="sub-stat">
                    <span class="stat-dot dot-sky"></span>
                    <span class="stat-name">今日急诊人数</span>
                    <span class="stat-num">89</span>
                  </div>
                </div>
                <div class="sub-stat-row">
                  <div class="sub-stat">
                    <span class="stat-dot dot-dim"></span>
                    <span class="stat-name">昨日门诊人数</span>
                    <span class="stat-num text-dim">354</span>
                  </div>
                  <div class="sub-stat">
                    <span class="stat-dot dot-dim"></span>
                    <span class="stat-name">昨日急诊人数</span>
                    <span class="stat-num text-dim">124</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Box 2: 住院情况 -->
            <div class="daily-block">
              <div class="block-left">
                <span class="block-tag">住院情况</span>
                <div class="block-circle circle-blue">
                  <span class="circle-icon">
                    <TechIcon name="bed" :size="18" />
                  </span>
                  <span class="circle-num">658<span class="unit">人</span></span>
                </div>
              </div>
              <div class="block-right">
                <div class="sub-stat-row">
                  <div class="sub-stat">
                    <span class="stat-dot dot-cyan"></span>
                    <span class="stat-name">今日住院人数</span>
                    <span class="stat-num">254</span>
                  </div>
                  <div class="sub-stat">
                    <span class="stat-dot dot-sky"></span>
                    <span class="stat-name">今日出院人数</span>
                    <span class="stat-num">124</span>
                  </div>
                </div>
                <div class="sub-stat-row">
                  <div class="sub-stat">
                    <span class="stat-dot dot-dim"></span>
                    <span class="stat-name">昨日住院人数</span>
                    <span class="stat-num text-dim">321</span>
                  </div>
                  <div class="sub-stat">
                    <span class="stat-dot dot-dim"></span>
                    <span class="stat-name">昨日出院人数</span>
                    <span class="stat-num text-dim">147</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Panel 2: 今日在院医生数 -->
        <div class="tech-panel panel-doctor-count">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="doctor" :size="14" />
            </div>
            <span>今日在院医生数</span>
          </div>

          <div class="panel-body doctor-body">
            <div class="doctor-gauge-box">
              <div ref="doctorDialRef" class="doctor-dial"></div>
              <div class="doctor-center-badge">
                <span class="doc-val">24<span class="doc-unit">人</span></span>
                <span class="doc-lbl">在院医生数</span>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <!-- Bottom Row: 4 Panels -->
      <footer class="bottom-row-epidemic">
        <!-- 1. 病情诊断排行 -->
        <div class="tech-panel panel-diagnosis">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="clipboard" :size="14" />
            </div>
            <span>病情诊断排行</span>
          </div>
          <div class="panel-body p-table">
            <table class="tech-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>病名</th>
                  <th>查看次数</th>
                  <th>查看人数</th>
                  <th>当前治愈人数</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in diagnosisRankings" :key="item.no">
                  <td class="td-no">{{ item.no }}</td>
                  <td class="td-name">{{ item.name }}</td>
                  <td class="td-num">{{ item.views }}</td>
                  <td class="td-num">{{ item.people }}</td>
                  <td class="td-num text-cyan">{{ item.cured }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- 2. 近期病情画像 (3D Sphere) -->
        <div class="tech-panel panel-portrait">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="sphere" :size="14" />
            </div>
            <span>近期病情画像</span>
          </div>
          <div class="panel-body portrait-body">
            <div class="sphere-wrap">
              <img src="/assets/disease_portrait_sphere.jpg" alt="病情球体" class="sphere-img" />
              <!-- Disease Floating Tags -->
              <span class="disease-tag tag-top">鼻炎</span>
              <span class="disease-tag tag-right">流感</span>
              <span class="disease-tag tag-left">肺气肿</span>
              <span class="disease-tag tag-bottom">细菌性痢疾</span>
            </div>
          </div>
        </div>

        <!-- 3. 各科室床位使用情况 (Divergent Horizontal Bars) -->
        <div class="tech-panel panel-beds">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="bed" :size="14" />
            </div>
            <span>各科室床位使用情况</span>
          </div>
          <div class="panel-body beds-body">
            <div class="bed-legends">
              <div class="legend-item"><span class="dot dot-cyan"></span> 使用床位</div>
              <div class="legend-item"><span class="dot dot-blue"></span> 剩余床位</div>
            </div>
            <div class="bed-list">
              <div v-for="dept in departmentBeds" :key="dept.name" class="bed-row">
                <span class="bed-used-val">已使用{{ dept.used }}</span>
                <div class="bed-dual-bar">
                  <div class="bed-bar-left-wrap">
                    <div class="bed-bar-left" :style="{ width: (dept.used / 40 * 100) + '%' }"></div>
                  </div>
                  <span class="bed-dept-title">{{ dept.name }}</span>
                  <div class="bed-bar-right-wrap">
                    <div class="bed-bar-right" :style="{ width: (dept.remain / 40 * 100) + '%' }"></div>
                  </div>
                </div>
                <span class="bed-remain-val">剩余{{ dept.remain }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- 4. 就诊人数医疗情况 (Line + Bar Mixed Chart) -->
        <div class="tech-panel panel-visits">
          <div class="tech-header">
            <div class="header-icon-box">
              <TechIcon name="chart-line" :size="14" />
            </div>
            <span>就诊人数医疗情况</span>
          </div>
          <div class="panel-body visits-body">
            <div class="visits-chart-wrap">
              <div class="chart-top-legend">
                <span class="legend-bar">■ 住院人数</span>
                <span class="legend-line">● 出院人数</span>
              </div>
              <div ref="visitsChartRef" class="visits-chart"></div>
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

const doctorDialRef = ref<HTMLDivElement>()
const visitsChartRef = ref<HTMLDivElement>()
const charts: echarts.ECharts[] = []

const diagnosisRankings = [
  { no: 'NO.1', name: '恶性肿瘤', views: 140, people: 125, cured: 125 },
  { no: 'NO.2', name: '高血压', views: 98, people: 79, cured: 79 },
  { no: 'NO.3', name: '心肌病', views: 88, people: 88, cured: 88 },
  { no: 'NO.4', name: '肺炎', views: 85, people: 79, cured: 79 },
  { no: 'NO.5', name: '急性阑尾炎', views: 82, people: 58, cured: 58 },
  { no: 'NO.6', name: '急性肠胃炎', views: 77, people: 32, cured: 32 }
]

const departmentBeds = [
  { name: '科室一', used: 15, remain: 35 },
  { name: '科室二', used: 24, remain: 12 },
  { name: '科室三', used: 21, remain: 25 },
  { name: '科室四', used: 9, remain: 16 },
  { name: '科室五', used: 18, remain: 27 },
  { name: '科室六', used: 22, remain: 33 }
]

const initDoctorDial = () => {
  if (!doctorDialRef.value) return
  const chart = echarts.init(doctorDialRef.value)
  charts.push(chart)

  chart.setOption({
    series: [
      {
        type: 'gauge',
        startAngle: 210,
        endAngle: -30,
        min: 0,
        max: 50,
        splitNumber: 5,
        axisLine: {
          lineStyle: {
            width: 10,
            color: [
              [0.48, '#00b4d8'],
              [0.8, '#1e65eb'],
              [1, '#2563eb']
            ]
          }
        },
        pointer: {
          show: true,
          length: '60%',
          width: 3,
          itemStyle: { color: '#00b4d8' }
        },
        axisTick: { distance: -14, length: 4, lineStyle: { color: '#1e3868', width: 1 } },
        splitLine: { distance: -16, length: 6, lineStyle: { color: '#00b4d8', width: 2 } },
        axisLabel: { show: false },
        detail: { show: false },
        data: [{ value: 24 }]
      }
    ]
  })
}

const initVisitsChart = () => {
  if (!visitsChartRef.value) return
  const chart = echarts.init(visitsChartRef.value)
  charts.push(chart)

  const dates = ['04/13', '04/14', '04/15', '04/16', '04/17', '04/18', '04/19', '04/20', '04/21', '04/22', '04/23', '04/24']
  const inpatient = [1100, 1050, 1450, 1300, 1500, 1420, 1480, 1390, 1580, 1250, 1320, 1400]
  const discharge = [850, 720, 950, 890, 1100, 980, 1050, 920, 1180, 910, 880, 990]

  chart.setOption({
    grid: { left: 35, right: 15, top: 25, bottom: 25 },
    tooltip: { trigger: 'axis' },
    xAxis: {
      type: 'category',
      data: dates,
      axisLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.12)' } },
      axisLabel: { color: '#8fa0bf', fontSize: 9 }
    },
    yAxis: {
      type: 'value',
      name: '次/人',
      nameTextStyle: { color: '#8fa0bf', fontSize: 9 },
      min: 0,
      max: 2100,
      splitLine: { lineStyle: { color: 'rgba(255, 255, 255, 0.06)', type: 'dashed' } },
      axisLabel: { color: '#8fa0bf', fontSize: 9 }
    },
    series: [
      {
        name: '住院人数',
        type: 'line',
        smooth: true,
        data: inpatient,
        lineStyle: { color: '#00b4d8', width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(0, 180, 216, 0.18)' },
            { offset: 1, color: 'rgba(0, 180, 216, 0.0)' }
          ])
        },
        symbol: 'circle',
        symbolSize: 3,
        itemStyle: { color: '#00b4d8' }
      },
      {
        name: '出院人数',
        type: 'bar',
        barWidth: 6,
        data: discharge,
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#1e65eb' },
            { offset: 1, color: '#1e40af' }
          ]),
          borderRadius: [2, 2, 0, 0]
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
    initDoctorDial()
    initVisitsChart()
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
.epidemic-view {
  position: relative;
  width: 1920px;
  height: 1016px;
  overflow: hidden;
  background-color: var(--bg-dark);
}

/* 3D Facade Stage */
.facade-stage {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.facade-bg-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: contrast(1.08) brightness(0.95);
}

.facade-vignette {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(circle at 55% 42%, transparent 35%, rgba(10, 17, 38, 0.85) 90%);
  pointer-events: none;
}

/* Floating Callout Badges with Connecting Lines */
.facade-callout {
  position: absolute;
  z-index: 10;
  pointer-events: auto;
}

.callout-card {
  display: flex;
  align-items: center;
  background: rgba(16, 28, 54, 0.94);
  border: 1px solid #1e3a68;
  border-radius: 4px;
  padding: 5px 10px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(10px);
}

.callout-half {
  display: flex;
  align-items: center;
  gap: 8px;
}

.callout-icon-box {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #38bdf8;
}

.callout-info {
  display: flex;
  flex-direction: column;
}

.callout-lbl {
  font-size: 10.5px;
  color: #8fa0bf;
}

.callout-val {
  font-family: var(--font-number);
  font-size: 14px;
  font-weight: 700;
  color: #ffffff;
}

.callout-val.highlight {
  color: #38bdf8;
  text-shadow: none;
}

.callout-unit {
  font-size: 9px;
  color: #64748b;
  margin-left: 2px;
}

.callout-divider {
  width: 1px;
  height: 20px;
  background: rgba(255, 255, 255, 0.08);
  margin: 0 10px;
}

/* Leader Lines */
.callout-line {
  position: absolute;
  pointer-events: none;
}

.line-dot {
  width: 6px;
  height: 6px;
  background: #00b4d8;
  border-radius: 50%;
  box-shadow: 0 0 6px rgba(0, 180, 216, 0.4);
  position: absolute;
}

.line-tr {
  bottom: -20px;
  right: 40px;
  width: 2px;
  height: 20px;
  background: linear-gradient(180deg, #1e65eb, transparent);
}
.line-tr .line-dot { bottom: 0; left: -2px; }

.line-tc {
  bottom: -24px;
  left: 50%;
  width: 2px;
  height: 24px;
  background: linear-gradient(180deg, #1e65eb, transparent);
}
.line-tc .line-dot { bottom: 0; left: -2px; }

.line-ml {
  bottom: -20px;
  left: 60px;
  width: 2px;
  height: 20px;
  background: linear-gradient(180deg, #1e65eb, transparent);
}
.line-ml .line-dot { bottom: 0; left: -2px; }

.line-bc {
  bottom: -18px;
  left: 50%;
  width: 2px;
  height: 18px;
  background: linear-gradient(180deg, #1e65eb, transparent);
}
.line-bc .line-dot { bottom: 0; left: -2px; }

.line-mr {
  bottom: -22px;
  right: 50px;
  width: 2px;
  height: 22px;
  background: linear-gradient(180deg, #1e65eb, transparent);
}
.line-mr .line-dot { bottom: 0; left: -2px; }

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

.bottom-row-epidemic {
  width: 100%;
  height: 265px;
  display: grid;
  grid-template-columns: 1.35fr 1fr 1.4fr 1.55fr;
  gap: 16px;
  pointer-events: auto;
}

/* Left Panel 1: Daily Med */
.panel-daily-med {
  height: 420px;
  display: flex;
  flex-direction: column;
}

.daily-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px;
  justify-content: space-around;
}

.daily-block {
  display: flex;
  align-items: center;
  gap: 16px;
  background: linear-gradient(145deg, rgba(22, 38, 68, 0.85) 0%, rgba(14, 24, 44, 0.85) 100%);
  border: 1px solid rgba(34, 60, 105, 0.55);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.05);
  border-radius: 4px;
  padding: 14px 16px;
}

.block-left {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 80px;
}

.block-tag {
  font-size: 10px;
  color: #8fa0bf;
  margin-bottom: 4px;
}

.block-circle {
  width: 58px;
  height: 58px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(30, 101, 235, 0.25) 0%, rgba(16, 28, 54, 0.5) 70%);
  border: 2px solid #1e65eb;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.circle-blue {
  background: radial-gradient(circle, rgba(0, 180, 216, 0.25) 0%, rgba(16, 28, 54, 0.5) 70%);
  border-color: #00b4d8;
}

.circle-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #38bdf8;
}

.circle-num {
  font-family: var(--font-number);
  font-size: 13.5px;
  font-weight: 700;
  color: #ffffff;
}

.circle-num .unit {
  font-size: 9px;
  color: #8fa0bf;
}

.block-right {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.sub-stat-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sub-stat {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
}

.stat-name {
  color: #cbd5e1;
}

.stat-num {
  font-family: var(--font-number);
  font-size: 13px;
  font-weight: 700;
  color: #ffffff;
}

.stat-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.dot-cyan { background-color: #00b4d8; }
.dot-sky { background-color: #1e65eb; }
.dot-dim { background-color: #64748b; }

/* Left Panel 2: Doctor Dial */
.panel-doctor-count {
  height: 265px;
  display: flex;
  flex-direction: column;
}

.doctor-body {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 10px;
}

.doctor-gauge-box {
  position: relative;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.doctor-dial {
  width: 100%;
  height: 100%;
}

.doctor-center-badge {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
}

.doc-val {
  font-family: var(--font-number);
  font-size: 26px;
  font-weight: 800;
  color: #ffffff;
}

.doc-unit {
  font-size: 12px;
  color: #8fa0bf;
}

.doc-lbl {
  font-size: 10.5px;
  color: #8fa0bf;
}

/* Bottom Panel 1: Diagnosis Table */
.panel-diagnosis .p-table {
  height: calc(100% - 37px);
  overflow-y: auto;
  padding: 8px 12px;
}

.td-no {
  font-family: var(--font-number);
  color: #38bdf8;
  font-weight: 700;
  width: 45px;
}

.td-name {
  color: #ffffff;
  font-weight: 500;
}

.td-num {
  font-family: var(--font-number);
  color: #cbd5e1;
}

/* Bottom Panel 2: Sphere Portrait */
.panel-portrait .portrait-body {
  height: calc(100% - 37px);
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  padding: 8px;
}

.sphere-wrap {
  position: relative;
  width: 145px;
  height: 145px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.sphere-img {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  filter: drop-shadow(0 0 10px rgba(30, 101, 235, 0.4));
  animation: techPulse 4s infinite ease-in-out;
}

.disease-tag {
  position: absolute;
  background: #132244;
  border: 1px solid #1e3868;
  color: #ffffff;
  font-size: 10.5px;
  padding: 2px 8px;
  border-radius: 4px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
}

.tag-top { top: 6%; left: 50%; transform: translateX(-50%); }
.tag-right { top: 40%; right: -25px; }
.tag-left { top: 40%; left: -25px; }
.tag-bottom { bottom: 6%; left: 50%; transform: translateX(-50%); }

/* Bottom Panel 3: Bed Usage Divergent Bars */
.panel-beds .beds-body {
  height: calc(100% - 37px);
  display: flex;
  flex-direction: column;
  padding: 8px 12px;
}

.bed-legends {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  font-size: 10.5px;
  color: #cbd5e1;
  margin-bottom: 6px;
}

.dot-blue {
  background-color: #1e65eb;
}

.bed-list {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-around;
}

.bed-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
}

.bed-used-val {
  font-family: var(--font-number);
  font-size: 11px;
  color: #00b4d8;
  font-weight: 600;
  width: 58px;
  text-align: right;
}

.bed-remain-val {
  font-family: var(--font-number);
  font-size: 11px;
  color: #38bdf8;
  font-weight: 600;
  width: 50px;
}

.bed-dual-bar {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 6px;
}

.bed-bar-left-wrap {
  flex: 1;
  height: 5px;
  background: #0d172e;
  display: flex;
  justify-content: flex-end;
  border-radius: 2px;
  overflow: hidden;
}

.bed-bar-left {
  height: 100%;
  background: linear-gradient(270deg, #00b4d8, #1e40af);
}

.bed-dept-title {
  width: 44px;
  text-align: center;
  color: #ffffff;
  font-size: 11px;
  font-weight: 600;
}

.bed-bar-right-wrap {
  flex: 1;
  height: 5px;
  background: #0d172e;
  border-radius: 2px;
  overflow: hidden;
}

.bed-bar-right {
  height: 100%;
  background: linear-gradient(90deg, #1e40af, #38bdf8);
}

/* Bottom Panel 4: Visits Mixed Chart */
.panel-visits .visits-body {
  height: calc(100% - 37px);
  padding: 8px 12px;
}

.visits-chart-wrap {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.chart-top-legend {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  font-size: 10.5px;
  color: #cbd5e1;
}

.legend-bar {
  color: #00b4d8;
}

.legend-line {
  color: #1e65eb;
}

.visits-chart {
  flex: 1;
  width: 100%;
}
</style>
