package repo

import (
	"context"
	"fmt"
	"math"
	"os"
	"sync"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func rollupDB(t *testing.T) *gorm.DB {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL_W")
	if dsn == "" {
		t.Skip("DATABASE_URL_W required for isolated write fixtures")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal("Cannot connect to isolated write database")
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	sqlDB.SetMaxOpenConns(16)
	t.Cleanup(func() { sqlDB.Close() })
	return db
}

func TestHourlySumDailyAndPartialWindows(t *testing.T) {
	db := rollupDB(t).Begin()
	t.Cleanup(func() { db.Rollback() })
	if err := db.Exec(`INSERT INTO dwd.outpatient_hourly(stat_time,dept_id,emerg_flag,visit_cnt,expert_cnt,wait_min_sum,fee_total)
		VALUES ('2031-01-01 15:59+00',1,false,3,1,6.1,10.01),('2031-01-01 16:00+00',1,true,4,2,8.2,20.02)`).Error; err != nil {
		t.Fatal(err)
	}
	r := &Ops{db: db}
	day := time.Date(2031, 1, 2, 0, 0, 0, 0, simLoc)
	for _, fixture := range []struct {
		name  string
		win   RangeWin
		visit int64
		fee   float64
	}{
		{"local day", RangeWin{Start: day, End: day.AddDate(0, 0, 1)}, 4, 20.02},
		{"same boundaries in UTC", RangeWin{Start: day.UTC(), End: day.AddDate(0, 0, 1).UTC()}, 4, 20.02},
		{"partial day raw facts", RangeWin{Start: day.Add(-time.Minute), End: day}, 3, 10.01},
		{"empty future", RangeWin{Start: day.AddDate(0, 0, 2), End: day.AddDate(0, 0, 3)}, 0, 0},
	} {
		t.Run(fixture.name, func(t *testing.T) {
			got, err := r.HourlySum(context.Background(), fixture.win)
			if err != nil || got.Visit != fixture.visit || math.Abs(got.FeeTotal-fixture.fee) > 1e-9 {
				t.Fatalf("sum=%+v error=%v want visit=%d fee=%f", got, err, fixture.visit, fixture.fee)
			}
		})
	}
}

func TestConcurrentHourlyRollupHasNoLostUpdates(t *testing.T) {
	db := rollupDB(t)
	var existing int64
	if err := db.Raw(`SELECT count(*) FROM dwd.outpatient_hourly WHERE stat_time >= '2031-02-01 00:00+08' AND stat_time < '2031-02-02 00:00+08'`).Scan(&existing).Error; err != nil || existing != 0 {
		t.Fatal("Concurrent fixture requires an unused synthetic day")
	}
	t.Cleanup(func() {
		db.Exec(`DELETE FROM dwd.outpatient_hourly WHERE stat_time >= '2031-02-01 00:00+08' AND stat_time < '2031-02-02 00:00+08'`)
		db.Exec(`DELETE FROM dws.outpatient_daily WHERE date='2031-02-01' AND visit=0 AND fee_total=0`)
	})
	start := make(chan struct{})
	errors := make(chan error, 8)
	var workers sync.WaitGroup
	for i := 0; i < 8; i++ {
		workers.Add(1)
		go func(i int) {
			defer workers.Done()
			<-start
			stamp := time.Date(2031, 2, 1, 0, i, 0, 0, simLoc)
			errors <- db.Transaction(func(tx *gorm.DB) error {
				return tx.Exec(`INSERT INTO dwd.outpatient_hourly(stat_time,dept_id,emerg_flag,visit_cnt,expert_cnt,wait_min_sum,fee_total)
					VALUES (?,1,?,?,1,2.5,12.34)`, stamp, i%2 == 0, i+1).Error
			})
		}(i)
	}
	close(start)
	workers.Wait()
	close(errors)
	for err := range errors {
		if err != nil {
			t.Fatal(err)
		}
	}
	day := time.Date(2031, 2, 1, 0, 0, 0, 0, simLoc)
	got, err := (&Ops{db: db}).HourlySum(context.Background(), RangeWin{Start: day, End: day.AddDate(0, 0, 1)})
	if err != nil || got.Visit != 36 || got.Expert != 8 || got.EmergVisit != 16 || got.WaitMinSum != 20 || math.Abs(got.FeeTotal-98.72) > 1e-9 {
		t.Fatal(fmt.Sprintf("Concurrent aggregate=%+v error=%v", got, err))
	}
}
