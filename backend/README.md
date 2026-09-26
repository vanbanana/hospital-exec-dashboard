# backend/ — 数据库迁移与种子（PostgreSQL）

> **状态**：可实施生产库设计（演示期用同一套种子灌出契约锚点数据）。
> **来源**：由 `/tmp/modeling/schema/` 10 个建模 lane 经 3 轮独立审核（0 BLOCKER/0 MAJOR）后装配。
> **目标**：PostgreSQL 15+（开发验证用 15.15 实测通过；生产建议 16）。

## 目录

```
migrations/   # 结构迁移，按文件名序号顺序执行（0000 → 0900）
seed/         # 确定性种子，按文件名序号顺序执行（1001 → 5001）
```

## 快速验证（干净库）

```bash
createdb hospital_edss
for f in migrations/*.sql; do psql -d hospital_edss -v ON_ERROR_STOP=1 -f "$f"; done
for f in seed/*.sql;       do psql -d hospital_edss -v ON_ERROR_STOP=1 -f "$f"; done
```

## 执行顺序约定

### migrations/（12 个文件）

| 序 | 文件 | 内容 |
|---|---|---|
| 0000 | `0000_schemas.sql` | 六 schema（sys/dim/dwd/dws/ads/sim）唯一属主 |
| 0100 | `0100_sys_org.sql` | sys 系统域（user/dict/metric_def/audit/notice/data_source/user_pref） |
| 0110 | `0110_dim_public.sql` | dim 公共维度（date/campus/building/department/staff/drg_group/ward/device/drug） |
| 0120/0130 | newdom 两域 | L8 维表（material/discipline）与 dwd 事实表（hr_cost/research/feedback/critical/infection/adverse/energy/supply） |
| 0200/0210 | dwd 两域 | 业务流事实（outpatient_hourly/inpatient_move/bed_state_day/charge_day/insurance）+ 临床事实（surgery_case/drg_case） |
| 0300 | `0300_dws_agg.sql` | dws 聚合层（hospital_oper_day/dept_oper_day/drg_dept_period/metric_value） |
| 0400/0410 | ads 两域 | 工作台集市（work_item/dept_rank_day/radar/benchmark/exam_indicator）+ 大屏集市（alert/today_kpi/campus_status） |
| 0500 | `0500_sim.sql` | 仿真时钟/参数/日志 |
| 0900 | `0900_sys_user_dept_fk.sql` | **延迟挂载**：`fk_user_department` ON DELETE RESTRICT（防科室删除静默升格账号权限） |

### seed/（13 个文件，相位序）

| 相位 | 文件 | 内容 |
|---|---|---|
| Ⅰa 定义 | `1001_sys_defs.sql` + `1002_l8_defs.sql` | sys.dict 全行 + sys.metric_def 全行（各 lane 供稿已并入） |
| Ⅰb 维度 | `1100_dim_public.sql` | 科室 81 / 人员 2,368 / DRG 病组 / 病区床位 / 设备 68 台 |
| Ⅱ.pre | `1150_sys_deferred.sql` | user.dept_id 回填 + 环 FK 收口 |
| Ⅱ 事实 | `2010/2020/203x` | dwd 全事实（门诊 41 万行/住院移动 33 万/DRG 10.4 万/手术 2.4 万） |
| Ⅲa 聚合 | `3001_dws_agg.sql` | 日/周期聚合，全部 `INSERT…SELECT` 自 dwd 派生 |
| Ⅲb 集市 | `3020/3030` | 工作台与大屏集市，事实层派生 ±10% 容差 |
| Ⅳ 仿真 | `5001_sim.sql` | sim.clock 锚定 BASE_DATE=2026-10-28 |

## 关键纪律

- **幂等**：所有种子可重复执行（ON CONFLICT DO NOTHING + 键域 DELETE 先导 + identity `setval` 后移）。
- **确定性**：零 `random()`/零 `now()`——伪随机一律 `md5(主键)` 派生，全库可复现。
- **锚点**（详见 `docs/database-schema.md` §勾稽）：BASE_DATE=2026-10-28；在院 1,846 / 床用 92.1% / 月出院 8,110 / ALOS 6.8 / 月门急诊 123,443 / 月医疗收入 14,800 万（住院 71%·门诊 25%·其他 4%）。
- **费用真源**：`dwd.charge_day`（门诊次均≈300 元 / 住院次均≈13,000 元）；`outpatient_hourly.fee_total` 逐日归一到 charge_day。
- `backend/` 下 SQL 与 `/tmp/modeling/schema/` lane 源文件一一对应；改数据请改 lane 源再装配，勿直接改本目录。
