# 设计令牌规范 — design-tokens.md

> 本文档是前端**全部视觉取值的唯一治理规范**。颜色 / 字号 / 间距 / 圆角 / 阴影 / 字重 / 行高 / 层级 / 透明度 / 动效时长，一律经令牌消费；**字面量只允许出现在 `src/styles/tokens.css` 中**。
>
> 依据：DTCG（Design Tokens Community Group）三层模型 + Tailwind/Radix 命名惯例；存量盘点见 `/tmp/audit-fe-r0/tokens.md`（r0 审计：散落 ≈570 声明点，token 化率 28%）。

## 1. 分层模型

```
L0 原色层 primitive  :root      --p-*   只有"值",不带用途语义,双形态共用
L1 语义层 semantic   :root 统一定义，前缀即形态隔离 --wb-* / --scr-*（R8 演进：Teleport 元素逃出布局作用域丢失全部 var()，L1 一律挂 :root）  绑定"用途",指向原色层
L2 组件层 component  (可选)      --{cmp}-*  组件内部件,指向语义层
```

- **禁止** L1/L2 直接写字面色值；一律 `var(--p-*)` 引用（例外：复合阴影、渐变、glass 半透明允许在内联值中写 rgba，但色基必须来自原色层，用 `rgb(from var(--p-x) r g b / alpha)` 或注释注明原色名）。
- **禁止**组件 `.vue` 文件出现任何颜色/字号/间距/圆角字面量（白名单：布局骨架一次性的几何尺寸，须注释注明"美术稿尺寸"）。
- ECharts/TS 侧取色：统一从 `chartPresets.ts` 单一出口读 token，不得再建第二份色值表。

## 2. 文件布局

```
src/styles/tokens.css   L0 原色层 + L1 语义层同挂 :root（--p-*/--wb-*/--scr-* 前缀隔离，R8 演进）
src/styles/index.css    全局 reset(无业务取值)
src/styles/workbench.css 仅保留"基元组件样式"(.wb-panel/.wb-table/...),取值全部 var(--wb-*)
src/styles/screen.css   大屏基元样式,取值全部 var(--scr-*)
src/components/workbench/chartPresets.ts  wb 图表出口:色值静态镜像+wbChartFs 字号档(注释挂 token 名)
src/components/screen/scrTokens.ts        scr 图表出口:运行时 getComputedStyle 读 --scr-*/--p-*
                                        (+readScrCanvas 读画布;读取器内 1920/1080 兜底为文档豁免的唯一 JS 字面)
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
  --p-cyan-400:#38bdf8;  --p-cyan-500:#00b4d8;
  /* 信号色(双形态共用原色) */
  --p-red-500:#ef4444;   --p-amber-500:#f59e0b; --p-amber-600:#d97706;
  --p-green-500:#10b981; --p-green-600:#059669; --p-teal-600:#0d9488;
  /* 信号浅底(wb tag/badge 族) */
  --p-green-bg:#e8f6ee; --p-red-bg:#feecec; --p-amber-bg:#fdf3e3;
  --p-teal-bg:#e5f6f3; --p-blue-bg:#e9f0fe;
  --p-white:#ffffff;
  /* 字体族 */
  --p-font-base:"Rajdhani", "Noto Sans SC", -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC",
    "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
  --p-font-number:"Rajdhani", "DIN Alternate", "Helvetica Neue", "Arial", sans-serif;
}
```

新增原色规则：与既有原色 ΔE 肉眼不可分辨（同色族差一档）→ 归并到最近档，不新增；确实为新色族 → 在本表登记并经 review。

## 4. L1 语义层 — 工作台（`:root`，既有 `--wb-*` 全保留为别名）

保留现有 24 个 token（值不变，改引用原色层重写），并按盘点补齐：

