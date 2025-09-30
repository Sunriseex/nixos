package config

import (
	"os"
	"path/filepath"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	TelegramToken    string
	TelegramUserID   int64
	DataPath         string
	DepositsDataPath string
	LedgerPath       string
}

var AppConfig *Config

func Init() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	envPath := filepath.Join(home, "nixos/scripts/payments-cli/configs/.env")

	if err := godotenv.Load(envPath); err != nil {
		return err
	}

	AppConfig = &Config{
		TelegramToken:    getEnv("TELEGRAM_BOT_TOKEN", ""),
		TelegramUserID:   getEnvInt64("TELEGRAM_USER_ID", 0),
		DataPath:         expandPath(getEnv("DATA_PATH", "~/.config/waybar/payments.json")),
		DepositsDataPath: expandPath(getEnv("DEPOSITS_DATA_PATH", "~/.config/waybar/deposits.json")),
		LedgerPath:       expandPath(getEnv("LEDGER_PATH", "~/ObsidianVault/finances/transactions.ledger")),
	}

	return nil
}

func expandPath(path string) string {
	if len(path) > 0 && path[0] == '~' {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[1:])
	}
	return path
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
