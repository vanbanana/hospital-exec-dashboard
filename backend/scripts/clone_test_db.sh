#!/usr/bin/env bash
# clone_test_db.sh —— 重建写测试克隆库(write_test.go / conc_test.go 基座)。
#
# 拓扑:读用例打共享库 $SRC_DB(默认 hospital_edss),写用例打克隆库
# $DST_DB(默认 hospital_edss_w,可用 DATABASE_URL_W 覆写测试侧 DSN)。
# 克隆方式=PG template 复制,结构与数据原样带走,比重跑 migrate+seed 快得多。
#
# 前置:克隆期间 $SRC_DB 不能有活动连接(先停 backend server 与跑着的测试);
#       $DST_DB 会被 dropdb 重建——克隆库本就是易失品,别往里放手工数据。
# 失败退路:源库有连接甩不开时用 pg_dump "$SRC_DB" | psql "$DST_DB"(慢,全量拷贝)。

set -euo pipefail

SRC_DB="${SRC_DB:-hospital_edss}"
DST_DB="${DST_DB:-hospital_edss_w}"

echo "==> 重建克隆库 ${DST_DB} <- ${SRC_DB}"
dropdb --if-exists "${DST_DB}"
createdb -T "${SRC_DB}" "${DST_DB}"
psql "${DST_DB}" -tAc "SELECT 'clone ok, clock=' || virtual_now FROM sim.clock WHERE id=1"