```css
:root {
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
  /* —— 字重/行高/字距 —— */
  --wb-fw-normal:400; --wb-fw-medium:500; --wb-fw-semibold:600; --wb-fw-bold:700;
  --wb-lh-tight:1.15; --wb-lh-compact:1.2; --wb-lh-normal:1.35; --wb-lh-loose:1.5;
  --wb-lh-solid:1; --wb-lh-mini:1.1; --wb-lh-snug:1.25; --wb-lh-mid:1.3;
  --wb-ls-sm:0.2px; --wb-ls-md:0.3px; --wb-ls-lg:0.5px; --wb-ls-xl:1px; --wb-ls-2xl:2px;
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
  --wb-opacity-muted:0.6; --wb-opacity-dimmed:0.7;
  --wb-z-raised:1; --wb-z-sticky:2; --wb-z-dropdown:3; --wb-z-modal:4; --wb-z-toast:5;
  --wb-dur-fast:0.15s; --wb-dur-normal:0.2s;
}
```

## 5. L1 语义层 — 大屏（`:root`，视觉基准 archive/smart-hospital-cockpit）

```css
:root {
  --scr-bg:var(--p-ink-950);
  --scr-panel:linear-gradient(135deg, rgba(16,26,48,.95), rgba(11,18,34,.96));
             /* REF tech-panel 玻璃底(复合渐变,色基 ink-800/900 间中插,无原色档) */
  --scr-border:rgba(30,64,115,.45);        /* 基础描边(复合值) */
  --scr-border-glow:rgba(56,189,248,.25);  /* cyan 辉光描边 */
  --scr-accent:var(--p-cyan-500); --scr-accent-bright:var(--p-cyan-400);
  --scr-text-1:var(--p-white); --scr-text-2:var(--p-slate-200);
  --scr-text-3:#8fa0bf;        --scr-text-4:var(--p-slate-500);
  --scr-up:var(--p-red-500); --scr-down:var(--p-green-500); --scr-warn:var(--p-amber-500);
  --scr-radius-card:4px; --scr-radius-tag:3px; --scr-radius-badge:2px;
  --scr-shadow-panel:0 8px 24px rgba(0,4,15,.55), inset 0 1px 0 rgba(255,255,255,.05);
  --scr-fs-axis:10px; --scr-fs-xxs:8px; --scr-fs-xs:10px; --scr-fs-sm:11px;
  /* fs-axis 升 10px 与 fs-xs 同值不同槽(轴标语义);REF 折线轴标=10px */
  --scr-fs-12:12px; --scr-fs-14:14px; --scr-fs-19:19px;
  /* 新档:表格/res-label=12、面板标题=14、面板大数字=19(spec §2.3 半档命名) */
  --scr-fs-md:13px; --scr-fs-title:20px;
  --scr-fw-medium:500; --scr-fw-semibold:600; --scr-fw-bold:700;
  --scr-lh-tight:1.15; --scr-lh-normal:1.4;
  --scr-ls-sm:0.3px; --scr-ls-mid:0.5px;
  --scr-ls-md:1px; --scr-ls-lg:1.4px; --scr-ls-xl:1.5px;
  --scr-opacity-sub:0.85;
  --scr-z-pin:2; --scr-z-overlay:5;
  --scr-dur-fast:0.18s; --scr-dur-normal:0.2s;
  /* 间距阶梯(收编 screen 域全部 padding/gap/margin 字面量,就近吸附) */
  --scr-space-1:2px;  --scr-space-2:4px;  --scr-space-3:6px;  --scr-space-4:8px;
  --scr-space-5:10px; --scr-space-6:12px; --scr-space-7:14px; --scr-space-8:16px;
  --scr-space-10:24px;
  /* 图表语义(scrTokens.ts 唯一引用源;alpha 变体色基注明原色档) */
  --scr-chart-axis:rgba(255,255,255,.12);      /* p-white @ .12 轴线(REF 白基弱化) */
  --scr-chart-grid:rgba(255,255,255,.06);      /* p-white @ .06 分隔线 dashed */
  --scr-chart-mark:rgba(56,189,248,.035);      /* p-cyan-400 @ .035 象限高亮底 */
  --scr-chart-area-top:rgba(0,180,216,.18);    /* p-cyan-500 @ .18 面积渐变顶(REF) */
  --scr-chart-area-bottom:rgba(0,180,216,0);   /* p-cyan-500 @ 0 面积渐变底(保色相防黑化) */
  --scr-tooltip-bg:rgba(6,11,23,.94);          /* p-ink-950 @ .94 图表浮层底 */
  /* 面板解剖件(REF tech-panel/tech-header/res-row/tech-table,spec §2.2/§3) */
  --scr-panel-head-h:38px;                     /* 面板头高(8+8 内边距+14px 标题+底线) */
  --scr-blur-panel:12px;                       /* tech-panel backdrop-filter */
  --scr-head-line:rgba(28,43,70,.8);           /* 面板头底线;无原色档(#1c2b46) */
  --scr-royal:#1e65eb;                         /* REF 第一主蓝:系列2/表头顶/tab选中/进度条;
                                                  无原色档(spec §5.2 拟 --p-blue-650,与 blue-600/700 不可归并) */
  --scr-royal-deep:#1546af;                    /* REF 表头/tab 渐变底;无原色档(§5.2 拟 --p-blue-800) */
  --scr-navy-deep:#1e40af;                     /* REF 柱/进度条渐变底;无原色档(§5.2 拟 --p-navy-700) */
  --scr-inset-bg:var(--p-ink-800);             /* REF 徽章/芯片/卡内底 #132244 */
  --scr-inset-border:#1e3a68;                  /* REF 小件描边(review F7 归位精确档) */
  --scr-iconbox-bg:#172b52;                    /* REF res-icon-box 底;无原色档 */
  --scr-bar-track:#0d172e;                     /* REF 进度条轨道;无原色档(§5.2 拟 --p-ink-820) */
  --scr-th-bg:linear-gradient(180deg, var(--scr-royal), var(--scr-royal-deep));
                                               /* REF tech-table 表头渐变 */
  --scr-bar-fill:linear-gradient(90deg, var(--scr-navy-deep), var(--scr-royal));
  --scr-bar-fill-sky:linear-gradient(90deg, var(--scr-royal), var(--p-cyan-500));
  --scr-bar-fill-cyan:linear-gradient(90deg, var(--p-cyan-500), var(--p-cyan-400));
  --scr-bar-fill-alert:linear-gradient(90deg, var(--p-red-500), var(--p-amber-500));
                                               /* 进度条四档:默认/亮一档/满档青/告警(REF fill 族) */
  --scr-scrollbar-w:4px;                       /* REF 细滚动条 */
  --scr-scrollbar-thumb:#1c2b46;               /* REF 滚动条 thumb;无原色档 */
  /* 画布:1920×1080(裁决:cockpit 真大屏实际实现 + 会议室主流分辨率;
     archive/output 冻结稿 2048×1152 为旧稿值,不再采用)
     消费方:ScreenLayout 经 scrTokens.readScrCanvas() 运行时读取——禁止 JS 内再写 1920/1080 字面量 */
  --scr-canvas-w:1920px; --scr-canvas-h:1080px;

  /* —— P07 浮层布局度量(院区图垫底+浮层面板,frontend-architecture §12.2;值为参考稿像素) —— */
  --scr-header-h:64px;        /* 顶栏高 */
  --scr-stage-h:calc(var(--scr-canvas-h) - var(--scr-header-h)); /* 主视口高 1016px */
  --scr-overlay-pad:16px;     /* ui-overlay 内边距 */
  --scr-col-left:430px;       /* 左列宽 */
  --scr-col-gap:15px;         /* 左列内面板间距 */
  --scr-ribbon-h:56px;        /* 顶部 KPI ribbon 高 */
  --scr-ribbon-px:18px;       /* ribbon 横向内边距 */
  --scr-bottom-h:265px;       /* 底行面板高 */

  /* —— 复刻新增材质/色基(复合值注明原色档,无档者标无原色档;
     --scr-royal/--scr-inset-border(pin 描边用此档)/--scr-fs-19(KPI 大数) 复用上方面板侧登记,勿再开) —— */
  --scr-header-bg:linear-gradient(180deg,var(--p-ink-900) 0%,#101a30 70%,#0c1428 100%); /* ink 系复合 */
  --scr-ribbon-bg:linear-gradient(90deg,rgba(14,24,46,.94) 0%,rgba(18,34,64,.92) 50%,rgba(14,24,46,.94) 100%); /* ink 系复合 */
  --scr-ribbon-border:rgba(30,64,115,.55);  /* --scr-border 色基加深 */
  --scr-ribbon-shadow:0 8px 24px rgba(0,4,15,.45), inset 0 1px 0 rgba(255,255,255,.08);
  --scr-vignette:radial-gradient(circle at 55% 42%,transparent 35%,rgba(10,17,38,.85) 90%); /* ink-950 系复合,偏心压边 */
  --scr-pin-bg:rgba(16,28,54,.94);   /* ink-900 系复合 */
  --scr-map-filter:contrast(1.08) brightness(.95); /* 底图调性滤镜 */
  --scr-blur-ribbon:14px;  --scr-blur-pop:10px;   /* pin 卡/弹层玻璃档(REF=10,区别于 --scr-blur-panel=12) */
  --scr-shadow-pin:0 4px 12px rgba(0,0,0,.5);
  --scr-radius-chip:12px;         /* 适配胶囊圆角(REF scale-indicator-pill,非全圆角) */

  /* —— 字号半档补齐(spec §2.3 阶梯,新增 5 档;fs-19 见上方面板侧) —— */
  --scr-fs-8p5:8.5px;   /* 头部英文副标 */
  --scr-fs-9p5:9.5px;   /* FIT/FILL 模式芯片 */
  --scr-fs-10p5:10.5px; /* KPI 单位 */
  --scr-fs-11p5:11.5px; /* 适配胶囊文本 */
  --scr-fs-21:21px;     /* 头部主标题 */
  /* 行高补齐(REF hero 区 1.1/1.2 档,命名同 wb 侧 --wb-lh-mini/compact) */
  --scr-lh-mini:1.1; --scr-lh-compact:1.2;

  /* —— 层级(spec §1.4:stage < overlay < ribbon < header) —— */
  --scr-z-stage:1; --scr-z-ui:20; --scr-z-ribbon:25; --scr-z-header:100;
  --scr-dur-pop:.25s; /* pin hover/modal 弹出 */
}
```

