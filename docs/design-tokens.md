# 设计令牌规范 — design-tokens.md

> 本文档是前端**全部视觉取值的唯一治理规范**。颜色 / 字号 / 间距 / 圆角 / 阴影 / 字重 / 行高 / 层级 / 透明度 / 动效时长，一律经令牌消费；**字面量只允许出现在 `src/styles/tokens.css` 中**。
>
> 依据：DTCG（Design Tokens Community Group）三层模型 + Tailwind/Radix 命名惯例；存量盘点见 `/tmp/audit-fe-r0/tokens.md`（r0 审计：散落 ≈570 声明点，token 化率 28%）。

## 1. 分层模型

```
L0 原色层 primitive  :root      --p-*   只有"值",不带用途语义,双形态共用
L1 语义层 semantic   按形态作用域 --wb-* / --scr-*  绑定"用途",指向原色层
L2 组件层 component  (可选)      --{cmp}-*  组件内部件,指向语义层
```

- **禁止** L1/L2 直接写字面色值；一律 `var(--p-*)` 引用（例外：复合阴影、渐变、glass 半透明允许在内联值中写 rgba，但色基必须来自原色层，用 `rgb(from var(--p-x) r g b / alpha)` 或注释注明原色名）。
- **禁止**组件 `.vue` 文件出现任何颜色/字号/间距/圆角字面量（白名单：布局骨架一次性的几何尺寸，须注释注明"美术稿尺寸"）。
- ECharts/TS 侧取色：统一从 `chartPresets.ts` 单一出口读 token，不得再建第二份色值表。

## 2. 文件布局

```
src/styles/tokens.css   L0 原色层 :root{--p-*} + L1 语义层 .workbench-layout{--wb-*}/.screen-layout{--scr-*}
src/styles/index.css    全局 reset(无业务取值)
src/styles/workbench.css 仅保留"基元组件样式"(.wb-panel/.wb-table/...),取值全部 var(--wb-*)
src/styles/screen.css   大屏基元样式(建 /screen 时创建),取值全部 var(--scr-*)
src/chartPresets.ts     ECharts 预设,颜色/字号读 token(getComputedStyle 或与 tokens.css 同源常量)
```

`variables.css` 废除：其深色 token 与 archive 冻结稿冲突（见 r0 审计 §三），全部作废按本文档重建；`--font-family-*` 迁入 tokens.css L0。

## 3. L0 原色层（primitive，值以盘点归并为准）

命名：`--p-{族}-{档}`；族 = slate / blue / navy / ink / cyan / red / amber / green / teal / green-bg 等信号浅底。

```css
:root {
  /* 中性 slate(双形态共用,Tailwind 档位) */
  --p-slate-50:#f8fafd;  --p-slate-100:#f1f5f9; --p-slate-150:#eef2f7;
  --p-slate-200:#e2e8f0; --p-slate-300:#cbd5e1; --p-slate-400:#94a3b8;
  --p-slate-500:#64748b; --p-slate-600:#475569; --p-slate-800:#1e293b;
  /* 蓝族(wb 主色 + scr 共享) */
  --p-blue-100:#eaf1fe;  --p-blue-300:#93c5fd; --p-blue-500:#3b82f6;
  --p-blue-600:#2563eb;  --p-blue-700:#1d4ed8; --p-navy-900:#0b1f47;
  /* scr 深色底族(cockpit 基准) */
  --p-ink-950:#060b17;   --p-ink-900:#0b1325;  --p-ink-800:#132244;
  --p-cyan-400:#38bdf8;  --p-cyan-500:#00b4d8; --p-cyan-glow:#00d2ff;
  /* 信号色(双形态共用原色) */
  --p-red-500:#ef4444;   --p-amber-500:#f59e0b; --p-amber-600:#d97706;
  --p-green-500:#10b981; --p-green-600:#059669; --p-teal-600:#0d9488;
  /* 信号浅底(wb tag/badge 族) */
  --p-green-bg:#e8f6ee; --p-red-bg:#feecec; --p-amber-bg:#fdf3e3;
  --p-teal-bg:#e5f6f3; --p-blue-bg:#e9f0fe;
  --p-white:#ffffff;
  /* 字体族 */
  --p-font-base:-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC",
    "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
  --p-font-number:"DIN Alternate", "Helvetica Neue", "Arial", sans-serif;
}
```

新增原色规则：与既有原色 ΔE 肉眼不可分辨（同色族差一档）→ 归并到最近档，不新增；确实为新色族 → 在本表登记并经 review。

## 4. L1 语义层 — 工作台（`.workbench-layout`，既有 `--wb-*` 全保留为别名）

保留现有 24 个 token（值不变，改引用原色层重写），并按盘点补齐：

