# 部署入口

执行步骤以 [部署与恢复手册](../docs/production-deploy.md) 为准，当前事实见 [实现清单](../docs/current-state.md)，历史证据见 [整改记录](../docs/quality-remediation-plan.md)，下一轮标准见 [工程计划](../docs/engineering-acceptance.md)。

- docker-compose.yml：本地演示基础栈，默认不灌种子。
- docker-compose.edssprod.yml：演示隔离端口与镜像内自签证书。
- docker-compose.production.yml：强制安全开关、HTTPS、正式证书文件挂载，缺口令或证书失败。只表示部署配置；使用已初始化的合成库验证，仍标 demo，不要求医院数据。
- docker-compose.cloud.yml：云代理 CA 的 BuildKit 临时信任挂载。
- Dockerfile：官方依赖源；会话 CA 不进入镜像层；应用后端以非 root 运行。

前端 Node >=22.12；后端 Go1.27；数据库 PG16。首次演示种子较大，等待 backend healthy；禁止向真实库灌演示种子，禁止用 down -v 作为日常重启。

ops.env.example 与 systemd/ 提供周期备份、巡检和资源采样模板。脚本与指标说明见 [运维性能手册](../docs/operations-performance.md)；须按实际部署配置后安装启用。

使用 `scripts/build-images.sh`（或 `make build-images`）串行构建，逐目标预检6GiB空闲并检查后端非root SQL读取权限；云CA由secret传入。无systemd云会话使用 `python3 scripts/ops.py run` 前台调度，避免与定时器重复。实际结果与失败见 [本轮证据](../docs/quality8-evidence.md)。