> P07 起字体族：`--p-font-base`/`--p-font-number` 栈首项挂自托管 `Rajdhani`（woff2 在 `src/assets/fonts/`，tokens.css 顶部 `@font-face`；无 CJK 字形，中文回落 Noto Sans SC/PingFang SC）。参考稿原栈 `'Rajdhani','Noto Sans SC',system-ui…` 的语义即"拉丁数字窄体科技字 + 中文无衬线"。

## 6. 治理规则

| 规则 | 内容 |
|---|---|
| R1 唯一出处 | 字面设计值只允许在 `tokens.css`;`.vue`/`.ts`/其他 `.css` 中出现 hex/rgb/px 字号间距圆角字面量 = 违例（§7 白名单除外） |
| R2 文档先行 | 新增/修改 token → 先改本文档 → 再改代码；代码里出现文档未登记的 token 名 = 违例 |
| R3 语义优先 | 能挂语义层就不许直用原色层；两个 .vue 需要同一取值 → 升语义 token。**配方豁免**：`rgb(from var(--p-*) r g b / α)` 相对色与一次性渐变底允许直用原色层（每个 tint 造 token 违反 R4 精神）；纯 `var(--p-*)` 赋值且无对应语义槽时须行内注释 `/* 原色直取 */` |
| R4 归并不扩 | 与原色 ΔE 不可分辨的值归并最近档；禁止再出现"第 6 个蓝" |
| R5 图表同源 | ECharts 配色/字号只允许经各域**单一出口**取色：wb 侧 `chartPresets.ts`（静态表，字面值必须行内注释标注对应 token 名，值与 token 同步）；scr 侧 `scrTokens.ts::readScrPalette()`（运行时 getComputedStyle 读 --scr-*/--p-*）。script 内 hex map（toneStyle/cardStyle/TITLE_COLORS）与 inline rgba 字面量全部消灭 |
| R6 死 token 清零 | 无消费方的 token 立即删除。**消费方认定**：运行时 var() 引用，或图表单一出口（chartPresets/scrTokens）对照表行内注释挂名——后者 token 定位为"语义锚"，允许无运行时 var 引用（`--wb-chart-*` 族即此类） |
| R7 别名言明 | 同值双名必须注释互指（--wb-up↔--wb-red） |
| R8 作用域登记 | L1 token 一律挂 `:root`——前缀（`--wb-*`/`--scr-*`）即形态隔离；`<Teleport to="body">` 元素（弹层/Toast）逃出 `.workbench-layout` DOM 子树会丢全部 var() 值（V3 实测：派发弹层透明、Toast 不渲染），故不允许把 L1 限定在布局容器选择器上。登录页（`.auth-layout`）不加 L1 块、直接消费 `:root` 上的 `--wb-*` |

