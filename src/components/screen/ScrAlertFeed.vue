<template>
  <ScrPanel title="实时告警">
    <!-- 契约 alerts.total_open（§14.1）：未传则不渲徽标 -->
    <template #head-extra>
      <span v-if="total != null" class="scr-badge feed-total">未闭环 {{ total }}</span>
    </template>
    <div v-if="items.length" ref="boxRef" class="alert-feed">
      <div class="feed-track" :class="{ 'is-scroll': scrolling }" :style="trackStyle">
        <!-- 首份为测量探针（RO 测 offsetHeight），滚动时追加副本保证轨道=单份×2 -->
        <div ref="probeRef" class="feed-copy">
          <div v-for="a in items" :key="a.id" class="feed-item" :class="`lv-${a.level}`">
            <span class="scr-tag" :class="levelClass(a.level)">{{ levelText(a.level) }}</span>
            <div class="feed-main">
              <span class="feed-title">{{ a.title }}</span>
              <span class="feed-meta">{{ a.dept }} · {{ fmtTime(a.occurred_at) }}</span>
            </div>
          </div>
        </div>
        <div v-for="ci in extraCopies" :key="`dup-${ci}`" class="feed-copy" aria-hidden="true">
          <div v-for="a in items" :key="a.id" class="feed-item" :class="`lv-${a.level}`">
            <span class="scr-tag" :class="levelClass(a.level)">{{ levelText(a.level) }}</span>
            <div class="feed-main">
              <span class="feed-title">{{ a.title }}</span>
              <span class="feed-meta">{{ a.dept }} · {{ fmtTime(a.occurred_at) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-else class="scr-empty">当前无未闭环告警</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import { computed, ref, watch, onMounted, onUnmounted, nextTick } from 'vue'
import ScrPanel from './ScrPanel.vue'
import type { AlertLevel, ScreenAlert } from '../../api/types'

const props = defineProps<{
  list?: ScreenAlert[]
  total?: number
}>()

/* 契约 §1.4-2：API 英文枚举 → 展示中文 高/中/低 */
const levelText = (lv: AlertLevel) => ({ urgent: '高', major: '中', minor: '低' })[lv] ?? lv
const levelClass = (lv: AlertLevel) =>
  ({ urgent: 'is-alert', major: 'is-warn', minor: 'is-info' })[lv] ?? 'is-info'

const items = computed(() => props.list ?? [])

/* B7：occurred_at 按字面墙钟渲染——直接截取 ISO 字段（契约恒 +08:00），不经本地时区换算 */
const fmtTime = (iso: string) => {
  const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/)
  return m ? `${m[2]}-${m[3]} ${m[4]}:${m[5]}` : iso
}

/* B1 跑马灯断带修复：复制份数按容器高/单份高动态计算。
   单份高 h1 ≤ 容器高 hc 时内容全部可见 → 不滚（否则 -50% 回绕必露空白）；
   h1 > hc 时总份数 = ceil(hc/h1)+1，轨道位移恰为单份高（track=2 份即 -50%），回绕无缝。 */
const boxRef = ref<HTMLElement>()
const probeRef = ref<HTMLElement>()
const copies = ref(1)
const copyH = ref(0)

const scrolling = computed(() => copies.value > 1)
const extraCopies = computed(() => copies.value - 1)
/* 恒定约 28px/s 滚速：时长随单份高度走，长短列表观感一致 */
const trackStyle = computed(() =>
  scrolling.value ? { animationDuration: `${Math.max(12, Math.round(copyH.value / 28))}s` } : {}
)

let ro: ResizeObserver | null = null
let measureFrame = 0
const scheduleMeasure = () => {
  cancelAnimationFrame(measureFrame)
  measureFrame = requestAnimationFrame(measure)
}
const measure = () => {
  const box = boxRef.value
  const probe = probeRef.value
  if (!box || !probe) return
  const h1 = probe.offsetHeight
  const hc = box.clientHeight
  copyH.value = h1
  copies.value = h1 > 0 && h1 > hc ? Math.ceil(hc / h1) + 1 : 1
}

onMounted(() => {
  ro = new ResizeObserver(scheduleMeasure)
  if (boxRef.value) ro.observe(boxRef.value)
  if (probeRef.value) ro.observe(probeRef.value)
})

watch(
  () => props.list,
  async () => {
    await nextTick() // 等 DOM 重排后再测量
    // list 晚到场景：feed 容器此刻才挂载，补挂观察
    if (ro && boxRef.value) ro.observe(boxRef.value)
    if (ro && probeRef.value) ro.observe(probeRef.value)
    scheduleMeasure()
  }
)

onUnmounted(() => {
  ro?.disconnect()
  cancelAnimationFrame(measureFrame)
  ro = null
})
</script>

<style scoped>
/* 面板头未闭环徽标：.scr-badge 族紧凑灰底（无向、中性） */
.feed-total {
  margin-left: auto;
  background: rgb(from var(--p-white) r g b / 0.08);
  color: var(--scr-text-3);
}

.alert-feed {
  flex: 1;
  min-height: 0;
  overflow: hidden;
  position: relative;
}

.feed-track {
  display: flex;
  flex-direction: column;
}

/* 滚动开启时才挂动画；时长由 trackStyle 按单份高度换算（~28px/s 恒速） */
.feed-track.is-scroll {
  animation: scr-scroll-y linear infinite;
}

.alert-feed:hover .feed-track.is-scroll {
  animation-play-state: paused;
}

.feed-copy {
  display: flex;
  flex-direction: column;
}

.feed-item {
  display: flex;
  align-items: center;
  gap: var(--scr-space-5);
  padding: var(--scr-space-4) var(--scr-space-1);
  border-bottom: 1px solid rgb(from var(--p-white) r g b / 0.05);
}

.feed-item.lv-urgent .feed-title {
  color: var(--scr-up);
}

.feed-main {
  display: flex;
  flex-direction: column;
  gap: var(--scr-space-1);
  min-width: 0;
}

.feed-title {
  font-size: var(--scr-fs-12);
  color: var(--scr-text-2);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.feed-meta {
  font-size: var(--scr-fs-xs);
  color: var(--scr-text-4);
}
</style>
