package config

import (
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/joho/godotenv"

	"github.com/sunriseex/payments-cli/pkg/errors"
)

type Config struct {
	TelegramToken    string
	TelegramUserID   int64
	DataPath         string
	DepositsDataPath string
	LedgerPath       string
	LogLevel         slog.Level
}

var AppConfig *Config

func Init() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return errors.NewConfigurationError("не удалось получить домашнюю директорию", err)
	}

	envPaths := []string{
		filepath.Join(home, "nixos/scripts/payments-cli/configs/.env"),
		filepath.Join(home, "nixos/scripts/payment-cli/configs/.env"),
		"./configs/.env",
		".env",
	}

	var loaded bool
	for _, envPath := range envPaths {
		if err := godotenv.Load(envPath); err == nil {
			loaded = true
			break
		}
	}

	if !loaded {
		return err
	}

	dataPath, err := expandPath(getEnv("DATA_PATH", "~/.config/waybar/payments.json"))
	if err != nil {
		return errors.NewConfigurationError("ошибка расширения пути DATA_PATH", err)
	}

	depositsDataPath, err := expandPath(getEnv("DEPOSITS_DATA_PATH", "~/.config/waybar/deposits.json"))
	if err != nil {
		return errors.NewConfigurationError("ошибка расширения пути DEPOSITS_DATA_PATH", err)
	}

	ledgerPath, err := expandPath(getEnv("LEDGER_PATH", "~/ObsidianVault/finances/transactions.ledger"))
	if err != nil {
		return errors.NewConfigurationError("ошибка расширения пути LEDGER_PATH", err)
	}

	AppConfig = &Config{
		TelegramToken:    getEnv("TELEGRAM_BOT_TOKEN", ""),
		TelegramUserID:   getEnvInt64("TELEGRAM_USER_ID", 0),
		DataPath:         dataPath,
		DepositsDataPath: depositsDataPath,
		LedgerPath:       ledgerPath,
	}

	logLevel := slog.LevelError
	if envLogLevel := os.Getenv("LOG_LEVEL"); envLogLevel != "" {
		switch envLogLevel {
		case "debug":
			logLevel = slog.LevelDebug
		case "info":
			logLevel = slog.LevelInfo
		case "warn":
			logLevel = slog.LevelWarn
		case "error":
			logLevel = slog.LevelError
		}
	}
	AppConfig.LogLevel = logLevel
	initLogger(logLevel)

	return nil
}

func initLogger(level slog.Level) {
	handler := slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: level,
	})
	slog.SetDefault(slog.New(handler))
}

func expandPath(path string) (string, error) {
	if path == "" {
		return "", errors.NewConfigurationError("путь не может быть пустым", nil)
	}

	if strings.HasPrefix(path, "~/") || path == "~" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", errors.NewConfigurationError("не удалось получить домашнюю директорию", err)
		}

		if path == "~" {
			return home, nil
		}
		return filepath.Join(home, path[2:]), nil
	}

	return filepath.Abs(path)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt64(key string, defaultValue int64) int64 {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.ParseInt(value, 10, 64); err == nil {
			return intValue
		}
	}
	return defaultValue
}
