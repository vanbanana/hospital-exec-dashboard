LOCK TABLE dwd.charge_day IN SHARE ROW EXCLUSIVE MODE;

CREATE TABLE dws.charge_daily (
    date date NOT NULL,
    dept_id bigint NOT NULL REFERENCES dim.department(id),
    in_fee numeric NOT NULL,
    out_fee numeric NOT NULL,
    in_drug numeric NOT NULL,
    out_drug numeric NOT NULL,
    mat numeric NOT NULL,
    PRIMARY KEY (date,dept_id)
);

INSERT INTO dws.charge_daily
SELECT date,dept_id,SUM(in_fee),SUM(out_fee),
       COALESCE(SUM(in_fee) FILTER (WHERE fee_cat='drug'),0),
       COALESCE(SUM(out_fee) FILTER (WHERE fee_cat='drug'),0),
       COALESCE(SUM(in_fee+out_fee) FILTER (WHERE fee_cat='material'),0)
FROM dwd.charge_day GROUP BY date,dept_id;

CREATE FUNCTION dws.sync_charge_daily() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE source_sql text;
BEGIN
    -- Only fixed transition-table statements enter the dynamic query.
    IF TG_OP='INSERT' THEN
        source_sql := 'SELECT date,dept_id,in_fee,out_fee,fee_cat FROM new_rows';
    ELSIF TG_OP='DELETE' THEN
        source_sql := 'SELECT date,dept_id,-in_fee AS in_fee,-out_fee AS out_fee,fee_cat FROM old_rows';
    ELSE
        source_sql := 'SELECT date,dept_id,in_fee,out_fee,fee_cat FROM new_rows
                       UNION ALL SELECT date,dept_id,-in_fee,-out_fee,fee_cat FROM old_rows';
    END IF;
    EXECUTE 'INSERT INTO dws.charge_daily AS target
        SELECT date,dept_id,SUM(in_fee),SUM(out_fee),
               COALESCE(SUM(in_fee) FILTER (WHERE fee_cat=''drug''),0),
               COALESCE(SUM(out_fee) FILTER (WHERE fee_cat=''drug''),0),
               COALESCE(SUM(in_fee+out_fee) FILTER (WHERE fee_cat=''material''),0)
        FROM ('||source_sql||') delta GROUP BY date,dept_id ORDER BY date,dept_id
        ON CONFLICT (date,dept_id) DO UPDATE SET
            in_fee=target.in_fee+EXCLUDED.in_fee, out_fee=target.out_fee+EXCLUDED.out_fee,
            in_drug=target.in_drug+EXCLUDED.in_drug, out_drug=target.out_drug+EXCLUDED.out_drug,
            mat=target.mat+EXCLUDED.mat';
    RETURN NULL;
END;
$$;

CREATE FUNCTION dws.truncate_charge_daily() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM dws.charge_daily;
    RETURN NULL;
END;
$$;

CREATE TRIGGER charge_daily_insert AFTER INSERT ON dwd.charge_day
REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION dws.sync_charge_daily();
CREATE TRIGGER charge_daily_update AFTER UPDATE ON dwd.charge_day
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION dws.sync_charge_daily();
CREATE TRIGGER charge_daily_delete AFTER DELETE ON dwd.charge_day
REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION dws.sync_charge_daily();
CREATE TRIGGER charge_daily_truncate AFTER TRUNCATE ON dwd.charge_day
FOR EACH STATEMENT EXECUTE FUNCTION dws.truncate_charge_daily();