```css
.workbench-layout {
  /* —— 既有(值不变,内部改为 var(--p-*)) —— */
  --wb-bg / --wb-surface / --wb-sidebar-bg / --wb-hover-bg
  --wb-border / --wb-hairline / --wb-input-border
  --wb-navy / --wb-primary / --wb-accent / --wb-accent-soft
  --wb-text-1 / --wb-text-2 / --wb-text-3 / --wb-text-4
  --wb-up / --wb-down / --wb-green / --wb-teal / --wb-amber / --wb-red
  /* 注:--wb-up 与 --wb-red、--wb-down 与 --wb-green 为语义别名对,
     保留双名但注释互指;图表侧绿色用 --wb-chart-green(--p-green-500) */
  --wb-radius-card / --wb-radius-inner / --wb-radius-tag
  --wb-gap / --wb-pad-x / --wb-pad-y
  --wb-shadow-card

  /* —— 新增:字号阶梯(r0 审计:108 处裸值,文档阶梯 11/12/13/15/18/22-24) —— */
  --wb-fs-2xs:10px; --wb-fs-xs:11px; --wb-fs-sm:12px; --wb-fs-md:13px;
  --wb-fs-lg:15px;  --wb-fs-xl:18px; --wb-fs-num:22px; --wb-fs-hero:24px;
  /* —— 字重/行高 —— */
  --wb-fw-normal:400; --wb-fw-medium:500; --wb-fw-semibold:600; --wb-fw-bold:700;
  --wb-lh-tight:1.15; --wb-lh-normal:1.35; --wb-lh-loose:1.5;
  /* —— 间距阶梯 —— */
  --wb-space-1:4px; --wb-space-2:8px; --wb-space-3:12px;
  --wb-space-4:16px; --wb-space-5:20px;
  /* —— 圆角补齐 —— */
  --wb-radius-sm:2px; --wb-radius-pill:999px;
  /* —— tag/badge 浅底族(消灭 4 处复制) —— */
  --wb-tag-green-bg:var(--p-green-bg); --wb-tag-red-bg:var(--p-red-bg);
  --wb-tag-amber-bg:var(--p-amber-bg); --wb-tag-teal-bg:var(--p-teal-bg);
  --wb-tag-blue-bg:var(--p-blue-bg);   --wb-tag-gray-bg:var(--p-slate-150);
  /* —— 组件件(收编基元内裸值) —— */
  --wb-th-bg:var(--p-slate-50);   --wb-bar-track:var(--p-slate-100);
  --wb-seg-bg:#eef3fa;            --wb-switch-off:var(--p-slate-300);
  --wb-scrollbar:var(--p-slate-300);
  /* —— 阴影族 —— */
  --wb-shadow-hover:0 4px 12px rgba(15,23,42,.06);
  --wb-shadow-accent:0 3px 8px rgba(37,99,235,.25);
  --wb-shadow-raised:0 1px 2px rgba(15,23,42,.08);
  /* —— 图表语义(chartPresets.ts 唯一引用源) —— */
  --wb-chart-text:var(--p-slate-500); --wb-chart-axis:var(--p-slate-400);
  --wb-chart-grid:#eef3f9;            --wb-chart-axis-line:#d7e0ee;
  --wb-chart-green:var(--p-green-500); --wb-chart-amber:var(--p-amber-500);
  --wb-chart-blue-1:var(--p-blue-700); --wb-chart-blue-2:var(--p-blue-600);
  --wb-chart-blue-3:var(--p-blue-500); --wb-chart-blue-4:var(--p-blue-300);
  /* —— 奖牌色 —— */
  --wb-rank-1:var(--p-amber-500); --wb-rank-2:var(--p-slate-400); --wb-rank-3:var(--p-amber-600);
  /* —— 布局度量 —— */
  --wb-sidebar-w:204px; --wb-header-h:64px; --wb-scrollbar-w:6px;
  /* —— 杂项 —— */
  --wb-opacity-dimmed:0.7; --wb-z-raised:1; --wb-z-sticky:2;
  --wb-dur-fast:0.15s; --wb-dur-normal:0.2s;
}
```

## 5. L1 语义层 — 大屏（`.screen-layout`，视觉基准 archive/smart-hospital-cockpit）

