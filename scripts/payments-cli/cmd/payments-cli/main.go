package main

import (
	"log/slog"
	"os"

	"github.com/sunriseex/payments-cli/internal/commands"
	"github.com/sunriseex/payments-cli/internal/config"
	"github.com/sunriseex/payments-cli/internal/notifications"
	"github.com/sunriseex/payments-cli/pkg/errors"
)

func main() {
	if err := config.Init(); err != nil {
		slog.Error("Ошибка инициализации конфигурации: %v", err)
		os.Exit(1)
	}

	if err := notifications.Init(); err != nil {
		slog.Warn("Ошибка инициализации Telegram: %v", err)
	}

	if err := commands.Execute(); err != nil {
		userMsg := errors.GetUserFriendlyMessage(err)
		slog.Error("Ошибка выполнения команды",
			"command", os.Args[1],
			"error", userMsg,
			"details", err)
		os.Exit(1)
	}
}
