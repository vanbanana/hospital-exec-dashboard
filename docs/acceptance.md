# 验证与验收基线 — EDSS（v2.2）

> 版本：v2.2（CI 流水线门禁生效：`.github/workflows/ci.yml` 为权威门禁，本地 `make ci` 复跑同一串）  
> 回答一个问题：**怎么证明这一版做完了？**

---

## 1. 门禁（不许跳过）

**权威门禁 = CI**：`.github/workflows/ci.yml` 在 push/PR→main 自动执行三 job——`frontend`（vue-tsc → test:unit → build）、`backend`（postgres:16 service 灌迁移+种子 → vet+build+test -race）、`mechanical`（机械自查豁免核对）。下方命令串是各 job 的人工可读规格；本地复跑同一串用 `make ci`。

```bash
# 前端
npx vue-tsc -b && npm run test:unit && npm run build

# 后端（在 backend/ 目录跑；实库集成测试——DATABASE_URL=读库、DATABASE_URL_W=写域克隆库，
# 库不可达则测试 Skip，本地跑注意别把"全跳过"当绿；CI 以灌库步骤硬失败兜底）
cd backend && go vet ./... && go build ./... && go test -count=1 -race ./...

# 机械自查（time.Now 豁免清单=传输/运维层墙钟:envelope.go 包络 ts、requestlog.go 延迟计时、
# write_alert.go failData ts(包络冻结故本地实现)、cmd/migrate/main.go 迁移耗时统计、
# cmd/loadbench/main.go 压测延迟/时长计时;clock.go 注释里的"time.Now"字样为文档串,
# 非调用——除此六处命中即违例）
grep -rn "time.Now\|as any\|@ts-ignore" --include="*.ts" --include="*.go" src/ backend/ 2>/dev/null

# 页面自验：无头截图后人工/半自动看图
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --screenshot=/tmp/shot.png --window-size=1568,880 --hide-scrollbars \
  http://localhost:5173/workbench/<路由>
```

注：`sim validate` 为 v1.1 残留命令，仓库中不存在，暂不列入门禁。

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
| 1 | 零假数据 | `src/mock/` 不存在；视图内 `grep "const.*=.*\["` 无契约形状数据块；无 `VITE_USE_MOCK` 引用 |
| 2 | 契约对齐 | `src/api/types.ts` 字段名在 api-contract 找得到（snake_case）；金额/率值口径照 api-contract §1.3（聚合万元/明细元；率值展示浮点） |
| 3 | 自洽 | 同指标跨页同值；环比方向与数值一致；床位占用≤开放 |
| 4 | 剧情可讲 | 预警→下钻链路数据相互印证（见 simulation-plan §2） |

## 4. P3 已恢复验收项（原"远期"清单回门禁）

v1.1 清单中随 P3 批落地、恢复条件已成就的项，挪回正式门禁；剩余远期项仍保留。

**已恢复（正式门禁，回归必过）**：

| # | 验收项 | 判据 |
| :- | :--- | :--- |
| 1 | 会话闭环 | `POST /auth/login` 成功签发 `edss_sid` HttpOnly Cookie + 全量上下文；`logout` 吊销幂等 `code=0`；无会话访问受保护端点 → `20001` |
| 2 | RBAC | `/sim/*` 全端点限 `admin`（无会话 → `20001`，非 admin → `20004`）；`GET /workbench/settings/config` 限 `admin`/`president`（其余 → `20004`）；写面角色矩阵与越权 `?role=` 切换闸 → `20005` |
| 3 | 写闭环 | 告警 `ack → dispatch → todo accept/report → alert done` / `close` 直闭环全链走通；幂等撞键 → `33002`/`33104`；`sys.audit_log` 落审计行 |
| 4 | sim 时钟 | `clock`/`tick`（≤43200/界校验）/`reset`（幂等）/`jobs` 台账全通；`SIM_ENABLED=0` 时 `/sim/*` → `NoRoute` → `10003` |

**仍远期**（保留 v1.1 口径，启用后恢复验收）：五级穿透与实名验密（R01–R03）、楼宇抽屉（R09）、Token 轮换（R12）、ChatBI（R13）、仿真生成引擎（`scope=full` 全量重灌/DayGen/Intraday 生成模型/AlertScan 去重键）、契约冒烟批量断言脚本化。
