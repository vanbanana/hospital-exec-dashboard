# 验证与验收基线 — EDSS（v2.0）

> 版本：v2.0  
> 回答一个问题：**怎么证明这一版做完了？**

---

## 1. 门禁（不许跳过）

```bash
# 前端（当前唯一常跑门禁）
npx vue-tsc -b && npm run build

# 机械自查（输出应为空；后端启用后 src/ 与 cmd/ 同扫 *.go）
grep -rn "time.Now\|as any\|@ts-ignore" --include="*.ts" --include="*.go" src/ cmd/ 2>/dev/null

# 页面自验：无头截图后人工/半自动看图
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --screenshot=/tmp/shot.png --window-size=1568,880 --hide-scrollbars \
  http://localhost:5173/workbench/<路由>
```

后端启用后恢复：`go vet ./... && go build ./... && go test ./... -run Contract` + `sim validate`。

## 2. 前端设计验收（工作台）

| # | 验收项 | 判据 |
| :- | :--- | :--- |
| 1 | 风格统一 | 全部页面走 `--wb-*` token；无散落硬编码色值/字号（grep 抽查） |
| 2 | 设计红线 | 无卡片套卡片；无圆角矩形堆叠；无廉价渐变/发光/混搭；图标统一 lucide |
| 3 | 素材规范 | 写实/装饰图为生成 png 资产（`src/assets/`），无 SVG 硬画照片 |
| 4 | 场景贴合 | 内容符合医院业务（指标口径、科室名、流程真实），无 lorem 占位 |
| 5 | 布局整齐 | 同行元素顶/底对齐；间距统一走 `--wb-gap` 系；无歪歪扭扭 |
| 6 | 路由完整 | 侧栏 12 项（首页+11 业务页）全部可达，无死链无占位页 |

## 3. 数据层验收

| # | 验收项 | 判据 |
| :- | :--- | :--- |
| 1 | mock 集中 | `src/mock/` 集中管理；视图内 `grep "const.*=.*\["` 无散落大数据块 |
| 2 | 契约对齐 | mock 字段名在 api-contract 找得到（snake_case）；金额/率值口径照 api-contract §1.3（聚合万元/明细元；率值展示浮点） |
| 3 | 自洽 | 同指标跨页同值；环比方向与数值一致；床位占用≤开放 |
| 4 | 剧情可讲 | 预警→下钻链路数据相互印证（见 simulation-plan §2） |

## 4. 远期验收（后端启用后恢复）

v1.1 清单保留（契约冒烟/五级穿透/权限/时钟/重置），见 git 历史；届时按启用范围逐项恢复。
