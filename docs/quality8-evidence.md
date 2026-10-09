# 验证范围与限制

此文档说明检查入口，不附带开发日历、耗时、评分或历史过程报告。实际验收应记录命令、输入、版本、输出及未测边界，不将配置存在或测试数量当作全部能力通过。

- 前端类型与构建：npm run build；单测：npm run test:unit。
- 后端：已初始化读/写两库后执行 Go vet/build/test -race，或 bash scripts/cloud-dev.sh test。
- 浏览器：分别验证演示和严格权限模式；HTTP 权限测试不替代 HTTPS、证书及 Secure Cookie 检查。
- 配置与运维：tests/deploy-config.py、tests/ops-test.py；配置检查不替代实际备份恢复。
- 交付：核对文件校验、锁文件、迁移/种子、干净解压构建及数据库持久化。
- 尚需目标环境独立验证：所有接口边界、非空恢复、持续读写容量、全面安全扫描、托管 CI、外部告警及高可用。

完整标准见 [acceptance.md](acceptance.md) 与 [engineering-acceptance.md](engineering-acceptance.md)。
