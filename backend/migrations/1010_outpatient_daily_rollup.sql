-- Keep the source and rollup atomic, including writes during migration.
LOCK TABLE dwd.outpatient_hourly IN SHARE ROW EXCLUSIVE MODE;

CREATE TABLE dws.outpatient_daily (
    date date PRIMARY KEY,
    visit bigint NOT NULL,
    expert bigint NOT NULL,
    emerg_visit bigint NOT NULL,
    wait_min_sum numeric NOT NULL,
    fee_total numeric NOT NULL
);

INSERT INTO dws.outpatient_daily
SELECT (stat_time AT TIME ZONE 'Asia/Shanghai')::date,
       COALESCE(SUM(visit_cnt),0), COALESCE(SUM(expert_cnt),0),
       COALESCE(SUM(visit_cnt) FILTER (WHERE emerg_flag),0),
       COALESCE(SUM(wait_min_sum),0), COALESCE(SUM(fee_total),0)
FROM dwd.outpatient_hourly GROUP BY 1;

CREATE FUNCTION dws.sync_outpatient_daily() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO dws.outpatient_daily AS target
        SELECT (stat_time AT TIME ZONE 'Asia/Shanghai')::date,
               COALESCE(SUM(visit_cnt),0), COALESCE(SUM(expert_cnt),0),
               COALESCE(SUM(visit_cnt) FILTER (WHERE emerg_flag),0),
               COALESCE(SUM(wait_min_sum),0), COALESCE(SUM(fee_total),0)
        FROM new_rows GROUP BY 1 ORDER BY 1
        ON CONFLICT (date) DO UPDATE SET
            visit=target.visit+EXCLUDED.visit, expert=target.expert+EXCLUDED.expert,
            emerg_visit=target.emerg_visit+EXCLUDED.emerg_visit,
            wait_min_sum=target.wait_min_sum+EXCLUDED.wait_min_sum,
            fee_total=target.fee_total+EXCLUDED.fee_total;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO dws.outpatient_daily AS target
        SELECT (stat_time AT TIME ZONE 'Asia/Shanghai')::date,
               -COALESCE(SUM(visit_cnt),0), -COALESCE(SUM(expert_cnt),0),
               -COALESCE(SUM(visit_cnt) FILTER (WHERE emerg_flag),0),
               -COALESCE(SUM(wait_min_sum),0), -COALESCE(SUM(fee_total),0)
        FROM old_rows GROUP BY 1 ORDER BY 1
        ON CONFLICT (date) DO UPDATE SET
            visit=target.visit+EXCLUDED.visit, expert=target.expert+EXCLUDED.expert,
            emerg_visit=target.emerg_visit+EXCLUDED.emerg_visit,
            wait_min_sum=target.wait_min_sum+EXCLUDED.wait_min_sum,
            fee_total=target.fee_total+EXCLUDED.fee_total;
    ELSE
        INSERT INTO dws.outpatient_daily AS target
        SELECT day, SUM(visit), SUM(expert), SUM(emerg_visit), SUM(wait_min_sum), SUM(fee_total)
        FROM (
            SELECT (stat_time AT TIME ZONE 'Asia/Shanghai')::date AS day,
                   COALESCE(visit_cnt,0)::bigint AS visit, COALESCE(expert_cnt,0)::bigint AS expert,
                   CASE WHEN emerg_flag THEN COALESCE(visit_cnt,0)::bigint ELSE 0 END AS emerg_visit,
                   COALESCE(wait_min_sum,0) AS wait_min_sum, COALESCE(fee_total,0) AS fee_total
            FROM new_rows
            UNION ALL
            SELECT (stat_time AT TIME ZONE 'Asia/Shanghai')::date,
                   -COALESCE(visit_cnt,0)::bigint, -COALESCE(expert_cnt,0)::bigint,
                   CASE WHEN emerg_flag THEN -COALESCE(visit_cnt,0)::bigint ELSE 0 END,
                   -COALESCE(wait_min_sum,0), -COALESCE(fee_total,0)
            FROM old_rows
        ) delta GROUP BY day ORDER BY day
        ON CONFLICT (date) DO UPDATE SET
            visit=target.visit+EXCLUDED.visit, expert=target.expert+EXCLUDED.expert,
            emerg_visit=target.emerg_visit+EXCLUDED.emerg_visit,
            wait_min_sum=target.wait_min_sum+EXCLUDED.wait_min_sum,
            fee_total=target.fee_total+EXCLUDED.fee_total;
    END IF;
    RETURN NULL;
END;
$$;

CREATE FUNCTION dws.truncate_outpatient_daily() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM dws.outpatient_daily;
    RETURN NULL;
END;
$$;

CREATE TRIGGER outpatient_daily_insert AFTER INSERT ON dwd.outpatient_hourly
REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION dws.sync_outpatient_daily();
CREATE TRIGGER outpatient_daily_update AFTER UPDATE ON dwd.outpatient_hourly
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION dws.sync_outpatient_daily();
CREATE TRIGGER outpatient_daily_delete AFTER DELETE ON dwd.outpatient_hourly
REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION dws.sync_outpatient_daily();
CREATE TRIGGER outpatient_daily_truncate AFTER TRUNCATE ON dwd.outpatient_hourly
FOR EACH STATEMENT EXECUTE FUNCTION dws.truncate_outpatient_daily();
