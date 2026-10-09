# 验证与验收基线 — EDSS（v2.3）

> 版本：v2.3，2026-10-09 静态对齐。当前自动化入口与回归标准；更高工程标准及待办见 [工程验收计划](engineering-acceptance.md)。无法获取真实医院数据是固定约束，不影响工程验收范围。
> 回答一个问题：**怎么证明这一版做完了？**

---

## 1. 门禁（不许跳过）

`.github/workflows/ci.yml` 在 push/PR→main 执行 frontend/backend/mechanical 三个 job。配置定义检查范围，是否通过须有实际运行结果；当前托管 Actions 尚未验证。

| 入口 | 实际包含 | 前置条件与限制 |
| --- | --- | --- |
| make ci | 前端类型/单测/构建；Go vet/build/race；机械检查 | 读/写两库已初始化、Go SDK 可用；不含浏览器、部署配置和恢复 |
| python3 tests/deploy-config.py | Compose 配置与云启动脚本静态检查 | 配置检查，不等于实际 TLS/恢复演练 |
| scripts/cloud-dev.sh test | 容器内全量 Go race；缺席时初始化独立写域库 | 已启动同项目读库，首次较慢；不是完整前后端 CI |
| npm run test:e2e -- --grep-invert '生产权限模式' | 演示浏览器链路与页面巡检 | 演示后端、初始化合成库、Chromium |
| EDSS_TEST_PRODUCTION=1 npm run test:e2e -- tests/e2e/permissions.spec.ts | 生产授权模式浏览器 | 使用独立/隔离后端切换严格开关；HTTP 检查不验证 Secure Cookie |
| GitHub CI | 前端检查；两库迁移/种子 + Go race；演示浏览器、生产权限浏览器；部署配置、运维脚本语法与机械检查 | CI 权限阶段使用 HTTP、AUTH_COOKIE_SECURE=0；不包含容器 HTTPS、备份恢复与持续容量 |

完整安全部署的 HTTPS、证书、Secure Cookie 和恢复演练步骤见 [部署手册](production-deploy.md)；结果登记整改记录。不要把 make ci 通过描述为所有 CI 和交付门禁均已运行。下方为基础命令规格：

```bash
# 前端
npx vue-tsc -b && npm run test:unit && npm run build

# 后端（在 backend/ 目录跑；实库集成测试——DATABASE_URL=读库、DATABASE_URL_W=写域克隆库，
# 库不可达即失败，不能以跳过集成测试得到绿灯）
cd backend && go vet ./... && go build ./... && go test -count=1 -race ./...

# 机械自查（time.Now 豁免清单=传输/运维层墙钟:envelope.go 包络 ts、requestlog.go 延迟计时、
# write_alert.go failData ts(包络冻结故本地实现)、cmd/migrate/main.go 迁移耗时统计、
# cmd/loadbench/main.go 压测延迟/时长计时;clock.go 注释里的"time.Now"字样为文档串,
# 非调用——除此六处命中即违例）
grep -rn "time.Now\|as any\|@ts-ignore" --include="*.ts" --include="*.go" src/ backend/ 2>/dev/null

# macOS 可选截图（云环境使用上表 Playwright；截图仍需查看）
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
| 6 | 路由完整 | 侧栏 14 项（首页+11 业务页+工单+个人偏好）按 allowed_pages 展示，无死链 |

## 3. 数据层验收

| # | 验收项 | 判据 |
| :- | :--- | :--- |
| 1 | 后端合成数据单轨 | 运行中的视图经 API 取持久化合成数据，失败显示空/错/stale；不编造业务值。无 src/mock 或 VITE_USE_MOCK；单测替身允许 |
| 2 | 契约对齐 | `src/api/types.ts` 字段名在 api-contract 找得到（snake_case）；金额/率值口径照 api-contract §1.3（聚合万元/明细元；率值展示浮点） |
| 3 | 自洽 | 同指标在相同时间/范围/口径下跨页一致；单位、分项和环比有独立样本断言；床位占用≤开放 |
| 4 | 剧情可讲 | 合成场景与已实现告警/工单状态相互印证；五级下钻未实现，办结不自动重算指标（见 simulation-plan §2） |

## 4. P3 已恢复验收项（原"远期"清单回门禁）

v1.1 清单中随 P3 批落地、恢复条件已成就的项，挪回正式门禁；剩余远期项仍保留。

**已恢复（正式门禁，回归必过）**：

| # | 验收项 | 判据 |
| :- | :--- | :--- |
| 1 | 会话闭环 | `POST /auth/login` 成功签发 `edss_sid` HttpOnly Cookie + 全量上下文；`logout` 吊销幂等 `code=0`；无会话访问受保护端点 → `20001` |
| 2 | RBAC | `/sim/*` 全端点限 `admin`（无会话 → `20001`，非 admin → `20004`）；`GET /workbench/settings/config` 限 `admin`/`president`（其余 → `20004`）；演示写面越权/范围拒绝 20005；production 异名 ?role= 闸为 20004，详细矩阵见契约与当前清单 |
| 3 | 写闭环 | 告警 `ack → dispatch → todo accept/report → alert done` / `close` 直闭环全链走通；重复/冲突状态 → `33002`/`33104`；`sys.audit_log` 落审计行 |
| 4 | sim 时钟 | `clock`/`tick`（≤43200/界校验）/`reset`（幂等）/`jobs` 台账全通；SIM_ENABLED=0 时不注册路由；合法会话走 NoRoute → 10003，无会话先返回 20001 |

**仍远期**（保留 v1.1 口径，启用后恢复验收）：五级穿透与实名验密（R01–R03）、楼宇抽屉（R09）、Token 轮换（R12）、ChatBI（R13）、仿真生成引擎（`scope=full` 全量重灌/DayGen/Intraday 生成模型/AlertScan 去重键）、契约冒烟批量断言脚本化。


## 质量整改门禁（2026-10-08）

新增偏好行为、轮询清理、金额换算与声音单元测试；后端显式授权矩阵、科室 SQL 过滤/total 一致、强制脱敏、私有大屏、完整督办闭环回归；浏览器验证偏好实际生效及吊销会话重定向。所有实库测试数据库不可达即失败，不能 Skip 为绿灯。python3 tests/deploy-config.py 校验空种子、空口令和生产 TLS/权限开关。备份恢复、迁移重跑、容器重启数据保留的实测证据登记置顶计划。医院指标对账已排除范围；合成样本的独立勾稽与范围隔离仍须验收。


## 后续标准与证据纪律

58 项前端单测、132 个 Go 测试/子测试和浏览器冒烟是此前的有限回归证据，不是覆盖率或全部质量的证明。该文档对齐轮仅静态核对；后续运行轮的138项Go测试/子测试、真实HTTPS、非空恢复和完整30分钟查询结果见 [本轮证据](quality8-evidence.md)。

真实数据获取不纳入验收；无效筛选、未知路由、权限矩阵、并发与回滚、非空恢复内容、托管 CI 和容量等仍是待完成工程任务，依次见 [置顶计划](engineering-acceptance.md)。历史结果与未测项见 [整改记录](quality-remediation-plan.md)。