## 7. 白名单（豁免字面量）

- `tokens.css` 内全部定义值（**L1 字面色允许条件**：复合值——shadow/渐变/rgba 变体——注释标明色基原色档；或无对应原色档的中插色、注释标"无原色档"。其余 L1 值必须 `var(--p-*)`）
- 一次性美术稿：几何尺寸**与色值**（Hero 渐变形状尺寸/取色、插画 anchor）——须行内注释 `/* 美术稿 */`
- `rgb(from var(--p-*) r g b / α)` 相对色配方（R3 配方豁免）
- `1px` 细线、`100%`/`50%` 比例、`0`/`auto`/`inherit`、CSS 动画关键帧内 opacity 0↔1
- `z-index`/`opacity`/`font-weight`/`line-height`/`letter-spacing`/`transition` 仅允许取 token（覆盖维，档已收编于各域 token 块）
- `font-family` 直用 `--p-font-base`/`--p-font-number`（字体族原色即语义，无 L1 别名）
- 数据层文件中的业务数值（非样式）；图表 JS `fontSize` 仅允许取各域出口常量（wb:`chartPresets.wbChartFs`，scr:`scrTokens` fs 槽）
- ECharts option 内的数据可视参数（`margin`/`grid` 内边距、`borderWidth`、`symbolSize`、悬停/极值 `opacity`）属图表出口实现细节，不归覆盖维——含在 `chartPresets`/`scrTokens` 出口或视图 option 内均可