```css
.screen-layout {
  --scr-bg:var(--p-ink-950);  --scr-bg-deep:#061021;
  --scr-panel:rgba(14,23,42,.92);          /* ink-900 玻璃底 */
  --scr-panel-hover:rgba(26,44,78,.9);
  --scr-border:rgba(30,64,115,.45);        /* 基础描边 */
  --scr-border-glow:rgba(56,189,248,.25);  /* cyan 辉光描边 */
  --scr-accent:var(--p-cyan-500); --scr-accent-bright:var(--p-cyan-400);
  --scr-text-1:var(--p-white); --scr-text-2:var(--p-slate-200);
  --scr-text-3:#8fa0bf;        --scr-text-4:var(--p-slate-500);
  --scr-up:var(--p-red-500); --scr-down:var(--p-green-500); --scr-warn:var(--p-amber-500);
  --scr-radius-card:4px; --scr-radius-tag:3px; --scr-radius-badge:2px;
  --scr-shadow-panel:0 8px 24px rgba(0,4,15,.55), inset 0 1px 0 rgba(255,255,255,.05);
  --scr-fs-axis:9px; --scr-fs-sm:11px; --scr-fs-md:13px;
  --scr-fs-title:20px; --scr-fs-num:26px;
  /* 间距阶梯(收编 screen 域全部 padding/gap/margin 字面量,就近吸附) */
  --scr-space-1:2px;  --scr-space-2:4px;  --scr-space-3:6px;  --scr-space-4:8px;
  --scr-space-5:10px; --scr-space-6:12px; --scr-space-7:14px; --scr-space-8:16px;
  --scr-space-9:20px; --scr-space-10:22px;
  /* 图表语义(scrTokens.ts 唯一引用源;alpha 变体色基注明原色档) */
  --scr-chart-axis:rgba(148,163,184,.30);      /* p-slate-400 @ .30 轴线 */
  --scr-chart-grid:rgba(148,163,184,.08);      /* p-slate-400 @ .08 分隔线 */
  --scr-chart-mark:rgba(56,189,248,.035);      /* p-cyan-400 @ .035 象限高亮底 */
  --scr-chart-area-top:rgba(56,189,248,.22);   /* p-cyan-400 @ .22 面积渐变顶 */
  --scr-chart-area-bottom:rgba(56,189,248,0);  /* p-cyan-400 @ 0 面积渐变底(保色相防黑化) */
  --scr-tooltip-bg:rgba(6,11,23,.94);          /* p-ink-950 @ .94 图表浮层底 */
  /* 画布:1920×1080(裁决:cockpit 真大屏实际实现 + 会议室主流分辨率;
     archive/output 冻结稿 2048×1152 为旧稿值,不再采用) */
  --scr-canvas-w:1920px; --scr-canvas-h:1080px;
}
```

## 6. 治理规则

| 规则 | 内容 |
|---|---|
| R1 唯一出处 | 字面设计值只允许在 `tokens.css`;`.vue`/`.ts`/其他 `.css` 中出现 hex/rgb/px 字号间距圆角字面量 = 违例（§7 白名单除外） |
| R2 文档先行 | 新增/修改 token → 先改本文档 → 再改代码；代码里出现文档未登记的 token 名 = 违例 |
| R3 语义优先 | 能挂语义层就不许直用原色层；两个 .vue 需要同一取值 → 升语义 token |
| R4 归并不扩 | 与原色 ΔE 不可分辨的值归并最近档；禁止再出现"第 6 个蓝" |
| R5 图表同源 | ECharts 配色/字号只允许经各域**单一出口**取色：wb 侧 `chartPresets.ts`（静态表，字面值必须行内注释标注对应 token 名，值与 token 同步）；scr 侧 `scrTokens.ts::readScrPalette()`（运行时 getComputedStyle 读 --scr-*/--p-*）。script 内 hex map（toneStyle/cardStyle/TITLE_COLORS）与 inline rgba 字面量全部消灭 |
| R6 死 token 清零 | 无消费方的 token 立即删除（variables.css 13 个深色死 token 为首个执行对象） |
| R7 别名言明 | 同值双名必须注释互指（--wb-up↔--wb-red） |

## 7. 白名单（豁免字面量）

- `tokens.css` 内全部定义值
- 一次性美术稿几何（Hero 渐变形状尺寸、插画 anchor）——须行内注释 `/* 美术稿 */`
- `1px` 细线、`100%`/`50%` 比例、`0`/`auto`/`inherit`
- `z-index` 仅允许取 token（1/2 档已收编），更多层级先登记本文档
- mock 数据文件中的数值（非样式）

## 8. 验收门禁

```bash
# 字面设计值扫描(tokens.css 豁免)——目标:颜色/字号/圆角零命中,间距仅剩白名单
rg -n "#[0-9a-fA-F]{3,8}\b|rgba?\(|hsla?\(" src/ --glob '!styles/tokens.css'
rg -n "font-size:\s*\d|border-radius:\s*\d|padding:\s*\d|margin:\s*\d|gap:\s*\d" src/ --glob '!styles/tokens.css'
# TS 侧色值
rg -n "#[0-9a-fA-F]{3,8}\b" src/ --glob '*.ts' --glob '!chartPresets.ts'
```

收敛目标：色值字面量 `tokens.css` 外 0 命中；`chartPresets.ts` 以外 `.ts` 0 命中。
