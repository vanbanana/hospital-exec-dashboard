// EDSS Go 后端入口:config → pg pool → router → listen
package main

import (
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/config"
	"hospital-edss/internal/router"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}
	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	r := router.Build(&router.Deps{DB: db, Clock: clock.New(db)})
	log.Printf("edss listening :%s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("server: %v", err)
	}
}
