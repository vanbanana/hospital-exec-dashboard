\set ON_ERROR_STOP on
-- Independent raw-fact comparison; all synthetic mutations roll back.
BEGIN;
SET TIME ZONE 'UTC';
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM (
            SELECT (stat_time AT TIME ZONE 'Asia/Shanghai')::date AS date,
                   SUM(visit_cnt) AS visit, SUM(expert_cnt) AS expert,
                   COALESCE(SUM(visit_cnt) FILTER (WHERE emerg_flag),0) AS emerg_visit,
                   SUM(wait_min_sum) AS wait_min_sum, SUM(fee_total) AS fee_total
            FROM dwd.outpatient_hourly GROUP BY 1
        ) raw FULL JOIN dws.outpatient_daily daily USING (date)
        WHERE (COALESCE(raw.visit,0),COALESCE(raw.expert,0),COALESCE(raw.emerg_visit,0),
               COALESCE(raw.wait_min_sum,0),COALESCE(raw.fee_total,0))
           IS DISTINCT FROM
              (COALESCE(daily.visit,0),COALESCE(daily.expert,0),COALESCE(daily.emerg_visit,0),
               COALESCE(daily.wait_min_sum,0),COALESCE(daily.fee_total,0))
    ) THEN RAISE EXCEPTION 'Raw facts and daily aggregates differ'; END IF;
END $$;

INSERT INTO dwd.outpatient_hourly(stat_time,dept_id,emerg_flag,visit_cnt,expert_cnt,wait_min_sum,fee_total)
VALUES ('2030-01-01 15:59+00',1,false,3,1,6.1,10.01),
       ('2030-01-01 16:00+00',1,true,4,2,8.2,20.02);
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dws.outpatient_daily WHERE date='2030-01-01'
                   AND (visit,expert,emerg_visit,wait_min_sum,fee_total)=(3,1,0,6.1,10.01))
       OR NOT EXISTS (SELECT 1 FROM dws.outpatient_daily WHERE date='2030-01-02'
                   AND (visit,expert,emerg_visit,wait_min_sum,fee_total)=(4,2,4,8.2,20.02))
    THEN RAISE EXCEPTION 'Insert or timezone boundary mismatch'; END IF;
END $$;

UPDATE dwd.outpatient_hourly SET stat_time='2030-01-01 16:01+00', emerg_flag=true,
    visit_cnt=5,expert_cnt=2,wait_min_sum=12.3,fee_total=30.03
WHERE stat_time='2030-01-01 15:59+00' AND dept_id=1 AND NOT emerg_flag;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dws.outpatient_daily WHERE date='2030-01-01'
                   AND (visit,expert,emerg_visit,wait_min_sum,fee_total)=(0,0,0,0,0))
       OR NOT EXISTS (SELECT 1 FROM dws.outpatient_daily WHERE date='2030-01-02'
                   AND (visit,expert,emerg_visit,wait_min_sum,fee_total)=(9,4,9,20.5,50.05))
    THEN RAISE EXCEPTION 'Update or cross-day move mismatch'; END IF;
END $$;

DELETE FROM dwd.outpatient_hourly WHERE stat_time >= '2030-01-01 00:00+00' AND dept_id=1;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM dws.outpatient_daily WHERE date IN ('2030-01-01','2030-01-02')
               AND (visit,expert,emerg_visit,wait_min_sum,fee_total) IS DISTINCT FROM (0,0,0,0,0))
    THEN RAISE EXCEPTION 'Delete mismatch'; END IF;
END $$;
ROLLBACK;

BEGIN;
TRUNCATE dwd.outpatient_hourly;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM dws.outpatient_daily) THEN RAISE EXCEPTION 'Truncate mismatch'; END IF;
END $$;
ROLLBACK;

SELECT 'PASS: raw equality, timezone, insert, update, delete, truncate and rollback';
