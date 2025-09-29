package main

import (
	"log"
	"os"

	"github.com/sunriseex/payments-cli/internal/commands"
	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/notifications"
)

func main() {
	if err := config.Init(); err != nil {
		log.Fatalf("Ошибка инициализации конфигурации: %v", err)
	}

	if err := notifications.Init(); err != nil {
		log.Printf("Ошибка инициализации Telegram: %v", err)
	}

	if err := commands.Execute(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}