## 8. 验收门禁

```bash
# 字面设计值扫描(tokens.css 豁免)——目标:颜色/字号/圆角零命中,间距仅剩白名单
rg -n "#[0-9a-fA-F]{3,8}\b|rgba?\(|hsla?\(" src/ --glob '!**/tokens.css'
rg -n "font-size:\s*\d|border-radius:\s*\d|padding:\s*\d|margin:\s*\d|gap:\s*\d" src/ --glob '!**/tokens.css'
# 覆盖维扫描(字重/行高/字距/透明/层级/时距)
rg -n "font-weight:\s*\d|line-height:\s*[\d.]|letter-spacing:\s*[\d.]|opacity:\s*[\d.]|z-index:\s*\d|transition:\s*[a-z-]+\s+[\d.]+s" src/ --glob '!**/tokens.css'
# TS 侧色值与图表字号
rg -n "#[0-9a-fA-F]{3,8}\b" src/ --glob '*.ts' --glob '!**/chartPresets.ts'
rg -n "fontSize:\s*\d" src/
# 幽灵引用核查(引用了未定义 token 应 0 命中——人工 diff tokens.css 定义集)
rg -o --no-filename 'var\(--[\w-]+' src/
```

收敛目标：色值字面量 `tokens.css` 外 0 命中；`chartPresets.ts` 以外 `.ts` 0 命中；图表 `fontSize` 仅经 `wbChartFs`/scrTokens fs 槽。
