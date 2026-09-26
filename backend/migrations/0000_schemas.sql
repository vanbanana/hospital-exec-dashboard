-- ============================================================================
-- file: migrations/0000_bootstrap.sql  lane: 全局前置（总架构师收口）
-- 作用：六 schema + 全库公共扩展，所有 lane 的 DDL 之前唯一一次执行。
-- 修复：阶段3审核 M1/B1 —— 原约定"首个使用该 schema 的文件头自建行"只落在
--       sys/dim/ads 三 lane，dwd/dws/sim 无 CREATE SCHEMA，干净库 apply 断链。
--       现统一收口到本文件，各 lane ddl.sql 内不再自建 schema。
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS sys;   -- 账号/字典/指标定义/审计/通知/数据源/偏好
CREATE SCHEMA IF NOT EXISTS dim;   -- 主数据维度（组织/人员/病组/病区/设备/物资/学科/日期）
CREATE SCHEMA IF NOT EXISTS dwd;   -- 明细事实（仿真器·未来 ETL 独占写）
CREATE SCHEMA IF NOT EXISTS dws;   -- 日/周期汇总（派生流水线独占写）
CREATE SCHEMA IF NOT EXISTS ads;   -- 应用集市（告警/督办/排名/实时快照）
CREATE SCHEMA IF NOT EXISTS sim;   -- 仿真控制（时钟/参数/作业日志，生产可按 env 跳过本 schema 内全部对象）

COMMENT ON SCHEMA sys IS '系统域：账号、字典、指标定义、审计、通知、数据源、偏好';
COMMENT ON SCHEMA dim IS '维度域：主数据维度，迁移+主数据同步写入，API 可读';
COMMENT ON SCHEMA dwd IS '明细事实域：仿真器/ETL 独占写，API 仅白名单直读';
COMMENT ON SCHEMA dws IS '汇总域：日/周期聚合，派生流水线独占写，API 默认可读';
COMMENT ON SCHEMA ads IS '应用集市域：面向页面/大屏的应用表，API 直读';
COMMENT ON SCHEMA sim IS '仿真域：虚拟时钟/参数/作业日志，不向 API 暴露（契约 §15 R14 预留）';

-- 公共扩展：当前 DDL/种子仅用内建函数（md5/generate_series/setseed），无强制依赖。
-- pgcrypto 为 U9 预留位（drg_case.patient_name 真实期加密方案启用前必先审计链）；
-- 演示期可不装——若部署环境禁扩展，删除本行不影响 0001-0503 全链 apply。
CREATE EXTENSION IF NOT EXISTS pgcrypto;
