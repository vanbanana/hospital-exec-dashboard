\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM (
            SELECT date,dept_id,SUM(in_fee) AS in_fee,SUM(out_fee) AS out_fee,
                   COALESCE(SUM(in_fee) FILTER (WHERE fee_cat='drug'),0) AS in_drug,
                   COALESCE(SUM(out_fee) FILTER (WHERE fee_cat='drug'),0) AS out_drug,
                   COALESCE(SUM(in_fee+out_fee) FILTER (WHERE fee_cat='material'),0) AS mat
            FROM dwd.charge_day GROUP BY date,dept_id
        ) raw FULL JOIN dws.charge_daily daily USING (date,dept_id)
        WHERE (COALESCE(raw.in_fee,0),COALESCE(raw.out_fee,0),COALESCE(raw.in_drug,0),
               COALESCE(raw.out_drug,0),COALESCE(raw.mat,0)) IS DISTINCT FROM
              (COALESCE(daily.in_fee,0),COALESCE(daily.out_fee,0),COALESCE(daily.in_drug,0),
               COALESCE(daily.out_drug,0),COALESCE(daily.mat,0))
    ) THEN RAISE EXCEPTION 'Raw charges and aggregates differ'; END IF;
END $$;
INSERT INTO dwd.charge_day(date,dept_id,fee_cat,in_fee,out_fee)
VALUES ('2030-01-01',1,'drug',100.01,20.02),('2030-01-01',1,'material',5.05,4.04);
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM dws.charge_daily WHERE date='2030-01-01' AND dept_id=1
                   AND (in_fee,out_fee,in_drug,out_drug,mat)=(105.06,24.06,100.01,20.02,9.09))
    THEN RAISE EXCEPTION 'Charge insert mismatch'; END IF;
END $$;
UPDATE dwd.charge_day SET date='2030-01-02',dept_id=2,in_fee=200.02,out_fee=30.03
WHERE date='2030-01-01' AND dept_id=1 AND fee_cat='drug';
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM dws.charge_daily WHERE date='2030-01-01' AND dept_id=1
                   AND (in_fee,out_fee,in_drug,out_drug,mat)=(5.05,4.04,0,0,9.09))
       OR NOT EXISTS (SELECT 1 FROM dws.charge_daily WHERE date='2030-01-02' AND dept_id=2
                   AND (in_fee,out_fee,in_drug,out_drug,mat)=(200.02,30.03,200.02,30.03,0))
    THEN RAISE EXCEPTION 'Charge update/move mismatch'; END IF;
END $$;
DELETE FROM dwd.charge_day WHERE date IN ('2030-01-01','2030-01-02');
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM dws.charge_daily WHERE date IN ('2030-01-01','2030-01-02')
               AND (in_fee,out_fee,in_drug,out_drug,mat) IS DISTINCT FROM (0,0,0,0,0))
    THEN RAISE EXCEPTION 'Charge delete mismatch'; END IF;
END $$;
ROLLBACK;
BEGIN;
TRUNCATE dwd.charge_day;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM dws.charge_daily) THEN RAISE EXCEPTION 'Charge truncate mismatch'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS: charge equality, insert, update/move, delete, truncate and rollback';
